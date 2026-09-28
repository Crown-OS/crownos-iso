#!/usr/bin/env bash
#
# Builds CrownOS: the desktop packages for every base distribution, the signed
# repository the installer installs them from, and the live ISO.
#
#   ./build.sh packages [distro…]   # build packages in containers (default: all)
#   ./build.sh repo                 # index and sign build/repo for publishing
#   ./build.sh installer            # build crownos-installer, stage it in live/
#   sudo ./build.sh iso             # build the ISO from live/ with mkarchiso
#
# The distros are arch, debian, ubuntu and fedora. NixOS builds from source
# through packaging/nix instead of from this repository.
#
# The live image is Arch whichever base the user picks: it only has to run the
# installer, and it carries every base's bootstrapper (see live/packages.x86_64).
#
# Everything except `iso` runs as your user. The ISO needs root, and a root
# build of the installer would leave its target/ owned by root, so the two are
# separate commands and this script refuses to be run as root for the others.
#
# Environment:
#   CROWNOS_SIGNING_KEY       gpg key that signs the repository (default: packages@crownos.org)
#   CROWNOS_VERSION           package version (default: today, YYYY.MM.DD)
#   CROWNOS_INSTALLER_REPO    crownos-installer checkout (default: ../crownos-installer)
#   CROWNOS_CONTAINER         podman or docker (default: whichever is installed)
#   CROWNOS_CARGO_CACHE       directory for the containers' cargo registry and git
#                             checkouts (default: named container volumes)
#   CROWNOS_WORK_DIR, CROWNOS_OUT_DIR   mkarchiso scratch and ISO output (work/, out/)
#
# Packages, cargo targets and the repository are built under build/.

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
crownos_root="$(dirname "$repo_dir")"
profile_dir="$repo_dir/live"
packaging_dir="$repo_dir/packaging"
build_dir="$repo_dir/build"
installer_repo="${CROWNOS_INSTALLER_REPO:-$crownos_root/crownos-installer}"
staged_installer="$profile_dir/airootfs/usr/bin/crownos-installer"
staged_key="$profile_dir/airootfs/usr/share/crownos/crownos-archive-keyring.asc"
repo_key="$build_dir/repo/crownos-archive-keyring.asc"
work_dir="${CROWNOS_WORK_DIR:-$repo_dir/work}"
iso_dir="${CROWNOS_OUT_DIR:-$repo_dir/out}"
signing_key="${CROWNOS_SIGNING_KEY:-packages@crownos.org}"
version="${CROWNOS_VERSION:-$(date +%Y.%m.%d)}"
all_distros=(arch debian ubuntu fedora)

log() { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m==> error:\033[0m %s\n' "$*" >&2; exit 1; }

refuse_root() {
    [[ "$EUID" -ne 0 ]] || die "run '$1' as your user; only 'iso' needs root"
}

container_runtime() {
    local runtime="${CROWNOS_CONTAINER:-}"
    [[ -n "$runtime" ]] || runtime="$(command -v podman || command -v docker || true)"
    [[ -n "$runtime" ]] || die "podman or docker is needed to build packages"
    printf '%s' "$runtime"
}

# The container image a distro builds in: <Containerfile> [build args…]
image_recipe() {
    case "$1" in
        arch) echo arch.Containerfile ;;
        debian) echo deb.Containerfile --build-arg BASE=debian:trixie ;;
        ubuntu) echo deb.Containerfile --build-arg BASE=ubuntu:26.04 ;;
        fedora) echo fedora.Containerfile ;;
        *) die "unknown distro '$1' (expected: ${all_distros[*]})" ;;
    esac
}

# Run a packaging script inside a distro's build container.
in_container() {
    local distro="$1" script="$2" runtime recipe
    local cache=(-v crownos-cargo-registry:/opt/cargo/registry -v crownos-cargo-git:/opt/cargo/git)
    if [[ -n "${CROWNOS_CARGO_CACHE:-}" ]]; then
        mkdir -p "$CROWNOS_CARGO_CACHE"/{registry,git}
        cache=(-v "$CROWNOS_CARGO_CACHE/registry:/opt/cargo/registry:z"
            -v "$CROWNOS_CARGO_CACHE/git:/opt/cargo/git:z")
    fi
    runtime="$(container_runtime)"
    read -ra recipe <<<"$(image_recipe "$distro")"
    "$runtime" build --quiet -t "crownos-build-$distro" \
        -f "$packaging_dir/containers/${recipe[0]}" "${recipe[@]:1}" \
        "$packaging_dir/containers" >/dev/null
    mkdir -p "$build_dir"
    "$runtime" run --rm \
        -v "$crownos_root:/src:ro,z" \
        -v "$build_dir:/out:z" \
        "${cache[@]}" \
        -e CROWNOS_VERSION="$version" -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
        "crownos-build-$distro" "/src/crownos-iso/packaging/scripts/$script" "$distro"
}

