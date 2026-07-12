## Settings Menu Checklist

Source design doc: `docs/design/settings-menu.md` — read it in full before starting any
task below; this checklist only summarizes what to do and where.

### Wave A — foundational, no dependencies (run in parallel)

- [x] Task 1 — `game/settings_state.lua` (new) — Create the `SettingsState` singleton
  modeled on `game/game_state.lua`'s pattern (module returns `SettingsState.new()`,
  a singleton instance, `require`d directly by other modules — not constructor-
  injected). Fields: `fullscreen` (bool) and `keybinds` (table: action → single key
  string) for exactly the six actions `up, down, left, right, interact,
  rotate_piece`. Default keybinds: `up=w, down=s, left=a, right=d, interact=e,
  rotate_piece=r` (single key each — this replaces today's dual WASD+arrow-key
  binding; arrow keys stop moving the player by default, per the design doc's
  "SettingsState" section and "Open questions"). Methods per the design doc's
  "SettingsState" section:
  - `SettingsState:toggle_fullscreen()` — flips `.fullscreen`, calls
    `love.window.setFullscreen(self.fullscreen)`.
  - `SettingsState:set_keybind(action, key)`.
  - `SettingsState:key_map()` — returns `{action = {key}}` shape, i.e. each action
    maps to a single-element list, matching the shape `lua/core/input.lua`'s
    `Input.new` expects for its keyboard key-list argument.
  - `SettingsState:to_save()` — returns `{version = 1, fullscreen = ..., keybinds =
    ...}`.
  - `SettingsState:apply_save(data)` — mirrors `GameState:apply_save`'s
    version-gate + reset-on-mismatch behavior (read `game/game_state.lua` for the
    exact pattern to copy).
  - `SettingsState:reset()` — resets to defaults, for test isolation, same purpose
    as `GameState:reset()`.
  Do not touch any other file in this task.

