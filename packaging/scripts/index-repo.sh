#!/usr/bin/env bash
#
# Lay one distribution's packages out as a repository under /out/repo and
# generate its index, unsigned. Runs inside that distribution's build container
# for its native tools; build.sh signs the result on the host, so the signing
# key never enters a container.

set -euo pipefail

distro="$1"
build="${CROWNOS_BUILD:-/out}"
packages="$build/packages/$distro"
repo="$build/repo"

# shellcheck source=/dev/null
release_field() { (. /etc/os-release && printf '%s' "${!1}"); }

case "$distro" in
    arch)
        dir="$repo/arch/x86_64"
        mkdir -p "$dir"
        rm -f "$dir"/*.pkg.tar.zst* "$dir"/crownos.*
        cp "$packages"/*.pkg.tar.zst* "$dir/"
        repo-add "$dir/crownos.db.tar.gz" "$dir"/*.pkg.tar.zst
        ;;
    debian | ubuntu)
        codename="$(release_field VERSION_CODENAME)"
        pool="pool/$codename"
        dists="dists/$codename"
        mkdir -p "$repo/deb/$pool" "$repo/deb/$dists/main/binary-amd64"
        cd "$repo/deb"
        rm -f "$pool"/*.deb "$dists"/{Release,InRelease,Release.gpg}
        cp "$packages"/*.deb "$pool/"
        apt-ftparchive packages "$pool" >"$dists/main/binary-amd64/Packages"
        gzip -9kf "$dists/main/binary-amd64/Packages"
        apt-ftparchive \
            -o APT::FTPArchive::Release::Origin=CrownOS \
            -o APT::FTPArchive::Release::Label=CrownOS \
            -o APT::FTPArchive::Release::Suite="$codename" \
            -o APT::FTPArchive::Release::Codename="$codename" \
            -o APT::FTPArchive::Release::Architectures=amd64 \
            -o APT::FTPArchive::Release::Components=main \
            release "$dists" >/tmp/Release
        mv /tmp/Release "$dists/Release"
        ;;
    fedora)
        dir="$repo/rpm/fedora-$(release_field VERSION_ID)/x86_64"
        mkdir -p "$dir"
        rm -rf "$dir"/*.rpm "$dir/repodata"
        cp "$packages"/*.rpm "$dir/"
        createrepo_c "$dir"
        ;;
    *) echo "unknown distro: $distro" >&2; exit 2 ;;
esac

[[ -z "${HOST_UID:-}" ]] || chown -R "$HOST_UID:${HOST_GID:-$HOST_UID}" "$repo"
