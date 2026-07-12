# Settings Menu

## Goal

Add a Settings menu with two controls — a fullscreen toggle and keyboard keybind
remapping — reachable both from the Start Scene (as a new menu item) and from
inside a running game (ESC opens it as a pause overlay). No sound/volume
settings: this repo has no `Sound` module (`grep -rn "lua/core/sound\|Sound\."`
returns nothing outside `/root/wip`), and none is being added for this
feature. Visual style matches the existing plain rectangle/text menu look
(`game/scenes/start_scene.lua`'s `NORMAL_COLOR`/`SELECTED_COLOR` rows) — no
image assets, since none of `/root/wip`'s `menu_btn.png`-style art exists in
this repo.

`/root/wip/lua/game/scenes/settings_menu.lua` and
`/root/wip/lua/game/settings_state.lua` are used only as a behavioral
reference (menu structure, keybind-capture flow, duplicate-key rejection,
opaque-vs-overlay dual mode). The actual implementation looks quite different
because jigsaw-game's architecture differs from wip's in two load-bearing
ways:

1. **No shared global `Input`.** wip has one process-lifetime `input` object
   (`lua/game/input.lua`) whose `_map` is rebuilt in place on every rebind.
   jigsaw-game instead constructs a fresh `lua/core/input.lua` `Input`
   instance per scene, and per-player in 2P
   (`game/player.lua:14-65`'s `Player.build_input`,
   `game/scenes/start_scene.lua:29-44`,
   `game/scenes/controller_select_scene.lua:52-77`). Rebinding has to reach
   into whichever `Input` instances are currently live, not one singleton.
2. **No settings/session singleton convention beyond `game/game_state.lua`.**
   jigsaw-game's existing precedent for "one process-lifetime piece of state
   every scene can `require` directly" is `GameState` (`game/game_state.lua`,
   returned as `GameState.new()` — a singleton instance, not a class table).
   The new `SettingsState` follows that exact pattern instead of wip's
   constructor-injected `SettingsState.new()` + threading through every
   scene's constructor.

## Affected files

**New:**
- `game/settings_state.lua` — new singleton, modeled on `game/game_state.lua`
  (`:reset()`, `:to_save()`, `:apply_save(data)` naming/shape). Holds
  `fullscreen` (bool) and `keybinds` (table: action → single key string, for
  exactly the six actions `game/player.lua`'s `Player.build_input` uses:
  `up, down, left, right, interact, rotate_piece` — the real gameplay action
  set, confirmed via `grep -n "Input.new(" game/scenes/*.lua game/player.lua`).
