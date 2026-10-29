#!/usr/bin/env bash
# Packs the latest CrownOS component releases into a bootable ISO under out/.
#
#   build.sh [--installer CHECKOUT] [--repo-key KEY] [--missing-release fail|skip]
#
#   --installer        build this crownos-installer checkout instead of using its release
#   --repo-key         the CrownOS repository signing key the installer trusts
#   --missing-release  what to do with a component that has no release yet [default: fail]
#
# Every package the components publish is installed into the image, which is
# what the live desktop runs from. The same packages, wrapped in the
# crownos-desktop meta package, are bundled with the base system as the offline
# repository the installer pacstraps from.

set -euo pipefail
shopt -s nullglob

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib.sh
source "$root/scripts/lib.sh"

profile=$root/profile
target=$root/target
repo_dir=$target/repo
staged_mirror=$profile/airootfs/var/cache/crownos/mirror
staged_installer=$profile/airootfs/usr/bin/crownos-installer
staged_key=$profile/airootfs/usr/share/crownos/crownos-archive-keyring.asc
staged_icons=$profile/airootfs/usr/share/icons
icon_theme_release=2026-09-10
icon_theme_archive=$target/whitesur-icon-theme-$icon_theme_release.tar.gz

warn() { printf 'warning: %s\n' "$*" >&2; }

installer='' repo_key='' missing_release=fail
while (($#)); do
    case $1 in
        --installer) installer=$(realpath -- "${2:?--installer needs a checkout}"); shift 2 ;;
        --repo-key) repo_key=${2:?--repo-key needs a file}; shift 2 ;;
        --missing-release) missing_release=${2:?--missing-release needs fail or skip}; shift 2 ;;
        *) die "unknown argument: $1" ;;
    esac
done
[[ $missing_release == @(fail|skip) ]] || die "--missing-release must be fail or skip"
((EUID != 0)) || die "run as a normal user; only the mkarchiso step needs root and asks sudo for it"

fetch_components() {
    rm -rf -- "$repo_dir"
    mkdir -p -- "$repo_dir"
    local repository
    while read -r repository <&3; do
        [[ -n $repository ]] || continue
        gh release download --repo "$repository" --dir "$repo_dir" --pattern '*.pkg.tar.zst' && continue
        [[ $missing_release == skip ]] || die "$repository has no release with packages"
        warn "skipping $repository"
    done 3<"$root/components.txt"
}

published_names() {
    local package name
    for package in "$repo_dir"/*.pkg.tar.zst; do
        name=${package##*/}
        name=${name%-*-*-*}
        [[ $name == *-debug ]] || printf '%s\n' "$name"
    done
}

live_packages() {
    local name
    for name in "${published[@]}"; do
        [[ $name == crownos-installer ]] || components+=("$name")
        [[ $name == crownos-installer && -n $installer ]] || packages+=("$name")
    done
    packages+=(crownos-desktop)
}

build_desktop_package() {
    local build=$target/crownos-desktop
    rm -rf -- "$build"
    cp -r -- "$root/packaging/." "$build"
    cp -r -- "$root/config" "$build/config"
    cp -r -- "$root/config/." "$profile/airootfs/etc/skel/.config/"
    cp -r -- "$root/config/." "$profile/airootfs/home/crownos-live/.config/"
    cp -r -- "$root/config/." "$profile/airootfs/root/.config/"
    install -Dm644 -- "$root/profile/airootfs/etc/default/useradd" "$profile/airootfs/etc/default/useradd"
    install -Dm644 -- "$root/profile/airootfs/etc/default/useradd" "$build/useradd"
    (cd -- "$build" && CROWNOS_COMPONENTS="${components[*]}" CROWNOS_VERSION=$(date +%Y.%m.%d) \
        PKGDEST=$repo_dir makepkg --force --nodeps)
}

write_pacman_conf() {
    cp -- "$profile/pacman.conf" "$target/pacman.conf"
    repo-add "$repo_dir/crownos.db.tar.zst" "$repo_dir"/*.pkg.tar.zst
    printf '\n[crownos]\nSigLevel = Optional TrustAll\nServer = file://%s\n' "$repo_dir" >>"$target/pacman.conf"
}

stage_mirror() {
    "$root/scripts/mirror.sh" "$target/pacman.conf" "$profile/install.packages" "$staged_mirror" "$target/pkg-cache"
}

stage_installer() {
    if [[ -n $installer ]]; then
        cargo build --release --locked --manifest-path "$installer/Cargo.toml"
        install -Dm755 -- "$installer/target/release/crownos-installer" "$staged_installer"
    else
        rm -f -- "$staged_installer"
    fi
}

stage_repo_key() {
    if [[ -n $repo_key ]]; then
        install -Dm644 -- "$repo_key" "$staged_key"
    elif [[ ! -e $staged_key ]]; then
        warn "no --repo-key given; the installer cannot add the CrownOS desktop"
    fi
}

stage_icon_theme() {
    if [[ ! -e $icon_theme_archive ]]; then
        mkdir -p -- "$target"
        curl -fsSL --output "$icon_theme_archive.part" \
            "https://github.com/vinceliuice/WhiteSur-icon-theme/archive/refs/tags/$icon_theme_release.tar.gz"
        mv -- "$icon_theme_archive.part" "$icon_theme_archive"
    fi
    local source=$target/whitesur-icon-theme
    rm -rf -- "$source" "$staged_icons"
    mkdir -p -- "$source"
    tar -xzf "$icon_theme_archive" --strip-components=1 -C "$source"
    "$source/install.sh" --dest "$staged_icons"
}

fetch_components
mapfile -t published < <(published_names)
components=() packages=()
live_packages
build_desktop_package
write_pacman_conf
stage_mirror
stage_installer
stage_repo_key
stage_icon_theme

sudo mkarchiso -v -r -w "$target/iso-work" -o "$root/out" -C "$target/pacman.conf" -p "${packages[*]}" "$profile"
