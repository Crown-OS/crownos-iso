# Publishing CrownOS

`components.toml` pins every CrownOS package. Pinning a new version there and
merging it is the only way a component version enters the system; an ISO tag is
the only way it reaches installed systems.

## Channels

Every channel is a GitHub release of Crown-OS/crownos-iso, signed with
`packages@crownos.org`:

| Release | Holds |
|---|---|
| `repo-testing` | every push to main |
| `repo-stable` | written only by an ISO tag, after its install test |
| `repo-<tag>` | immutable copy of what each tag shipped |

Each holds, flat, the packages, their detached `.sig` files, `crownos.{db,files}`
as real files (release assets have no symlinks), `manifest.toml(.sig)`,
`notes.md(.sig)` and `crownos.asc`. None of them is ever the latest release, and
their tags never match the `v*` triggers. `https://repo.crownos.org` is a
Cloudflare redirect (302) onto the release downloads. `<channel>` is `testing`,
`stable` or a tag such as `v0.4.2`:

| Request | Redirects to `https://github.com/Crown-OS/crownos-iso/releases/download/…` |
|---|---|
| `/<channel>/x86_64/<file>` | `repo-<channel>/<file>` |
| `/<channel>/manifest.toml(.sig)` | `repo-<channel>/manifest.toml(.sig)` |
| `/<channel>/notes.md(.sig)` | `repo-<channel>/notes.md(.sig)` |
| `/crownos.asc` | `repo-stable/crownos.asc` |

An installed system is pinned to the release it runs. The installer writes the
channel of the installed release (`testing` for a testing build):

```
[crownos]
SigLevel = Required DatabaseOptional
Server = https://repo.crownos.org/v<installed>/$arch
```

Because of this, a plain `pacman -Syu` does not install packages of a newer
CrownOS release. Only `crownos-updated` changes this line: after a successful
update it writes the channel of the release it installed. It reads the index
channel (`stable`, or `testing` for a testing install) only to find the next
release.

A published `manifest.toml` names the release and the set an installed system
must have:

```toml
version = "0.4.2"
build_id = "<crownos-iso commit>"
channel = "stable"                           # testing builds: "testing"
restart = "soft-reboot"                      # session | soft-reboot | reboot
notes = "notes.md"                           # the file beside the manifest
releases = ["0.1.0", "0.1.2", ..., "0.4.2"]  # every v* tag up to version
packages = ["crownpositor", "crownbar", ...] # what to sync: system packages only

[[package]]
name = "crownbar"
version = "0.4.0-1"                          # one per package in the repository
```

`version` and `build_id` are read from the `crownos-release` package in the
repository, so the manifest always describes the bytes beside it. Testing builds
are versioned `X.Y.Z.rN.g<sha>` (N commits after tag vX.Y.Z), which `vercmp`
orders above vX.Y.Z and below the next tag.

- `restart` comes from `releases/<version>/release.toml` (see Releases). A
  testing build without that file gets `reboot`.
- `releases` is the order in which installed systems update. `crownos-updated`
  installs only the first release that is newer than the installed one, so it
  never skips a release. A testing build adds its own version at the end.
- `notes` names `notes.md`, which `scripts/notes.sh` writes and the publish
  scripts sign beside the manifest.

## Flow (.github/workflows/release.yml)

| Event | Jobs |
|---|---|
| pull request | `check`: `just check`, then `manifest.sh resolve`; nothing is signed or uploaded |
| push to main | `resolve` (resolve, sign, publish `repo-testing`) → `build` (build the ISO at zstd level 6, then install it in QEMU); the ISO is skipped when the commit is tagged, since the tag's run builds it |
| `v*` tag | `resolve` (`gate.sh` first, nothing published) → `build` (build the ISO at zstd level 19, then install it in QEMU) → `publish` (ISO to Backblaze B2, then the GitHub release with `notes.sh` as its body, then the SourceForge mirror) ∥ `promote` (the tested repository and its notes to `repo-<tag>` and `repo-stable`) → `pkgbuilds` |
| `component-updated` dispatch | `bump.yml` opens a pull request pinning the release |