- `game/scenes/settings_scene.lua` — the menu/overlay object. **Not** a
  `lua/core/scene.lua` subclass and never passed to `SceneManager:switch` —
  see "opaque vs overlay" below for why. Exposes `:open(opaque)`, `:close()`,
  `.is_open`, `:update(dt)`, `:draw()`, `:keypressed(key)` (returns
  true/consumed like wip's version, for rebind-capture and the "all bound"
  gate), `:gamepadpressed(button)` (returns true/consumed the same way, for
  the keybind subscreen's confirm/nav — see "Menu-chrome navigation" below).
  Internally owns its own `lua/core/input.lua` `Input` instance for
  up/down/confirm row navigation, built the same way `StartScene` builds its
  menu-nav `Input` — this repo has **zero** existing `love.gamepadpressed`
  handling anywhere (`grep -rn "gamepadpressed\|gamepressed\|joystickpressed"
  main.lua lua/core/*.lua game/scenes/*.lua` returns nothing today), so this
  doc has to specify the mechanism from scratch rather than point at an
  existing pattern for the *open/close* trigger specifically (menu-row nav
  *within* an already-open Settings screen does follow `StartScene`'s
  existing pattern directly).
- `tests/test_settings_state.lua` — construction defaults, `toggle_fullscreen`,
  `set_keybind`, `key_map()` shape, `to_save`/`apply_save` round-trip
  (matching `tests/test_save.lua`'s in-memory-`love.filesystem` stub pattern).
- `tests/test_settings_scene.lua` — navigation, opaque-vs-overlay visible
  items, rebind-capture flow incl. duplicate rejection, "all bound" gate
  (matching `tests/test_start_scene.lua`'s `tap()`/`with_joysticks()` helpers).

**Modified:**
- `main.lua` — owns one `SettingsState`/`SettingsScene` pair (module-locals,
  like the existing `manager`), loaded/applied in `love.load()`; ESC handling
  in `love.keypressed` rewritten (see below); gains a **new**
  `love.gamepadpressed(joystick, button)` function (none exists today — see
  below) so a gamepad Start press can open/close Settings the same way ESC
  does; `love.update`/`love.draw` gain an open-settings branch, mirroring
  `/root/wip/main.lua`'s `settings_menu.is_open` gating of
  `scene_manager:update`/`:draw`.
- `game/scenes/start_scene.lua` — new "Settings" item; `StartScene.new`
  gains an optional `on_settings` callback param.
- `game/scenes/game_scene.lua` — gains `self.esc_opens_settings = true`;
  on-screen control hint text updated.
- `game/player.lua` — `Player.build_input`'s keyboard-driven branches read
  keys from `SettingsState:key_map()` instead of hardcoded lists.
- `lua/core/save.lua` — three new functions for a second, independent save
  file (`Save.settings_exists`, `Save.write_settings`, `Save.read_settings`),
  parallel to the existing `save.dat` trio.
- `tests/test_start_scene.lua` — every index-dependent assertion
  (`selected == 3/4`, `items[3]`, etc. — roughly 20 of the 21 tests) shifts by
  one once "Settings" is inserted into the item list. Purely mechanical, but
  wide-reaching; called out explicitly for the checklist phase.

## What changes

### SettingsState (`game/settings_state.lua`)

A singleton, `require`d directly wherever needed (no constructor threading),
exactly like `GameState`:

```lua
function SettingsState:toggle_fullscreen()   -- flips .fullscreen, calls love.window.setFullscreen
function SettingsState:set_keybind(action, key)
function SettingsState:key_map()             -- {action = {key}} shape for Input.new
function SettingsState:to_save()             -- {version=1, fullscreen=, keybinds=}
function SettingsState:apply_save(data)      -- mirrors GameState:apply_save's version-gate + reset-on-mismatch
function SettingsState:reset()               -- test isolation, same purpose as GameState:reset()
```

Default keybinds: `up=w, down=s, left=a, right=d, interact=e, rotate_piece=r`
— today's primary keys. **Behavior change worth flagging:** today's keyboard
`Input.new` calls bind *two* keys per movement action (e.g.
`up = {"w", "up"}`, arrow keys work alongside WASD — see
`game/player.lua:17-20`). A single rebindable key per action (matching wip's
model, and required for a sane "press a key to rebind" UI / duplicate-key
check) replaces that dual binding. Arrow-key movement stops working by
default; WASD/E/R remain the defaults and are rebindable. Gamepad bindings
(`opts.gamepad_buttons`) are untouched and not remappable — only keyboard
keys go through the keybind UI, matching wip (whose own subscreen is
keyboard-only and hides the Keybinds row entirely in gamepad mode).

**Why only these six actions are remappable:** `StartScene`'s own menu-nav
`Input` (`up/down/left/right/confirm`, `start_scene.lua:29-44`) and
`ControllerSelectScene`'s (`left/right/confirm`,
`controller_select_scene.lua:52-77`) stay hardcoded. Making menu navigation
itself remappable would let a bad rebind lock a player out of every menu,
including the Settings menu used to undo it — wip sidesteps this because its
menu-nav and gameplay share the same physical keys by construction; this repo
doesn't share that structure, so the safer, simpler choice is: only gameplay
actions are remappable, menu chrome never is.

### Wiring rebinds into live `Input` instances

`game/player.lua`'s `Player.build_input(device)`, for the `device == nil` and
`device.type == "keyboard"` branches only, builds its key lists from
`SettingsState:key_map()` instead of literals, and tags the returned
`Input` with `inp._keyboard_rebindable = true`. The gamepad-only branch is
untouched and never tagged.

When a rebind is confirmed inside the Keybinds subscreen (in-game overlay
context only — the Settings menu opened opaquely from the Start Scene has no
live `Player` to touch), `settings_scene.lua` reaches into
`scene_manager.current` (passed to `:open()`) and does, for each of
`.player`/`.player2` that exist and whose `.input._keyboard_rebindable` is
true:

```lua
scene.player.input._map = SettingsState:key_map()
```

The `_keyboard_rebindable` tag exists specifically to prevent a bug: in 2P
split-screen, a gamepad-assigned `player2.input` is built with **empty**
keyboard key lists (`up = {}`, etc. — see
`game/player.lua:46-51`) but `lua/core/input.lua:80-97`'s `Input:update()`
still checks `love.keyboard.isDown` for *every* action in `_map` regardless
of device. Blindly overwriting `_map` on every live player would silently
hand keyboard control to a controller-assigned player. Rebuilding `_map` only
where `_keyboard_rebindable == true` avoids that.

### Settings scene/overlay (`game/scenes/settings_scene.lua`)

Not a `Scene` — a persistent object main.lua owns and draws *on top of*
whatever `SceneManager.current` is, for both entry points, mirroring
`/root/wip/main.lua`'s `settings_menu` (drawn after `sm:draw()`, updated
instead of the scene manager while open). This sidesteps
`lua/core/scene.lua:24-26`'s `on_exit` clearing `self.drawer` — switching
*away* from a live `GameScene` to open Settings would tear down all its
puzzle/piece state, which a pause overlay must not do.

Items, plain-rectangle style like `StartScene`:
- **Fullscreen** — toggle, label flips "Fullscreen"/"Window" like wip.
- **Keybinds** — enters the remap subscreen (6 rows: Up/Down/Left/
  Right/Interact/Rotate Piece; select a row, press a key to rebind; duplicate
  key on another action triggers the shake-and-reject feedback ported from
  wip's `settings_menu.lua:320-327`; leaving the subscreen is gated on every
  action having a bound key, ported from wip's `_all_bound`, mostly defensive
  since `set_keybind` never assigns `nil`).
- **Opaque mode only** (`:open(true)`, reached from the Start Scene): a
  **Back** row that closes the overlay, returning to the still-alive
  `StartScene` beneath it.
- **Overlay mode only** (`:open()`/`:open(false)`, reached via in-game ESC):
  a **Main Menu** row that calls `GameScene:to_save()` +
  `Save.write({...})` (same shape `main.lua`'s current `_save_current`
  writes) and then `scene_manager:switch(StartScene.new(manager))` — this is
  the explicit replacement for today's instant-ESC-saves-and-leaves. No
  "Back"/"Exit Settings" row is needed here: ESC (or gamepad Start) pressed
  again already closes the overlay and resumes play, so an on-screen
  duplicate of that action would be redundant. (Opaque mode gets an explicit
  Back row instead, since it's reached by menu confirm rather than a
  dedicated hotkey, and benefits from an obvious way out.)

Background: opaque mode fills the full 1280×720 canvas with a solid color
(no patterned art, unlike wip); overlay mode draws a `(0,0,0,0.55)`
semi-transparent rect over the frozen game world, exactly like wip.

### Menu-chrome navigation (keyboard + gamepad, while Settings is open)

Moving between rows (Fullscreen/Keybinds/Back or Main Menu, and the 6 rows
inside the Keybinds subscreen) is **not** raw-polled like wip's
`_joy_nav`/`love.keyboard.isDown` helper, and it is **not** keyboard-only
either — it follows `StartScene`'s existing precedent
(`start_scene.lua:29-44`) directly: `settings_scene.lua` builds its own
`lua/core/input.lua` `Input` instance for exactly this purpose:

```lua
self.input = Input.new({
    up      = { "w", "up" },
    down    = { "s", "down" },
    confirm = { "e", "return" },
}, {
    gamepad_buttons = {
        up      = { "dpup" },
        down    = { "dpdown" },
        confirm = { "a" },
    },
    joystick_scope = "first_two",
})
```

Same keys, same `gamepad_buttons`, same `joystick_scope = "first_two"` as
`StartScene`'s own menu `Input` — deliberately identical, so a controller
that can navigate the Start Scene can navigate Settings with no surprises.
`"first_two"` (`lua/core/input.lua:25-27`) means either of the first two
connected joysticks can move the cursor and confirm, matching how the
pre-game Start Scene already lets either an as-yet-unassigned P1 or P2
controller drive its menu before `ControllerSelectScene` assigns them to
specific slots. This `Input` instance is reused for both the top-level item
list and the Keybinds subscreen's row list (`self._subscreen` just changes
which list `self.selected`/`self.input` indexes into) — `self.input:update()`
runs every frame `settings:update(dt)` runs, same as any other scene.

