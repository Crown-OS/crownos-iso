#!/usr/bin/env bash
# Installs an ISO unattended in QEMU with no network, then boots the installed
# disk and waits for it to come up.
#
#   install-test.sh [--android] [ISO]   [default: the newest ISO in out/]
#
# The disk starts as an empty GPT table, the smallest machine the installer
# accepts: it creates its own boot, swap and root partitions. tests/autoinstall.json reaches the
# live image through fw_cfg, which starts crownos-autoinstall.service there.
# Logs land in target/install-test/.
#
# --android installs with tests/autoinstall-android.json instead: Android apps
# with Google Play. It then reads the installed ext4 root straight from the disk
# image with debugfs, which needs no root, and checks that the setup service and
# the daemon's user units are enabled and that the pending marker and
# /etc/crownos/android.ron exist. Last, it boots the system, lets the setup
# service start, powers the VM off cleanly through the QEMU monitor and checks
# that setup.json says setup is waiting for the network the VM does not have.

set -euo pipefail
shopt -s nullglob

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib.sh
source "$root/scripts/lib.sh"

firmware=${OVMF_DIR:-/usr/share/edk2/x64}
work=$root/target/install-test
install_timeout=${INSTALL_TIMEOUT:-1800}
boot_timeout=${BOOT_TIMEOUT:-600}
setup_settle=${SETUP_SETTLE:-60}
shutdown_timeout=${SHUTDOWN_TIMEOUT:-180}

autoinstall=$root/tests/autoinstall.json
android=''
if [[ ${1:-} == --android ]]; then
    android=yes
    autoinstall=$root/tests/autoinstall-android.json
    shift
fi

iso=$(realpath -- "${1:-$(newest_iso)}")
[[ -f $iso ]] || die "no ISO to test; run \`just build\` first"

booted='Reached target .*(Multi-User System|Graphical Interface)'
setup_started='Starting .*Set up Android apps'
powered_off='reboot: Power down'
root_partition_type=4f68bce3-e8cd-4db1-96e7-fbcaf984b709
sector_size=512
installed_root=''
failures=0

machine=(
    qemu-system-x86_64 -machine q35,accel=kvm:tcg -cpu max -m 4G -smp 4
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
        -fw_cfg "name=opt/org.crownos/autoinstall,file=$autoinstall" \
        -serial "file:$work/install.log" ||
        die "the install VM did not power off within ${install_timeout}s; see $work/install.log"
    grep -q 'crownos-installer: install complete' "$work/install.log" ||
        die "the install failed; see $work/install.log"
}

# Succeeds once LOG has a line matching PATTERN; fails if the VM exits or TIMEOUT seconds pass first.
await_line() {
    local log=$1 pattern=$2 timeout=$3 vm=$4 waited
    for ((waited = 0; waited < timeout; waited += 5)); do
        grep -qE -- "$pattern" "$log" 2>/dev/null && return 0
        kill -0 "$vm" 2>/dev/null || return 1
        sleep 5
    done
    return 1
}

await_exit() {
    local vm=$1 timeout=$2 waited
    for ((waited = 0; waited < timeout; waited += 5)); do
        kill -0 "$vm" 2>/dev/null || return 0
        sleep 5
    done
    return 1
}

stop_vm_and_die() {
    kill "$1" 2>/dev/null || true
    die "$2"
}

boot_installed() {
    "${machine[@]}" -serial "file:$work/boot.log" &
    local vm=$!
    await_line "$work/boot.log" "$booted" "$boot_timeout" "$vm" ||
        stop_vm_and_die "$vm" "the installed system did not boot within ${boot_timeout}s; see $work/boot.log"
    kill "$vm"
}