Main pushes publish testing one at a time (`crownos-testing` concurrency group);
promotions are serialized on `crownos-stable`. A tag run never writes testing.
`promote.sh` signs the repository artifact itself and checks that its
`crownos-release` matches the tag's version and commit. Re-running a tag is safe:
the same build continues where it stopped, another build for a published tag is
refused, and a stable that already holds a newer version is left alone
(`promote.sh TAG DIR --force-stable` rolls stable back on purpose).

## Releases

Each release has a directory `releases/<X.Y.Z>/` (see `releases/README.md`).
Write it in the pull request before the tag.

| File | Required | Use |
|---|---|---|
| `release.toml` | yes | `restart = "session" \| "soft-reboot" \| "reboot"`, copied into the manifest |
| `notes.md` | yes | the hand-written highlights |
| `post-update.sh` | no | `crownos-release` installs it as `/usr/lib/crownos/post-update` |

- On a tag, `gate.sh` stops the build when `release.toml` or `notes.md` is
  missing, when `restart` is not one of the three values, or when
  `post-update.sh` fails `bash -n`. `just check` lints each `post-update.sh`
  with `bash -n` and shellcheck.
- `scripts/notes.sh <version>` writes the release notes: `notes.md` (or a short
  header for a testing build), then `## Components` with one section for each
  component whose pin changed since the previous `v*` tag. Each section holds
  the component's GitHub release notes. The publish scripts sign the result as
  `notes.md` beside the manifest, and the tag's GitHub release uses it as its
  body. The kernel is not in the list.
- `crownos-updated` runs `/usr/lib/crownos/post-update` as root after the pacman
  transaction, with `CROWNOS_FROM_VERSION` and `CROWNOS_TO_VERSION`. When it
  fails, the update fails. Every local user can see its output in the update
  state, so it must not print secrets. The daemon runs a failed script again,
  so each script must be safe to run more than one time.
- A tagged install steps through the tags one at a time. A testing install
  follows the testing channel: its next release is the current testing build.
- The restart kinds: `session` restarts the desktop (the compositor exits with
  status 75 and `crownos-desktop` starts it again), `soft-reboot` restarts all
  user space (`systemctl soft-reboot`), `reboot` restarts the computer.

Before each update `crownos-updated` takes a snapper snapshot, keeps the
current kernel pair in `EFI/CrownOS/rollback/` (`crownos-esp-kernel keep`) and
writes `EFI/refind/crownos-rollback.conf`. To go back, hold Space while the
computer starts and choose "Rollback to CrownOS <from>". The initramfs hook
`crownos-recover` then makes a writable copy of that snapshot the root, and
`crownos-recover-finish.service` copies the kept kernel pair back
(`crownos-esp-kernel restore`).

## components.toml

```toml
[[package]]
name = "crownbar"
repo = "Crown-OS/crownbar"
tag = "v0.3.0"
asset = "crownbar-0.3.0-1-x86_64.pkg.tar.zst"
sha256 = "<hex>"
siblings = { crownui = "<commit>", llts-protocol = "<commit>" }

[[package]]
name = "crownos-base"
source = "packaging/crownos-base"
```

- A release entry reuses the package the component's release publishes; the
  asset is downloaded and checked against `sha256`. A source entry is built from
  that directory with `makepkg` at the ISO version.
- `siblings` is copied from the release's `siblings.lock`: the sibling commits the
  package was built against. Absent means unknown; `{}` means it has none.
  `gen-pkgbuilds.sh` skips packages whose siblings are unknown.
- `install = "system" | "live" | "optional"` (default `system`): `system` packages
  are in every installed system and in the published `packages` list, `live` only
  in the live image (`crownos-installer`), `optional` only in the repository
  (`crownos-source`).
- `pkgbuild = "<path>"`: the repository's own PKGBUILD that `gen-pkgbuilds.sh`
  uses instead of the generic Rust template (with every file and subdirectory
  beside it, such as `snapd.install` or `systemd/`). The PKGBUILD can build its
  own checkout through `_workspace="$startdir/.."` or `"$startdir/../.."`.
- `allow_stale = true`: let a tag build ship this release although the
  repository's default branch has moved on.

