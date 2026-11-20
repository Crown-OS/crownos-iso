#!/usr/bin/env bash
# Installs an ISO unattended in QEMU with no network, then boots the installed
# disk and waits for it to come up.
#
#   install-test.sh [ISO]   [default: the newest ISO in out/]
#
# The disk starts as an empty GPT table, the smallest machine the installer
# accepts: it creates its own boot, swap and root partitions. tests/autoinstall.json reaches the
# live image through fw_cfg, which starts crownos-autoinstall.service there.
# Logs land in target/install-test/.

set -euo pipefail
shopt -s nullglob

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib.sh
source "$root/scripts/lib.sh"

firmware=${OVMF_DIR:-/usr/share/edk2/x64}
work=$root/target/install-test
install_timeout=${INSTALL_TIMEOUT:-1800}
boot_timeout=${BOOT_TIMEOUT:-600}

iso=$(realpath -- "${1:-$(newest_iso)}")
[[ -f $iso ]] || die "no ISO to test; run \`just build\` first"

machine=(
    qemu-system-x86_64 -machine "q35,accel=kvm:tcg" -cpu max -m 4G -smp 4
    -nic none -display none -no-reboot
    -drive "if=pflash,format=raw,readonly=on,file=$firmware/OVMF_CODE.4m.fd"
    -drive "if=pflash,format=raw,file=$work/vars.fd"
    -drive "if=virtio,format=raw,file=$work/disk.raw"
)

prepare_disk() {
    rm -rf -- "$work"
    mkdir -p -- "$work"
    truncate -s 24G "$work/disk.raw"
    printf 'label: gpt\n' | sfdisk --quiet "$work/disk.raw"
    cp -- "$firmware/OVMF_VARS.4m.fd" "$work/vars.fd"
}

extract_live_kernel() {
    bsdtar -xf "$iso" -C "$work" --strip-components=3 \
        crownos/boot/x86_64/vmlinuz-linux-cachyos crownos/boot/x86_64/initramfs-linux-cachyos.img
}

install_unattended() {
    local label
    label=$(blkid -o value -s LABEL -- "$iso")
    timeout --foreground "$install_timeout" "${machine[@]}" \
        -cdrom "$iso" \
        -kernel "$work/vmlinuz-linux-cachyos" -initrd "$work/initramfs-linux-cachyos.img" \
        -append "archisobasedir=crownos archisolabel=$label console=ttyS0" \
        -fw_cfg "name=opt/org.crownos/autoinstall,file=$root/tests/autoinstall.json" \
        -serial "file:$work/install.log" ||
        die "the install VM did not power off within ${install_timeout}s; see $work/install.log"
    grep -q 'crownos-installer: install complete' "$work/install.log" ||
        die "the install failed; see $work/install.log"
}

# The installer ends by printing the boot and update setup from inside the new
# system (grep -H, systemctl is-enabled, btrfs subvolume get-default, ls of
# EFI/CrownOS and EFI/refind). Only that output is matched: the logged commands
# never carry the path:content shape, and their file names follow a slash
# rather than the start of a line or a space.
assert_installed_layout() {
    local log=$work/install.log expected
    local -a layout=(
        '/efi/EFI/refind/refind.conf:timeout -1'
        '/efi/EFI/refind/refind.conf:default_selection "CrownOS"'
        '/efi/EFI/refind/refind.conf:include crownos-rollback.conf'
        '/etc/mkinitcpio.conf.d/crownos.conf:HOOKS=.*block crownos-recover filesystems .*'
        '/etc/snapper/configs/root:NUMBER_LIMIT="10"'
        '/etc/pacman.conf:Server = https://repo.crownos.org/(v[0-9.]+|testing)/[$]arch'
        'crownos-recover-finish.service enabled'
        'crownos-updated.service enabled'
        'path @'
        'vmlinuz-linux-cachyos'
        'initramfs-linux-cachyos.img'
        'refind_x64.efi'
        'rollback'
    )
    for expected in "${layout[@]}"; do
        grep -qE "(^|[[:space:]])${expected}[[:space:]]*$" "$log" ||
            die "the installed system lacks \`$expected\`; see $log"
    done
}

assert_booted_layout() {
    local log=$work/boot.log
    grep -q 'running hook \[crownos-recover\]' "$log" ||
        die "the installed initramfs did not run crownos-recover; see $log"
    # rEFInd prints the options it hands the kernel as "Using load options";
    # the kernel's own "Command line:" line stays in its log buffer on this path.
    local command_line
    command_line=$(grep -aE "Command line:|Using load options '" "$log") ||
        die "neither rEFInd nor the installed kernel printed the command line; see $log"
    if grep -qE 'crownos\.recover|subvol(id)?=' <<<"$command_line"; then
        die "the default boot entry names recovery or a subvolume; see $log"
    fi
    grep -q 'root=PARTUUID=' <<<"$command_line" ||
        die "the default boot entry does not name the root by PARTUUID; see $log"
}

boot_installed() {
    "${machine[@]}" -serial "file:$work/boot.log" &
    local vm=$! waited
    for ((waited = 0; waited < boot_timeout; waited += 5)); do
        if grep -qE 'Reached target .*(Multi-User System|Graphical Interface)' "$work/boot.log" 2>/dev/null; then
            kill "$vm"
            assert_booted_layout
            return
        fi
        kill -0 "$vm" 2>/dev/null || break
        sleep 5
    done
    kill "$vm" 2>/dev/null || true
    die "the installed system did not boot within ${boot_timeout}s; see $work/boot.log"
}

prepare_disk
extract_live_kernel
printf 'installing %s\n' "${iso##*/}"
install_unattended
assert_installed_layout
printf 'booting the installed system\n'
boot_installed
printf 'pass: %s installs offline and boots\n' "${iso##*/}"
