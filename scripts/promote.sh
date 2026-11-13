#!/usr/bin/env bash
# Publishes the repository an ISO tag was built and tested from as the
# immutable GitHub release repo-<tag> and as repo-stable. testing is never read.
#
#   promote.sh TAG REPO_DIR [--force-stable]
#
# REPO_DIR is the resolved repository of the tag's build, signed or not. A re-run
# with the same build continues where it stopped; another build for a published
# tag is refused. stable is left alone when it already holds a newer version,
# unless --force-stable rolls it back on purpose. Needs GPGKEY, a GH_TOKEN that
# can write releases, and a checkout that has TAG.

set -euo pipefail
shopt -s nullglob

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib.sh
source "$root/scripts/lib.sh"
# shellcheck source=scripts/repo.sh
source "$root/scripts/repo.sh"

usage='usage: promote.sh TAG REPO_DIR [--force-stable]'
tag=${1:?$usage} repo_dir=${2:?$usage} force_stable=${3:-}
[[ -z $force_stable || $force_stable == --force-stable ]] || die "$usage"
require_publishing_env
require_tools vercmp git

archive_tag=$(release_tag "$tag")
stable_tag=$(release_tag stable)
staged=$root/target/stable

check_artifact_matches_tag() {
    local manifest=$1 version build expected_build
    version=$(toml json "$manifest" | jq -r .version)
    build=$(toml json "$manifest" | jq -r .build_id)
    expected_build=$(git -C "$root" rev-parse "$tag^{commit}") || die "this checkout has no tag $tag"
    [[ $version == "${tag#v}" ]] || die "the repository is version $version, not ${tag#v}"
    [[ $build == "$expected_build" ]] || die "the repository was built from $build, not $tag ($expected_build)"
}

check_release_is_ours() {
    manifest_published "$archive_tag" || return 0
    local published_build ours
    published_build=$(verified_manifest_field "$archive_tag" build_id)
    ours=$(toml json "$staged/manifest.toml" | jq -r .build_id)
    [[ $published_build == "$ours" ]] ||
        die "$archive_tag already holds build $published_build; releases are immutable"
}

stable_is_newer() {
    [[ -z $force_stable ]] && manifest_published "$stable_tag" || return 1
    local stable ours
    stable=$(verified_manifest_field "$stable_tag" version) ||
        die "$stable_tag's manifest.toml does not verify; pass --force-stable to overwrite it"
    ours=$(toml json "$staged/manifest.toml" | jq -r .version) || die "cannot read $staged/manifest.toml"
    (($(vercmp "$stable" "$ours") > 0)) || return 1
    printf '::notice::stable holds newer %s; not touching stable\n' "$stable"
}

mkdir -p -- "$staged"
sign_packages "$repo_dir"
rebuild_database "$repo_dir"
"$root/scripts/manifest.sh" published stable "$repo_dir" >"$staged/manifest.toml"
check_artifact_matches_tag "$staged/manifest.toml"
sign_file "$staged/manifest.toml"

check_release_is_ours
publish_repository "$archive_tag" "$repo_dir" "$staged"

stable_is_newer && exit 0
publish_repository "$stable_tag" "$repo_dir" "$staged"
printf 'promoted %s to %s and %s\n' "$tag" "$archive_tag" "$stable_tag"
