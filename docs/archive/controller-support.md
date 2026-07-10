# Controller Support Checklist

- [x] Task A — `game/constants.lua` — Add `GAMEPAD_DEADZONE = 0.35` alongside
      the other tunables, exported in the returned table.

- [x] Task B — `lua/headless/stubs.lua` — Add a `love.joystick.getJoysticks`
      stub returning `{}` (mirroring the existing `love.keyboard.isDown`
      stub style), so any real `Input` instance created during a headless
      test doesn't error once `Input:update()` unconditionally calls
      `love.joystick.getJoysticks()`.

- [x] Task C — `lua/core/input.lua` — Extend `Input.new(key_map)` to accept
      an optional second `opts` argument:
      `opts = { gamepad_buttons = { action = {button_names...} },
      use_left_stick = bool, joystick_scope = "first" | "first_two" | "any" }`.
      In `Input:update()`, for each action also check gamepad state (OR'd
      with the existing keyboard check):
      - Resolve the joystick list per `joystick_scope` (default `"first"`
        when `opts` or `opts.joystick_scope` is omitted): `"first"` →
        `{ love.joystick.getJoysticks()[1] }`; `"first_two"` → the first two
        entries; `"any"` → the full list. Filter out nil slots.
      - For each joystick in scope, check `joystick:isGamepadDown(button)`
        for every button configured for that action in
        `opts.gamepad_buttons[action]`.
      - If `opts.use_left_stick` and the action is `up`/`down`/`left`/
        `right`, also check `joystick:getGamepadAxis("leftx"|"lefty")`
        against `C.GAMEPAD_DEADZONE` (requires `require("game/constants")`
        in this file).
      - Preserve existing `is_down`/`pressed` rising-edge semantics exactly;
        behavior with `opts` omitted must be identical to today (no
        regression for any future keyboard-only caller).

- [x] Task D — `game/player.lua` — Extend the existing `Input.new({...})`
      call with the `opts` table: `gamedpad_buttons` mapping
      `up/down/left/right` to `dpup/dpdown/dpleft/dpright`, `interact` to
      `{"a"}`, `rotate_piece` to `{"x"}`; `use_left_stick = true`;
      `joystick_scope = "first_two"`.

- [x] Task E — `game/scenes/start_scene.lua` — Extend the existing
      `Input.new({...})` call with the `opts` table: `gamepad_buttons`
      mapping `up/down` to `dpup/dpdown`, `confirm` to `{"a"}`;
      `joystick_scope = "first_two"` (no `use_left_stick` needed — D-pad is
      enough for a discrete menu cursor).

- [x] Task F — `tests/test_input_gamepad.lua` (new file) — Unit tests for
      `lua/core/input.lua`'s new gamepad behavior: build fake joystick
      tables (`{ isGamepadDown = ..., getGamepadAxis = ... }`), monkey-patch
      `love.joystick.getJoysticks` to return them (restore afterward), and
      assert `Input:is_down`/`pressed` correctly reflect: (1) a mapped
      button press, (2) left-stick axis crossing the deadzone in each
      direction, (3) `"first"` vs `"first_two"` vs `"any"` scope
      differences (a press from controller 2 registers under `"first_two"`
      and `"any"` but not `"first"`; a press from controller 3 registers
      under `"any"` only), (4) `opts` omitted preserves current
      keyboard-only behavior exactly.
