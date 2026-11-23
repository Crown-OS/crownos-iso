---
name: crownos-context
description: Use the CrownOS visual context engine's memory of what the user has been doing - current activity, recent documents and apps, searchable timeline - through the crown-context command before starting a task. Use when a request refers to "this", "what I was working on", "that page from yesterday", or when a task should continue the user's work.
---

# The visual context engine

CrownOS keeps a local, encrypted memory of the user's activity: which app and document had
focus, the text that was on screen, notifications, copies, and the segments and episodes that
they make. The engine keeps text only. It analyses each capture and deletes the pixels at once,
so it has no screenshots and no thumbnails. Nothing leaves the machine.

The engine is off until the user turns it on in Settings > Privacy > Screen context. If
`crown-context status` says that `crown-contextd` is not running, the engine is off or not
installed. Tell the user; do not start it yourself.

## The crown-context command

| Command | Scope | Use |
|---|---|---|
| `crown-context status` | any scope | Whether the engine observes, is paused or is degraded. |
| `crown-context context` | `metadata` (titles and documents need `text`) | The app, document and activity now. Call it before a task that says "this". |
| `crown-context tail` | `metadata` (titles and text need `text`) | Follow context changes and closed segments. Stop it when you have what you need. |
| `crown-context timeline --today \| --yesterday \| --hours N [--episodes]` | `text` | Segments or episodes in a time range. "What was I doing yesterday?" |
| `crown-context search <text> [--limit N]` | `text` | Search the text seen on screen and the places visited. Snippets are redacted. |
| `crown-context forget --last-minutes N [--app ID]` | `memory_delete` | Forget a stretch of time. Only when the user asks for it. |
| `crown-context pause [--seconds N]` | `pause` | Stop observing; without `--seconds`, until `resume`. Only when the user asks for it. |
| `crown-context resume` | `pause` | Observe again. |

Add `--json` to get JSON. The `raw` scope gives raw text lines without redaction. Agents never get
it. If a task truly needs them, ask the user to open the item.

The engine sees the caller as the `crown-context` program, not as you. A grant to
`crown-context` applies to every program that runs it.

## First use

The first call of a program without a grant opens a consent dialog for the user. The call waits
until the user answers, for at most 120 s. The user chooses the scope and whether to remember the
answer. After a deny that the user did not remember, the engine does not ask again for 10 minutes.

- Tell the user that a dialog can open before your first call.
- Do not call again in a loop while the dialog is open or after a deny.
- You cannot answer the dialog. It ignores agent input.

## Planned

The `crown-context-mcp` bridge (phase 9 of the engine plan) is not in this release. It will give
agents `context.*` and `memory.*` MCP tools with a grant for each agent, and `memory.remember`
to record facts. Until then, use only the command above. If `context.*` tools show in your tool
list, prefer them.

## Rules

- Say what you looked up: "Your focus for the last hour was `report.md` in the thesis project."
- The user can revoke a grant at any time. A `denied` error means that the user did not allow
  this scope. Ask; do not work around it.
- A grant of `metadata` gives no titles and no text. Do not ask for more than the task needs.
- Do not paste engine output into other tools or messages word for word. It can contain names and
  snippets that the user thinks are private. Give a summary.
- Never use `forget` or `pause` unless the user asks for it.
