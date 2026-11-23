---
name: crownos-context
description: Use the CrownOS visual context engine's memory of what the user has been doing - current activity, recent documents and projects, searchable timeline - before starting a task, and record what you did afterwards. Use when a request refers to "this", "what I was working on", "that file from yesterday", or when a task should continue the user's work.
---

# The visual context engine

CrownOS keeps a local, encrypted memory of the user's activity: which app and document had
focus, the text that was on screen, notifications, copies, and the segments and episodes that
they make. The engine keeps text only. It analyses each capture and deletes the pixels at once,
so it has no screenshots and no thumbnails. Nothing leaves the machine.

The engine is off until the user turns it on in Settings > Privacy > Screen context. Agents get
its `context.*` and `memory.*` tools from the `crown-context-mcp` bridge. The bridge sends the
agent's own identity, so the engine applies the grant of that agent. The bridge is not in every
release yet. Look at the tool list at session start. If a tool is missing, ask the user.

## Tools and scopes

| Tool | Scope | Use |
|---|---|---|
| `context.current()` | `metadata` (titles, documents and entities need `text`) | The app, document, project and activity label now, and recent entities. No raw text. Call it before a task that says "this". |
| `context.timeline(from, to)` | `text` | Episodes in a time range: what the user did, in order, with the documents. "What was I doing yesterday?" |
| `context.search(query, from?, to?)` | `text` | Search over summaries, episodes, entities and facts. Snippets are redacted. "Where did I see that error?" |
| `context.project(name?)` | `text` | The profile of a project: root, recent files, open threads. |
| `context.resume(project?)` | `text` | What to pick up: the last file, document or URL, and the step that was in progress. |
| `context.explain(id)` | `text` | Why the engine believes a fact or an episode: its sources. |
| `context.entity(entity)` | `text` | One entity: aliases, facts that are valid now, recent episodes. |
| `context.pack(task)` | `text` | A short context pack for a task, in a token budget. |
| `memory.remember(text, about?)` | `memory_write` | Record something the user said or you learned that must persist. |
| `memory.correct(id, text)` | `memory_write` | Correct a wrong fact. The engine marks the old fact as not valid; it does not delete it. |

Raw text lines and exact clipboard contents need the `raw` scope. Agents never get it. If a task
truly needs them, ask the user to open the item.

## First use

The first call of an agent without a grant opens a consent dialog for the user. The call waits
until the user answers, for at most 120 s. The user chooses the scope and whether to remember the
answer. After a deny that the user did not remember, the engine does not ask again for 10 minutes.

- Tell the user that a dialog can open before your first call.
- Do not call again in a loop while the dialog is open or after a deny.
- You cannot answer the dialog. It ignores agent input.

## When to call

- Before a task with a referent ("this document", "the thing I was reading"): `context.current`.
- Before you continue work ("carry on with the report"): `context.resume` or `context.pack`.
- When the user asks where or when something happened: `context.search` or `context.timeline`.
- After a task with a durable outcome (a decision, a preference, the place of a file):
  `memory.remember`, one or two sentences, with `about` naming the project or entity.

## Rules

- Say what you looked up: "Your focus for the last hour was `report.md` in the thesis project."
- Grants are per agent, and the user can revoke them at any time. A `denied` error means that the
  user did not allow this scope. Ask; do not work around it.
- A grant of `metadata` gives no titles and no text. Do not ask for more than the task needs.
- Do not paste engine output into other tools or messages word for word. It can contain names and
  snippets that the user thinks are private. Give a summary.
- Do not store secrets, credentials or health details with `memory.remember`. For passwords and
  keys, use the crownos-secrets tools.