# The monitor's FIFOs are opened read-write on both sides, so neither QEMU nor
# this script ever blocks on them.
boot_until_setup_waits() {
    local log=$work/boot.log vm monitor
    mkfifo -- "$work/monitor.in" "$work/monitor.out"
    "${machine[@]}" -serial "file:$log" -monitor "pipe:$work/monitor" &
    vm=$!
    exec {monitor}<>"$work/monitor.in"
    await_line "$log" "$booted" "$boot_timeout" "$vm" ||
        stop_vm_and_die "$vm" "the installed system did not boot within ${boot_timeout}s; see $log"
    await_line "$log" "$setup_started" "$boot_timeout" "$vm" ||
        stop_vm_and_die "$vm" "crownos-android-setup.service never started; see $log"
    sleep "$setup_settle"
    printf 'system_powerdown\n' >&"$monitor"
    await_exit "$vm" "$shutdown_timeout" ||
        stop_vm_and_die "$vm" "the installed system did not power off within ${shutdown_timeout}s; see $log"
    exec {monitor}>&-
    grep -q -- "$powered_off" "$log" || die "the installed system did not shut down cleanly; see $log"
}

# debugfs reads the root partition in place, given its byte offset after `?offset=`.
locate_installed_root() {
    local start type offset
    while read -r start type; do
        [[ $type == "$root_partition_type" ]] || continue
        offset=$((start * sector_size))
        [[ $(blkid -p -O "$offset" -s TYPE -o value -- "$work/disk.raw") == ext4 ]] ||
            die "the --android checks read an ext4 root, and this root is not ext4"
        installed_root="$work/disk.raw?offset=$offset"
        return
    done < <(partx -g -o START,TYPE -- "$work/disk.raw")
    die "the installed disk has no root partition"
}

installed_path_exists() {
    debugfs -R "stat $1" "$installed_root" 2>/dev/null | grep -q '^Inode:'
}

installed_file_matches() {
    debugfs -R "cat $1" "$installed_root" 2>/dev/null | grep -Eq -- "$2"
}

expect() {
    local description=$1
    shift
    if "$@"; then
        printf 'pass: %s\n' "$description"
    else
        printf 'FAIL: %s\n' "$description" >&2
        failures=$((failures + 1))
    fi
}

check_android_install() {
    expect "crownos-android-setup.service is enabled" \
        installed_path_exists /etc/systemd/system/multi-user.target.wants/crownos-android-setup.service
    expect "crown-androidd.socket is enabled for every user" \
        installed_path_exists /etc/systemd/user/sockets.target.wants/crown-androidd.socket
    expect "crown-androidd.path is enabled for every user" \
        installed_path_exists /etc/systemd/user/paths.target.wants/crown-androidd.path
    expect "the setup pending marker exists" installed_path_exists /var/lib/crownos/android/pending
    expect "/etc/crownos/android.ron enables Android with Google Play" \
        installed_file_matches /etc/crownos/android.ron 'google_play:[[:space:]]*true'
}

check_android_setup() {
    local status=/var/lib/crownos/android/setup.json
    expect "setup.json reports waiting_for_network" \
        installed_file_matches "$status" '"stage":[[:space:]]*"waiting_for_network"'
    ((failures == 0)) && return
    debugfs -R "cat $status" "$installed_root" >&2 2>/dev/null || true
    die "$failures Android check(s) failed"
}

test_plain_install() {
    printf 'booting the installed system\n'
    boot_installed
    printf 'pass: %s installs offline and boots\n' "${iso##*/}"
}

test_android_install() {
    locate_installed_root
    check_android_install
    printf 'booting the installed system until Android setup waits for the network\n'
    boot_until_setup_waits
    check_android_setup
    printf 'pass: %s installs offline with Android apps and starts their setup\n' "${iso##*/}"
}

if [[ -n $android ]]; then
    for tool in debugfs partx mkfifo; do
        command -v "$tool" >/dev/null || die "--android needs $tool"
    done
fi
prepare_disk
extract_live_kernel
printf 'installing %s\n' "${iso##*/}"
install_unattended
if [[ -n $android ]]; then
    test_android_install
else
    test_plain_install
fi
