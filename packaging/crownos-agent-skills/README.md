# crownos-agent-skills

What a coding agent needs to know about the CrownOS desktop, installed where the agents look.

## Skills

| Skill | Teaches |
|---|---|
| `crownos-config` | Changing the system by editing `~/.config/crownos/<section>.ron`, with the generated reference |
| `crownos-hooks` | Notifying through crownotify from Claude Code hooks; event shapes |
| `crownos-computer-use` | The `crownos-computer-use` MCP server: windows, snapshots, refs, actions, the agent workspace |
| `crownos-browser` | Chromium through the automation profile; when the user's own browser is needed |
| `crownos-context` | The visual context engine's `context.*` and `memory.*` tools |
| `crownos-plugins` | Themes and plugins with `crownplugin` (from the crownos-plugins repository) |

## Paths

| Path | What |
|---|---|
| `/usr/share/crownos/skills/<name>/SKILL.md` | The skills |
| `/etc/claude-code/.claude/skills/<name>` | Claude Code's system-wide skill folder, links to the above |
| `/etc/codex/skills/<name>` | Codex's admin skill folder, links |
| `/usr/share/crownos/claude-marketplace/` | A `directory` marketplace named `crownos` with one plugin, `crownos` |
| `.../plugins/crownos/` | The plugin: `.claude-plugin/plugin.json`, `skills/` (links), `hooks/hooks.json` + scripts, `.mcp.json` |
| `/etc/claude-code/managed-settings.json` | `{}`; kept on upgrade (`backup`) so an admin may extend it |
| `/etc/claude-code/managed-settings.d/50-crownos.json` | Registers the marketplace and force-enables `crownos@crownos` |
| `/usr/share/doc/crownos/config/` | The settings reference, `cargo xtask config-docs` output from crownos-config |
| `/usr/bin/crownos-agent-skills` | Per-user setup: links skills into `~/.agents/skills` (Codex, Antigravity) and `~/.gemini/config/skills` (Antigravity) when those agents are present |

The fish login hook in `crownos-base` runs `crownos-agent-skills` before the desktop starts, so a
user who installs Codex or Antigravity later gets the links at the next login. `--remove` undoes
them, `--list` shows the folders.

## Claude Code specifics

- Managed settings cannot be turned off by the user; a plugin force-enabled there stays on. That
  is the point for a distribution, and also why the plugin only adds skills, notification hooks
  and one MCP server, never permissions or model settings.
- `managed-mcp.json` is deliberately not used: it takes exclusive control of MCP servers and would
  block every server a user adds. The MCP server comes through the plugin's `.mcp.json`.
- Drop-ins under `managed-settings.d/` merge alphabetically after `managed-settings.json`; the
  `50-` prefix leaves room on both sides.
- The MCP entry runs `crownos-computer-use mcp` over stdio. That binary ships with the
  crownos-computer-use component; until it is installed the server fails to start and Claude Code
  reports it in `/mcp`, which is harmless.

## Hooks

`hooks/notify.sh` turns `Notification` (`permission_prompt`, `idle_prompt`), `PermissionRequest`
and `Stop` into `notify-send` cards, which crownotify shows. `hooks/session-start.sh` adds one
paragraph of CrownOS context at `startup` and `resume`. Both need `jq` and `libnotify`, the
package's only dependencies.

## Build

The PKGBUILD reads two sibling checkouts through `CROWNOS_SIBLINGS` (set by
`scripts/manifest.sh`, default `../..` from `packaging/`): `crownos-plugins/skill/SKILL.md` and
`crownos-config/docs/config/*.md`. Regenerate the latter with `cargo xtask config-docs` in
crownos-config; its `--check` mode fails CI there when it is stale.
