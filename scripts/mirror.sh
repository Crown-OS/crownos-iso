#!/usr/bin/env bash
# Bundles every package the installer can pacstrap, with all dependencies, as an
# indexed repository the live image installs from without a network.
#
#   mirror.sh PACMAN_CONF PACKAGE_LIST MIRROR_DIR CACHE_DIR
#
# CACHE_DIR keeps the downloads between builds and is pruned to what the
# current list resolves to; MIRROR_DIR is rebuilt from it as hard links.

set -euo pipefail

pacman_conf=${1:?pacman.conf} package_list=${2:?package list} mirror=${3:?mirror dir} cache=${4:?cache dir}
database=$(mktemp -d)
trap 'rm -rf -- "$database"' EXIT

mapfile -t wanted < <(grep -Ev '^[[:space:]]*(#|$)' "$package_list")
pacman_args=(--config "$pacman_conf" --dbpath "$database" --cachedir "$cache" --noconfirm)

mkdir -p -- "$cache"
download() { fakeroot -- pacman "${pacman_args[@]}" -Syw "${wanted[@]}"; }
download || download
mapfile -t files < <(fakeroot -- pacman "${pacman_args[@]}" -Sp --print-format '%f' "${wanted[@]}")

declare -A selected
for file in "${files[@]}"; do selected[$file]=1; done
for path in "$cache"/*; do
    [[ -n ${selected[${path##*/}]:-} ]] || rm -f -- "$path"
done

rm -rf -- "$mirror"
mkdir -p -- "$mirror"
cp --link -- "${files[@]/#/$cache/}" "$mirror/" 2>/dev/null || cp -- "${files[@]/#/$cache/}" "$mirror/"
repo-add --quiet "$mirror/crownos-offline.db.tar.zst" "${files[@]/#/$mirror/}"
