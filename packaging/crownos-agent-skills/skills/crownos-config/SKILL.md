---
name: crownos-config
description: Change any CrownOS desktop setting (appearance, bar, compositor tiling and window rules, keybinds, lock screen, power, notifications, sound, wifi, files, camera, theme tokens) by editing the RON section files under ~/.config/crownos, with the generated reference for every key. Use whenever the user wants the system to look or behave differently, or asks what a setting does.
---

# Changing CrownOS settings

Every setting is one RON file in `~/.config/crownos/`, named after its section:
`appearance.ron`, `compositor.ron`, `keybinds.ron`, `bar.ron`, `lock.ron`, and so on. The settings
panel, the bar, the compositor and every other app read the same files through `crownos-config`
and watch them, so a saved edit applies at once. Editing the file is the settings panel.

The user's file sets only the keys that the user changed. It lists every other key as a `//`
comment with its current default, so a comment line is not a value. Each key that the file does
not set comes from the layers below it, and the highest layer that has the key wins:

1. `~/.config/crownos/<section>.ron`: the user's changes. Edit only this file.
2. `/etc/crownos/defaults/<section>.ron`: the defaults of this machine, if any.
3. `/usr/share/crownos/defaults/<section>.ron`: the CrownOS defaults. Each system update replaces
   them, so do not edit them.
4. The default of each key in the reference.

To find the current value of a key, read the layers in that order. A key in the user's file stays
at the user's value after an update. A list is one key: to add one item to a list that a lower
layer sets, copy the whole list into the user's file. That stops updates from changing that list,
so for startup programs use `startup`, which no lower layer sets, and not `session_startup`.

## Workflow

1. Find the section and key in the reference: `/usr/share/doc/crownos/config/index.md` lists every
   section with who reads it; `/usr/share/doc/crownos/config/<section>.md` lists each key with its
   type, default, meaning, the enum variants it accepts, and a complete example file.
2. Read the current file and the layers below it. A `//` line shows a default, not a user value.
   A missing user file means that every key comes from the layers.
3. Edit only the keys you mean to change. To set a commented key, remove `// ` from each line of
   that entry and change the value. To go back to the default, comment the entry out again. Keep
   the surrounding parentheses: a section is one RON struct, `( key: value, )`. A program that
   saves the section writes the file again and does not keep comments that you add.
4. Save atomically if scripting: write `<file>.tmp` beside it and rename over the original. Apps
   never see a half-written file that way, which is what `crownos-config` itself does.
5. Confirm the change took: the compositor and bar react within a frame; apps that read at
   startup (the reference says which) need a restart.

## RON rules that trip people up

- Enum values are bare names: `accent: Blue`, `layout: Floating`, `position: Bottom`.
- Strings are double-quoted, lists are `[...]`, nested structs are `(...)`.
- Optional fields are written plainly: `floating: true`, not `Some(true)`.
- Floats need a decimal point: `transparency: 0.2`, `dim: 0.0`.
- A file that fails to parse is ignored and the defaults apply, silently. If a change has no
  effect, parse-check your edit against the example in the reference.

## Where things live

| You want to change | Section | Notes |
|---|---|---|
| Dark mode, accent, wallpaper, gaps, borders, blur, animations, cursor and icon theme | `appearance` | Read live by the compositor and every app |
| Tiling or floating default, window rules, outputs, startup programs, gaming | `compositor` | Rules match `app_id` and `title` as regexes; add programs to `startup` |
| Global shortcuts | `keybinds` | Chords like `"Super+Shift+Q"`; actions are the compositor's own names |
| Bar position, size, which widgets, floating bar | `bar` | Plugin widgets are `"plugin:<id>/<widget>"` |
| Lock screen clock, background, slots, idle lock | `lock` | |
| Theme tokens (colors, radii, fonts) | `theme` | Sparse overrides by slot name, `surface.bg` |
| Power profile and battery behaviour | `power` | |
| Notifications, sound, wifi, bluetooth, display | their own section | |
| Themes and plugins | `plugins` | Written only by `crownplugind`: use the `crownos-plugins` skill, not this file |

The CrownOS defaults are in `/usr/share/crownos/defaults/`. To make a key follow the defaults
again, remove it from the user's file.

## Example: a floating desktop with a bottom bar and a blue accent

`~/.config/crownos/appearance.ron`

```ron
(
    accent: Blue,
    gaps_inner: 12,
    animations: Smooth,
)
```

`~/.config/crownos/compositor.ron`

```ron
(
    layout: Floating,
    window_rules: [
        (app_id: "^org.mozilla.firefox$", workspace: 1),
        (title: "^(Open|Save)", floating: true, focus: false),
    ],
)
```

`~/.config/crownos/bar.ron`

```ron
(
    position: Bottom,
    floating: true,
)
```

## When not to edit files

- Themes and plugins: `crownplugin` (see the `crownos-plugins` skill) writes through a journal so
  turning a theme off restores what it changed. Hand edits to `plugins.ron` break that.
- Anything that needs root (drivers, services, package installs) is not a CrownOS setting.
