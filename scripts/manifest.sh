#!/usr/bin/env bash
# Reads components.toml, the manifest of every CrownOS package.
#
#   manifest.sh names system|live|installed|online|optional|all
#   manifest.sh resolve REPO_DIR [--icon-theme CHECKOUT] [--siblings DIR]
#   manifest.sh published CHANNEL REPO_DIR [PACKAGE...]
#
# names      the package names an install path takes: system is on the live
#            image and in its offline mirror, live adds what only the live image
#            runs, installed is what every installed system has (system plus the
#            online packages), online is what installed systems download and the
#            ISO does not carry, optional is opt-in, all is everything; it
#            validates the manifest
# resolve    fills REPO_DIR with every package: release assets are downloaded
#            and checked against their sha256, source entries are built with
#            makepkg at the ISO version; then indexes it unsigned. DIR holds the
#            sibling checkouts crownos-agent-skills reads (crownos-plugins,
#            crownos-config); it defaults to the workspace above this repository
# published  prints the manifest a channel publishes for the packages in REPO_DIR;
#            each PACKAGE is a system package in REPO_DIR that components.toml
#            does not list, such as the crownos-setup of build.sh --installer

set -euo pipefail
shopt -s nullglob

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib.sh
source "$root/scripts/lib.sh"
# shellcheck source=scripts/repo.sh
source "$root/scripts/repo.sh"
require_tools jq python3

validate() {
    local problems
    problems=$(manifest_json | jq -r '
        .package as $packages
        | ($packages | group_by(.name)[] | select(length > 1) | "\(.[0].name) is listed twice"),
          ($packages[] |
            if (has("repo") | not) == (has("source") | not) then "\(.name): needs exactly one of repo and source"
            elif has("repo") and ([.tag, .asset, .sha256] | map(type) != ["string", "string", "string"])
              then "\(.name): a release entry needs tag, asset and sha256"
            elif has("repo") and (.sha256 | test("^[0-9a-f]{64}$") | not) then "\(.name): sha256 is not 64 hex digits"
            elif has("repo") and (.tag == "TODO" or (.sha256 | test("^0+$")))
              then "\(.name): a placeholder entry (tag TODO or a zero sha256); pin a release with scripts/pin.sh"
            elif has("repo") and (.asset | sub("-[^-]+-[^-]+-[^-]+$"; "")) != .name
              then "\(.name): asset \(.asset) holds another package"
            elif (.install // "system" | IN("system", "live", "installed", "optional") | not)
              then "\(.name): install must be system, live, installed or optional"
            else empty end)')
    [[ -z $problems ]] || die "components.toml is invalid:"$'\n'"$problems"
}

names() {
    validate
    local filter
    case ${1:?names needs system, live, installed, online, optional or all} in
        system) filter='.install // "system" | . == "system"' ;;
        live) filter='.install // "system" | IN("system", "live")' ;;
        installed) filter='.install // "system" | IN("system", "installed")' ;;
        online) filter='.install == "installed"' ;;
        optional) filter='.install == "optional"' ;;
        all) filter='true' ;;
        *) die "unknown install set: $1" ;;
    esac
    manifest_json | jq -r ".package[] | select($filter) | .name"
}

fetch_release() {
    local repo_dir=$1 entry=$2 repo tag asset sha
    read -r repo tag asset sha < <(jq -r '[.repo, .tag, .asset, .sha256] | join(" ")' <<<"$entry")
    gh release download "$tag" --repo "$repo" --pattern "$asset" --dir "$repo_dir"
    sha256sum --quiet -c - <<<"$sha  $repo_dir/$asset" || die "$asset from $repo $tag does not match its sha256"
    [[ $(package_field "$repo_dir/$asset" pkgname) == "$(package_name "$asset")" ]] ||
        die "$asset does not contain the package it is named after"
}

build_source() {
    local repo_dir=$1 source=$2 icon_theme=$3 siblings=$4 version id
    version=$(iso_version) id=$(build_id)
    (cd -- "$root/$source" && BUILDDIR=$root/target/build PKGDEST=$repo_dir SRCDEST=$root/target/src \
        CROWNOS_VERSION=$version CROWNOS_BUILD_ID=$id CROWNOS_ICON_THEME=$icon_theme \
        CROWNOS_SIBLINGS=$siblings \
        makepkg --force --nodeps --cleanbuild --noconfirm)
}

