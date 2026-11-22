#!/usr/bin/env bash
# Packs the packages pinned in components.toml into a bootable ISO under out/.
#
#   build.sh [--repo DIR] [--installer CHECKOUT] [--icon-theme CHECKOUT] [--squashfs-level LEVEL]
#
#   --repo        an already resolved repository, like CI's repo artifact
#                 [default: resolve components.toml into target/repo]
#   --installer   build this crownos-installer checkout instead of using its release,
#                 and its crownos-setup package into the repository as a system package
#   --icon-theme  the crownos-icon-theme checkout to install [default: ../crownos-icon-theme]
#   --squashfs-level  the zstd level of the live image, 1 to 22 [default: 19]. A lower
#                 level builds much faster and makes the ISO a little larger
#
# The live image installs every system and live package of the manifest. The
# offline mirror the installer pacstraps from holds profile/install.packages
# plus the manifest's system packages, with all dependencies, and the image
# carries the published-shape manifest and the repository key so the installer
# knows what to install and always adds the [crownos] repository.

set -euo pipefail
shopt -s nullglob

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib.sh
source "$root/scripts/lib.sh"
# shellcheck source=scripts/repo.sh
source "$root/scripts/repo.sh"

profile=$root/profile
target=$root/target
staged_mirror=$profile/airootfs/var/cache/crownos/mirror
staged_installer=$profile/airootfs/usr/bin/crownos-installer
staged_key=$profile/airootfs/usr/share/crownos/crownos-archive-keyring.asc
staged_manifest=$profile/airootfs/usr/share/crownos/manifest.toml
staged_root_config=$profile/airootfs/root/.config
staged_live_config=$profile/airootfs/home/crownos-live/.config
staged_live_home=$profile/airootfs/home/crownos-live
staged_pacman_conf=$profile/airootfs/etc/pacman.conf
keyring=$root/packaging/crownos-keyring/crownos.gpg
package_cache=$target/pkg-cache

repo_dir='' installer='' icon_theme=$root/../crownos-icon-theme squashfs_level=19
while (($#)); do
    case $1 in
        --repo) repo_dir=$(realpath -- "${2:?--repo needs a directory}"); shift 2 ;;
        --installer) installer=$(realpath -- "${2:?--installer needs a checkout}"); shift 2 ;;
        --icon-theme) icon_theme=${2:?--icon-theme needs a checkout}; shift 2 ;;
        --squashfs-level) squashfs_level=${2:?--squashfs-level needs a level}; shift 2 ;;
        *) die "unknown argument: $1" ;;
    esac
done
if [[ ! $squashfs_level =~ ^[0-9]+$ ]] || ((squashfs_level < 1 || squashfs_level > 22)); then
    die "--squashfs-level must be 1 to 22, not $squashfs_level"
fi
[[ -x $icon_theme/install.sh ]] || die "no crownos-icon-theme checkout at $icon_theme"
((EUID != 0)) || die "run as a normal user; only the mkarchiso step needs root and asks sudo for it"
[[ -e $keyring ]] || die "packaging/crownos-keyring/crownos.gpg is missing: run scripts/export-key.sh packages@crownos.org (docs/publishing.md)"

resolve_repository() {
    if [[ -z $repo_dir ]]; then
        repo_dir=$target/repo
        "$root/scripts/manifest.sh" resolve "$repo_dir" --icon-theme "$icon_theme"
    fi
    [[ -e $repo_dir/crownos.db ]] || die "$repo_dir is not a resolved repository"
}

# A local build keeps the version of the PKGBUILD, so an older file of the same
# name in the repository or the package cache would hide the new bytes.
build_local_setup_package() {
    local packaging=$installer/packaging/crownos-setup file
    [[ -n $installer && -e $packaging/PKGBUILD ]] || return 0
    for file in "$repo_dir"/crownos-setup-*.pkg.tar.zst* "$package_cache"/crownos-setup-*.pkg.tar.zst*; do
        [[ $(package_name "${file%.sig}") == crownos-setup ]] && rm -f -- "$file"
    done
    (cd -- "$packaging" && BUILDDIR=$target/build PKGDEST=$repo_dir SRCDEST=$target/src \
        makepkg --force --nodeps --cleanbuild --noconfirm)
    rm -f -- "$repo_dir"/crownos.{db,files}*
    repo-add --quiet "$repo_dir/crownos.db.tar.zst" "$repo_dir"/*.pkg.tar.zst
    dereference_db_links "$repo_dir"
    local_system_packages+=(crownos-setup)
}

# The packages built from packaging/ keep their version on each resolve, but
# makepkg writes new bytes, so pacman rejects the older cached file of that name.
drop_stale_cached_packages() {
    local package cached
    for package in "$repo_dir"/*.pkg.tar.zst; do
        cached=$package_cache/${package##*/}
        if [[ -e $cached ]] && ! cmp -s -- "$package" "$cached"; then
            rm -f -- "$cached" "$cached.sig"
        fi
    done
}