Never edit pins by hand: `just pin Crown-OS/crownbar v0.4.0` (or
`just pin --latest Crown-OS/crownbar`) downloads, hashes and writes them. A pin
replaces the entry's `siblings` with the new release's lock; `install`,
`pkgbuild` and `allow_stale` are kept, so remove `allow_stale` yourself once the
repository is tagged again. `scripts/toml.py` rewrites the file canonically, so
comments are not kept.

## Scripts

| Script | Does |
|---|---|
| `manifest.sh names system\|live\|optional\|all` | lists and validates |
| `manifest.sh resolve DIR [--icon-theme CHECKOUT] [--siblings DIR]` | downloads, verifies and builds every package into DIR, indexed unsigned; the siblings directory holds the `crownos-plugins` and `crownos-config` checkouts that `crownos-agent-skills` reads (CI checks them out under `siblings/`) |
| `manifest.sh published CHANNEL DIR [PACKAGE...]` | prints the published manifest for DIR; each PACKAGE is an extra system package in DIR |
| `pin.sh` | the only writer of `components.toml` |
| `gate.sh` | fails if a pinned repository's default branch is ahead of its tag; on a tag, also checks `releases/<version>/` |
| `notes.sh VERSION` | prints the release notes of VERSION |
| `publish.sh testing DIR` | signs DIR and uploads it as `repo-testing` |
| `promote.sh TAG DIR` | signs DIR and uploads it as `repo-TAG` and `repo-stable` |
| `gen-pkgbuilds.sh DIR OUT` | writes the crownos-source PKGBUILDs |
| `export-key.sh KEY` | writes the public key into `packaging/crownos-keyring/` |
| `build.sh [--repo DIR] [--installer CHECKOUT]` | builds the ISO from a resolved repository |
| `b2-publish.sh FILE...` | uploads the files to the B2 bucket behind `download.crownos.org`, then deletes all other file versions in the bucket |

`build.sh` reads the resolved repository with `SigLevel = Never`: its assets were
checked against their pinned sha256 and its database was built locally, and a
repository `publish.sh` already signed would otherwise fail against a build
keyring without the CrownOS key. The ISO's offline mirror is unsigned either
way; installed systems verify everything they fetch from `repo.crownos.org`.

`just build-local` (`build.sh --installer CHECKOUT`) also builds `crownos-setup`
from `packaging/crownos-setup/` of the installer checkout into the repository,
puts it in the offline mirror and lists it in the `packages` of the staged
manifest.

Uploads skip assets whose sha256 digest already matches, then go new names
first, then changed ones (packages before the database), then delete what the
release no longer names, so no client sees a database naming a missing package.
A changed asset is uploaded as `NAME.next` and renamed over the old one, so its
name is missing only between two API calls. Each asset upload gets a new
download URL, so nothing serves a stale database.

Tools: `python>=3.11` (TOML through `scripts/toml.py`, stdlib `tomllib`), `jq`,
`github-cli`, `pacman` (`repo-add`, `vercmp`, `makepkg`), `base-devel`,
`libarchive` (`bsdtar`), `gnupg`; `shellcheck` and `just` for `just check`.
Publish and promote use `gh` with a token that can write releases on
crownos-iso (`github.token` in CI).

## Packages built here

| Package | Holds |
|---|---|
| `crownos-base` | what the old `crownos-desktop` meta installed except the components: skel configs, GTK and icon themes, wallpapers, `.desktop` files, polkit policies, D-Bus services, the tty launcher, the windows-apps and memory helpers, fontconfig, the `crownos-updated` and `crownos-update-notify` units and `/usr/lib/tmpfiles.d/crownos.conf` and the `kernel.yama.ptrace_scope = 1` sysctl drop-in; depends on `desktop.depends`, `snapper`, `snap-pac`, `refind`; ships `packaging/boot/` (pacman hooks, initcpio hooks, helpers, systemd units, `/etc/snapper/configs/root`) |
| `crownos-release` | `/usr/lib/crownos/os-release`, a pacman hook copying it over `/usr/lib/os-release`, and `/usr/lib/crownos/post-update` when the release has a `post-update.sh` |
| `crownos-keyring` | the repository key for `pacman-key --populate crownos` |
| `crownos-source` | opt-in: `-march=native` and paru's `[crownos-src]` |
| `crownos-yazi` | the Yazi plugins pinned in `dotfiles/etc/skel/.config/yazi/package.toml`, fetched with `ya pkg install` into `/etc/skel/.config/yazi/plugins`; depends on the tools those plugins call |
| `crownos-agent-skills` | the skills coding agents read about CrownOS (`/usr/share/crownos/skills`, linked into Claude Code's and Codex's system skill folders), a Claude Code plugin with crownotify hooks and the MCP servers whose package `components.toml` ships (`crownos-computer-use`, `playwright`, `crownos-secrets`) in a local marketplace that `/etc/claude-code/managed-settings.d/50-crownos.json` force-enables, the settings reference from `crownos-config`'s `cargo xtask config-docs`, and the `crownos-agent-skills` per-user setup, the fallback when `crownos-setup user` from the `crownos-setup` package is not installed; built from the sibling checkouts named in `packaging/crownos-agent-skills/README.md` |