resolve() {
    local repo_dir=${1:?resolve needs REPO_DIR} icon_theme=$root/../crownos-icon-theme siblings=$root/..
    shift
    while (($#)); do
        case $1 in
            --icon-theme) icon_theme=${2:?--icon-theme needs a checkout}; shift 2 ;;
            --siblings) siblings=${2:?--siblings needs a directory}; shift 2 ;;
            *) die "unknown argument: $1" ;;
        esac
    done
    require_tools gh makepkg repo-add bsdtar sha256sum git
    validate
    [[ -e $root/packaging/crownos-keyring/crownos.gpg ]] ||
        die "packaging/crownos-keyring/crownos.gpg is missing: run scripts/export-key.sh packages@crownos.org (docs/publishing.md, one-time setup)"
    [[ -x $icon_theme/install.sh ]] || die "no crownos-icon-theme checkout at $icon_theme"
    icon_theme=$(realpath -- "$icon_theme")
    [[ -f $siblings/crownos-plugins/skill/SKILL.md && -f $siblings/crownos-config/docs/config/index.md ]] ||
        die "no crownos-plugins and crownos-config checkouts under $siblings (packaging/crownos-agent-skills/README.md)"
    siblings=$(realpath -- "$siblings")
    mkdir -p -- "$repo_dir"
    repo_dir=$(realpath -- "$repo_dir")
    find "$repo_dir" -mindepth 1 -delete

    local entry source
    while read -r entry; do
        source=$(jq -r '.source // empty' <<<"$entry")
        if [[ -n $source ]]; then
            build_source "$repo_dir" "$source" "$icon_theme" "$siblings"
        else
            fetch_release "$repo_dir" "$entry"
        fi
    done < <(manifest_json | jq -c '.package[]')

    repo-add --quiet "$repo_dir/crownos.db.tar.zst" "$repo_dir"/*.pkg.tar.zst
    dereference_db_links "$repo_dir"
}

# The file of a package in REPO_DIR, whatever version it was built at.
package_file() {
    local file
    for file in "$1/$2"-*.pkg.tar.zst; do
        [[ $(package_name "$file") == "$2" ]] && { printf '%s\n' "$file"; return; }
    done
    die "$2 is missing from $1"
}

release_field() {
    local release key value
    release=$(package_file "$1" crownos-release)
    while IFS='=' read -r key value; do
        [[ $key == "$2" ]] && { printf '%s\n' "${value//\"/}"; return; }
    done < <(bsdtar -qxOf "$release" usr/lib/crownos/os-release)
    die "$release has no $2"
}

published() {
    local channel=${1:?published needs CHANNEL} repo_dir=${2:?published needs REPO_DIR}
    [[ $channel == @(testing|stable) ]] || die "the channel is testing or stable, not $channel"
    validate
    local name versions=() version build_id restart retired releases all_names system_names online_names
    mapfile -t all_names < <(names all)
    mapfile -t system_names < <(names installed)
    mapfile -t online_names < <(names online)
    for name in "${@:3}"; do
        [[ " ${all_names[*]} " == *" $name "* ]] || all_names+=("$name")
        [[ " ${system_names[*]} " == *" $name "* ]] || system_names+=("$name")
    done
    for name in "${all_names[@]}"; do
        versions+=("$name" "$(package_version "$(package_file "$repo_dir" "$name")")")
    done
    version=$(release_field "$repo_dir" VERSION_ID)
    build_id=$(release_field "$repo_dir" BUILD_ID)
    restart=$(release_restart "$version" "$channel")
    retired=$(release_retired "$version")
    releases=$(release_chain "$version" | jq -R . | jq -s .)
    jq -n --arg version "$version" --arg build_id "$build_id" --arg channel "$channel" --arg restart "$restart" \
        --argjson releases "$releases" --argjson retired "$retired" \
        --argjson system "$(printf '%s\n' "${system_names[@]}" | jq -R . | jq -s .)" \
        --argjson online "$(printf '%s\n' "${online_names[@]}" | jq -R 'select(length > 0)' | jq -s .)" '
        {version: $version, build_id: $build_id, channel: $channel, restart: $restart, notes: "notes.md",
         releases: $releases, packages: $system, online: $online, retired: $retired,
         package: [$ARGS.positional as $pairs | range(0; $pairs | length; 2) | {name: $pairs[.], version: $pairs[. + 1]}]}' --args "${versions[@]}" |
        toml write --bare
}

command=${1:?usage: manifest.sh names|resolve|published ...}
shift
case $command in
    names | resolve | published) "$command" "$@" ;;
    *) die "unknown command: $command" ;;
esac