This `Input` instance deliberately does **not** include an escape/close
action — closing Settings (keyboard ESC or gamepad Start) is handled
one level up, by `main.lua`'s global callbacks (next section), the same way
`StartScene` itself has no "quit" action in its own `Input` and instead
relies on `main.lua`'s `love.keypressed` for that. Keeping "move the cursor"
and "leave the screen" on two different mechanisms, in both `StartScene` and
`settings_scene.lua`, avoids duplicating edge-detection state for the same
key/button in two places.

Raw key capture for the Keybinds subscreen's "press a key to rebind" step is
the one place that *doesn't* go through this `Input` instance — it needs the
literal key that was pressed (any key, not a named action), so it stays on
`settings:keypressed(key)` receiving the raw `love.keypressed` event
directly, exactly as scoped in "Wiring rebinds into live `Input` instances"
above. Gamepad rebinding isn't a thing here (gamepad bindings are fixed, see
"What stays the same"), so `settings:gamepadpressed(button)` only ever needs
to feed `self.input`-style edge detection for nav/confirm on the Keybinds
row list, never a capture step.

### ESC / gamepad Start behavior resolution (`main.lua`)

Today: ESC either saves+returns-to-menu if `manager.current.to_save` is
truthy (`GameScene`), or checks `escape_to_menu`
(`ControllerSelectScene`), or quits (`StartScene`) — `main.lua:70-81`. There
is no gamepad equivalent at all today — no `love.gamepadpressed` is defined
anywhere in this repo, so opening Settings from a controller needs a new
callback, not just a new branch in an existing one.

