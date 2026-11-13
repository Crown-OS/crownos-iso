# shellcheck shell=bash disable=SC2154
# Signs, indexes and publishes the [crownos] repository as GitHub releases.
# Source it after lib.sh. GPGKEY names the signing key; RELEASE_REPO the GitHub
# repository that holds the releases (default: this workflow's, else crownos-iso).

readonly release_repo=${RELEASE_REPO:-${GITHUB_REPOSITORY:-Crown-OS/crownos-iso}}

# repo-testing, repo-stable and repo-<ISO tag>: never matched by the v* release triggers.
release_tag() { printf 'repo-%s\n' "$1"; }

# Release assets are plain files, so the names repo-add links must be real files.
dereference_db_links() {
    local link
    for link in "$1"/crownos.{db,files}{,.sig}; do
        [[ -L $link ]] && cp --remove-destination -- "$(readlink -f -- "$link")" "$link"
    done
    rm -f -- "$1"/crownos.{db,files}.tar.zst.old{,.sig}
}

sign_file() {
    gpg --batch --yes --local-user "${GPGKEY:?set GPGKEY to the signing key}" --detach-sign -- "$1"
}

sign_packages() {
    local package
    for package in "$1"/*.pkg.tar.zst; do
        gpg --batch --quiet --verify -- "$package.sig" "$package" 2>/dev/null || sign_file "$package"
    done
}

rebuild_database() {
    rm -f -- "$1"/crownos.{db,files}*
    repo-add --quiet --sign --key "${GPGKEY:?set GPGKEY to the signing key}" "$1/crownos.db.tar.zst" "$1"/*.pkg.tar.zst
    dereference_db_links "$1"
}

releases_api() { gh api "repos/$release_repo/releases$1" "${@:2}"; }

# Fails only on a 404, so an unreachable API never reads as "nothing published yet".
release_exists() {
    local error
    error=$(releases_api "/tags/$1" --silent 2>&1) && return 0
    [[ $error == *'HTTP 404'* ]] || die "cannot read release $1: $error"
    return 1
}

# Prints "name id digest" for every asset of the release TAG.
asset_index() {
    local release
    release=$(releases_api "/tags/$1" --jq .id) || die "cannot read release $1"
    releases_api "/$release/assets" --paginate --jq '.[] | "\(.name) \(.id) \(.digest)"' || die "cannot list release $1"
}

asset_field() { awk -v name="$2" -v field="$3" '$1 == name { print $field }' <<<"$1"; }

ensure_release() {
    release_exists "$1" && return
    gh release create "$1" --repo "$release_repo" --latest=false --title "$1" \
        --notes "The signed [crownos] pacman repository and its manifest. Do not edit by hand: scripts/publish.sh and scripts/promote.sh write it." >/dev/null
}

# Uploads the new name beside the old asset and renames it over, so a client
# never finds the name missing for longer than one API call.
replace_asset() {
    local tag=$1 old_id=$2 file=$3 staging=$4 name=${3##*/} new_id
    ln -sf -- "$(realpath -- "$file")" "$staging/$name.next"
    gh release upload "$tag" --repo "$release_repo" --clobber -- "$staging/$name.next"
    new_id=$(asset_field "$(asset_index "$tag")" "$name.next" 2)
    [[ -n $new_id ]] || die "uploaded $name.next to $tag but cannot find it"
    releases_api "/assets/$old_id" --method DELETE --silent
    releases_api "/assets/$new_id" --method PATCH -f name="$name" --silent
}

# Makes the release TAG hold exactly FILES. New names go up first, then changed
# ones in the order given, then what FILES no longer name is deleted: callers
# pass packages before the database, so no client sees a database naming a
# package that is not there yet.
sync_release() {
    local tag=$1 index file name staging
    shift
    index=$(asset_index "$tag")
    local new_files=() changed_files=()
    declare -A wanted=()
    for file; do
        name=${file##*/}
        wanted[$name]=1
        case $(asset_field "$index" "$name" 3) in
            "sha256:$(sha256sum -- "$file" | cut -d' ' -f1)") ;;
            '') new_files+=("$file") ;;
            *) changed_files+=("$file") ;;
        esac
    done
    ((${#new_files[@]} == 0)) || gh release upload "$tag" --repo "$release_repo" -- "${new_files[@]}"
    staging=$(mktemp -d)
    for file in "${changed_files[@]}"; do
        replace_asset "$tag" "$(asset_field "$index" "${file##*/}" 2)" "$file" "$staging"
    done
    rm -rf -- "$staging"
    asset_index "$tag" | while read -r name id _; do
        [[ -n ${wanted[$name]:-} ]] || releases_api "/assets/$id" --method DELETE --silent
    done
}

# Publishes REPO_DIR and the signed manifest in STAGED as the release TAG.
publish_repository() {
    local tag=$1 repo_dir=$2 staged=$3
    gpg --armor --export "${GPGKEY:?}" >"$staged/crownos.asc"
    ensure_release "$tag"
    sync_release "$tag" "$repo_dir"/*.pkg.tar.zst "$repo_dir"/*.pkg.tar.zst.sig "$repo_dir"/crownos.{db,files}* \
        "$staged"/manifest.toml{,.sig} "$staged/crownos.asc"
}

manifest_published() {
    release_exists "$1" || return 1
    local index
    index=$(asset_index "$1") || die "cannot list release $1"
    [[ -n $(asset_field "$index" manifest.toml 1) ]]
}

# Prints FIELD of the signed manifest.toml the release TAG holds.
verified_manifest_field() {
    local tag=$1 field=$2 scratch status=0
    scratch=$(mktemp -d)
    gh release download "$tag" --repo "$release_repo" --dir "$scratch" --pattern 'manifest.toml*' &&
        gpg --batch --quiet --verify -- "$scratch/manifest.toml.sig" "$scratch/manifest.toml" &&
        toml json "$scratch/manifest.toml" | jq -r --arg field "$field" '.[$field]' || status=$?
    rm -rf -- "$scratch"
    ((status == 0)) || die "release $tag's manifest.toml cannot be fetched or does not verify"
}

require_publishing_env() {
    require_tools gpg gh repo-add jq python3 bsdtar sha256sum
    : "${GPGKEY:?set GPGKEY to the signing key}"
    gpg --list-secret-keys -- "$GPGKEY" >/dev/null 2>&1 || die "no secret key for $GPGKEY in this keyring"
}