build_packages() {
    refuse_root packages
    local distros=("$@") distro
    [[ ${#distros[@]} -gt 0 ]] || distros=("${all_distros[@]}")
    for distro in "${distros[@]}"; do
        log "building $distro packages ($version)"
        in_container "$distro" build-packages.sh
    done
}

sign() { gpg --batch --yes --local-user "$signing_key" "$@"; }

build_repo() {
    refuse_root repo
    command -v gpg >/dev/null || die "gpg is needed to sign the repository"
    gpg --list-secret-keys "$signing_key" >/dev/null 2>&1 ||
        die "no secret key for '$signing_key'; set CROWNOS_SIGNING_KEY"

    local distro built=0 file
    for distro in "${all_distros[@]}"; do
        compgen -G "$build_dir/packages/$distro/*" >/dev/null || continue
        built=1
        if [[ "$distro" == arch ]]; then
            for file in "$build_dir/packages/arch"/*.pkg.tar.zst; do sign --detach-sign "$file"; done
        fi
        log "indexing $distro"
        in_container "$distro" index-repo.sh
    done
    [[ "$built" -eq 1 ]] || die "no packages in $build_dir/packages; run './build.sh packages' first"

    log "signing the repository indexes"
    for file in "$build_dir"/repo/arch/x86_64/crownos.{db,files}.tar.gz; do
        [[ -f "$file" ]] || continue
        sign --detach-sign "$file"
        ln -sf "$(basename "$file").sig" "${file%.tar.gz}.sig"
    done
    for file in "$build_dir"/repo/deb/dists/*/Release; do
        [[ -f "$file" ]] || continue
        sign --clearsign --output "$(dirname "$file")/InRelease" "$file"
        sign --armor --detach-sign --output "$file.gpg" "$file"
    done
    for file in "$build_dir"/repo/rpm/*/*/repodata/repomd.xml; do
        [[ -f "$file" ]] || continue
        sign --armor --detach-sign "$file"
    done
    gpg --armor --export "$signing_key" >"$repo_key"
    log "repository ready in $build_dir/repo — publish it at the installer's REPO_URL"
}

build_installer() {
    refuse_root installer
    [[ -d "$installer_repo" ]] ||
        die "crownos-installer not found at $installer_repo. Set CROWNOS_INSTALLER_REPO."
    log "building crownos-installer (release)"
    # `--locked` so an ISO build cannot silently pick up different dependency
    # versions than the ones the installer was tested against.
    cargo build --release --locked --manifest-path "$installer_repo/Cargo.toml"
    local built="$installer_repo/target/release/crownos-installer"
    # The kiosk runs it inside cage, where a wrong binary fails with nobody
    # watching; this at least proves it is the right kind of file.
    if command -v file >/dev/null; then
        file -b "$built" | grep -q 'ELF 64-bit' || die "$built is not a 64-bit ELF binary"
    fi
    install -Dm755 "$built" "$staged_installer"
    log "staged $(du -h "$staged_installer" | cut -f1) installer"
}

build_iso() {
    [[ "$EUID" -eq 0 ]] || die "mkarchiso needs root. Try: sudo ./build.sh iso"
    command -v mkarchiso >/dev/null || die "mkarchiso not found. Install the 'archiso' package."
    # Without the installer the ISO boots to a kiosk unit whose ExecStart does
    # not exist; without the key every install fails at the desktop step.
    [[ -f "$staged_installer" ]] || die "no staged installer. Run './build.sh installer' first."
    [[ -f "$repo_key" ]] || die "no repository key at $repo_key. Run './build.sh repo' first."
    install -Dm644 "$repo_key" "$staged_key"
    log "building the ISO into $iso_dir"
    mkarchiso -v -w "$work_dir" -o "$iso_dir" "$profile_dir"
}

action="${1:-}"
[[ $# -gt 0 ]] && shift
case "$action" in
    packages) build_packages "$@" ;;
    repo) build_repo ;;
    installer) build_installer ;;
    iso) build_iso ;;
    *) sed -n '3,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
