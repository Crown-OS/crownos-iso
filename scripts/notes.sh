#!/usr/bin/env bash
# Prints the release notes of an ISO version: releases/<version>/notes.md (a
# short header for testing builds), then the GitHub release notes of each
# component whose pin changed since the previous v* tag.
#
#   notes.sh VERSION
#
# The pins come from the components.toml of the checkout and of the previous
# tag. A tag without components.toml counts as no pins, so all are new.

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib.sh
source "$root/scripts/lib.sh"
require_tools gh git jq python3

version=${1:?usage: notes.sh VERSION}

# sort -V and not vercmp: the publish job runs on a runner without pacman.
previous_tag() {
    { git -C "$root" tag --list 'v[0-9]*' | sed 's/^v//'; printf '%s\n' "$version"; } |
        sort -uV | awk -v version="$version" '$0 == version { if (NR > 1) print "v" previous; exit } { previous = $0 }'
}

pins_of() { toml json /dev/stdin | jq -c '[.package[] | select(.repo) | {(.repo): .tag}] | add // {}'; }

previous_pins() {
    local tag
    tag=$(previous_tag)
    if [[ -n $tag ]] && git -C "$root" cat-file -e "$tag:components.toml" 2>/dev/null; then
        git -C "$root" show "$tag:components.toml" | pins_of
    else
        echo '{}'
    fi
}

introduction() {
    local notes=$root/releases/$version/notes.md
    if [[ -e $notes ]]; then
        tr -d '\r' <"$notes"
    elif [[ $version =~ ^([0-9]+\.[0-9]+\.[0-9]+)\.r([0-9]+)\.g ]]; then
        printf 'A testing build of CrownOS, %s commits after v%s. It can change at any time.\n' \
            "${BASH_REMATCH[2]}" "${BASH_REMATCH[1]}"
    else
        printf 'warning: releases/%s/notes.md is missing\n' "$version" >&2
        return
    fi
    echo
}

component_section() {
    local heading=$1 repo=$2 tag=$3 body
    body=$(gh release view "$tag" --repo "$repo" --json body --jq .body </dev/null) || {
        printf '::warning::cannot read the %s release of %s\n' "$tag" "$repo" >&2
        body=''
    }
    body=${body//$'\r'/}
    printf '\n### %s\n\n%s\n' "$heading" "${body:-No release notes.}"
}

changes() {
    jq -nr --argjson old "$(previous_pins)" --argjson new "$(pins_of <"$root/components.toml")" '
        ($new | keys_unsorted) as $current
        | ($current + (($old | keys_unsorted) - $current))[] as $repo
        | if $old[$repo] == null then "added \($repo) \($new[$repo])"
          elif $new[$repo] == null then "removed \($repo) \($old[$repo])"
          elif $old[$repo] != $new[$repo] then "changed \($repo) \($new[$repo]) \($old[$repo])"
          else empty end'
}

pin_changes=$(changes)
introduction
echo '## Components'
[[ -n $pin_changes ]] || { printf '\nNo component changed.\n'; exit 0; }
while read -r change repo tag old_tag; do
    case $change in
        added) component_section "${repo##*/} $tag (new)" "$repo" "$tag" ;;
        changed) component_section "${repo##*/} $old_tag → $tag" "$repo" "$tag" ;;
        removed) printf '\n### %s\n\nNo longer part of CrownOS.\n' "${repo##*/} $tag (removed)" ;;
    esac
done <<<"$pin_changes"
