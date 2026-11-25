# Releases

Each CrownOS release has a directory `releases/<X.Y.Z>/`. Write it before you
push the tag `v<X.Y.Z>`. `scripts/gate.sh` stops the tag build when a file is
missing or not valid.

| File | Required | Contents |
|---|---|---|
| `release.toml` | yes | `restart = "session"`, `"soft-reboot"` or `"reboot"`, and an optional `retired = ["package", ...]` |
| `notes.md` | yes | The highlights of the release, in Markdown |
| `post-update.sh` | no | A bash script that runs as root after the update |

## restart

The restart that the update needs after it installs the packages:

- `session`: the desktop restarts. Use it only when no system service and no
  kernel changed.
- `soft-reboot`: all user space restarts, the kernel stays. Use it when system
  services changed but the kernel did not.
- `reboot`: the computer restarts. Use it when the kernel or the initramfs
  changed, or when you are not sure.

`scripts/gate.sh` refuses `session` when a system unit, a user unit, a
`.wants` link or a line of `80-crownos.preset` in `packaging/` was added,
changed or removed since the previous tag. A session restart does not restart
the system manager or the user manager, so these changes start only at the next
boot or login. The gate does not see the units that a component package ships
itself. Check them yourself.

Testing builds between two tags have no directory and use `reboot`.

## retired

The packages that the release removes from updated systems. Use it when you
remove a component from `components.toml` and no other package replaces it.
For a rename or a merge, use `replaces=` and `conflicts=` in the PKGBUILD of the
new package, as `crownos-base` does for `crownos-desktop`.

```toml
restart = "soft-reboot"
retired = ["crownos-oldtool"]
```

`scripts/manifest.sh` copies the list into the published manifest. After the
pacman transaction, `crownos-updated` removes each retired package that is
installed, with `pacman -Rs`. It skips the packages that are not installed. If
the removal fails, the update fails. `scripts/gate.sh` refuses a name that is
not a package name, and a name that `components.toml` still lists.

The update to a release runs the `crownos-updated` of the release before it.
The `crownos-updated` of 0.3.0 and earlier does not know `retired` and does
not remove the packages. To remove them on an update from such a release, use
`post-update.sh`.

## New system units

`packaging/crownos-base/systemd/80-crownos.preset` is the list of the system units that
CrownOS enables. To enable a new system daemon, add an `enable` line for its
unit there. Do not add it to the installer. The installer runs `systemctl
preset` for the units of the file. After the update, `crownos-updated` runs
`systemctl preset` only for the units of lines that are new since the last
update, so a unit that the user disabled stays disabled. It records the
applied lines in `/var/lib/crownos/update/applied-presets`. A system that has
no record (installed with 0.3.0 or earlier) gets the units that the old
installer enabled as its record. The `crownos-updated` of 0.3.0 and earlier
does not read the preset file, so on an update from such a release the new
units are enabled at the update after it.

New user units start through `default.target.wants` links in `crownos-base`.
Use `soft-reboot` or `reboot` for a release that adds a unit.

## Home files and rollback

A rollback restores the system, not the homes. The first release with the
default layers (`/usr/share/crownos/defaults`) therefore changes no file in a
home: it reads the full files that earlier releases copied into
`~/.config/crownos` as they are, and `refresh-shipped-dotfiles` does nothing.
A rollback to a release without the layers still finds every file as it was.

In the release after it, add the empty file
`defaults/history/reduce-home-files`. crownos-base installs it to
`/usr/share/crownos/defaults-history/`. Then crownos-config reduces each full
file to the keys that the user changed (and keeps the old file as
`<section>.ron.before-layers`), and `refresh-shipped-dotfiles` replaces the
unchanged dotfile copies. A rollback from that release goes to a release that
has the layers, so the reduced files still give the same values.
`scripts/gate.sh` refuses the file in a release whose previous release has no
default layers.

## notes.md

`scripts/notes.sh` puts this file first. Then it adds the release notes of
each component that changed since the previous tag. Do not write a title:
Settings and the GitHub release show their own.

## post-update.sh

The `crownos-release` package installs this script as
`/usr/lib/crownos/post-update`. `crownos-updated` runs it after the pacman
transaction, with `CROWNOS_FROM_VERSION` and `CROWNOS_TO_VERSION` set. Start it
with `#!/usr/bin/env bash` and `set -euo pipefail`. If it fails, the update
fails and Settings shows how to roll back. Make it safe to run two times.
`just check` lints it with `bash -n` and shellcheck.
