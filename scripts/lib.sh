# shellcheck shell=bash disable=SC2154
# Shared by the scripts in this directory. Source it after setting `root`.

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

newest_iso() {
    local iso newest=''
    for iso in "$root"/out/*.iso; do
        [[ $iso -nt $newest ]] && newest=$iso
    done
    printf '%s' "$newest"
}

require_tools() {
    local tool missing=()
    for tool; do
        command -v -- "$tool" >/dev/null || missing+=("$tool")
    done
    ((${#missing[@]} == 0)) || die "missing tools: ${missing[*]} (see docs/publishing.md)"
}

toml() { python3 -I "$root/scripts/toml.py" "$@"; }

manifest_json() {
    [[ -n ${manifest_cache:-} ]] || manifest_cache=$(toml json "$root/components.toml")
    printf '%s\n' "$manifest_cache"
}

# vX.Y.Z on a tag, else X.Y.Z.rN.gSHA: above the last tag, below the next.
iso_version() {
    if [[ ${GITHUB_REF_TYPE:-} == tag ]]; then
        printf '%s\n' "${GITHUB_REF_NAME#v}"
        return
    fi
    local exact described
    if exact=$(git -C "$root" describe --tags --exact-match --match 'v[0-9]*' 2>/dev/null); then
        printf '%s\n' "${exact#v}"
        return
    fi
    described=$(git -C "$root" describe --tags --long --match 'v[0-9]*') ||
        die "no v* tag reachable from HEAD; fetch tags (fetch-depth: 0)"
    local commit=${described##*-g} rest=${described%-g*}
    local distance=${rest##*-} tag=${rest%-*}
    printf '%s.r%s.g%s\n' "${tag#v}" "$distance" "$commit"
}

build_id() { git -C "$root" rev-parse HEAD; }

default_channel() {
    if git -C "$root" describe --tags --exact-match --match 'v[0-9]*' >/dev/null 2>&1; then
        echo stable
    else
        echo testing
    fi
}

package_name() {
    local asset=${1##*/}
    printf '%s\n' "${asset%-*-*-*}"
}

package_field() {
    local info key value
    info=$(bsdtar -qxOf "$1" .PKGINFO)
    while IFS=' = ' read -r key value; do
        if [[ $key == "$2" ]]; then printf '%s\n' "$value"; fi
    done <<<"$info"
}

package_version() { package_field "$1" pkgver; }

# Checkout directories the component workspaces expect under another name.
declare -grA sibling_repo_of_dir=([llts-protocol]=lls-protocol)

sibling_dir() {
    local dir
    for dir in "${!sibling_repo_of_dir[@]}"; do
        [[ ${sibling_repo_of_dir[$dir]} == "$1" ]] && { printf '%s\n' "$dir"; return; }
    done
    printf '%s\n' "$1"
}

sibling_repo() { printf '%s\n' "${sibling_repo_of_dir[$1]:-$1}"; }
