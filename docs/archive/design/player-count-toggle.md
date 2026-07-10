# Player Count Toggle

## Goal

Add a "Players: 1" / "Players: 2" toggle to the start menu so the user can
pick 1-player or 2-player mode before starting a game. This ticket is
**UI + state only**: the selected count is stored for later use, but no
actual two-player gameplay (second `Player` instance, split input, etc.) is
implemented yet.

## Affected files

- `game/scenes/start_scene.lua` — add a new "Players: N" row to the menu;
  add left/right handling to cycle 1 ↔ 2 while that row is selected; draw
  the current value with a "< N >" affordance.
- `lua/core/input.lua` — no changes expected; `Input.new` already supports
  arbitrary named actions and both keyboard and gamepad bindings via the
  existing `key_map`/`gamepad_buttons` options, so `left`/`right` are added
  as new actions on the start scene's existing `Input` instance, not a
  library change.
- `game/game_state.lua` — add a `player_count` field (1 or 2, default 1),
  include it in `to_save()`/`apply_save()`/`reset()` so it round-trips
  through save/load like the other fields on this singleton.
- `tests/test_start_scene.lua` — cover the new menu item: default value,
  cycling with left/right (including that it clamps/wraps between 1 and 2,
  not skipped like "Continue" is), and that confirming other rows still
  works with the new item present.
- `tests/test_game_state.lua` — cover `player_count` default, mutation, and
  save/load round-trip.

## What changes

- Start menu becomes 4 rows: `New Game`, `Continue`, `Players: 1`,
  `Exit Game`. ("Players" placed after Continue, before Exit — open to
  reordering if you'd rather it sit right under "New Game".)
- Up/down navigation moves through all 4 rows as today (still skipping
  "Continue" when there's no save).
- When "Players: N" is the selected row, left/right (keyboard `a`/`d` or
  `left`/`right` arrows; gamepad D-pad left/right or left-stick) cycles
  the value between 1 and 2. Confirm on this row also toggles it (so
  gamepad players without a d-pad-left mapping edge case aren't stuck) —
  matches your answer that confirm can double as the cycle action, layered
  on top of keyboard/gamepad left-right as the primary path.
- `GameState.player_count` is set from the toggle's value at the moment
  "New Game" is confirmed (mirrors how `GameState:reset()` already runs at
  that point), and is restored from save data when "Continue" is used.
- No other scene, `Player`, or input-scoping code changes. `game_scene.lua`
  still constructs exactly one `Player`, unchanged.

## What stays the same

- Menu layout constants (`ITEM_W`/`ITEM_H`/`ITEM_GAP`/`ITEMS_TOP`), the
  disabled/skip styling for "Continue", and the overall `Input` wiring
  pattern stay as-is — the new row follows the existing item-rect/list
  rendering, just with an extra small bit of "< >" decoration.
- Two-player gameplay itself (second `Player`, per-controller assignment,
  split-screen or shared-input handling) is explicitly out of scope; the
  toggle only produces a stored integer.

## Open questions

None outstanding — resolved during design:
- UI pattern: separate "Players: N" menu row (not inline on "New Game").
- State: stored on `GameState` (not purely visual).
- Input: keyboard + gamepad left/right cycle it (confirm also cycles it
  as a fallback, see above).

Remaining minor judgment calls to make during implementation (not blocking
approval, but flagging so the checklist can call them out explicitly):
- Exact row order (`Players` before or after `Continue`).
