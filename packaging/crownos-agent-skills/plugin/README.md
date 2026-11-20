# crownos

The CrownOS desktop for Claude Code. The plugin has skills, hooks and two MCP server entries.

The skills explain these tasks:

- Change system settings through the RON files under `~/.config/crownos`.
- Operate desktop apps through the `crownos-computer-use` MCP server.
- Drive web pages through the `playwright` MCP server.
- Use the memory of the visual context engine.
- Write themes and plugins.

The hooks turn permission prompts, idle waits and finished turns into crownotify cards.

The `crownos-agent-skills` package installs the plugin system-wide. Managed settings force-enable
it, so you do not need to set it up.

The MCP server entries are:

- `crownos-computer-use` runs `crownos-computer-use mcp`. It starts once the crownos-computer-use
  component is installed.
- `playwright` runs `crownos-setup playwright-mcp`. It starts once the `crownos-setup` package is
  installed.
