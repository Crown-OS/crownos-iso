#!/bin/sh
# Hands Claude the CrownOS facts a session needs: where the settings reference and the skills
# are, and that the computer-use server exists. Plain stdout becomes context.
set -eu

[ -r /usr/lib/crownos/os-release ] || [ -d /usr/share/crownos ] || exit 0

release=$(sed -n 's/^PRETTY_NAME=//p' /usr/lib/crownos/os-release 2>/dev/null | tr -d '"')
cat <<CONTEXT
This machine runs ${release:-CrownOS}. Desktop settings are RON files under ~/.config/crownos/,
documented per key in /usr/share/doc/crownos/config/index.md (skill: crownos-config). GUI work goes
through the crownos-computer-use MCP server (skills: crownos-computer-use, crownos-browser,
crownos-context); themes and plugins through crownplugin (skill: crownos-plugins).
CONTEXT
