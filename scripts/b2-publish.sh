#!/usr/bin/env bash
# Uploads the release files to the Backblaze B2 bucket that serves
# https://download.crownos.org, then deletes every other file version in the
# bucket, so it holds only the newest release.
#
#   B2_KEY_ID=... B2_APPLICATION_KEY=... b2-publish.sh FILE...
#
# The application key must be restricted to one bucket. The free plan stores
# 10 GB, and the old release stays until the new one is uploaded, so the
# script stops before the upload if both releases together do not fit.

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib.sh
source "$root/scripts/lib.sh"

: "${B2_KEY_ID:?B2_KEY_ID is not set}" "${B2_APPLICATION_KEY:?B2_APPLICATION_KEY is not set}"
(($#)) || die 'no files to upload'
require_tools curl jq sha1sum stat
free_storage_bytes=10000000000
max_attempts=3

b2_api() {
    local call=$1 body=$2
    curl --fail-with-body --silent --show-error --retry 3 \
        -H "Authorization: $auth_token" -H 'Content-Type: application/json' \
        --data "$body" "$api_url/b2api/v3/$call"
}

account=$(curl --fail-with-body --silent --show-error --retry 3 \
    -u "$B2_KEY_ID:$B2_APPLICATION_KEY" https://api.backblazeb2.com/b2api/v3/b2_authorize_account)
auth_token=$(jq -r .authorizationToken <<<"$account")
api_url=$(jq -r .apiInfo.storageApi.apiUrl <<<"$account")
bucket_id=$(jq -er '.apiInfo.storageApi.bucketId // error("the key must be restricted to one bucket")' <<<"$account")

all_file_versions() {
    local request page
    request=$(jq -cn --arg bucket "$bucket_id" '{bucketId: $bucket, maxFileCount: 1000}')
    while [[ -n $request ]]; do
        page=$(b2_api b2_list_file_versions "$request")
        jq -c '.files[] | {fileName, fileId, contentLength}' <<<"$page"
        request=$(jq -c --argjson request "$request" \
            'if .nextFileName then $request + {startFileName: .nextFileName, startFileId: .nextFileId} else empty end' <<<"$page")
    done
}

listed_versions=$(all_file_versions)
mapfile -t old_versions <<<"$listed_versions"
stored_bytes=$(jq -s 'map(.contentLength) | add // 0' <<<"$listed_versions")
upload_bytes=$(stat -c %s -- "$@" | jq -s add)
((stored_bytes + upload_bytes <= free_storage_bytes)) ||
    die "the bucket holds $stored_bytes bytes; $upload_bytes more do not fit in the free $free_storage_bytes"

upload() {
    local file=$1 name sha1 target attempt
    name=$(basename -- "$file")
    sha1=$(sha1sum -- "$file" | cut -d' ' -f1)
    for ((attempt = 1; attempt <= max_attempts; attempt++)); do
        target=$(b2_api b2_get_upload_url "$(jq -cn --arg bucket "$bucket_id" '{bucketId: $bucket}')")
        if curl --fail-with-body --silent --show-error -X POST -T "$file" \
            -H "Authorization: $(jq -r .authorizationToken <<<"$target")" \
            -H "X-Bz-File-Name: $(jq -rn --arg name "$name" '$name | @uri')" \
            -H 'Content-Type: b2/x-auto' -H "X-Bz-Content-Sha1: $sha1" \
            "$(jq -r .uploadUrl <<<"$target")" | jq -r .fileId; then
            printf 'uploaded %s\n' "$name" >&2
            return
        fi
        printf 'upload of %s failed (attempt %s of %s)\n' "$name" "$attempt" "$max_attempts" >&2
        sleep $((attempt * 15))
    done
    die "could not upload $name"
}

declare -A kept_file_ids
for file; do
    file_id=$(upload "$file")
    kept_file_ids[$file_id]=1
done

for version in "${old_versions[@]}"; do
    [[ -n $version ]] || continue
    file_id=$(jq -r .fileId <<<"$version")
    [[ -n ${kept_file_ids[$file_id]:-} ]] && continue
    b2_api b2_delete_file_version "$(jq -c '{fileName, fileId}' <<<"$version")" >/dev/null
    printf 'deleted %s\n' "$(jq -r .fileName <<<"$version")" >&2
done
