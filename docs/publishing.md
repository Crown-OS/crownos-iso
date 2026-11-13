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
as real files (release assets have no symlinks), `manifest.toml(.sig)` and
`crownos.asc`. None of them is ever the latest release, and their tags never
match the `v*` triggers. `https://repo.crownos.org` is a Cloudflare redirect
(302) onto the release downloads:

| Request | Redirects to `https://github.com/Crown-OS/crownos-iso/releases/download/…` |
|---|---|
| `/<channel>/x86_64/<file>` | `repo-<channel>/<file>` |
| `/<channel>/manifest.toml(.sig)` | `repo-<channel>/manifest.toml(.sig)` |
| `/crownos.asc` | `repo-stable/crownos.asc` |

`repo-<tag>` is not behind the domain; point `Server` at its release download to
pin a system to an old release. Installed systems use

```
[crownos]
SigLevel = Required DatabaseOptional
Server = https://repo.crownos.org/stable/$arch
```

A published `manifest.toml` names the release and the set an installed system
must have:

```toml
version = "0.1.12"
build_id = "<crownos-iso commit>"
channel = "stable"
packages = ["crownpositor", "crownbar", ...]   # what to sync: system packages only

[[package]]
name = "crownbar"
version = "0.3.0-1"                            # one per package in the repository
```

`version` and `build_id` are read from the `crownos-release` package in the
repository, so the manifest always describes the bytes beside it. Testing builds
are versioned `X.Y.Z.rN.g<sha>` (N commits after tag vX.Y.Z), which `vercmp`
orders above vX.Y.Z and below the next tag.

## Flow (.github/workflows/release.yml)

| Event | Jobs |
|---|---|
| pull request | `check`: `just check`, then `manifest.sh resolve`; nothing is signed or uploaded |
| push to main | `resolve` (resolve, sign, publish `repo-testing`) → `build` → `install-test`; the ISO is skipped when the commit is tagged, since the tag's run builds it |
| `v*` tag | `resolve` (`gate.sh` first, nothing published) → `build` → `install-test` → `publish` (ISO to SourceForge and the GitHub release) ∥ `promote` (the tested repository to `repo-<tag>` and `repo-stable`) → `pkgbuilds` |
| `component-updated` dispatch | `bump.yml` opens a pull request pinning the release |

Main pushes publish testing one at a time (`crownos-testing` concurrency group);
promotions are serialized on `crownos-stable`. A tag run never writes testing.
`promote.sh` signs the repository artifact itself and checks that its
`crownos-release` matches the tag's version and commit. Re-running a tag is safe:
the same build continues where it stopped, another build for a published tag is
refused, and a stable that already holds a newer version is left alone
(`promote.sh TAG DIR --force-stable` rolls stable back on purpose).

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
  uses instead of the generic Rust template (with every file beside it, such as
  `snapd.install`).
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
| `manifest.sh resolve DIR` | downloads, verifies and builds every package into DIR, indexed unsigned |
| `manifest.sh published CHANNEL DIR` | prints the published manifest for DIR |
| `pin.sh` | the only writer of `components.toml` |
| `gate.sh` | fails if a pinned repository's default branch is ahead of its tag |
| `publish.sh testing DIR` | signs DIR and uploads it as `repo-testing` |
| `promote.sh TAG DIR` | signs DIR and uploads it as `repo-TAG` and `repo-stable` |
| `gen-pkgbuilds.sh DIR OUT` | writes the crownos-source PKGBUILDs |
| `export-key.sh KEY` | writes the public key into `packaging/crownos-keyring/` |
| `build.sh [--repo DIR]` | builds the ISO from a resolved repository |

`build.sh` reads the resolved repository with `SigLevel = Never`: its assets were
checked against their pinned sha256 and its database was built locally, and a
repository `publish.sh` already signed would otherwise fail against a build
keyring without the CrownOS key. The ISO's offline mirror is unsigned either
way; installed systems verify everything they fetch from `repo.crownos.org`.

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
| `crownos-base` | what the old `crownos-desktop` meta installed except the components: skel configs, GTK and icon themes, wallpapers, `.desktop` files, polkit policies, D-Bus services, the tty launcher, the windows-apps and memory helpers, fontconfig; depends on `desktop.depends`, `snapper`, `snap-pac`; ships `packaging/boot/` (pacman hooks, initcpio hooks, helpers, systemd units, `/etc/snapper/configs/root`) |
| `crownos-release` | `/usr/lib/crownos/os-release` and a pacman hook copying it over `/usr/lib/os-release` |
| `crownos-keyring` | the repository key for `pacman-key --populate crownos` |
| `crownos-source` | opt-in: `-march=native` and paru's `[crownos-src]` |

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

The shared `arch-package.yml` packages only `usr/bin/*`. Until crownos-appstore's
release ships its own data, `crownos-base` keeps:

| File | Owner today | Moves to |
|---|---|---|
| `/usr/share/applications/crownappstore.desktop` | crownos-base | crownos-appstore |
| `/usr/share/applications/crownappstore-updates.desktop` | crownos-base | crownos-appstore |
| `/usr/share/polkit-1/actions/org.crownos.appstore.policy` | crownos-base | crownos-appstore |
| `/usr/lib/systemd/user/crownos-update-check.service` | crownos-base | crownos-appstore |
| `/usr/lib/systemd/user/crownos-update-check.timer` and its `timers.target.wants` link | crownos-base | crownos-appstore |

Each copy in `packaging/crownos-base/` is byte-identical to the file under
`crownos-appstore/data/`. The pull request that pins a data-carrying
crownos-appstore must drop them all from `packaging/crownos-base/` in the same
change, or pacman reports a file conflict. The binaries (`crownos-appstore`,
`crownos-appstore-helper`, `crownos-system-update`, `crownos-update-check`) need
no such step: the shared workflow packages every cargo bin target, so they
arrive with the next crownos-appstore tag that is pinned.

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
   `AAAA repo 100::` record (no origin; the redirect answers first) and three
   Single Redirect rules, 302, query string not preserved:

   | When the request URL matches (wildcard) | Redirect to |
   |---|---|
   | `https://repo.crownos.org/*/x86_64/*` | `https://github.com/Crown-OS/crownos-iso/releases/download/repo-${1}/${2}` |
   | `https://repo.crownos.org/*/manifest.toml*` | `https://github.com/Crown-OS/crownos-iso/releases/download/repo-${1}/manifest.toml${2}` |
   | `https://repo.crownos.org/crownos.asc` | `https://github.com/Crown-OS/crownos-iso/releases/download/repo-stable/crownos.asc` |

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

6. **Merge order.** Release the installer that pacstraps the staged manifest's
   `packages` first. The pull request that switches to `components.toml` then
   pins that installer tag, so `install-test` is green on the first main run.
   Until both are in, `install-test` is red by construction.

## Using the repository on an existing Arch install

```sh
curl -fsSLo /tmp/crownos.asc https://repo.crownos.org/crownos.asc
sudo pacman-key --add /tmp/crownos.asc
sudo pacman-key --lsign-key packages@crownos.org
printf '\n[crownos]\nSigLevel = Required DatabaseOptional\nServer = https://repo.crownos.org/stable/$arch\n' | sudo tee -a /etc/pacman.conf
sudo pacman -Sy crownos-keyring
```
