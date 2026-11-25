#!/usr/bin/env bash
# Reads the third-party package lists in packages/. Each name is in one list,
# and the list says where the package goes (see the header of each file).
#
#   packages.sh names live|mirror|install-base
#                                   the names the live image or the offline mirror needs,
#                                   besides the packages of components.toml; install-base
#                                   is what crownos-installer pacstraps besides them
#   packages.sh check               refuses a name in two lists, or a CrownOS package
#                                   that components.toml already names

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib.sh
source "$root/scripts/lib.sh"

lists=$root/packages

names_in() {
    local list
    for list; do
        grep -Ev '^[[:space:]]*(#|$)' "$lists/$list.list"
    done
}

check() {
    local repeated listed_components
    repeated=$(names_in desktop system live mirror drivers | sort | uniq -d)
    [[ -z $repeated ]] || die "packages/ names these in more than one list:"$'\n'"$repeated"
    listed_components=$(comm -12 <(names_in desktop system live mirror drivers | sort) \
        <("$root/scripts/manifest.sh" names all | sort))
    [[ -z $listed_components ]] || die "packages/ names these components.toml packages:"$'\n'"$listed_components"
}

case ${1:-} in
    names)
        case ${2:-} in
            live) names_in system live ;;
            mirror) names_in system mirror drivers ;;
            install-base) names_in system mirror ;;
            *) die "usage: packages.sh names live|mirror|install-base" ;;
        esac
        ;;
    check) check ;;
    *) die "usage: packages.sh names live|mirror|install-base | check" ;;
esac