New:

```lua
function love.keypressed(key)
    if settings.is_open then
        if settings:keypressed(key) then return end
    end
    if key == "escape" then
        if settings.is_open then
            settings:close()
        elseif manager.current and manager.current.esc_opens_settings then
            settings:open(false, manager.current, manager)
        elseif manager.current and manager.current.escape_to_menu then
            manager:switch(StartScene.new(manager))
        else
            love.event.quit()
        end
    end
end

-- New: no love.gamepadpressed exists anywhere in this repo today.
function love.gamepadpressed(joystick, button)
    if settings.is_open then
        if settings:gamepadpressed(button) then return end
        if button == "start" then settings:close() end
        return
    end
    if button == "start" and manager.current and manager.current.esc_opens_settings then
        settings:open(false, manager.current, manager)
    end
end
```

`GameScene` sets `self.esc_opens_settings = true` (new field) instead of
relying on `to_save` for this branch. `to_save` (the method) is unchanged and
still used by `love.quit()`'s existing save-on-quit path and now also by the
Settings overlay's Main Menu action. `ControllerSelectScene`'s
`escape_to_menu` path and `StartScene`'s quit-on-ESC are untouched — gamepad
Start mirrors ESC exactly: it only opens Settings from `GameScene`
(`esc_opens_settings == true`), never from the Start Scene or
`ControllerSelectScene`, and does nothing new there.
`game_scene.lua`'s on-screen hint (`"ESC: save & menu"`) is updated to
`"ESC / Start: settings"`, reflecting both input methods now open the same
overlay.

**Multi-controller decision (the couch-co-op gap):** `love.gamepadpressed(joystick,
button)` is LÖVE's own per-joystick event callback — it fires once per
physical controller's button press, and jigsaw-game's handler above
deliberately ignores *which* `joystick` argument it received, checking only
`button == "start"`. This means **any** connected controller's Start button
opens/closes Settings, including a gamepad-only Player 2's — there is no
`joystick_scope`/index filtering on this specific check, unlike
`Input.new`'s `joystick_scope` option (`lua/core/input.lua:16-31`), which
scopes *action polling* to specific joystick slots (P1 vs. P2's assigned
controller, via `ControllerSelectScene`'s `device.index` —
`controller_select_scene.lua:83-87`, `game/player.lua:44-63`). Pausing the
whole game is a different kind of action than "move Player 2" — it doesn't
belong to either player specifically, so it isn't run through a
per-player-scoped `Input` instance at all; it's a raw, unscoped event check.
This is also why wip's own approach — tracking one `self._input._joystick`
reference and polling `joy:isGamepadDown("start")` against just that single
joystick — isn't ported here: wip's version can only ever react to *one*
connected controller's Start button (whichever last claimed
`input._joystick`), which would silently fail to open Settings for a second
controller in jigsaw-game's actual 2P mode. Using LÖVE's per-joystick
`love.gamepadpressed` callback instead of a single tracked reference avoids
that limitation for free.

