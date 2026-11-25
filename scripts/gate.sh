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
    check_reduction_follows_a_layered_release "$version"
}

# A home is not rolled back with the system. defaults/history/reduce-home-files
# lets crownos-config and refresh-shipped-dotfiles change the files that earlier
# releases copied into homes, which only a release with the default layers can
# read. So the release before the one that ships it must have the layers.
check_reduction_follows_a_layered_release() {
    local version=$1 previous
    [[ -e $root/defaults/history/reduce-home-files ]] || return 0
    previous=$(previous_release "$version")
    if [[ -z $previous ]] || ! git -C "$root" cat-file -e "v$previous:defaults/history" 2>/dev/null; then
        die "defaults/history/reduce-home-files ships in $version, but v${previous:-<none>} has no default layers; a rollback to it would read reduced home files. Ship it from the release after the first one with layers (releases/README.md)"
    fi
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

# crownos-config 0.2.0 reads the distro defaults in /usr/share/crownos/defaults
# below the user's changes, and it reduces the user's file. An older reader
# reads only the user's file and gets nothing from crownos-base, so one ISO
# must not mix the two.
layered_config_version=0.2.0

pinned_crownos_config_version() {
    local repo=$1 tag=$2
    gh api -H 'Accept: application/vnd.github.raw' "repos/$repo/contents/Cargo.lock?ref=$tag" 2>/dev/null |
        awk '/^name = "crownos-config"$/ { found = 1; next } found && /^version = / { gsub(/"/, "", $3); print $3; exit }'
}

check_layered_config_readers() {
    local repo tag used old=()
    while read -r repo tag; do
        used=$(pinned_crownos_config_version "$repo" "$tag")
        [[ -z $used ]] || (($(vercmp "$used" "$layered_config_version") >= 0)) ||
            old+=("$repo $tag: crownos-config $used")
    done < <(manifest_json | jq -r '[.package[] | select(.repo) | "\(.repo) \(.tag)"] | unique[]')
    ((${#old[@]} == 0)) && return 0
    printf '%s\n' "${old[@]}" >&2
    die "the components above read the config without the default layers; rebuild and tag them with crownos-config $layered_config_version"
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
check_layered_config_readers
echo "every pinned component reads the default layers"
