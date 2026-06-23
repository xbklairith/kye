# Kye

A lightweight macOS **menu-bar keyboard remapper**. Kye intercepts key events with a `CGEvent` tap and rewrites them according to your rules — remap a key to another key, or build modifier *layers* (e.g. hold Right-Command and use `h j k l` as arrow keys). Rules can be authored right in the app or by editing a JSON file that reloads automatically.

> Requires **macOS 14 (Sonoma) or later**.

## Features

- **Basic remaps** — map one key to another (e.g. Right Alt → Right Command).
- **Layer remaps** — while a trigger modifier is held, remap keys (e.g. Right Command + `h/j/k/l` → arrows, Vim-style).
- **In-app rule authoring** — add, edit, and delete rules from the Settings → Rules tab, with live **key capture** (press the key to record it) or a dropdown of supported keys.
- **Config auto-reload** — edits to the JSON config on disk apply automatically; an invalid edit keeps the last good rules and shows a banner until you fix it.
- **Menu-bar status** — at-a-glance state (Active / Disabled / Permission Required) plus enable/disable and reload actions.

## Install

1. Download `Kye-vX.Y.Z.zip` from the [latest release](https://github.com/xbklairith/kye/releases/latest), unzip it, and move **Kye.app** to `/Applications`.
2. Launch it. The app is signed with an Apple Development certificate (not a Developer ID, not notarized), so Gatekeeper warns on first launch — **right-click the app → Open**, or allow it under **System Settings → Privacy & Security**.
3. Grant **Accessibility** permission when prompted (**System Settings → Privacy & Security → Accessibility**). This is required for keyboard interception — without it, Kye can't remap keys.

The menu-bar icon shows the current status. Use it to enable/disable remapping, reload the config, or open Settings.

## Default rules

On first run Kye writes a default config with two rules:

| Rule | Effect |
| --- | --- |
| `right-alt-to-right-cmd` (basic) | Remap **Right Alt → Right Command** |
| `vim-navigation` (layer) | Hold **Right Command** + `h` `j` `k` `l` → **← ↓ ↑ →** |

Together these let you use Right Alt as a Vim-style navigation layer.

## Configuration

Rules live at `~/.config/kye/config.json`. You can edit rules in the app, or edit this file directly — Kye watches it and reloads on save.

```json
{
  "version": "1.0",
  "enabled": true,
  "rules": [
    {
      "type": "basic",
      "id": "right-alt-to-right-cmd",
      "description": "Remap Right Alt to Right Command",
      "enabled": true,
      "from": "right_option",
      "to": "right_command"
    },
    {
      "type": "layer",
      "id": "vim-navigation",
      "description": "Vim-style navigation with Right Command",
      "enabled": true,
      "trigger": "right_command",
      "mappings": {
        "h": "left_arrow",
        "j": "down_arrow",
        "k": "up_arrow",
        "l": "right_arrow"
      }
    }
  ]
}
```

**Rule fields**

- Common: `type` (`"basic"` | `"layer"`), `id` (unique string), `description` (optional), `enabled` (defaults to `true`).
- `basic`: `from` and `to` key names.
- `layer`: `trigger` modifier key name, and `mappings` of held-key → output-key.

**Supported key names**

- Letters `a`–`z`, numbers `0`–`9`
- Modifiers: `left_shift` `right_shift`, `left_control` `right_control`, `left_option`/`left_alt` `right_option`/`right_alt`, `left_command` `right_command`
- Arrows: `left_arrow` `right_arrow` `up_arrow` `down_arrow`
- Editing/navigation: `return`/`enter`, `tab`, `space`, `delete`/`backspace`, `forward_delete`, `escape`/`esc`, `home`, `end`, `page_up`, `page_down`, `caps_lock`
- Function keys: `f1`–`f12`
- Punctuation: `minus` `equal` `left_bracket` `right_bracket` `backslash` `semicolon` `quote` `grave` `comma` `period` `slash`

> Note: multi-mapping layer rules (more than one mapping) are edited via the JSON file; the in-app inline editor handles basic rules and single-mapping layers.

## Build from source

Requires Xcode (macOS 14 SDK).

```bash
# Build
xcodebuild build -project Kye.xcodeproj -scheme Kye -configuration Release -destination 'platform=macOS'

# Test
xcodebuild test -project Kye.xcodeproj -scheme Kye -destination 'platform=macOS'
```

The project signs **ad-hoc** by default, which keeps the app host and test bundle Team IDs consistent for `xcodebuild test`. Building a permission-stable installable app uses an Apple Development signing identity (applied locally, not committed).

## Project layout

```
Kye/
  Core/       Key mapping, modifier handling, rule engine, key capture
  Models/     Configuration, Rule (basic/layer), RuleDraft, AppError
  Services/   AppController, event tap, permissions, config manager + file watcher, logging
  Views/      Menu-bar content, Settings, rule editor
KyeTests/     Unit + integration tests
```

## License

Released under the [MIT License](LICENSE) — free to use, modify, and distribute.
