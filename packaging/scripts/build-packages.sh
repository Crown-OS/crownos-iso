#!/usr/bin/env bash
#
# Build every CrownOS component and package it for one base distribution.
#
# Runs inside the container from packaging/containers/, with the CrownOS
# checkout (crownos-iso and its sibling repos) at /src and the output tree at
# /out; build.sh starts it. CROWNOS_SRC and CROWNOS_BUILD move those, and
# CROWNOS_COMPONENTS limits the build to the named packages, for iterating on
# one package natively on a machine running that distribution.
#
# Library dependencies are not listed anywhere by hand: each binary's shared
# libraries are resolved to the packages that own them in this container, which
# is the release they are being built for. Service dependencies the linker
# cannot see (pipewire, bluez, portals…) come from packaging/depends/.

set -euo pipefail

distro="$1"
version="${CROWNOS_VERSION:?}"
src="${CROWNOS_SRC:-/src}"
build="${CROWNOS_BUILD:-/out}"
only=" ${CROWNOS_COMPONENTS:-} "
packaging="$src/crownos-iso/packaging"
out="$build/packages/$distro"
work="$build/work/$distro"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$build/target/$distro}"

case "$distro" in
    arch) format=archlinux ;;
    debian | ubuntu) format=deb ;;
    fedora) format=rpm ;;
    *) echo "unknown distro: $distro" >&2; exit 2 ;;
esac

log() { printf '\033[1;35m==>\033[0m [%s] %s\n' "$distro" "$*"; }

owners() {
    case "$format" in
        archlinux) xargs -r pacman -Qqo 2>/dev/null ;;
        deb) xargs -r dpkg -S 2>/dev/null | cut -d: -f1 ;;
        rpm) xargs -r rpm -qf --qf '%{NAME}\n' | grep -v '^file ' ;;
    esac || true
}

library_packages() {
    ldd "$@" | awk '$2 == "=>" && $3 ~ /^\// { print $3 }' | sort -u |
        while read -r library; do
            printf '%s\n%s\n' "$library" "$(realpath "$library")"
        done | sort -u | owners | sort -u
}

yaml_list() {
    local item
    for item in "$@"; do printf '  - %s\n' "$item"; done
}

# Write the nfpm config for one package. $contents is the YAML contents list.
write_config() {
    local name="$1" summary="$2"
    shift 2
    cat <<EOF
name: $name
version: "$version"
version_schema: none
release: 1
arch: amd64
platform: linux
maintainer: CrownOS <packages@crownos.org>
homepage: https://crownos.org
license: MIT
description: "$summary"
depends:
$(yaml_list "$@")
contents:
$contents
EOF
}

content() {
    local source="$1" destination="$2" mode="$3"
    printf '  - src: %s\n    dst: %s\n    file_info: { mode: 0%s }\n' "$source" "$destination" "$mode"
}

package() {
    local name="$1" config="$work/$1.yaml"
    shift
    write_config "$name" "$@" >"$config"
    nfpm package --packager "$format" --config "$config" --target "$out/"
}

[[ "$only" != "  " ]] || rm -rf "$out" "$work"
mkdir -p "$out" "$work"

components=()
while IFS='|' read -r name repo cargo_package entries summary; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    components+=("$name")
    [[ "$only" == "  " || "$only" == *" $name "* ]] || continue

    log "building $name"
    cargo build --release --locked --manifest-path "$src/$repo/Cargo.toml" \
        ${cargo_package:+--package "$cargo_package"} </dev/null

    contents=""
    binaries=()
    for entry in $entries; do
        IFS=: read -r kind source destination <<<"$entry"
        staged="$work/$name$destination"
        case "$kind" in
            bin)
                install -Dm755 "$CARGO_TARGET_DIR/release/$source" "$staged"
                strip --strip-unneeded "$staged"
                binaries+=("$staged")
                contents+="$(content "$staged" "$destination" 755)"$'\n'
                ;;
            file)
                mkdir -p "$(dirname "$staged")"
                sed 's|@libexecdir@|/usr/lib|g' "$src/$repo/$source" >"$staged"
                contents+="$(content "$staged" "$destination" 644)"$'\n'
                ;;
            link)
                contents+="$(printf '  - src: %s\n    dst: %s\n    type: symlink' "$source" "$destination")"$'\n'
                ;;
        esac
    done

    mapfile -t depends < <(library_packages "${binaries[@]}")
    package "$name" "$summary" "${depends[@]}"
done <"$packaging/components.list"

log "packaging crownos-desktop"
desktop="$packaging/crownos-desktop"
contents="$(content "$desktop/crownos-session" /usr/bin/crownos-session 755)
$(content "$desktop/crownos-session.sh" /etc/profile.d/crownos-session.sh 644)
$(content "$desktop/crownos.desktop" /usr/share/wayland-sessions/crownos.desktop 644)
$(content "$desktop/compositor.ron" /usr/share/crownos/compositor.ron 644)"
mapfile -t services < "$packaging/depends/$distro.list"
package crownos-desktop "The CrownOS desktop: compositor, shell and system apps" \
    "${components[@]}" "${services[@]}"

[[ -z "${HOST_UID:-}" ]] || chown -R "$HOST_UID:${HOST_GID:-$HOST_UID}" "$build/packages" "$build/work" "$CARGO_TARGET_DIR"
log "packages in $out"
