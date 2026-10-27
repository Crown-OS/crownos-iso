#!/usr/bin/env bash
# Boots an ISO in QEMU with UEFI firmware and virgl GPU acceleration.
#
#   run.sh [ISO]   [default: the newest ISO in out/]

set -euo pipefail
shopt -s nullglob

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib.sh
source "$root/scripts/lib.sh"

target=$root/target
firmware=/usr/share/edk2/x64
disk=$target/disk.qcow2
uefi_vars=$target/OVMF_VARS.fd

iso=${1:-$(newest_iso)}
[[ -n $iso ]] || die "no ISO in out/; run \`just build\` first"

mkdir -p -- "$target"
[[ -e $disk ]] || qemu-img create -f qcow2 "$disk" 32G
[[ -e $uefi_vars ]] || cp -- "$firmware/OVMF_VARS.4m.fd" "$uefi_vars"

exec qemu-system-x86_64 \
    -enable-kvm -cpu host -m 4G -smp 4 \
    -drive "if=pflash,format=raw,readonly=on,file=$firmware/OVMF_CODE.4m.fd" \
    -drive "if=pflash,format=raw,file=$uefi_vars" \
    -drive "if=virtio,format=qcow2,file=$disk" \
    -cdrom "$iso" \
    -device virtio-vga-gl -display gtk,gl=on \
    -device qemu-xhci -device usb-tablet \
    -nic user,model=virtio-net-pci