Once Settings is open, both players' in-game `Input` polling is paused
regardless of who opened it (`main.lua`'s `love.update` skips
`manager:update(dt)` entirely while `settings.is_open`, per "Settings
scene/overlay" above) — so which controller's Start button opened the
overlay has no bearing on who can navigate it once it's open: `first_two`
scoping on `settings_scene.lua`'s own `Input` (previous section) already
lets either controller drive the menu from there.

### Start Scene entry point

`StartScene.new(manager, on_settings)` — `on_settings` optional/nil-safe (so
every existing `StartScene.new(manager)` call in `tests/test_start_scene.lua`
keeps constructing correctly; selecting the new item with `on_settings == nil`
is a no-op). `main.lua` supplies
`function() settings:open(true, nil, manager) end`. New item order:
`{"New Game", "Continue", "Players: N", "Settings", "Exit Game"}` — inserted
before Exit Game so Exit Game stays the last, most-final item, consistent
with it being the "point of no return." This shifts Exit Game from index 4 to
5 and Settings occupies the old Exit Game slot (4); the `_next_selectable`
skip-logic (`start_scene.lua:59-66`, currently hardcoding "skip index 2 if no
save") is untouched — it already parameterizes over `#self.items`, so a 5th
item needs no logic change, only the many index-literal test assertions do.

### Persistence (`lua/core/save.lua`)

A second, independent file, `settings.dat`, written/read the same way
`save.dat` already is (reusing the same private `serialize()`):

```lua
function Save.settings_exists() ... end   -- getInfo("settings.dat")
function Save.write_settings(data) ... end
function Save.read_settings() ... end
```

Kept separate from `save.dat` rather than added as a new top-level key
inside it: settings (fullscreen, keybinds) are meaningful with or without an
in-progress game, must survive "New Game" resetting `GameState`, and must
survive a player deleting their save to start fresh. Mixing it into
`save.dat`'s `{game_state=, scene=}` shape would also touch every existing
`tests/test_save.lua` assertion about that shape for no benefit. `main.lua`'s
`love.load()` does:

```lua
if Save.settings_exists() then SettingsState:apply_save(Save.read_settings()) end
love.window.setFullscreen(SettingsState.fullscreen)
```

and writes it out whenever it changes (on fullscreen toggle and on each
successful rebind — cheap, infrequent, avoids a separate "Save Settings"
menu item like wip has, which this simpler menu doesn't need).

## What stays the same

- No sound/volume settings, no `Sound` module, no new asset files.
- `GameScene`'s save-game format/shape (`save.dat`) is untouched.
- `ControllerSelectScene`'s `escape_to_menu` behavior, and `StartScene`'s
  quit-on-ESC behavior, are untouched.
- Gamepad button bindings are fixed/not remappable; only keyboard keys go
  through the Keybinds subscreen.
- `lua/core/input.lua` itself is unchanged — no new concept added there;
  rebinding works entirely by replacing `Input._map` from the outside, the
  same mechanism wip already uses.
- `lua/core/scene.lua`/`lua/core/scene_manager.lua` are unchanged — the
  Settings overlay deliberately stays outside the `Scene`/`SceneManager`
  lifecycle rather than extending it.
- `--headless` test runs are unaffected beyond the new test files:
  `main.lua`'s headless branch returns before `love.keypressed`/`love.load`
  are ever defined (same pre-existing gap `docs/archive/design/escape-save-menu.md`
  already notes for ESC-handling test coverage), so `main.lua`'s ESC-wiring
  and new `love.gamepadpressed` changes get no direct test coverage, same as
  today — `settings_scene.lua`'s own `:gamepadpressed(button)` method is
  still directly unit-testable in `tests/test_settings_scene.lua` (matching
  how `tests/test_start_scene.lua` already drives `StartScene`'s `Input`
  through fake joysticks via `with_joysticks()`), only the two one-line
  `main.lua` callbacks that forward into it are not.

## Open questions

None blocking.

- **Dropping default arrow-key movement** (previously flagged here) —
  **confirmed by the user.** Arrow keys stop moving the player by default;
  WASD/E/R remain the defaults and are rebindable, as described in
  "SettingsState" above.
- **`tests/test_start_scene.lua` index churn.** Inserting "Settings" before
  "Exit Game" shifts ~20 existing index-literal assertions by one. This is
  mechanical (not ambiguous) but sizable enough to call out rather than have
  it discovered mid-checklist.
- **Controller support (previously underspecified, now addressed).** Menu-
  chrome navigation, the new `love.gamepadpressed` open/close trigger, and
  the multi-controller ("any connected gamepad's Start button") decision are
  now fully specified in "Menu-chrome navigation" and "ESC / gamepad Start
  behavior resolution" above.
