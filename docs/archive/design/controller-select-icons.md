# Controller Select Icons

## Goal
Replace the plain text device labels in the controller selection screen
("Keyboard", "Controller 1", "Controller 2") with images: one keyboard icon
and one generic controller icon (all connected gamepads share the same
icon — no per-brand Xbox/PlayStation/Switch-Pro detection, since no such
detection logic exists in the codebase today and distinguishing brands was
explicitly deferred by `docs/archive/design/controller-support.md`).

Per user decisions:
- **Icon scope**: one generic controller icon for any joystick, one keyboard
  icon. Not distinguishing controller brands.
- **Art style**: flat placeholder art, matching the existing precedent for
  `assets/ui/panel_normal.png` / `panel_selected.png` — generated via a
  throwaway Python + PIL script (script itself not committed, only the
  resulting `.png`s).
- **Layout**: icon **replaces** the text label rather than sitting alongside
  it.

## Affected files

- **New assets** — `assets/ui/icon_keyboard.png` and
  `assets/ui/icon_controller.png`. Small flat placeholder images (following
  the 64x64 flat-square precedent of `panel_normal.png`), simple enough to
  read as "keyboard" vs. "gamepad" shapes at a glance, generated via a
  throwaway PIL script (not committed).

- **`game/scenes/controller_select_scene.lua`**
  - Add module-level image loads next to the existing `PANEL_NORMAL` /
    `PANEL_SELECTED` loads (`:11-12`):
    ```lua
    local ICON_KEYBOARD   = love.graphics.newImage("assets/ui/icon_keyboard.png")
    local ICON_CONTROLLER = love.graphics.newImage("assets/ui/icon_controller.png")
    ```
  - In `on_enter()`, attach an `icon` field to each source alongside its
    existing `label`: the keyboard source (`:49-57`) gets `icon =
    ICON_KEYBOARD`; each gamepad source built in the loop (`:59-80`) gets
    `icon = ICON_CONTROLLER`. `label` stays as-is on every source — it's
    still read by `tests/test_controller_select_scene.lua` and by
    `_label_for()` for a middle-column fallback (see below), so it isn't
    removed, just no longer drawn directly for the per-slot icon views.
  - In `draw()`, replace the three places that currently print a label as
    text with an icon draw:
    - Player 1 slot (`:182`, currently
      `love.graphics.printf(_label_for(self.p1_device, self._sources), ...)`):
      resolve the claimed source (not just its label) and draw its `icon`
      centered in the column if a device is claimed; draw nothing (empty
      slot, matching today's "-" being effectively blank body text) if not.
    - Middle "Devices" legend loop (`:192-194`): replace
      `love.graphics.printf(source.label, ...)` with a small icon draw per
      unclaimed source, stacked vertically the same way the text rows are
      today.
    - Player 2 slot (`:201`): same treatment as Player 1.
  - A small local helper (e.g. `_source_for(device, sources)`, sibling to
    the existing `_label_for()`) returns the whole matched source table
    (not just `.label`) so `draw()` can reach `.icon`; `_label_for()` itself
    can stay if still needed, or be inlined into the new helper — final call
    left to the implementing task, since it's a local, easily-reversible
    refactor.
  - Icon draw sizing: scale each icon to a fixed on-screen size (e.g. 48x48
    for the per-slot icons, ~24x24 for the middle-column list rows) the same
    way panel images are scaled today — dividing target size by
    `icon:getWidth()/getHeight()` — since these are small flat source images
    reused at different draw sizes, matching the codebase's existing
    scaling convention.

## What stays the same
- `source.label` remains on every source's data (kept for tests and for any
  remaining internal bookkeeping) — only its *use inside `draw()`* changes
  from `printf` to an icon draw.
- Source discovery logic (`on_enter()`'s keyboard-always / up-to-2-gamepads
  loop), claim/release logic (`update()`), confirm/ready gating, and
  `escape_to_menu` are untouched — this is a pure `draw()`-and-data-shape
  change.
- "Player 1" / "Player 2" column headers and the "Ready!" / "press Confirm"
  status text stay as `printf` text — only the *device identity* row becomes
  an icon.
- The bottom instructions line (`:207-210`) stays text.
- Panel backgrounds (`PANEL_NORMAL` / `PANEL_SELECTED`) are unchanged.
- No controller-brand detection is added — every gamepad, regardless of
  vendor, uses the same generic controller icon.
- No shared theme/asset module — image loads stay duplicated per scene file,
  matching this codebase's established convention (see
  `docs/archive/design/menu-ui-pngs.md`).

## Open questions
None outstanding — icon scope (generic, not per-brand), art style (flat
placeholder, script-generated), and layout (icon replaces text) were all
confirmed with the user before writing this doc.