`filesystem` owns `/usr/lib/os-release` and the `/etc/os-release` link, so
`crownos-release` cannot. Its hook runs after every transaction that installs or
upgrades either package, so a `filesystem` upgrade is overwritten in the same
transaction. `pacman -Qkk filesystem` therefore reports that file as modified.

`crownos-base` never touches `/etc/conf.d/snapper`. snap-pac's pre-transaction
hook aborts the transaction when that file lacks a `SNAPPER_CONFIGS` line and
does nothing while it is empty, which is what snapper ships. So the live image
and `mkarchiso` take no snapshots. The installer appends `root` to
`SNAPPER_CONFIGS` once `@snapshots` is mounted.

### File ownership while component packages carry only binaries

The shared `arch-package.yml` packages only `usr/bin/*`. Until the component
releases ship their own data, `crownos-base` keeps:

| File | Owner today | Moves to |
|---|---|---|
| `/usr/share/applications/crownappstore.desktop` | crownos-base | crownos-appstore |
| `/usr/share/polkit-1/actions/org.crownos.appstore.policy` | crownos-base | crownos-appstore |
| `/usr/lib/systemd/system/crownos-updated.service` | crownos-base | crownos-update |
| `/usr/lib/systemd/user/crownos-update-notify.service` and its `default.target.wants` link | crownos-base | crownos-update |
| `/usr/lib/tmpfiles.d/crownos.conf` (`/run/crownos`, 0755) | crownos-base | crownos-update |
| `/usr/share/applications/crownos-settings-updates.desktop` | crownos-base | crownos-settings |

The crownos-appstore files in `packaging/crownos-base/appstore/` and `applications/` are byte-identical to
the files under `crownos-appstore/data/`. The pull request that pins a release
that carries one of these files must drop it from `packaging/crownos-base/` in
the same change, or pacman reports a file conflict. The binaries need no such
step: the shared workflow packages every cargo bin target, so they arrive with
the next tag that is pinned.

The App Store no longer updates the system. `crownappstore-updates.desktop`,
`crownos-update-check.service` and `crownos-update-check.timer` are gone; Settings
→ System Updates is the only place to update CrownOS.

`crownos-base` no longer depends on the components, so nothing orders snapd
before it in a pacstrap. Its `crownos-snapd-socket.hook` enables `snapd.socket`
in the transaction that installs snapd instead of testing for the unit in
`crownos-base.install`.

## One-time setup

Nothing builds before step 0: `manifest.sh resolve` and `build.sh` stop with a
pointer here while `packaging/crownos-keyring/crownos.gpg` is missing.

0. **Signing key.** Create a passphrase-less key (CI cannot type a passphrase)
   and commit its public half:

   ```sh
   gpg --quick-generate-key 'CrownOS Packages <packages@crownos.org>' ed25519 sign never
   scripts/export-key.sh packages@crownos.org
   git add packaging/crownos-keyring/{crownos.gpg,crownos-trusted,crownos-revoked}
   gpg --armor --export-secret-keys packages@crownos.org   # → secret CROWNOS_SIGNING_KEY
   ```