- [x] Task 7 — `game/scenes/start_scene.lua` — Add a new "Settings" menu item and an
  optional `on_settings` callback param, per the design doc's "Start Scene entry
  point" section. `StartScene.new(manager, on_settings)` — `on_settings` must be
  nil-safe (every existing `StartScene.new(manager)` call site, including in
  `tests/test_start_scene.lua`, keeps constructing correctly; selecting the new
  item when `on_settings == nil` is a no-op, don't error). New item order:
  `{"New Game", "Continue", "Players: N", "Settings", "Exit Game"}` — "Settings" is
  inserted immediately before "Exit Game", shifting Exit Game from index 4 to
  index 5. Selecting "Settings" invokes `on_settings()` if present. The
  `_next_selectable` skip-logic (`start_scene.lua:59-66`, skip index 2 if no save)
  already parameterizes over `#self.items` and needs no changes — do not modify it
  beyond what naturally falls out of the item list growing by one. Do not update
  `tests/test_start_scene.lua` in this task — that is a separate, later task
  (Task 10) that depends on this one being done first.

- [x] Task 8 — `game/scenes/game_scene.lua` — Add `self.esc_opens_settings = true`
  as a new field (set alongside `GameScene`'s other instance fields at
  construction), and update the on-screen control hint text from
  `"ESC: save & menu"` to `"ESC / Start: settings"`, per the design doc's "ESC /
  gamepad Start behavior resolution" section. Do not change `to_save` or any other
  existing behavior — `to_save` stays exactly as-is; `esc_opens_settings` is an
  independent new field `main.lua` will read later (main.lua wiring is a separate
  task). Do not touch `main.lua` in this task.

- [x] Task 9 — `lua/core/save.lua` — Add three new functions for a second,
  independent save file `settings.dat`, parallel to (and reusing the same private
  `serialize()` helper as) the existing `save.dat` trio, per the design doc's
  "Persistence" section:
  - `Save.settings_exists()` — same pattern as the existing exists-check but calls
    `love.filesystem.getInfo("settings.dat")`.
  - `Save.write_settings(data)` — writes `data` to `settings.dat` the same way the
    existing write function writes `save.dat`.
  - `Save.read_settings()` — reads and deserializes `settings.dat` the same way the
    existing read function reads `save.dat`.
  Keep this fully separate from the existing `save.dat` read/write/exists trio —
  do not add a new key to `save.dat`'s `{game_state=, scene=}` shape, and do not
  modify any existing `tests/test_save.lua` assertions in this task (new tests for
  these functions, if desired, can be added alongside existing `test_save.lua`
  patterns, but are not required by the design doc as a separate checklist item —
  use judgment matching `tests/test_save.lua`'s existing in-memory-`love.filesystem`
  stub style if you do add coverage).

### Wave B — depends on Task 1 (run in parallel with each other once Task 1 is done)

- [x] Task 2 — `tests/test_settings_state.lua` (new) — Depends on: Task 1. Write
  tests for `game/settings_state.lua` covering: construction defaults (fullscreen
  false/off, default keybinds `w/s/a/d/e/r`), `toggle_fullscreen()` flips the flag,
  `set_keybind(action, key)` updates a single action, `key_map()`'s exact `{action
  = {key}}` shape, and `to_save()`/`apply_save()` round-tripping correctly
  (including the version-gate/reset-on-mismatch case). Match
  `tests/test_save.lua`'s in-memory-`love.filesystem` stub pattern for any
  save/load-adjacent assertions. Read `game/settings_state.lua` (from Task 1) for
  the actual method signatures before writing assertions against it.

- [x] Task 5 — `game/player.lua` — Depends on: Task 1. Change
  `Player.build_input(device)`'s keyboard-driven branches (the `device == nil`
  branch and the `device.type == "keyboard"` branch only — leave the gamepad-only
  branch untouched) to build their keyboard key lists from
  `SettingsState:key_map()` instead of hardcoded literals (currently e.g. `up =
  {"w", "up"}` around `game/player.lua:17-20` — that dual-key list is replaced by
  the single-key list `key_map()` returns). After building the `Input` instance in
  those two branches, tag it: `inp._keyboard_rebindable = true`. Do not tag the
  gamepad-only branch's `Input`. Requires `require`ing `game/settings_state.lua`
  at the top of the file. This tag is load-bearing (see the design doc's "Wiring
  rebinds into live `Input` instances" section) — a later task
  (`settings_scene.lua`, Task 3) will check `.input._keyboard_rebindable` before
  overwriting `._map` on a live player's `Input`, specifically to avoid handing
  keyboard control to a gamepad-assigned `player2` whose keyboard key lists are
  built empty (`game/player.lua:46-51`). Get the field name exactly right:
  `_keyboard_rebindable`.

### Wave B' — depends on Task 1 and Task 9

- [x] Task 3 — `game/scenes/settings_scene.lua` (new) — Depends on: Task 1, Task 9.
  Build the Settings menu/overlay object per the design doc's "Settings
  scene/overlay" and "Menu-chrome navigation" sections in full — read both
  sections closely, this is the largest task in the feature. Key points:
  - **Not** a `lua/core/scene.lua` subclass, never passed to `SceneManager:switch`.
    A plain object `main.lua` owns and draws on top of `SceneManager.current`.
  - Public surface: `:open(opaque, scene, manager)`, `:close()`, `.is_open`,
    `:update(dt)`, `:draw()`, `:keypressed(key)` (returns true if consumed, for
    rebind-capture and the all-bound gate), `:gamepadpressed(button)` (returns
    true if consumed, for menu nav/confirm).
  - Builds its own `lua/core/input.lua` `Input` instance for row navigation,
    identical in shape to `StartScene`'s menu-nav `Input`
    (`start_scene.lua:29-44`): keyboard `up={"w","up"}, down={"s","down"},
    confirm={"e","return"}`; `gamepad_buttons = {up={"dpup"}, down={"dpdown"},
    confirm={"a"}}`; `joystick_scope = "first_two"`. This `Input` instance has no
    escape/close action — closing is handled by `main.lua` (Task 6), not here.
    Reuse this same `Input` instance for both the top-level item list and the
    Keybinds subscreen's row list (switch which list `self.selected` indexes into
    via a `self._subscreen` flag).
  - Top-level items, plain-rectangle style like `StartScene`: **Fullscreen**
    (toggle; label flips "Fullscreen"/"Window"; calls
    `SettingsState:toggle_fullscreen()` then persists via
    `Save.write_settings(SettingsState:to_save())`), **Keybinds** (enters the
    remap subscreen), plus **opaque-mode-only** a **Back** row (closes the
    overlay, returns to the still-alive scene beneath — used when opened via
    `:open(true, ...)` from the Start Scene), plus **overlay-mode-only** a **Main
    Menu** row (calls `scene.to_save()` + `Save.write({...})` using the same shape
    `main.lua`'s current save-on-ESC path writes, then expects the caller/`main.lua`
    to switch to `StartScene.new(manager)` — read the design doc's "Settings
    scene/overlay" section for exactly what belongs to the scene object vs.
    `main.lua`; if ambiguous, have this row perform the save-and-switch itself
    using the `manager` passed to `:open()`, since `:open(opaque, scene, manager)`
    is given both).
  - Keybinds subscreen: 6 rows (Up/Down/Left/Right/Interact/Rotate Piece); select
    a row, then the *next* raw key pressed (via `:keypressed(key)`, not the nav
    `Input`) rebinds it — call `SettingsState:set_keybind(action, key)` on success,
    then persist via `Save.write_settings(SettingsState:to_save())`. Duplicate-key
    rejection: if the pressed key is already bound to a different action, reject
    with shake-and-reject feedback (port the logic from
    `/root/wip/lua/game/scenes/settings_menu.lua:320-327` — read that file for the
    exact shake/reject behavior to replicate). Leaving the subscreen is gated on
    every action having a bound key (port `_all_bound` from the same wip file;
    mostly defensive since `set_keybind` never assigns `nil`).
  - After a successful rebind (in overlay mode only, since opaque mode has no live
    `Player`), reach into `scene.player` and `scene.player2` (the `scene` passed to
    `:open()`) — for each that exists and whose `.input._keyboard_rebindable ==
    true`, do `scene.player.input._map = SettingsState:key_map()` (and same for
    `player2`). Do **not** touch `.input._map` for a player whose
    `_keyboard_rebindable` is falsy/nil.
  - Background: opaque mode fills the full 1280×720 canvas with a solid color (no
    patterned art); overlay mode draws a `(0,0,0,0.55)` semi-transparent rect over
    the frozen game world beneath it.
  - `require`s `game/settings_state.lua` and `lua/core/save.lua` at the top.

### Wave C — depends on Task 3

- [x] Task 4 — `tests/test_settings_scene.lua` (new) — Depends on: Task 3. Write
  tests for `game/scenes/settings_scene.lua` matching
  `tests/test_start_scene.lua`'s `tap()`/`with_joysticks()` helper patterns
  (read that file for the exact helper style to reuse). Cover: row navigation
  (up/down wraps or clamps — check what `StartScene` does and match it),
  opaque-vs-overlay mode showing the correct row set (Back only in opaque, Main
  Menu only in overlay), the rebind-capture flow including duplicate-key
  rejection, and the "all bound" gate preventing leaving the Keybinds subscreen
  when applicable. Also test `:gamepadpressed(button)` drives the same nav/confirm
  behavior as keyboard, via fake joysticks the way `test_start_scene.lua` already
  does with `with_joysticks()`.

### Wave D — depends on Tasks 1, 3, 7, 8, 9 (integration; run after all of Wave A/B/B'/C)

- [x] Task 6 — `main.lua` — Depends on: Task 1, Task 3, Task 7, Task 8, Task 9.
  Wire everything together per the design doc's "ESC / gamepad Start behavior
  resolution" and "Persistence" sections (both contain literal code the design
  doc wants followed closely — read them directly rather than relying on this
  summary):
  - Add module-local `settings` (a `SettingsScene` instance) and reference
    `SettingsState` (the singleton), alongside the existing `manager` module-local.
  - In `love.load()`: `if Save.settings_exists() then
    SettingsState:apply_save(Save.read_settings()) end` then
    `love.window.setFullscreen(SettingsState.fullscreen)`.
  - Rewrite `love.keypressed(key)`: if `settings.is_open`, forward to
    `settings:keypressed(key)` first and return early if it returns true
    (consumed). Then handle `key == "escape"`: if `settings.is_open`,
    `settings:close()`; elseif `manager.current and
    manager.current.esc_opens_settings`, `settings:open(false, manager.current,
    manager)`; elseif `manager.current and manager.current.escape_to_menu`,
    `manager:switch(StartScene.new(manager))`; else `love.event.quit()`. This
    replaces the current `to_save`-truthy check with the new `esc_opens_settings`
    field from Task 8 — `to_save` (the method) itself is unchanged and still used
    by `love.quit()`'s save-on-quit path and by the Settings overlay's Main Menu
    action.
  - Add new `love.gamepadpressed(joystick, button)` (none exists today anywhere in
    this repo): if `settings.is_open`, forward to `settings:gamepadpressed(button)`
    and return early if consumed; else if `button == "start"`,
    `settings:close()`; return. Outside that, if `button == "start" and
    manager.current and manager.current.esc_opens_settings`, `settings:open(false,
    manager.current, manager)`. Deliberately ignore which `joystick` fired — check
    only `button == "start"` (see design doc's "Multi-controller decision"
    paragraph for why: any connected controller's Start should open/close
    Settings).
  - Gate `love.update`/`love.draw`: while `settings.is_open`, skip
    `manager:update(dt)` (pause gameplay input polling entirely) but still call
    `settings:update(dt)`; in `love.draw`, draw `manager` first then `settings:draw()`
    on top when open, mirroring `/root/wip/main.lua`'s `settings_menu.is_open`
    gating.
  - Wire the Start Scene entry point: wherever `StartScene.new(manager)` is
    currently constructed, change to `StartScene.new(manager, function()
    settings:open(true, nil, manager) end)`.
  - `require`s `game/settings_state.lua`, `game/scenes/settings_scene.lua`, and
    the already-imported `lua/core/save.lua`.

### Wave E — depends on Task 7 (mechanical cleanup, can run once Task 7 is merged; no need to wait for Wave D)

- [x] Task 10 — `tests/test_start_scene.lua` — Depends on: Task 7. Update every
  index-dependent assertion (`selected == 3/4`, `items[3]`, etc.) to account for
  the new "Settings" item inserted before "Exit Game" — per the design doc,
  roughly 20 of the 21 existing tests shift by one index. This is purely
  mechanical renumbering, not new test logic: Exit Game moves from index 4 to
  index 5, and "Settings" occupies the old index-4 slot. Also add at least one new
  test asserting the "Settings" item exists at its new index and that selecting it
  invokes the `on_settings` callback passed to `StartScene.new(manager,
  on_settings)` (and that omitting `on_settings` — i.e. calling
  `StartScene.new(manager)` as before — doesn't error when that item is selected).
  Run the full test file after editing to confirm every assertion was caught, not
  just a sample.

---

**Note for Phase 4 (Verification Agent) — not a Phase 3 task:** The design doc's
"What changes" section notes `game_scene.lua`'s on-screen control hint text changes
(`"ESC: save & menu"` → `"ESC / Start: settings"`, done in Task 8) and this is a
user-facing controls change. Per NFF rules only the Verification Agent touches
READMEs/archive — Phase 4 should check whether any top-level README or
`docs/`-level controls reference documents the old ESC hint text or control scheme
and update it to match, as part of its normal "update affected READMEs" step, before
archiving this checklist and the design doc.
