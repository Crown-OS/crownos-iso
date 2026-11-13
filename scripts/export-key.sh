#!/usr/bin/env bash
# Writes the public half of the CrownOS signing key into packaging/crownos-keyring/.
#
#   export-key.sh KEY_ID

set -euo pipefail

key=${1:?usage: export-key.sh KEY_ID}
keyring=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../packaging/crownos-keyring" && pwd)

gpg --export "$key" >"$keyring/crownos.gpg"
gpg --with-colons --fingerprint "$key" | awk -F: '$1 == "fpr" { print $10 ":4:"; exit }' >"$keyring/crownos-trusted"
: >"$keyring/crownos-revoked"