# A repository publish.sh already signed carries .sig files, and pacman checks a
# signature that is present even under Optional, against a build keyring that
# has no CrownOS key. Every asset was verified against its pinned sha256 and
# the database was built here, so the build repository is trusted as is.
# mkarchiso installs from the CacheDir mirror.sh already filled with retries.
write_pacman_conf() {
    sed "/^\[options\]/a CacheDir = $package_cache/" -- "$profile/pacman.conf" >"$target/pacman.conf"
    printf '\n[crownos]\nSigLevel = Never\nServer = file://%s\n' "$repo_dir" >>"$target/pacman.conf"
}

stage_install_list() {
    {
        grep -Ev '^[[:space:]]*(#|$)' "$profile/install.packages"
        "$root/scripts/manifest.sh" names system
        ((${#local_system_packages[@]} == 0)) || printf '%s\n' "${local_system_packages[@]}"
    } | sort -u >"$target/install.packages"
}

stage_live_list() {
    {
        grep -Ev '^[[:space:]]*(#|$)' "$profile/packages.x86_64"
        printf '%s\n' "${packages[@]}"
    } | sort -u >"$target/live.packages"
}

stage_manifest() {
    mkdir -p -- "${staged_manifest%/*}"
    "$root/scripts/manifest.sh" published "$(default_channel)" "$repo_dir" "${local_system_packages[@]}" >"$staged_manifest"
}

stage_root_config() {
    rm -rf -- "$staged_root_config"
    mkdir -p -- "$staged_root_config"
    cp -r -- "$root/config/." "$staged_root_config/"
}

stage_live_config() {
    rm -rf -- "$staged_live_config"
    mkdir -p -- "$staged_live_config/crownos"
    cp -r -- "$root/config/." "$staged_live_config/"
    cp -- "$profile/airootfs/usr/share/crownos/live/compositor.ron" \
        "$staged_live_config/crownos/compositor.ron"
}

# crownos-neovim puts Neovim's plugins and parsers in /etc/skel, which the
# prebuilt live home never copies from, so its files are unpacked there too.
stage_live_nvim_data() {
    local packages=("$repo_dir"/crownos-neovim-*.pkg.tar.zst)
    ((${#packages[@]} == 1)) || die "$repo_dir needs exactly one crownos-neovim package"
    rm -rf -- "$staged_live_home/.local"
    bsdtar -xf "${packages[0]}" -C "$staged_live_home" --strip-components 2 etc/skel/.local
}

# crownos-yazi puts Yazi's plugins in /etc/skel, which the prebuilt live home
# never copies from, so its plugins are unpacked into the live config too.
stage_live_yazi_plugins() {
    local packages=("$repo_dir"/crownos-yazi-*.pkg.tar.zst)
    ((${#packages[@]} == 1)) || die "$repo_dir needs exactly one crownos-yazi package"
    bsdtar -xf "${packages[0]}" -C "$staged_live_config" --strip-components 3 etc/skel/.config/yazi/plugins
}

stage_pacman_conf() {
    install -Dm644 -- "$profile/pacman.conf" "$staged_pacman_conf"
}

stage_mirror() {
    "$root/scripts/mirror.sh" "$target/pacman.conf" "$package_cache" "$staged_mirror" \
        "$target/install.packages" "$target/live.packages"
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
    local keyring_home
    keyring_home=$(mktemp -d)
    gpg --homedir "$keyring_home" --batch --quiet --import "$keyring"
    mkdir -p -- "${staged_key%/*}"
    gpg --homedir "$keyring_home" --batch --armor --export >"$staged_key"
    rm -rf -- "$keyring_home"
}

live_packages() {
    local name
    while read -r name; do
        [[ $name == crownos-installer && -n $installer ]] || packages+=("$name")
    done < <("$root/scripts/manifest.sh" names live)
}

mkdir -p -- "$target"
resolve_repository
local_system_packages=()
build_local_setup_package
drop_stale_cached_packages
packages=()
live_packages
write_pacman_conf
stage_install_list
stage_live_list
stage_manifest
stage_root_config
stage_live_config
stage_live_nvim_data
stage_live_yazi_plugins
stage_pacman_conf
stage_repo_key
stage_mirror
stage_installer

sudo rm -rf -- "$target/iso-work"
sudo env CROWNOS_SQUASHFS_LEVEL="$squashfs_level" mkarchiso -v -r -w "$target/iso-work" -o "$root/out" -C "$target/pacman.conf" -p "${packages[*]}" "$profile"
