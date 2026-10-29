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
)
