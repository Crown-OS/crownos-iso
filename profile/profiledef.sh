#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="crownos"
iso_label="CROWNOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="CrownOS <https://crownos.org>"
iso_application="CrownOS Installer"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="crownos"
buildmodes=('iso')
bootmodes=('uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=(
  '-comp' 'zstd' '-Xcompression-level' '19' '-b' '1M'
  '-action' 'uncompressed@subpathname(var/cache/crownos/mirror)'
)
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sudoers.d/crownos-live"]="0:0:440"
  ["/usr/bin/crownos-installer"]="0:0:755"
  ["/usr/bin/crownos-install"]="0:0:755"
  ["/etc/default/useradd"]="0:0:644"
  ["/etc/skel/.config/chromium-flags.conf"]="0:0:644"
  ["/etc/skel/.config/fish"]="0:0:755"
  ["/etc/skel/.config/fish/config.fish"]="0:0:644"
  ["/etc/skel/.config/gtk"]="0:0:755"
  ["/etc/skel/.config/kitty"]="0:0:755"
  ["/etc/skel/.config/kitty/kitty.conf"]="0:0:644"
  ["/root/.config/chromium-flags.conf"]="0:0:644"
  ["/root/.config/fish"]="0:0:755"
  ["/root/.config/fish/config.fish"]="0:0:644"
  ["/root/.config/gtk"]="0:0:755"
  ["/root/.config/kitty"]="0:0:755"
  ["/root/.config/kitty/kitty.conf"]="0:0:644"
  ["/home/crownos-live/.config"]="1000:1000:755"
  ["/home/crownos-live/.config/chromium-flags.conf"]="1000:1000:644"
  ["/home/crownos-live/.config/fish"]="1000:1000:755"
  ["/home/crownos-live/.config/fish/config.fish"]="1000:1000:644"
  ["/home/crownos-live/.config/gtk"]="1000:1000:755"
  ["/home/crownos-live/.config/kitty"]="1000:1000:755"
  ["/home/crownos-live/.config/kitty/kitty.conf"]="1000:1000:644"
)
