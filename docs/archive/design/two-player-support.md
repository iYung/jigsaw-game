# Two Player Support

## Goal

Turn the existing "Players: 1/2" start-menu toggle (UI + state only, from the
prior ticket) into actual 2-player gameplay. When 1 player is selected,
behavior is unchanged: go straight into the game scene, controlled by
keyboard or gamepad (merged, as today). When 2 players are selected, first
go into a new controller-select scene where each player independently
claims an input device — Keyboard, Controller 1, or Controller 2 — then
confirms to start the game with two characters, each exclusively driven by
their claimed device. Player 2 spawns one grid cell to the right of player
1; no other two-player gameplay mechanic (splitscreen, distinct sprite,
independent save state) is in scope.

## Affected files

- `lua/core/input.lua` — `scoped_joysticks(scope)` gains support for a
  numeric `scope` (e.g. `joystick_scope = 2`), returning exactly that
  connected joystick (1-based index into `love.joystick.getJoysticks()`),
  alongside the existing `"first"` / `"first_two"` / `"any"` string modes.
  This is what lets the game scope a single player's gameplay `Input` to
  exactly one claimed controller, distinct from another player's.
- `game/player.lua` — `Player.new(x, y, input)` gains an optional third
  param: a pre-built `Input` instance. When given, it's used instead of the
  default merged keyboard + first-two-gamepads `Input` that `Player.new`
  builds today. When omitted, behavior is byte-for-byte unchanged (every
  existing call site, including all of 1-player mode, passes nothing and
  keeps today's merged input).
- `game/scenes/controller_select_scene.lua` (new) — the device-claim
  screen. See "What changes" for the interaction model.
- `game/scenes/start_scene.lua` — `_confirm()` for "New Game" and
  "Continue": when the effective `player_count` is 2, switch to
  `ControllerSelectScene.new(...)` instead of `GameScene.new(...)`
  directly; when it's 1, behavior is unchanged (straight to `GameScene`).
- `game/scenes/game_scene.lua` — `GameScene.new(save_data, input_assignments)`
  gains an optional second param, `{ p1 = <Input>, p2 = <Input> }`. In
  `on_enter`, `self.player` is built with `input_assignments.p1` when
  present (else today's default). When `GameState.player_count == 2`,
  also construct `self.player2` one grid cell (`C.SLOT`) to the right of
  player 1's spawn position, wired through `update()`/`draw()`/the
  world-bounds clamp the same way `self.player` already is.
- `main.lua` — `love.keypressed`'s Escape handler gains a branch so
  `ControllerSelectScene` can return to the start menu on Escape without
  going through the save path (which only makes sense for `GameScene`).
- `tests/test_input_gamepad.lua` — cover the new numeric `joystick_scope`.
- `tests/test_controller_select_scene.lua` (new) — cover the claim/confirm
  logic below.
- `tests/test_start_scene.lua` — cover routing to `ControllerSelectScene`
  vs `GameScene` based on `player_count`, for both New Game and Continue.

## What changes

**Controller-select scene (2P path only).** Three columns:

- **Middle** — a legend of available devices: "Keyboard" always listed,
  plus "Controller 1" / "Controller 2" only for controllers connected when
  the scene is entered (mirrors the `"first_two"` convention already used
  elsewhere). Purely informational — not an interactive cursor/list.
- **Left** — Player 1's current claim (device name, or an unassigned
  placeholder like "—" until claimed).
- **Right** — Player 2's current claim, same treatment.

Interaction model — no cursor, no cycling:

- The scene builds three independent, single-device `Input` instances at
  `on_enter` (keyboard-only; controller-1-only via the new numeric
  `joystick_scope`; controller-2-only), each mapping `left` / `right` /
  `confirm` (keyboard: arrows + a/d + e/return; gamepad: d-pad left/right +
  left-stick + face button, matching the existing menu-input convention).
- Each frame, whichever of the three devices presses **left** becomes
  Player 1's claimed device; whichever presses **right** becomes Player
  2's. A press is rejected (no-op) if it would claim a device the *other*
  player has already claimed — e.g. once P2 has claimed Controller 1,
  Controller 1 pressing "left" does nothing until P2's claim changes.
  Re-pressing your own already-claimed device's direction, or a fresh
  device pressing the direction, simply (re)assigns that player's claim.
- Both start unassigned (no defaults). **Confirm** (from any of the three
  devices) only takes effect once both P1 and P2 have a claim; it then
  builds each player's full gameplay `Input` (the same up/down/left/right/
  interact/rotate_piece map `Player.new` uses today, scoped to exactly the
  claimed device via the new numeric `joystick_scope` for a controller, or
  keyboard-only with no gamepad opts for keyboard) and switches to
  `GameScene.new(save_data, { p1 = <input>, p2 = <input> })`.
- **Escape** returns to the start menu (does not quit, does not save —
  there's nothing to save yet).

**Start menu routing.** "New Game" with `player_count == 1` and "Continue"
restoring a save with `player_count == 1` are both unchanged (straight to
`GameScene`). "New Game" with `player_count == 2` goes to
`ControllerSelectScene.new(manager)` (fresh game, no save data). "Continue"
restoring a save with `player_count == 2` goes to
`ControllerSelectScene.new(manager, data.scene)`, threading the save's
scene data through so confirming still resumes the saved game, now with
two players.

**Game scene.** When `GameState.player_count == 2`, a second `Player` is
constructed one grid cell (`C.SLOT`) to the right of player 1's spawn
position (restored-from-save position if continuing, else the same
default spawn) and fully mirrored through the scene's update loop, draw
loop, and world-bounds clamp — same treatment `self.player` already gets,
just duplicated. The camera keeps following player 1 only; no splitscreen
or dual-camera logic.

## What stays the same

- 1-player mode end-to-end: no controller-select scene, `Player.new`'s
  default input (merged keyboard + first-two-gamepads) unchanged, single
  `Player` in `GameScene`.
- Save file shape/version: unchanged. No new persisted fields — input
  device assignments are session-only, passed directly from
  `ControllerSelectScene` to `GameScene`'s constructor, never written to
  disk. Player 2 has no independent saved position/state; it's always
  respawned one grid cell to the right of player 1's (possibly restored)
  position on scene entry.
- Player 2's appearance: identical sprite to player 1 (`assets/player.png`),
  no color/skin differentiation.
- `lua/core/input.lua`'s existing string-based `joystick_scope` modes
  (`"first"`, `"first_two"`, `"any"`) and all current callers of them.
- Start menu's layout constants, item-rect rendering, "Players: N" toggle
  itself, and the existing "Continue"-skip navigation pattern.

## Open questions

None outstanding — resolved during design:
- **Confirm step**: explicit confirm required once both players have
  claimed a device (not auto-start on both being set).
- **Device overlap**: not allowed — a claim attempt on a device the other
  player already holds is rejected.
- **Default claims**: both start unassigned; each player must actively
  press their direction to claim a device before confirm is possible.
- **Escape behavior**: returns to the start menu rather than quitting.
