# Kernel

The ISO and the installed systems run `linux-cachyos`. Android apps need the
kernel's binder driver, and that decides when the kernel changes
(crownos-android `docs/decisions/d1-kernel.md`).

## The switch to linux-cachyos-lts

- **Why:** Linux 7.4 deletes the C binder and keeps only the Rust one. CachyOS
  builds its kernels with ThinLTO and BTF, which rules Rust out, so a 7.4
  `linux-cachyos` has no binder at all and Android apps stop working.
- **What:** `linux-cachyos-lts` (6.18, C binder built in, supported until December
  2028), and `linux-cachyos-lts-nvidia-open` on NVIDIA machines.
- **When:** before the first ISO is built while `[cachyos]` carries a 7.4
  `linux-cachyos`. Until then the 7.2 and 7.3 kernels have the C binder built
  in and nothing changes. Check before every release build with
  `pacman -Si linux-cachyos`, or run crownos-android's
  `spikes/s3-platform/kernel-check.sh` on the kernel the build resolves to.

## What the switch touches

Every place that names the kernel moves together, in one change:

- `profile/packages.x86_64` (the live image's kernel) and `profile/install.packages`;
- `profile/airootfs/etc/mkinitcpio.d/linux-cachyos.preset`, renamed for the new
  kernel, with its `ALL_kver` and `archiso_image`;
- `profile/efiboot/loader/entries/01-crownos.conf`;
- the `vmlinuz-` and `initramfs-` names in `scripts/install-test.sh`;
- crownos-installer's `base::KERNEL`, which names the installed kernel, its
  boot entry and its mkinitcpio preset.

Binder nodes need nothing at the switch: `crownos-android-setup prepare-container`
pins them to `binder`, `vndbinder` and `hwbinder` before every container start,
on any kernel.
