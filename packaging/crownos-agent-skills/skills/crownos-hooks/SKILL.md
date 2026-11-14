---
name: crownos-hooks
description: Wire Claude Code and other coding agents into the CrownOS desktop with hooks - desktop notifications through crownotify when the agent needs permission, waits for input, or finishes, and session-start context about the machine. Use when the user wants to be told what the agent is doing, or asks for hooks, notifications or events from an agent.
---

# Hooks between agents and the CrownOS desktop

crownotify is the notification daemon. It serves `org.freedesktop.Notifications`, so the plain
`notify-send` from libnotify reaches it, with actions, urgency and icons. No CrownOS-specific
helper is needed from a hook.

## What is already installed

The `crownos` Claude Code plugin (force-enabled through managed settings) ships these hooks in
`/usr/share/crownos/claude-marketplace/plugins/crownos/hooks/hooks.json`:

| Event | Matcher | Effect |
|---|---|---|
| `Notification` | `permission_prompt\|idle_prompt` | A card: "Claude needs your permission" or "Claude is waiting for you" |
| `PermissionRequest` | all tools | A critical card naming the tool, the moment the prompt opens |
| `Stop` | | A card with the first line of the final answer |
| `SessionStart` | `startup\|resume` | Tells Claude where the CrownOS settings reference and skills are |

They run `notify.sh` and `session-start.sh` from the same directory. Read them before writing your
own; they show the stdin shape of each event.

## Writing a hook that notifies

Hooks receive JSON on stdin. Pull fields with `jq`, then call `notify-send`:

```sh
#!/bin/sh
input=$(cat)
message=$(printf '%s' "$input" | jq -r '.message // "Needs your attention"')
notify-send --app-name "Claude Code" --icon dialog-information "Claude Code" "$message"
```

Useful `notify-send` flags: `--urgency critical` bypasses Do Not Disturb; `--expire-time 0` keeps
the card until dismissed; `--action key=Label` adds a button and prints the pressed key on stdout,
so a hook can wait for an answer (`--wait`).

Register it in `~/.claude/settings.json` (user) or `.claude/settings.json` (project):

```json
{
  "hooks": {
    "Notification": [
      { "matcher": "permission_prompt|idle_prompt",
        "hooks": [ { "type": "command", "command": "~/.claude/hooks/notify.sh" } ] }
    ]
  }
}
```

Event fields worth knowing:

- `Notification`: `message`, `title`, `notification_type` (`permission_prompt`, `idle_prompt`,
  `agent_needs_input`, `agent_completed`, ...). Cannot block or change anything.
- `PermissionRequest`: `tool_name`, `tool_input`. Printing JSON with
  `hookSpecificOutput.decision.behavior` set to `allow` or `deny` answers the prompt; print nothing
  to leave it to the user.
- `Stop`: `last_assistant_message`, `stop_hook_active`. Exit code 2 keeps Claude working.
- `SessionStart`: `source` (`startup`, `resume`, `clear`, `compact`, `fork`). Plain stdout becomes
  context Claude sees.
- Every event: `session_id`, `cwd`, `transcript_path`, `hook_event_name`.

## Other agents

Codex and Antigravity read their own hook files (`hooks.json` next to their config). The same
`notify-send` scripts work unchanged; only the registration differs. Check each agent's
documentation for the event names it fires.

## Desktop to agent

The reverse direction, the desktop telling an agent that a window gained focus or a notification
was posted, is not available yet. crownpositor and crownotify will gain event streams for it
through `crownos-computer-use`; until then poll the `list_windows` tool of that MCP server when a
task needs to react to the desktop.

## Keep hooks quiet

A hook that posts on every `PostToolUse` floods the notification center. Notify on what needs a
person: permission, idleness, completion, failure. Do Not Disturb (`crownotify`'s focus mode) still
holds back everything but `critical`.
