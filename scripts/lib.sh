# shellcheck shell=bash
# Shared by the scripts in this directory. Source it after setting `root`.

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

newest_iso() {
    local iso newest=''
    for iso in "$root"/out/*.iso; do
        [[ $iso -nt $newest ]] && newest=$iso
    done
    printf '%s' "$newest"
}
