#!/usr/bin/env bash
# Signs a resolved repository and publishes it as the testing channel, the
# GitHub release repo-testing.
#
#   publish.sh testing REPO_DIR
#
# Needs GPGKEY (the signing key) and a GH_TOKEN that can write releases. Only
# scripts/promote.sh writes repo-stable and repo-<tag>.

set -euo pipefail
shopt -s nullglob

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib.sh
source "$root/scripts/lib.sh"
# shellcheck source=scripts/repo.sh
source "$root/scripts/repo.sh"

channel=${1:?usage: publish.sh testing REPO_DIR}
repo_dir=${2:?usage: publish.sh testing REPO_DIR}
[[ $channel == testing ]] || die "publish.sh only writes testing; scripts/promote.sh writes stable"
require_publishing_env

staged=$root/target/$channel
mkdir -p -- "$staged"
sign_packages "$repo_dir"
rebuild_database "$repo_dir"
"$root/scripts/manifest.sh" published "$channel" "$repo_dir" >"$staged/manifest.toml"
sign_file "$staged/manifest.toml"

publish_repository "$(release_tag "$channel")" "$repo_dir" "$staged"
printf 'published %s\n' "$channel"
