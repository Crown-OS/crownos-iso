#!/usr/bin/env bash
# Pins a component release in components.toml, the only way a new version of a
# CrownOS package enters the system. The only writer of components.toml.
#
#   pin.sh REPO TAG [ASSET [SHA256]]
#   pin.sh --latest REPO
#
# Without ASSET every package on the release is pinned, restricted to the names
# the manifest already takes from REPO (all of them for a new repository). The
# assets are always downloaded and hashed: a SHA256 that differs is fatal. The
# entry's siblings come from the new release's siblings.lock alone, so a pin
# drops the old ones before merging; install, pkgbuild and allow_stale are kept.

set -euo pipefail
shopt -s nullglob

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib.sh
source "$root/scripts/lib.sh"
require_tools gh jq python3 bsdtar sha256sum

usage='usage: pin.sh REPO TAG [ASSET [SHA256]] | pin.sh --latest REPO'
if [[ ${1:-} == --latest ]]; then
    repo=${2:?$usage}
    tag=$(gh release view --repo "$repo" --json tagName --jq .tagName)
    asset='' expected_sha=''
else
    repo=${1:?$usage} tag=${2:?$usage} asset=${3:-} expected_sha=${4:-}
fi

manifest=$root/components.toml
download=$(mktemp -d)
trap 'rm -rf -- "$download"' EXIT

current_manifest() {
    if [[ -e $manifest ]]; then manifest_json; else echo '{"package": []}'; fi
}

release_assets() {
    gh release view "$tag" --repo "$repo" --json assets --jq '.assets[].name'
}

wanted_assets() {
    if [[ -n $asset ]]; then
        printf '%s\n' "$asset"
        return
    fi
    local pinned candidate
    pinned=$(current_manifest | jq -r --arg repo "$repo" '.package[] | select(.repo == $repo) | .name')
    while read -r candidate; do
        [[ $candidate == *.pkg.tar.zst && $candidate != *-debug-* ]] || continue
        [[ -z $pinned ]] || grep -qxF -- "$(package_name "$candidate")" <<<"$pinned" || continue
        printf '%s\n' "$candidate"
    done < <(release_assets)
}

pinned_entry() {
    local file=$download/$1 name sha
    gh release download "$tag" --repo "$repo" --pattern "$1" --dir "$download"
    name=$(package_name "$1")
    [[ $(package_field "$file" pkgname) == "$name" ]] || die "$1 does not contain the package $name"
    sha=$(sha256sum -- "$file")
    sha=${sha%% *}
    [[ -z $expected_sha || $expected_sha == "$sha" ]] || die "$1 hashes to $sha, not $expected_sha"
    jq -n --arg name "$name" --arg repo "$repo" --arg tag "$tag" --arg asset "$1" --arg sha "$sha" \
        '{name: $name, repo: $repo, tag: $tag, asset: $asset, sha256: $sha}'
}

# siblings.lock lines are "<repo> <commit>" or "<dir> <repo> <commit>". The
# shared package workflow uploads <asset>.sha256 always and skips an empty lock,
# so a release with the checksum but no lock has no siblings; a release with
# neither predates the workflow and its siblings stay unknown.
siblings_json() {
    local published
    published=$(release_assets)
    if ! grep -qxF siblings.lock <<<"$published"; then
        if grep -qxF "${assets[0]}.sha256" <<<"$published"; then echo '{}'; else echo null; fi
        return
    fi
    gh release download "$tag" --repo "$repo" --pattern siblings.lock --dir "$download"
    local first second third dir commit
    while read -r first second third; do
        [[ -n $first && $first != '#'* ]] || continue
        if [[ -n $third ]]; then
            dir=$first commit=$third
        else
            dir=$(sibling_dir "${first##*/}") commit=$second
        fi
        jq -n --arg dir "$dir" --arg commit "$commit" '{($dir): $commit}'
    done <"$download/siblings.lock" | jq -s 'add // {}'
}

mapfile -t assets < <(wanted_assets)
((${#assets[@]})) || die "$repo $tag has no package to pin"
[[ -z $expected_sha || ${#assets[@]} == 1 ]] || die "a SHA256 needs exactly one ASSET"

entries=$(for each in "${assets[@]}"; do pinned_entry "$each"; done | jq -s .)
siblings=$(siblings_json)

current_manifest | jq --argjson entries "$entries" --argjson siblings "$siblings" --arg repo "$repo" '
    reduce $entries[] as $new (.;
        if any(.package[]; .name == $new.name and (.repo // "") != $repo)
        then error("\($new.name) is already pinned from another source") else . end
        | ($new + (if $siblings == null then {} else {siblings: $siblings} end)) as $pin
        | if any(.package[]; .name == $new.name)
          then .package |= map(if .name == $new.name then del(.siblings) + $pin else . end)
          else .package += [$pin] end)' | toml write >"$manifest.new"
mv -- "$manifest.new" "$manifest"
printf 'pinned %s %s: %s\n' "$repo" "$tag" "${assets[*]}"
