# Two Player Support Checklist

Design doc: `docs/design/two-player-support.md`

All tasks below are independently completable in parallel — every
cross-file contract (function names/signatures, field names, device
descriptor shape) is fixed by this checklist, so no task needs to read
another task's actual code to conform to it. Every task touches a
distinct file, so there are no edit conflicts either.

## Fixed contracts (read this before starting any task)

- **Device descriptor**: `nil` (default merged input), `{ type = "keyboard" }`,
  or `{ type = "gamepad", index = 1 }` / `{ type = "gamepad", index = 2 }`.
  `index` is 1-based into `love.joystick.getJoysticks()`.
- **`Player.build_input(device)`** (new module function in `game/player.lua`,
  alongside the existing `Player.new`): given a device descriptor (or `nil`),
  returns an `Input` instance:
  - `nil` → exactly today's default merged Input (keyboard + first-two
    gamepads, `use_left_stick = true`).
  - `{ type = "keyboard" }` → the same keyboard `key_map` as the default,
    but `opts = nil` (no gamepad opts at all, so no controller can drive
    this player).
  - `{ type = "gamepad", index = N }` → `key_map` with an **empty** array
    for every action (`up = {}`, `down = {}`, etc. — so no keyboard key
    ever triggers it), `opts = { gamepad_buttons = <same as default>,
    use_left_stick = true, joystick_scope = N }` (the new numeric scope
    from Task A, scoping to exactly controller `N`).
- **`Player.new(x, y, input)`**: `input` is optional. Internally:
  `self.input = input or Player.build_input()`. When omitted, behavior is
  byte-for-byte unchanged from today.
- **`ControllerSelectScene.new(manager, save_data)`**: `save_data` is
  optional (nil for a fresh New Game, the saved scene table when
  continuing). Sets `self.escape_to_menu = true`.
- **`GameScene.new(save_data, input_assignments)`**: `input_assignments`
  is optional: `{ p1 = <Input or nil>, p2 = <Input or nil> }`.

