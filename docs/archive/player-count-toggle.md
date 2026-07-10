# Player Count Toggle Checklist

Design doc: `docs/design/player-count-toggle.md`

All tasks below are independently completable in parallel — the field
name (`player_count`), its default (`1`), and its valid range (`1` or `2`)
are fixed by this checklist, so no task needs to observe another task's
actual code to conform to the contract.

- [x] Task A — `game/game_state.lua` — Add a `player_count` field to the
  singleton, default `1`. Update `GameState.new()` to initialize it, add it
  to the payload built by `to_save()`, restore it in `apply_save()` (falling
  back to `1` if missing/absent from older save data, consistent with how
  `apply_save` already falls back to `reset()` on a version mismatch — but
  since `player_count` is a new field, an old-version save should still
  restore its other fields normally and just default `player_count` to `1`
  rather than wiping everything), and reset it to `1` in `reset()`. No
  getter/setter methods needed — direct field access (`GameState.player_count`)
  matches the style of every other field on this module.

- [x] Task B — `game/scenes/start_scene.lua` — Add a fourth menu row with
  label built as `"Players: " .. self.player_count` (or similar), initialized
  to `1` on `StartScene.new`. Insert it into `self.items` per the design
  doc's row order (Players after Continue, before Exit Game — flag in the
  PR if you think it reads better right under New Game, but implement the
  documented order). Extend the scene's `Input.new` key_map/gamepad_buttons
  with `left`/`right` actions (keyboard `a`/`left`; gamepad `dpleft`/`dpright`
  or left-stick horizontal, matching the existing `use_left_stick`-style
  option already used elsewhere in the repo for gamepad menu input). In
  `update()`, when the Players row is selected, `pressed("left")`,
  `pressed("right")`, or `pressed("confirm")` all cycle the value between 1
  and 2 (toggle, not wrap through other numbers). In `draw()`, render the
  row like the other rows but wrap the label in `"< " .. label .. " >"`
  only when it's the selected row (unselected rows show the plain label,
  same visual pattern as the normal/selected color distinction already
  used for other items — do not reuse the "Continue" disabled/0.4-alpha
  style, since this row is never disabled). On `_confirm()` for the
  "New Game" row, set `GameState.player_count = self.player_count` before
  calling `GameState:reset()` and switching scenes (reset() will already
  set it back to 1 internally per Task A — so this line must run through a
  path that doesn't get clobbered; read Task A's final `reset()` behavior
  before wiring this so the ordering is right: reset() then assign, not the
  reverse). On "Continue", after `GameState:apply_save(data.game_state)`,
  no extra wiring needed — `apply_save` (Task A) already restores
  `player_count` from the save.

- [x] Task C — `tests/test_game_state.lua` — Add coverage: (1)
  `GameState.new()` defaults `player_count` to `1`; (2) mutating
  `player_count` then calling `to_save()` includes it in the returned
  table; (3) `apply_save()` with a table containing `player_count = 2`
  restores it to `2`; (4) `apply_save()` with save data that omits
  `player_count` (simulating a pre-feature save) defaults it to `1` rather
  than erroring; (5) `reset()` sets it back to `1`.

- [x] Task D — `tests/test_start_scene.lua` — Add coverage: (1) the new
  "Players: 1" row exists and defaults to showing `1`; (2) pressing
  right/left while that row is selected toggles the displayed value
  between `1` and `2` (and back), without affecting other rows' selection
  or the up/down navigation order; (3) pressing confirm while that row is
  selected also toggles it, rather than starting a game or exiting; (4)
  confirming "New Game" with the toggle set to `2` results in
  `GameState.player_count == 2` after the switch; (5) up/down navigation
  still correctly skips "Continue" when there's no save, with the new row
  present in the list.
