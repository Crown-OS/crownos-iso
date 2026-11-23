---
name: crownos-computer-use
description: Operate desktop apps on CrownOS through the crownos-computer-use MCP server - list windows, snapshot a window's UI elements as refs, act on a ref (click, type, press, scroll), focus, show or hide windows, take a screenshot, and launch apps on the agent workspace so the user keeps working. Use whenever a task needs a GUI that no CLI, file or API reaches.
---

# Computer use on CrownOS

Prefer a programmatic path: a shell command, a file, an HTTP API, an app's own CLI. Reach for the
GUI only when nothing else does the job. When you do, use the `crownos-computer-use` MCP server,
never raw screenshots and coordinates: it reads each window's real UI tree and acts through the
compositor, with the user's consent and an audit trail.

## The loop

1. `list_windows` to see what is open: every window and browser tab with identifier, app, title,
   process, bounds and state.
2. `snapshot(window, interactive_only=true)` returns the window's elements as refs like
   `@s3:e7`, each with role, name, value, bounds and the actions it supports. Refs belong to
   that snapshot: after anything changes, snapshot again and use the new refs. A stale ref is
   refused, never guessed at.
3. `find(window, role=, name=, text=)` when you know what you are looking for.
4. `act(ref, action)` with `click`, `double_click`, `hover`, `focus`, `type_text`, `press_key`,
   `scroll` or `set_value`. Semantic actions are used when the element
   supports them (CrownUI apps, AT-SPI widgets); otherwise the daemon injects input at the
   element's centre through the agent's own cursor.
5. `screenshot(window)` only to confirm something the tree cannot tell you (a rendered chart, a
   colour). It is the slowest tool and the one the user is most sensitive about.
6. `focus(window)`, `make_visible(window)`, `make_hidden(window)` and `close(window)` for window
   management.

Element sources, best first: CrownUI semantic tree, AT-SPI (GTK, Qt, Electron, Chromium-based
browsers with accessibility on), the browser DOM over the DevTools pipe of a Chromium-based browser
(Brave, Google Chrome or Chromium) through the `crownos-browser` path. OCR of a capture is planned.
The daemon picks the source.

## The agent workspace

Start programs you drive with `launch(command, headless=true)`. `command` is an argv array, for
example `["crownos-files"]`, and `headless` is the default. They
open on the agent workspace, and `agent_workspace` returns its identifier. The agent workspace is
a workspace the user does not see unless they switch to it, listed in the dock with an agent badge
and as a card in SpaceControl. Your cursor is drawn there in your colour with your name on its
flag, and your keyboard focus is your own, so the user keeps working on their workspaces while you
work on yours.

- Keep your windows on the agent workspace unless the task is about the user's own window.
- `make_visible(window)` brings a result onto the user's screen when they should see it; the dock
  icon does the same when they click it. `make_hidden(window)` sends a window back to the agent
  workspace.
- Acting on a window on the user's workspace shares their screen but still uses your own cursor
  and focus; say so before you start.

## Rules

- To enter a password or key, never type it: call `type_secret {ref, name}` or `fill_login`. List
  names with the crownos-secrets tools; if one is missing, use `secrets_request`.
  `act` refuses `type_text` and `set_value` on elements marked `secure` (skill: crownos-secrets).
- Never dismiss a permission prompt, a lock screen or a compositor dialog. Those are the user's.
- Read before acting: snapshot, confirm the element, then act once. Do not retry a click in a
  loop; snapshot again and look at what changed.
- One action per `act`. Compose longer flows from snapshots between steps.
- Prefer `set_value` over typing into a widget letter by letter.
- When `snapshot` fails or returns no elements for a window, tell the user the task is slower and
  less reliable, and ask before anything destructive.
- Stop and report when actions fail with a compositor error: the user withdrew access.

## Example

```text
list_windows
→ {untrusted_content: true, note: ..., data: {windows: [{identifier: "41", app_id: "org.crownos.Files",
   title: "Downloads", workspace: "3", state: {agent_workspace: true, ...}, ...}]}}
snapshot("41", interactive_only=true)
→ @s7:e3 button "New folder", @s7:e8 text_field "Search", ...
act("@s7:e3", {action: "click"})
→ {ok: true}
snapshot("41") → @s8:e14 text_field "Folder name"
act("@s8:e14", {action: "set_value", value: "reports"})
act("@s8:e14", {action: "press_key", keybind: "Return"})
```

## Browsers

Web pages are driven through the DOM, not the accessibility tree. When the browser chosen at
install time is a Chromium-based browser (Brave, Google Chrome or Chromium), the daemon drives it
over the DevTools pipe with a separate automation profile. Read the `crownos-browser` skill before
touching a browser window. When the chosen browser is Firefox, use the `playwright` MCP server
and read the `crownos-playwright` skill.
