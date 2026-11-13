#!/usr/bin/env bash
# Downloads every package the image build and the installer need, with all
# dependencies, and bundles the installer's as an indexed repository the live
# image installs from without a network.
#
#   mirror.sh PACMAN_CONF CACHE_DIR MIRROR_DIR MIRROR_LIST [LIST...]
#
# Each list is fetched into CACHE_DIR as its own transaction, retried with
# backoff, so mkarchiso finds the live packages there instead of downloading
# them itself. CACHE_DIR keeps the downloads between builds and is pruned to
# what the lists resolve to; MIRROR_DIR is rebuilt from MIRROR_LIST as hard
# links.

set -euo pipefail

pacman_conf=${1:?pacman.conf} cache=${2:?cache dir} mirror=${3:?mirror dir}
lists=("${@:4}")
((${#lists[@]})) || { echo 'error: no package list' >&2; exit 1; }
database=$(mktemp -d)
trap 'rm -rf -- "$database"' EXIT

pacman_args=(--config "$pacman_conf" --dbpath "$database" --cachedir "$cache" --noconfirm)
max_attempts=5

pacman_on_list() {
    local list=$1 wanted
    mapfile -t wanted < <(grep -Ev '^[[:space:]]*(#|$)' "$list")
    fakeroot -- pacman "${pacman_args[@]}" "${@:2}" "${wanted[@]}"
}

files_of() { pacman_on_list "$1" -Sp --print-format '%f'; }

retry() {
    local attempt=1
    until "$@"; do
        ((attempt < max_attempts)) || return 1
        printf 'retrying in %ss (attempt %s of %s failed)\n' $((attempt * 15)) "$attempt" "$max_attempts" >&2
        sleep $((attempt * 15))
        ((attempt++))
    done
}

mkdir -p -- "$cache"
retry fakeroot -- pacman "${pacman_args[@]}" -Sy
for list in "${lists[@]}"; do retry pacman_on_list "$list" -Sw; done

declare -A selected
for list in "${lists[@]}"; do
    listed=$(files_of "$list")
    while read -r file; do selected[$file]=1 selected[$file.sig]=1; done <<<"$listed"
done
for path in "$cache"/*; do
    [[ -n ${selected[${path##*/}]:-} ]] || rm -rf -- "$path" || echo "warning: cannot prune $path" >&2
done

mirrored=$(files_of "${lists[0]}")
mapfile -t files <<<"$mirrored"
rm -rf -- "$mirror"
mkdir -p -- "$mirror"
cp --link -- "${files[@]/#/$cache/}" "$mirror/" 2>/dev/null || cp -- "${files[@]/#/$cache/}" "$mirror/"
repo-add --quiet "$mirror/crownos-offline.db.tar.zst" "${files[@]/#/$mirror/}"
