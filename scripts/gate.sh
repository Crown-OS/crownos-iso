#!/usr/bin/env bash
# Fails when a pinned component's default branch is ahead of its pinned tag, so
# an ISO tag never ships a component missing work that already landed. Mark an
# entry allow_stale = true in components.toml to accept it. On a release
# version it also checks releases/<version>/ (releases/README.md): the retired
# packages, and that a session restart is not used when a unit changed.
#
#   gate.sh

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib.sh
source "$root/scripts/lib.sh"
require_tools gh git jq python3 vercmp

check_release_directory() {
    local version=$1 file
    for file in release.toml notes.md; do
        [[ -s $root/releases/$version/$file ]] || die "releases/$version/$file is missing or empty (releases/README.md)"
    done
    release_restart "$version" stable >/dev/null
    local post_update=$root/releases/$version/post-update.sh
    [[ ! -e $post_update ]] || bash -n -- "$post_update" || die "releases/$version/post-update.sh has a syntax error"
    check_retired "$version"
    check_restart_starts_changed_units "$version"
}

check_retired() {
    local version=$1 retired shipped
    retired=$(release_retired "$version")
    shipped=$(manifest_json | jq -r --argjson retired "$retired" \
        '[.package[].name] as $names | $retired[] | select(IN($names[]))')
    [[ -z $shipped ]] || die "releases/$version/release.toml retires packages that components.toml still lists: ${shipped//$'\n'/ }"
}

# The release before VERSION, empty for the first release.
previous_release() {
    local version=$1 release previous=''
    while read -r release; do
        [[ $release == "$version" ]] || previous=$release
    done < <(release_chain "$version")
    printf '%s\n' "$previous"
}

# The unit files, wants links and preset lines in packaging/ that changed
# since TAG, and the PKGBUILD lines that install or link a unit.
changed_units() {
    local tag=$1 files pkgbuild_changes
    files=$(git -C "$root" diff --name-only "$tag" HEAD -- packaging) || die "cannot compare packaging/ with $tag"
    pkgbuild_changes=$(git -C "$root" diff "$tag" HEAD -- 'packaging/*/PKGBUILD') || die "cannot compare the PKGBUILDs with $tag"
    grep -E '\.(service|timer|socket|preset)$|\.wants/' <<<"$files" || true
    grep -E '^[-+][^-+].*(\.wants|systemd/(system|user)|system-preset)' <<<"$pkgbuild_changes" || true
}

# A session restart does not restart the system manager or the user manager,
# so a changed unit starts only at the next boot or login.
check_restart_starts_changed_units() {
    local version=$1 restart previous changed
    restart=$(release_restart "$version" stable)
    [[ $restart == session ]] || return 0
    previous=$(previous_release "$version")
    [[ -n $previous ]] || return 0
    changed=$(changed_units "v$previous")
    [[ -z $changed ]] || die "releases/$version/release.toml: restart = \"session\" does not start the units that changed since v$previous; use soft-reboot or reboot:"$'\n'"$changed"
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
