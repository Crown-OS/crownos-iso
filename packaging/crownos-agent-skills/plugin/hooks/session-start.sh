#!/bin/sh
# Hands Claude the CrownOS facts a session needs: where the settings reference and the skills
# are, and which MCP servers exist. Plain stdout becomes context.
set -eu

[ -r /usr/lib/crownos/os-release ] || [ -d /usr/share/crownos ] || exit 0

release=$(sed -n 's/^PRETTY_NAME=//p' /usr/lib/crownos/os-release 2>/dev/null | tr -d '"')
has() { command -v "$1" >/dev/null 2>&1; }
desktop='Desktop apps have no MCP server on this release'
if has crownos-computer-use; then
    desktop='Desktop apps go through the crownos-computer-use MCP server (skills:
crownos-computer-use, crownos-browser)'
fi
web=''
if has crownos-setup; then
    web='; web pages through the playwright MCP server (skill: crownos-playwright)'
elif has crownos-computer-use; then
    web='; web pages through the browser tools of the same server (skill: crownos-browser)'
fi
context=''
if has crown-context; then
    context="
What the user did recently comes from the crown-context command (skill: crownos-context)."
fi
secrets=''
if has crownos-secrets-mcp; then
    secrets="
Passwords and API keys are used by name through the crownos-secrets MCP server (skill:
crownos-secrets); never ask the user to paste one into the chat."
fi
cat <<CONTEXT
This machine runs ${release:-CrownOS}. Desktop settings are RON files under ~/.config/crownos/,
documented per key in /usr/share/doc/crownos/config/index.md (skill: crownos-config).
${desktop}${web}; themes and plugins through crownplugin (skill: crownos-plugins).${context}${secrets}
CONTEXT
