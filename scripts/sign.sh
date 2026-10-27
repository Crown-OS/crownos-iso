#!/usr/bin/env bash
# Signs an ISO with GnuPG and writes its checksum next to it.
#
#   sign.sh [ISO]   [default: the newest ISO in out/]
#
# CROWNOS_SIGNING_KEY picks the key; otherwise GnuPG's default key signs.
# CROWNOS_SIGNING_PASSPHRASE unlocks it without a prompt, for CI.
# Produces ISO.sig (detached, binary) and ISO.sha256.

set -euo pipefail
shopt -s nullglob

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib.sh
source "$root/scripts/lib.sh"

iso=${1:-$(newest_iso)}
[[ -f $iso ]] || die "no ISO to sign; run \`just build\` first"

gpg_args=(--batch --yes)
[[ -n ${CROWNOS_SIGNING_KEY:-} ]] && gpg_args+=(--local-user "$CROWNOS_SIGNING_KEY")
[[ -n ${CROWNOS_SIGNING_PASSPHRASE:-} ]] && gpg_args+=(--pinentry-mode loopback --passphrase-fd 0)

gpg "${gpg_args[@]}" --detach-sign --output "$iso.sig" "$iso" <<<"${CROWNOS_SIGNING_PASSPHRASE:-}"
(cd -- "$(dirname -- "$iso")" && sha256sum -- "${iso##*/}" >"${iso##*/}.sha256")
gpg --verify "$iso.sig" "$iso"