1. **Cloudflare redirect.** In the `crownos.org` zone add a proxied
   `AAAA repo 100::` record (no origin; the redirect answers first) and four
   Single Redirect rules, 302, query string not preserved:

   | When the request URL matches (wildcard) | Redirect to |
   |---|---|
   | `https://repo.crownos.org/*/x86_64/*` | `https://github.com/Crown-OS/crownos-iso/releases/download/repo-${1}/${2}` |
   | `https://repo.crownos.org/*/manifest.toml*` | `https://github.com/Crown-OS/crownos-iso/releases/download/repo-${1}/manifest.toml${2}` |
   | `https://repo.crownos.org/crownos.asc` | `https://github.com/Crown-OS/crownos-iso/releases/download/repo-stable/crownos.asc` |
   | `https://repo.crownos.org/*/notes.md*` | `https://github.com/Crown-OS/crownos-iso/releases/download/repo-${1}/notes.md${2}` |

2. **crownos-iso secrets and variables** (Settings → Secrets and variables → Actions):

   | Kind | Name | Value |
   |---|---|---|
   | secret | `CROWNOS_SIGNING_KEY` | the armored secret key |
   | secret | `CROWNOS_PKGBUILDS_TOKEN` | contents: write on Crown-OS/crownos-pkgbuilds |
   | secret | `CROWNOS_BOT_TOKEN` | contents and pull-requests write on crownos-iso |

   The ISO and SourceForge settings stay as they are. `CROWNOS_REPO_KEY` is no
   longer read: the key is always staged from `packaging/crownos-keyring/`.
   Delete it wherever it exists.

3. **crownos-pkgbuilds.** `gh repo create Crown-OS/crownos-pkgbuilds --public`,
   push its README and `.gitignore`. Until it exists, the `pkgbuilds` job only
   uploads the generated tree as an artifact.

4. **Pull requests from CI.** Enable *Allow GitHub Actions to create and approve
   pull requests* on crownos-iso.

5. **Dispatch.** The token component workflows use for `component-updated`
   (`CROWNOS_ISO_DISPATCH_TOKEN`) already targets crownos-iso; `bump.yml` now
   receives it.

6. **ISO downloads.** `https://download.crownos.org/<file>` serves the newest
   ISO, its `.sig`, its `.sha256` and `SHA256SUMS` from the private Backblaze B2
   bucket `crownos-releases`. The bucket is private because B2 makes a bucket
   public only after a card payment. The Worker in `download-worker/` reads the
   bucket with a read-only key and forwards `Range`, so interrupted downloads
   continue. B2 egress to Cloudflare is free, and B2 stores 10 GB free, so
   `b2-publish.sh` stops before the upload when the old and the new ISO do not
   fit together.

   - In B2, set the lifecycle of `crownos-releases` to *Keep only the last
     version of the file*.
   - Make an application key with read and write access to `crownos-releases`
     only. Put its key ID and key into the secrets `CROWNOS_B2_KEY_ID` and
     `CROWNOS_B2_APPLICATION_KEY`.
   - Make a read-only key for `crownos-releases` and deploy the Worker:

     ```sh
     cd download-worker
     wrangler deploy
     wrangler secret put B2_KEY_ID
     wrangler secret put B2_APPLICATION_KEY
     ```

7. **Merge order.** Release the installer that pacstraps the staged manifest's
   `packages` first. The pull request that switches to `components.toml` then
   pins that installer tag, so the install test in `build` passes on the first
   main run. Until both are in, the install test fails by construction.

## Installs from before crownos-updated

Systems installed from a `v0.1.x` ISO use systemd-boot, have
`Server = https://repo.crownos.org/stable/$arch` and do not run
`crownos-updated`. They cannot use Settings → System Updates. A plain
`pacman -Syu` on such a system can install more than one release at a time and
gives no rollback entry. There is no automatic migration: to use the new flow,
install CrownOS again from a current ISO.

## Using the repository on an existing Arch install

```sh
curl -fsSLo /tmp/crownos.asc https://repo.crownos.org/crownos.asc
sudo pacman-key --add /tmp/crownos.asc
sudo pacman-key --lsign-key packages@crownos.org
printf '\n[crownos]\nSigLevel = Required DatabaseOptional\nServer = https://repo.crownos.org/stable/$arch\n' | sudo tee -a /etc/pacman.conf
sudo pacman -Sy crownos-keyring
```