- [x] Task A — `lua/core/input.lua` — In the local `scoped_joysticks(scope)`
  function, add a branch for `type(scope) == "number"`: return
  `{ sticks[scope] }` if `sticks[scope]` exists, else `{}` (empty, no
  error, if that controller isn't connected). Keep the existing
  `"any"` / `"first_two"` / default(`"first"`) string branches exactly as
  they are — this is purely an additional accepted shape for
  `opts.joystick_scope`, e.g. `joystick_scope = 2` now means "exactly
  the 2nd connected joystick," independent of the string modes. No other
  function in this file changes; `Input.new`, `:update`, `:is_down`,
  `:pressed` keep their exact current signatures and behavior.

- [x] Task B — `game/player.lua` — Extract the `Input.new(...)` call
  currently inline in `Player.new` into a new exported function
  `Player.build_input(device)`, implementing the three cases from the
  "Device descriptor" contract above (`nil`, `{type="keyboard"}`,
  `{type="gamepad", index=N}`). The gamepad case's `key_map` needs an
  empty array per action (`up = {}, down = {}, left = {}, right = {},
  interact = {}, rotate_piece = {}`) — reuse the same action names the
  default map already uses. The keyboard case reuses the exact same
  keyboard `key_map` table shape as the default (same keys per action).
  Change `Player.new(x, y, input)` to accept the new optional third
  param and set `self.input = input or Player.build_input()`. Nothing
  else in this file (`update`, `draw`, `centre`, `drop_target`) changes.
  Since `Player.build_input(nil)` must reproduce today's exact behavior,
  do not change the default `key_map`/`gamepad_buttons` values already
  hardcoded here — just relocate them into the new function.

- [x] Task C — `game/scenes/controller_select_scene.lua` (new file) —
  Build against Task A's numeric `joystick_scope` and Task B's
  `Player.build_input` contracts directly (no need to read either file).
  - `require("lua/core/scene")`, `require("lua/core/input")`,
    `require("game/scenes/game_scene")`, `require("game/player")`.
  - `ControllerSelectScene.new(manager, save_data)`: per the fixed
    contract above (stores `self.manager`, `self._save_data`, sets
    `self.escape_to_menu = true`), plus `self.p1_device = nil`,
    `self.p2_device = nil`.
  - `on_enter()`: build `self._sources`, a list built from
    `love.joystick.getJoysticks()` (first two only, mirroring the
    `"first_two"` convention used elsewhere in this codebase):
    - Always include one entry:
      `{ device = { type = "keyboard" }, label = "Keyboard",
         input = Input.new({ left = {"a","left"}, right = {"d","right"},
                              confirm = {"e","return"} }, nil) }`
    - For each connected joystick index `i` in `1, 2`: append
      `{ device = { type = "gamepad", index = i }, label = "Controller "..i,
         input = Input.new({ left = {}, right = {}, confirm = {} },
           { gamepad_buttons = { left = {"dpleft"}, right = {"dpright"},
             confirm = {"a"} }, use_left_stick = true, joystick_scope = i }) }`
  - `update(dt)`: call `:update()` on every `self._sources[*].input`. For
    each source, compare `source.device` to `self.p1_device`/
    `self.p2_device` by value (same `type`, and same `index` when
    `type == "gamepad"`) — not by table identity. If
    `source.input:pressed("left")` and the source's device does not
    equal `self.p2_device`, set `self.p1_device = source.device`.
    Symmetrically, if `pressed("right")` and the device does not equal
    `self.p1_device`, set `self.p2_device = source.device`. If
    `pressed("confirm")` on any source and both `self.p1_device` and
    `self.p2_device` are set, call `self:_confirm()`.
  - `_confirm()`: `local p1_input = Player.build_input(self.p1_device)`,
    `local p2_input = Player.build_input(self.p2_device)`, then
    `self.manager:switch(GameScene.new(self._save_data, { p1 = p1_input,
    p2 = p2_input }))`.
  - `draw()`: three columns over the scene's `1280x720` logical canvas
    (reuse the `Scene.new(1280, 720)` sizing convention from
    `start_scene.lua`). Left column shows "Player 1" and the current
    `self.p1_device`'s label (or a placeholder like `"-"` when nil).
    Right column mirrors this for Player 2. Middle column lists every
    `self._sources[*].label` as a legend. Include a one-line hint like
    "P1: press Left to claim   P2: press Right to claim   Confirm to
    start". Reuse `start_scene.lua`'s color-box rendering style
    (`NORMAL_COLOR`/`SELECTED_COLOR`-style rectangles) for visual
    consistency; define local color constants here rather than requiring
    `start_scene.lua`.
  - `on_exit()`: no-op (or call `Scene.on_exit(self)` if this scene ends
    up owning drawer content — match whatever `game_scene.lua`'s own
    `on_exit` override does for consistency with how this codebase
    forwards to `Scene`).

- [x] Task D — `game/scenes/start_scene.lua` — Add
  `local ControllerSelectScene = require("game/scenes/controller_select_scene")`.
  In `_confirm()`, selected == 1 branch (New Game): after
  `GameState:reset()` and `GameState.player_count = self.player_count`,
  branch on `self.player_count`: if `2`, switch to
  `ControllerSelectScene.new(self.manager)`; else (today's `1` case)
  switch to `GameScene.new()` exactly as today. Selected == 2 branch
  (Continue): after `GameState:apply_save(data.game_state)`, branch on
  the now-restored `GameState.player_count`: if `2`, switch to
  `ControllerSelectScene.new(self.manager, data.scene)`; else switch to
  `GameScene.new(data.scene)` exactly as today. No other changes to this
  file — menu items, toggle logic, navigation all stay as they are.

- [x] Task E — `game/scenes/game_scene.lua` — Change
  `function GameScene.new(save_data)` to
  `function GameScene.new(save_data, input_assignments)` and store
  `self._input_assignments = input_assignments`. In `on_enter()`, change
  the `self.player = Player.new(0, GROUND_Y - C.SLOT)` construction to
  pass the P1 override:
  `Player.new(0, GROUND_Y - C.SLOT, self._input_assignments and
  self._input_assignments.p1)` (this is the line that runs regardless of
  `self._save_data`, before the save-restore block overwrites
  `self.player.sprite.x/y` — keep that restore logic exactly as-is, just
  construct with the extra arg). After the existing `if self._save_data
  ... else ... end` block that finishes positioning `self.player` (i.e.
  once `self.player.sprite.x`/`.y` hold their final spawn-or-restored
  values), add: if `GameState.player_count == 2`, construct
  `self.player2 = Player.new(self.player.sprite.x + C.SLOT,
  self.player.sprite.y, self._input_assignments and
  self._input_assignments.p2)` and `self.drawer:add(self.player2, 10)`
  (same priority `self.player` uses). In `update(dt)`, immediately after
  the existing `self.player:update(dt, self.pieces, self.boxes,
  self.pile, self.drawer)` call, add: `if self.player2 then
  self.player2:update(dt, self.pieces, self.boxes, self.pile,
  self.drawer) end`. Immediately after the existing world-bounds clamp
  for `self.player.sprite.x`/`.y`, add the same two clamp lines for
  `self.player2` (guarded by `if self.player2 then ... end`), using the
  same `self.world_w`/`self.world_h`/`C.SLOT` bounds. Do not touch
  `self.camera:follow(...)` (still follows `self.player` only), and do
  not touch `to_save()` (player 2 is never persisted, per the design
  doc).

- [x] Task F — `main.lua` — In `love.keypressed`, add a branch between
  the existing `manager.current.to_save` branch and the final `else`:
  ```lua
  elseif manager.current and manager.current.escape_to_menu then
      manager:switch(StartScene.new(manager))
  ```
  so a scene with `escape_to_menu = true` (set by
  `ControllerSelectScene.new`, per Task C) returns to the start menu on
  Escape without saving. No other changes to this file.

- [x] Task G — `tests/test_input_gamepad.lua` — Add coverage for the new
  numeric `joystick_scope` (Task A), following this file's existing
  `with_joysticks`/`fake_stick` pattern: (1) `joystick_scope = 1` with
  two connected controllers registers a press on controller 1 but not
  controller 2; (2) `joystick_scope = 2` registers a press on controller
  2 but not controller 1; (3) `joystick_scope = 2` with only one
  controller connected registers nothing and does not error (empty
  joystick list for that scope, not a crash).

- [x] Task H — `tests/test_controller_select_scene.lua` (new file) —
  Using the `lua/headless` stubs/runner pattern already used by this
  test suite (see other test files for `love.keyboard`/joystick
  stubbing), cover: (1) with zero controllers connected, only the
  Keyboard source exists; with one/two connected, the corresponding
  Controller N source(s) also exist. (2) A keyboard "left" press sets
  `self.p1_device` to `{ type = "keyboard" }`; a controller-1 "right"
  press (via a faked joystick, `dpright` down) sets `self.p2_device` to
  `{ type = "gamepad", index = 1 }`. (3) Once `self.p2_device` is
  claimed by a given device, that same device pressing "left" does not
  change `self.p1_device` (overlap rejected) — but a *different* device
  pressing "left" still claims P1 normally. (4) Pressing "confirm" does
  nothing (`manager.current` stays this scene — or track via a spy on
  `manager:switch`) while either `p1_device` or `p2_device` is still
  nil; once both are set, "confirm" calls `manager:switch` with a
  `GameScene` instance. (5) A fresh `ControllerSelectScene.new(manager)`
  has `escape_to_menu == true`.

- [x] Task I — `tests/test_start_scene.lua` — Add coverage: (1) New Game
  confirm with the "Players" toggle left at `1` still switches
  `manager.current` to a `GameScene` (regression check against Task D's
  change). (2) New Game confirm with the toggle set to `2` switches
  `manager.current` to a `ControllerSelectScene` instead of a
  `GameScene`. (3) Continue confirm where the loaded save's
  `game_state.player_count == 1` still switches to `GameScene` with the
  save's scene data (regression). (4) Continue confirm where the loaded
  save's `game_state.player_count == 2` switches to
  `ControllerSelectScene` (verify the save's scene data was threaded
  through — e.g. that the resulting scene's stored `_save_data` matches
  what `Save.read()` returned, however this test file already asserts
  save-data threading for the existing `GameScene` Continue case).

- [x] Task J — `tests/test_player.lua` (new file) — Cover
  `Player.build_input` (Task B) directly, using the
  `with_joysticks`/`fake_stick` pattern from `tests/test_input_gamepad.lua`:
  (1) `Player.build_input(nil)` (and `Player.new(x, y)` with no third
  arg) produce an `Input` that still responds to both keyboard keys and
  a first-connected controller's mapped buttons — i.e. unchanged from
  today's default. (2) `Player.build_input({ type = "keyboard" })`
  responds to keyboard keys but a mapped press on a connected
  controller does *not* register. (3)
  `Player.build_input({ type = "gamepad", index = 2 })`, with two fake
  controllers connected, registers a mapped press on controller 2 but
  not controller 1 and not any keyboard key press.
