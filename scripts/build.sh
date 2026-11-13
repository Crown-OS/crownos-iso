#!/usr/bin/env bash
# Packs the packages pinned in components.toml into a bootable ISO under out/.
#
#   build.sh [--repo DIR] [--installer CHECKOUT] [--icon-theme CHECKOUT]
#
#   --repo        an already resolved repository, like CI's repo artifact
#                 [default: resolve components.toml into target/repo]
#   --installer   build this crownos-installer checkout instead of using its release
#   --icon-theme  the crownos-icon-theme checkout to install [default: ../crownos-icon-theme]
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

repo_dir='' installer='' icon_theme=$root/../crownos-icon-theme
while (($#)); do
    case $1 in
        --repo) repo_dir=$(realpath -- "${2:?--repo needs a directory}"); shift 2 ;;
        --installer) installer=$(realpath -- "${2:?--installer needs a checkout}"); shift 2 ;;
        --icon-theme) icon_theme=${2:?--icon-theme needs a checkout}; shift 2 ;;
        *) die "unknown argument: $1" ;;
    esac
done
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
    "$root/scripts/manifest.sh" published "$(default_channel)" "$repo_dir" >"$staged_manifest"
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
packages=()
live_packages
write_pacman_conf
stage_install_list
stage_live_list
stage_manifest
stage_root_config
stage_live_config
stage_live_nvim_data
stage_pacman_conf
stage_repo_key
stage_mirror
stage_installer

sudo rm -rf -- "$target/iso-work"
sudo mkarchiso -v -r -w "$target/iso-work" -o "$root/out" -C "$target/pacman.conf" -p "${packages[*]}" "$profile"
