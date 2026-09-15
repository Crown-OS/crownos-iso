# crownos-iso

The [archiso](https://gitlab.archlinux.org/archlinux/archiso) profile that builds
the [CrownOS](https://github.com/Crown-OS) installation image.

**Status: Skeleton.** This profile is currently an **unmodified copy of the
upstream Arch Linux `releng` profile**. It has no CrownOS branding, no CrownOS
package repository, and no CrownOS package in its package list. What it builds is
a generic Arch rescue image.

## What is actually in it

```sh
# profiledef.sh
iso_name="archlinux"
iso_publisher="Arch Linux <https://archlinux.org>"
iso_application="Arch Linux Live/Rescue DVD"
install_dir="arch"
```

- `airootfs/etc/hostname` is `archiso`
- The motd points at the Arch install guide
- `pacman.conf` enables only `[core]` and `[extra]`
- `packages.x86_64` is upstream's 127-package rescue set — filesystem tools,
  network tools, firmware, VM guest agents, `archinstall`. **No compositor, no
  Wayland stack, no CrownOS component.**

| Setting | Value |
|---|---|
| `buildmodes` | `('iso')` |
| `bootmodes` | `('bios.syslinux' 'uefi.systemd-boot')` |
| Root filesystem | squashfs, xz with the x86 BCJ filter |
| Bootstrap tarball | zstd `-19` |

## Building

`./build.sh` builds the image. You do not need to be on Arch — it uses
`mkarchiso` natively when the host has it, and otherwise runs the same build
inside a privileged Arch container, so any distribution with `podman` or
`docker` can produce the ISO.

```bash
./build.sh --check       # what can this machine do? changes nothing
./build.sh               # native if possible, container otherwise
```

| Flag | Effect |
|---|---|
| `--check` | Report host distro, `mkarchiso`, container runtime, free space, loop devices. Builds nothing. |
| `--native` | Force `mkarchiso` on the host. Needs Arch and root. |
| `--container` | Force the container path, even on Arch. Reproduces what CI would do. |
| `--out DIR` | Output directory, default `./out` |
| `--work DIR` | Scratch directory, default `./work` |

Both directories are gitignored. A full build needs roughly **12 GB** free and
takes tens of minutes; `--check` warns before you find out the slow way.

The container path is `--privileged` because `mkarchiso` needs loop devices and
`mount(2)`. That is a genuine requirement of building a squashfs image, not a
shortcut. Override the base image with `CROWNOS_ISO_IMAGE` if you mirror it.

Equivalent by hand, on an Arch host:

```bash
sudo pacman -S archiso
sudo mkarchiso -v -w ./work -o ./out .
```

## Boot flow

1. **BIOS** → syslinux, with `whichsys.c32` dispatching to the PXE or sys config.
   Entries: `arch` and `archspeech` (adds `accessibility=on`).
2. **UEFI** → systemd-boot, 15 s timeout, entries for normal boot, speech boot
   and Memtest86+.
3. **GRUB** (`grub/grub.cfg`, also used as `loopback.cfg`) — serial console,
   plus UEFI Shell entries for five architectures.
4. Kernel → mkinitcpio `archiso` hooks mount the squashfs → systemd → root
   autologin on tty1 → `.zlogin` → `.automated_script.sh`, which runs anything
   named by `script=` on the kernel command line.

## ⚠ Live-medium defaults

The inherited profile carries upstream Arch's live-medium settings, which are
deliberate for a rescue image and **inappropriate for an installed desktop**:

- Empty root password (`airootfs/etc/shadow`)
- Root autologin on tty1
- `sshd` with `PermitRootLogin yes` and `PasswordAuthentication yes`

These must change before the profile becomes an installable CrownOS image. See
[SECURITY.md](https://github.com/Crown-OS/crownos-documentations/blob/main/SECURITY.md).

## What making this a CrownOS ISO involves

Roughly in order:

1. **Package the components.** No PKGBUILDs exist anywhere in the organization.
   This gates everything else — and it is itself gated on `crownshell 0.3.0`
   and `crownos-config 0.2.0` reaching crates.io, since nothing downstream
   builds from a clean checkout until they do.
2. **Brand the profile** — `iso_name`, `iso_label`, `iso_publisher`,
   `iso_application`, `install_dir`, hostname, motd.
3. **Add a CrownOS pacman repository** to `pacman.conf`, or build packages into
   the profile.
4. **Add the Wayland stack** to `packages.x86_64` — it is not there.
5. **Provide a session** — there is no session file, no greeter, and no
   `.desktop` entry for `crownpositor`.
6. **Fix the live-medium security defaults** for the installed case.
7. **Decide the installer.** Upstream `archinstall` is what is currently
   included.
8. **Resolve licensing** — see below.

## Licensing

**GPL-3.0-or-later** — see [LICENSE](LICENSE). Unlike the rest of the CrownOS
organisation, this repository is not MIT, and that is not a choice: it derives
from Arch Linux's archiso `releng` profile, whose scripts carry
`SPDX-License-Identifier: GPL-3.0-or-later` headers, and a derivative of
GPL-3.0-or-later material is GPL-3.0-or-later.

Preserve the SPDX headers on inherited files, and mark CrownOS-authored files
here `GPL-3.0-or-later` as well.

## Note on the download page

The CrownOS website advertises three ISO editions across five mirrors. None of
that exists — this profile builds one unbranded x86_64 image, and there are no
mirrors.

## Contributing

See the organization-wide
[contribution guide](https://github.com/Crown-OS/crownos-documentations/blob/main/CONTRIBUTING.md).
Default branch here is **`main`**. CrownOS-authored shell should pass
`shellcheck`.
