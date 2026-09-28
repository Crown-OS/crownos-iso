#!/usr/bin/env bash
#
# Clone every repository in packaging/sources.list next to crownos-iso, at its
# default branch, and record the revision of each in build/sources.txt. For CI:
# a developer checkout already has them, and existing directories are left alone.
#
# CROWNOS_SOURCES_TOKEN authenticates the clones when repositories are private.

set -euo pipefail

iso="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
root="$(dirname "$iso")"
auth="${CROWNOS_SOURCES_TOKEN:+x-access-token:$CROWNOS_SOURCES_TOKEN@}"

mkdir -p "$iso/build"
while read -r directory repository; do
    [[ -z "$directory" || "$directory" == \#* ]] && continue
    [[ -d "$root/$directory" ]] ||
        git clone --quiet --depth 1 "https://${auth}github.com/$repository.git" "$root/$directory"
    printf '%s %s %s\n' "$directory" "$repository" "$(git -C "$root/$directory" rev-parse --verify --quiet HEAD 2>/dev/null || echo unversioned)"
done <"$iso/packaging/sources.list" >"$iso/build/sources.txt"
cat "$iso/build/sources.txt"
