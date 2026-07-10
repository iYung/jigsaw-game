# Controller Support

## Goal

The game currently only accepts keyboard input for gameplay
(`game/player.lua`) and keyboard + mouse for the start menu
(`game/scenes/start_scene.lua`). Both already funnel keyboard state through
the same lightweight action-mapper, `lua/core/input.lua` (`Input.new(key_map)`
→ `is_down(action)` / `pressed(action)`), which reads `love.keyboard.isDown`
each frame. There is no gamepad/joystick code anywhere in the repo today
(confirmed by search — `conf.lua` only disables the joystick module under
`--headless`).

This feature adds gamepad support by teaching `Input` to also poll
`love.joystick`/gamepad state for the same named actions, so both
`Player` and `StartScene` gain controller support for free — no scene
rewrite needed, just richer construction options.

Decisions confirmed with the user:
- Movement: D-pad **and** left analog stick both drive `up`/`down`/`left`/
  `right` (stick uses a deadzone).
- Buttons: `A` → interact/pickup-drop, `X` → rotate — LÖVE's standard
  virtual gamepad button names, so this works the same across Xbox/
  PlayStation/Switch-Pro controllers without per-brand mapping.
- Both `StartScene` (menu nav + confirm) and `GameScene` (via `Player`) get
  controller input.
- Multi-controller scope: both `StartScene` and `Player` in `GameScene`
  listen to the **first two** connected controllers
  (`love.joystick.getJoysticks()[1]` and `[2]`) — either of the first two
  pads can navigate the menu or drive the player (e.g. a second pad as a
  convenient swap/backup), while a third+ pad is ignored everywhere.

## Affected files

- `lua/core/input.lua` — core change: teach `Input` to also read gamepad
  buttons/axes for the same action names.
- `lua/headless/stubs.lua` — add a `love.joystick.getJoysticks` stub (returns
  `{}`) so headless tests don't crash once `Input:update()` calls it
  unconditionally.
- `game/constants.lua` — add `GAMEPAD_DEADZONE`.
- `game/player.lua` — pass gamepad options into its `Input.new(...)` call.
- `game/scenes/start_scene.lua` — pass gamepad options into its
  `Input.new(...)` call.
- `tests/test_input_gamepad.lua` (new) — unit tests for the new `Input`
  behavior using a fake joystick object.

## What changes

1. **`lua/core/input.lua`**: `Input.new(key_map, opts)` gains an optional
   second argument:
   ```lua
   opts = {
       gamepad_buttons = { -- action -> list of LÖVE virtual button names
           interact = { "a" },
           rotate_piece = { "x" },
           confirm = { "a" },
           up = { "dpup" }, down = { "dpdown" },
           left = { "dpleft" }, right = { "dpright" },
       },
       use_left_stick = true,      -- also drive up/down/left/right from leftx/lefty axes
       joystick_scope = "first_two", -- "first" (default if omitted), "first_two", or "any"
   }
   ```
   `Input:update()` additionally does, per action:
   - Resolves the joystick list per `joystick_scope`: `"first"` →
     `{ love.joystick.getJoysticks()[1] }`; `"first_two"` → the first two
     entries of `love.joystick.getJoysticks()`; `"any"` → the full list.
     All variants filter out any nil slots (fewer controllers connected than
     the scope allows).
   - For each joystick in scope, checks `joystick:isGamepadDown(button)` for
     every button configured for that action.
   - If `use_left_stick` and the action is `up`/`down`/`left`/`right`, also
     checks `joystick:getGamepadAxis("leftx"|"lefty")` against
     `C.GAMEPAD_DEADZONE`, treating a magnitude past the deadzone in the
     relevant direction as down.
   - The result is OR'd with the existing keyboard check — same `is_down`/
     rising-edge `pressed` semantics as today, callers don't change.
   - This is a **polling** design (checked every `update()`), matching the
     existing keyboard approach — no `love.gamepadpressed`/`joystickadded`
     callbacks needed, and hot-plug "just works" since `getJoysticks()` is
     re-queried every frame.
   - Missing/absent joystick module or zero connected controllers must be
     silent no-ops (already true of `love.joystick.getJoysticks()` returning
     `{}`).

2. **`lua/headless/stubs.lua`**: add
   ```lua
   love.joystick = love.joystick or {}
   love.joystick.getJoysticks = function() return {} end
   ```
   so any real `Input` instance created during a headless test (e.g. via
   `Player.new`/`StartScene.new`) doesn't error when `Input:update()` calls
   `love.joystick.getJoysticks()`.

3. **`game/constants.lua`**: add `GAMEPAD_DEADZONE = 0.35` alongside the
   other tunables.

4. **`game/player.lua`**: extend its existing `Input.new({...})` call with
   the `opts` table described above (`joystick_scope = "first_two"`).

5. **`game/scenes/start_scene.lua`**: extend its existing `Input.new({...})`
   call with the `opts` table (`gamepad_buttons = { up={"dpup"},
   down={"dpdown"}, confirm={"a"} }`, `joystick_scope = "first_two"`; no
   `use_left_stick` needed for a discrete up/down menu, D-pad is enough).

6. **`tests/test_input_gamepad.lua`** (new): constructs fake joystick tables
   (`{ isGamepadDown = function(...) ... end, getGamepadAxis = function(...)
   ... end }`), monkey-patches `love.joystick.getJoysticks` to return a list
   of them (restoring the stub afterward), and asserts `Input:is_down`/
   `pressed` reflect button presses and stick-axis deadzone crossing
   correctly for all three `joystick_scope` modes — in particular for
   `"first_two"` (used by both scenes), a press from controller 1 or 2
   registers but a press from a 3rd controller does not.

## What stays the same

- `Input`'s keyboard behavior, `is_down`/`pressed` semantics, and its public
  interface for existing callers are unchanged when `opts` is omitted —
  `opts` is optional, so any future/other `Input.new(map)` call site with no
  second argument behaves exactly as it does today.
- `lua/headless/input.lua` (`HeadlessInput`) is untouched — it's a scriptable
  test double for injecting actions directly and has nothing to do with real
  `love.joystick` polling.
- `StartScene`'s and `Player`'s mouse/keyboard code paths are untouched;
  controller input is additive (OR'd with existing checks), not a
  replacement.
- No on-screen controller-vs-keyboard prompt/icon swapping — out of scope
  for this pass.
- `conf.lua`'s existing `t.modules.joystick = false` under `--headless` is
  unaffected; headless tests never touch the real joystick module, they use
  the new stub instead.

## Open questions

None outstanding — movement mapping, button mapping, menu scope, and
multi-controller scope were all confirmed with the user before writing this
doc.
