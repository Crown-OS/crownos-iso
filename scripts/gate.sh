#!/usr/bin/env bash
# Fails when a pinned component's default branch is ahead of its pinned tag, so
# an ISO tag never ships a component missing work that already landed. Mark an
# entry allow_stale = true in components.toml to accept it.
#
#   gate.sh

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib.sh
source "$root/scripts/lib.sh"
require_tools gh jq python3

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
