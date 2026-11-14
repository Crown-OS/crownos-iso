---
name: crownos-computer-use
description: Operate desktop apps on CrownOS through the crownos-computer-use MCP server - list windows, snapshot a window's UI elements as refs, act on a ref (click, type, press, scroll), focus or move windows, take a screenshot, and run apps in the agent workspace so the user keeps working. Use whenever a task needs a GUI that no CLI, file or API reaches.
---

# Computer use on CrownOS

Prefer a programmatic path: a shell command, a file, an HTTP API, an app's own CLI. Reach for the
GUI only when nothing else does the job. When you do, use the `crownos-computer-use` MCP server,
never raw screenshots and coordinates: it reads each window's real UI tree and acts through the
compositor, with the user's consent and an audit trail.

## The loop

1. `list_windows` to see what is open: id, app, title, workspace, whether it is on the agent
   workspace, and whether it exposes a UI tree.
2. `snapshot(window, interactive_only=true)` returns the window's elements as refs like
   `@s3f1:e12`, each with role, name, value, bounds and the actions it supports. Refs belong to
   that snapshot: after anything changes, snapshot again and use the new refs. A stale ref is
   refused, never guessed at.
3. `find(window, role=, name=, text=)` when you know what you are looking for.
4. `act(ref, action)` with `click`, `double_click`, `hover`, `focus`, `type_text`, `press_key`,
   `scroll`, `drag`, `set_value`, `toggle`, `select`. Semantic actions are used when the element
   supports them (CrownUI apps, AT-SPI widgets); otherwise the daemon injects input at the
   element's centre through the agent's own cursor.
5. `screenshot(window)` only to confirm something the tree cannot tell you (a rendered chart, a
   colour). It is the slowest tool and the one the user is most sensitive about.
6. `focus(window)`, `move_window(window, workspace|agent)`, `close(window)` for window management.

Element sources, best first: CrownUI semantic tree, AT-SPI (GTK, Qt, Electron, Chromium with
accessibility on), the browser DOM through the `crownos-browser` path, OCR of a capture as a last
resort. The daemon picks; `snapshot` reports which source it used.

## The agent workspace

Launch programs you drive with `WORKSPACE=headless <command>`. They open on the agent workspace:
a workspace the user does not see unless they switch to it, listed in the dock with an agent badge
and as a card in SpaceControl. Your cursor is drawn there in your colour with your name on its
flag, and your keyboard focus is your own, so the user keeps working on their workspaces while you
work on yours.

- Keep your windows on the agent workspace unless the task is about the user's own window.
- `move_window(window, "visible")` brings a result to the user's current workspace when they
  should see it; the dock icon does the same when they click it.
- Acting on a window on the user's workspace shares their screen but still uses your own cursor
  and focus; say so before you start.

## Rules

- Never type into a field whose role or name says password, PIN, secret or OTP. The tree marks
  them `secure`; `act` refuses `type_text` on them, and so should you.
- Never dismiss a permission prompt, a lock screen or a compositor dialog. Those are the user's.
- Read before acting: snapshot, confirm the element, then act once. Do not retry a click in a
  loop; snapshot again and look at what changed.
- One action per `act`. Compose longer flows from snapshots between steps.
- Prefer `set_value` and `select` over typing into a widget letter by letter.
- When an app has no UI tree (`snapshot` reports `ocr`), tell the user the task is slower and less
  reliable, and ask before anything destructive.
- Stop and report when the compositor revokes access (`revoked` error): the user pulled the plug.

## Example

```text
list_windows
→ [{id: 41, app: "org.crownos.Files", title: "Downloads", workspace: "agent", tree: "crownui"}]
snapshot(41, interactive_only=true)
→ revision 7, refs: @s9k2:e3 button "New folder", @s9k2:e8 text_field "Search", ...
act("@s9k2:e3", {action: "click"})
→ ok, revision 8
snapshot(41) → @s9k3:e14 text_field "Folder name" (focused)
act("@s9k3:e14", {action: "type_text", text: "reports"})
act("@s9k3:e14", {action: "press_key", keybind: "Return"})
```

## Browsers

Web pages are driven through the DOM, not the accessibility tree, and Chromium needs a separate
automation profile. Read the `crownos-browser` skill before touching a browser window.
