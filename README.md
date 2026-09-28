# crownos-iso

Everything that turns the CrownOS source repositories into an installable
system: desktop packages for each base distribution, the signed repository
they are installed from, and the live ISO that runs the installer.

The user picks the base — Arch, Debian 13, Ubuntu 26.04, Fedora 44 or
NixOS 26.05 — on the installer's *Where should CrownOS go?* page, or the
Windows installer's `oobe.json` names it (`install.distro`). The live image is
Arch in every case; it carries each base's bootstrapper and installs the chosen
one onto the disk, then adds `crownos-desktop` from the CrownOS repository.

## Layout

```
build.sh                 build packages, sign the repository, stage the installer, build the ISO
live/                    the archiso profile (profiledef.sh, packages.x86_64, airootfs/, boot loaders)
packaging/
  components.list        one line per package: repo, cargo package, installed files
  crownos-desktop/       session files carried by the crownos-desktop meta-package
  depends/<distro>.list  runtime services and dlopen()ed libraries the meta-package pulls in
  containers/            one build environment per package format
  scripts/               build-packages.sh and index-repo.sh, run inside those containers
  nix/                   flake with the packages and the services.crownos NixOS module
```

This repository expects the component repositories next to it, as in a
checkout of the whole of CrownOS: `../crownpositor`, `../crownshell`,
`../vendor` and so on.

## Building

```
./build.sh packages              # all bases, or name some: ./build.sh packages arch fedora
./build.sh repo                  # needs the signing key (CROWNOS_SIGNING_KEY)
./build.sh installer
sudo ./build.sh iso
```

Packages are built in podman or docker containers of the base they are for,
because the components link its ffmpeg, pipewire and Mesa. Their library
dependencies are read off the built binaries, not maintained by hand.

`build/repo` is the tree to publish at `https://repo.crownos.org`
(`crownos-installer/src/engine/distro/mod.rs`, `REPO_URL`). Signing happens on
the host with your own gpg; no secret key enters a container.

NixOS is built from source by `packaging/nix`, which every NixOS install
references as `github:Crown-OS/crownos-iso?dir=packaging/nix`. It needs each
component, `crownos-protocols`, `ffsp-protocol` and `vendor` published under
`github.com/Crown-OS`.

## CI/CD

`.github/workflows/build.yml` runs on pull requests, pushes to `main`, `v*`
tags, every night at 03:00 UTC, and on `component-updated` dispatches:

| Job | Does | Runs on PRs |
|---|---|---|
| `lint` | shellcheck, Nix parse, picks the run's package version | yes |
| `installer` | builds `crownos-installer` | yes |
| `packages` | builds all four bases in parallel | yes |
| `repo` | signs the repository | no |
| `deploy-repo` | publishes it to GitHub Pages | no |
| `iso` | builds the ISO in a privileged Arch container | no |
| `release` | attaches the ISO and its checksum to a GitHub release | `v*` tags only |

`packaging/sources.list` names the repositories CI clones next to this one;
each run records the revisions it built in `sources.txt`, published at the
root of the repository site.

One-time setup on `Crown-OS/crownos-iso`:

1. **Settings → Pages**: source *GitHub Actions*, custom domain `repo.crownos.org`
   (a `CNAME` record for `repo.crownos.org` pointing at `crown-os.github.io`).
2. **Secrets**:
   - `CROWNOS_SIGNING_KEY_ASC`: `gpg --armor --export-secret-subkeys packages@crownos.org`,
     from a signing subkey without a passphrase.
   - `CROWNOS_SOURCES_TOKEN`: only if component repositories are private; a
     fine-grained token with *Contents: read* on them.

To rebuild when a component changes rather than nightly, give the component
repository a `CROWNOS_ISO_DISPATCH_TOKEN` secret (fine-grained, *Contents:
read and write* on `crownos-iso`) and add the `notify-iso` job from
`crownos-installer/.github/workflows/ci.yml`.
