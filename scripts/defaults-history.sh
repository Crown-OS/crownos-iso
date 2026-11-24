#!/usr/bin/env bash
# Writes defaults-history/<version>/<section>.ron: the distro defaults in
# config/crownos/ at each released tag. Up to 0.3.0, crownos-base copied these
# files into each new home, and crownos-setup then put the chosen browser into
# the dock, so each dock also gets one variant for each browser, in
# defaults-history/<version>+<browser>/dock.ron. crownos-config reduces a user
# file to the keys that differ from all of these. defaults-history/dotfiles.sha256
# lists each shipped version of the dotfiles that now have a system path, for
# remove-shipped-dotfiles. Run it after you tag a release that changed config/,
# and commit the result.
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
history=$root/defaults-history
applications=/usr/share/applications
setup_browsers=(brave-browser google-chrome firefox)
system_path_dotfiles='^config/(fish/config\.fish|kitty/|fastfetch/|starship\.toml$|mimeapps\.list$|crownos/templates/)'

write_release() {
    local tag=$1 version=${1#v} file
    while IFS= read -r file; do
        mkdir -p -- "$history/$version"
        git -C "$root" show "$tag:$file" >"$history/$version/${file##*/}"
    done < <(git -C "$root" ls-tree --name-only "$tag" config/crownos/ | grep '\.ron$')
}

write_dock_variants() {
    local version=$1 dock=$history/$1/dock.ron browser
    [[ -f $dock ]] && grep -q "\"$applications/chromium.desktop\"" "$dock" || return 0
    for browser in "${setup_browsers[@]}"; do
        mkdir -p -- "$history/$version+$browser"
        sed "s|\"$applications/chromium.desktop\"|\"$applications/$browser.desktop\"|" \
            "$dock" >"$history/$version+$browser/dock.ron"
    done
}

write_dotfile_hashes() {
    local tag=$1 file hash
    while IFS= read -r file; do
        hash=$(git -C "$root" show "$tag:$file" | sha256sum)
        printf '%s  %s\n' "${hash%% *}" "${file#config/}"
    done < <(git -C "$root" ls-tree -r --name-only "$tag" config/ | grep -E "$system_path_dotfiles")
}

rm -rf -- "$history"
while IFS= read -r tag; do
    write_release "$tag"
    write_dock_variants "${tag#v}"
    write_dotfile_hashes "$tag"
done < <(git -C "$root" tag -l 'v*' | sort -V) | sort -u -k2,2 -k1,1 >"$root/dotfiles.sha256.tmp"
mv -- "$root/dotfiles.sha256.tmp" "$history/dotfiles.sha256"
