---
name: crownos-context
description: Use the CrownOS visual context engine's memory of what the user has been doing - current activity, recent documents and projects, searchable timeline - before starting a task, and record what you did afterwards. Use when a request refers to "this", "what I was working on", "that file from yesterday", or when a task should continue the user's work.
---

# The visual context engine

CrownOS keeps a local, encrypted memory of the user's activity: which app and document had
focus, what was on screen (text, not pixels, except small thumbnails), notifications, copies, and
the segments and episodes those form. Nothing leaves the machine. Agents reach it through the
`context.*` and `memory.*` tools of the `crownos-computer-use` MCP server, which forwards the
agent's own identity so the engine applies that agent's grant.

The engine is being built; tools appear as its phases land. Check the tool list at session start
and fall back to asking the user when a tool is missing.

## Tools and what they are for

| Tool | Scope | Use |
|---|---|---|
| `context.current()` | `context.current` | The app, document, project and activity label right now, plus recent entities. No raw text. Call before a task that says "this". |
| `context.timeline(from, to)` | `context.search` | Episodes in a time range: what the user did, in order, with the documents involved. "What was I doing yesterday?" |
| `context.search(query, from?, to?)` | `context.search` | Hybrid search over summaries, episodes, entities and facts. Snippets are redacted. "Where did I see that error?" |
| `context.project(name?)` | `context.search` | A project's profile: root, recent files, open threads. |
| `context.resume(project?)` | `context.search` | What to pick up: last file, document or URL, and the step that was underway. |
| `context.explain(id)` | `context.search` | Why the engine believes a fact or an episode: its sources. |
| `memory.remember(text, about?)` | `memory.write` | Record something the user said or you learned that should persist. |
| `memory.correct(id, text)` | `memory.write` | Fix a wrong fact; the old one is invalidated, not deleted. |

Raw text lines, thumbnails and exact clipboard contents are `context.raw`, which agents never
hold. If a task truly needs them, ask the user to open the item.

## When to call

- Before a task with a referent ("this document", "the thing I was reading"): `context.current`.
- Before continuing work ("carry on with the report"): `context.resume`.
- When the user asks where or when something happened: `context.search` or `context.timeline`.
- After finishing a task with a durable outcome (a decision, a preference, a place something was
  put): `memory.remember`, one or two sentences, with `about` naming the project or entity.

## Rules

- Say what you looked up: "Your focus for the last hour was `report.md` in the thesis project."
- Grants are per agent and revocable; a `denied` error means the user has not allowed this scope.
  Ask, do not work around it.
- Never paste engine output into other tools or messages verbatim; it may contain names and
  snippets the user considers private. Summarise.
- Do not store secrets, credentials or health details with `memory.remember`.
