installer := "../crownos-installer"
export SUDO_ASKPASS := justfile_directory() / "scripts/sudo-askpass"
cachyos_key := "F3B607488DB35A47"

default:
    @just --list

# Build the ISO from the packages pinned in components.toml
build *args: trust-cachyos
    scripts/build.sh {{args}}

# Build the ISO with a local installer checkout instead of its release
build-local *args: trust-cachyos
    scripts/build.sh --installer {{installer}} {{args}}

# Download and build every package of components.toml into target/repo
resolve:
    scripts/manifest.sh resolve target/repo

# Sign target/repo and publish it as the repo-testing release (needs GPGKEY and a gh login that can write releases)
publish: resolve
    scripts/publish.sh testing target/repo

# Publish the resolved repository of an ISO tag as the repo-<tag> and repo-stable releases
promote tag:
    scripts/promote.sh {{tag}} target/repo

# Pin a component release in components.toml: just pin Crown-OS/crownbar v0.4.0, or --latest Crown-OS/crownbar
pin repo *args:
    scripts/pin.sh {{repo}} {{args}}

# Generate the crownos-source PKGBUILDs into a crownos-pkgbuilds checkout
gen-pkgbuilds out="../crownos-pkgbuilds": resolve
    scripts/gen-pkgbuilds.sh target/repo {{out}}

# Fail if a pinned component's default branch is ahead of its pinned tag
gate:
    scripts/gate.sh

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

# Lint the scripts and PKGBUILDs and validate components.toml
check:
    for script in scripts/*.sh packaging/*/PKGBUILD packaging/boot/bin/*; do bash -n "$script" || exit 1; done
    shellcheck -x scripts/*.sh packaging/*/PKGBUILD packaging/boot/bin/*
    python3 -I scripts/toml.py json components.toml | python3 -I scripts/toml.py write | diff - components.toml
    scripts/manifest.sh names all >/dev/null
    test "$(vercmp 0.1.11.r7.gf66daf5 0.1.11)" = 1
    test "$(vercmp 0.1.11.r7.gf66daf5 0.1.12)" = -1
    test "$(vercmp 0.1.11.r10.g0000000 0.1.11.r7.gf66daf5)" = 1
