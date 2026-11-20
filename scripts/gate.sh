#!/usr/bin/env bash
# Fails when a pinned component's default branch is ahead of its pinned tag, so
# an ISO tag never ships a component missing work that already landed. Mark an
# entry allow_stale = true in components.toml to accept it. On a release
# version it also checks releases/<version>/ (releases/README.md).
#
#   gate.sh

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib.sh
source "$root/scripts/lib.sh"
require_tools gh git jq python3

check_release_directory() {
    local version=$1 file
    for file in release.toml notes.md; do
        [[ -s $root/releases/$version/$file ]] || die "releases/$version/$file is missing or empty (releases/README.md)"
    done
    release_restart "$version" stable >/dev/null
    local post_update=$root/releases/$version/post-update.sh
    [[ ! -e $post_update ]] || bash -n -- "$post_update" || die "releases/$version/post-update.sh has a syntax error"
}

version=$(iso_version)
if [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    check_release_directory "$version"
fi

stale=()
while read -r repo tag; do
    branch=$(gh api "repos/$repo" --jq .default_branch)
    ahead=$(gh api "repos/$repo/compare/$tag...$branch" --jq .ahead_by)
    [[ $ahead =~ ^[0-9]+$ ]] || die "cannot compare $repo $tag with $branch (got '$ahead')"
    ((ahead == 0)) || stale+=("$repo: $branch is $ahead commits ahead of $tag")
done < <(manifest_json | jq -r '[.package[] | select(.repo and (.allow_stale | not)) | "\(.repo) \(.tag)"] | unique[]')

if ((${#stale[@]})); then
    printf '%s\n' "${stale[@]}" >&2
    die "tag the components above and pin them with scripts/pin.sh, or set allow_stale = true"
fi
echo "every pinned component is at the head of its default branch"
