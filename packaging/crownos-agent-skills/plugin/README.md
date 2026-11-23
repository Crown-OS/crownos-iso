# crownos

The CrownOS desktop for Claude Code. The plugin has skills, hooks and MCP server entries.

The skills explain these tasks:

- Change system settings through the RON files under `~/.config/crownos`.
- Operate desktop apps through the `crownos-computer-use` MCP server.
- Drive web pages through the `playwright` MCP server.
- Use the memory of the visual context engine.
- Use passwords and API keys by name, without seeing a value.
- Write themes and plugins.

The hooks turn permission prompts, idle waits and finished turns into crownotify cards.

The `crownos-agent-skills` package installs the plugin system-wide. Managed settings force-enable
it, so you do not need to set it up.

The MCP server entries are these. Each one is in the plugin only when the ISO ships its package:

- `crownos-computer-use` runs `crownos-computer-use mcp`, from the crownos-computer-use component.
- `playwright` runs `crownos-setup playwright-mcp`, from the `crownos-setup` package.
- `crownos-secrets` runs `crownos-secrets-mcp`, from the crownos-secrets-manager component.
