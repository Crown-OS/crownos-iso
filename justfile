installer := "../crownos-installer"
export SUDO_ASKPASS := justfile_directory() / "scripts/sudo-askpass"
cachyos_key := "F3B607488DB35A47"

default:
    @just --list

# Build the ISO from the latest component releases
build *args: trust-cachyos
    scripts/build.sh {{args}}

# Build the ISO from a local installer checkout, skipping components without a release
build-local *args: trust-cachyos
    scripts/build.sh --installer {{installer}} --missing-release skip {{args}}

# Let pacman verify packages from the CachyOS repository
trust-cachyos:
    @pacman-key --list-keys {{cachyos_key}} >/dev/null 2>&1 || \
        { sudo -A pacman-key --recv-keys {{cachyos_key}} --keyserver keyserver.ubuntu.com \
        && sudo -A pacman-key --lsign-key {{cachyos_key}}; }

# Boot an ISO in QEMU [default: the newest one in out/]
run iso="":
    scripts/run.sh {{iso}}

# Build from local sources, then boot the result
test: build-local run

# Install an ISO unattended in QEMU with no network and boot the result [default: the newest one in out/]
test-install iso="":
    scripts/install-test.sh {{iso}}

# Sign an ISO with GnuPG and write its checksum [default: the newest one in out/]
sign iso="":
    scripts/sign.sh {{iso}}

# Wipe the test VM's disk and UEFI variables
reset-vm:
    rm -f target/disk.qcow2 target/OVMF_VARS.fd

check:
    for script in scripts/*.sh; do bash -n "$script"; done
    shellcheck -x scripts/*.sh packaging/crownos-desktop/PKGBUILD
