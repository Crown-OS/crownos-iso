# Releases

Each CrownOS release has a directory `releases/<X.Y.Z>/`. Write it before you
push the tag `v<X.Y.Z>`. `scripts/gate.sh` stops the tag build when a file is
missing or not valid.

| File | Required | Contents |
|---|---|---|
| `release.toml` | yes | `restart = "session"`, `"soft-reboot"` or `"reboot"` |
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

Testing builds between two tags have no directory and use `reboot`.

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
