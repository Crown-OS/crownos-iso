#!/usr/bin/env bash
# Installs the plugins, treesitter parsers and blink.cmp library of a Neovim
# config into a data directory, so Neovim starts offline with nothing to fetch.
#
#   nvim-prefetch.sh CONFIG_DIR DATA_DIR
#
# CONFIG_DIR holds nvim/init.lua. DATA_DIR keeps its contents between runs, so
# a rebuild only fetches what changed. State and cache go to a throwaway
# directory because lazy.nvim records absolute host paths there, and the links
# nvim-treesitter makes into DATA_DIR are made relative so it can be copied.

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib.sh
source "$root/scripts/lib.sh"

config_dir=$(realpath -- "${1:?nvim-prefetch.sh needs a config directory}")
data_dir=${2:?nvim-prefetch.sh needs a data directory}
for tool in nvim git cc; do
    command -v "$tool" >/dev/null || die "$tool is needed to prefetch the Neovim plugins"
done

mkdir -p -- "$data_dir"
data_dir=$(realpath -- "$data_dir")
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
cp -r -- "$config_dir/nvim" "$scratch/nvim"

XDG_CONFIG_HOME=$scratch XDG_DATA_HOME=$data_dir \
    XDG_STATE_HOME=$scratch/state XDG_CACHE_HOME=$scratch/cache \
    nvim --headless "+luafile $root/scripts/nvim-prefetch.lua"
rm -rf -- "$data_dir/nvim/session" "$data_dir/nvim/dirsession"
find "$data_dir" -type l -lname "$data_dir/*" -exec sh -c 'ln -sfnr -- "$(readlink -- "$1")" "$1"' _ {} \;
