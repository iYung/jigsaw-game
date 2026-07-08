## Goal

`GameState` (`game/game_state.lua`) currently only tracks which puzzle images
have been *seen* per difficulty tier. We want it to also track:

1. **How many puzzles the player has solved** this session (a running
   counter).
2. **How many puzzles are currently active in the world**, and use that count
   to cap the player at working on **3 puzzles at a time** — once 3 boxes
   exist in the world (opened or not), spawning a new box is a no-op until
   one of the existing ones is solved.

## Affected files

- `game/game_state.lua` — add a solved counter and an active-puzzle counter,
  plus the accessors/mutators `GameScene` needs to drive them.
- `game/scenes/game_scene.lua` — `on_enter()` and `:_spawn_box()` both create
  boxes and push `active_puzzles` entries; both need to call into `GameState`
  on spawn, gate spawning on the cap, and call into `GameState` when a puzzle
  is detected solved (in the existing solved-check loop in `update()`).
- `tests/test_game_state.lua` (**new file**, no existing test file for this
  module) — unit tests for the new counters in isolation, same style as the
  existing `seen` tests presumably already living in a test file for
  `game_state.lua` (verify at implementation time; add alongside if one
  exists).
- `tests/test_jigsaw.lua` — existing tests construct `active_puzzles` entries
  directly (bypassing `GameScene:_spawn_box()`) and don't go through
  `GameState`, so they should be unaffected; add new tests for the cap
  no-op behavior in `_spawn_box()` and for the solved counter incrementing
  when the solved-check fires.
- `README.md` — document the 3-puzzle cap and the solved counter briefly,
  matching how the seen-tracking feature is already documented.

## What changes

- **`GameState`**: add two pieces of state:
  - `solved_count` (number, starts at 0) — incremented once per puzzle
    solved.
  - `active_count` (number, starts at 0) — incremented once per box spawned,
    decremented once per puzzle solved.

  New methods:
  - `GameState:puzzle_started()` — increments `active_count`. Called the
    moment a box is created and added to `active_puzzles` (in `on_enter()`
    and `_spawn_box()`), regardless of whether the box has been opened yet.
  - `GameState:puzzle_solved()` — increments `solved_count` and decrements
    `active_count`. Called the instant a puzzle's arrangement is detected
    correct (the existing `JigsawSolver.is_assembled(...)` check in
    `GameScene:update()`), **not** when its pieces finish fading and its
    `active_puzzles` entry is pruned. This means a slot frees up immediately
    on solve, while the solved pieces may still be visibly fading out.
  - `GameState:can_start_puzzle()` — returns `active_count < MAX_ACTIVE_PUZZLES`.
  - `GameState:solved_count()` / `GameState:active_count()` — plain readers
    (or expose the fields directly, matching whatever style the existing
    `seen` table accessors use).
  - A module-level constant `GameState.MAX_ACTIVE_PUZZLES = 3`.
  - `GameState:reset()` is extended to also zero `solved_count` and
    `active_count`, consistent with its existing role of resetting all
    session state for test isolation.

- **`GameScene:on_enter()`**: before creating the initial box, this is a
  no-op change in practice (active_count starts at 0, so the cap can't
  already be hit) — but for consistency the initial box creation still goes
  through the same "check cap, call `GameState:puzzle_started()` on
  success" path as `_spawn_box()`, rather than being special-cased.

- **`GameScene:_spawn_box()`**: gains a cap check at the top — if
  `not GameState:can_start_puzzle()`, return immediately (silent no-op,
  same shape as the existing "catalog exhausted" no-op: no message, no
  button state change). If under the cap, proceeds as today, and after a
  box is successfully constructed (non-nil) and pushed into
  `self.active_puzzles`, calls `GameState:puzzle_started()`.

  Note: the cap check must happen *before* calling `JigsawBox.new(...)`,
  since `JigsawBox.new` marks a puzzle image as "seen" as a side effect of
  selecting it — we don't want to burn a puzzle image against the
  seen-tracker for a box that never gets created because the cap was
  already hit.

- **`GameScene:update()`**'s existing solved-check loop: the line that
  currently sets `entry.solved = true` and starts vanishing all of the
  entry's pieces also calls `GameState:puzzle_solved()` at that point (once
  per entry, same one-shot guard already in place via `if not entry.solved`).

## What stays the same

- Persistence: still nothing written to disk — both new counters are
  in-memory fields on the same session-lifetime `GameState` singleton,
  reset on process restart, matching the existing `seen` state.
- `active_puzzles` itself (the array on `GameScene`, holding
  `{pieces, piece_count, solved}`) is untouched in shape; it remains the
  source of truth for the fade/prune loop. The new `GameState.active_count`
  is a separate, independently-maintained counter used only for the spawn
  cap — it does not replace or derive from `#self.active_puzzles` at read
  time, since a solved-but-fading entry still sits in `active_puzzles` after
  `active_count` has already been decremented.
- Exhaustion behavior (`JigsawBox.new` returning `nil` when every difficulty
  tier is fully seen) is unchanged and independent of the new cap — either
  condition alone is enough to make `_spawn_box()` a no-op.
- The spawn button (`game/spawn_button.lua`) is unchanged — same as the
  exhaustion case, the no-op lives entirely in `GameScene:_spawn_box()`.
- No UI is added to display the solved count, active count, or cap anywhere
  on screen — this is state-tracking only, matching the "start tracking"
  framing of the ask. Surfacing it in the UI is a separate future feature.

## Open questions

All resolved by the user before this doc was written:

1. **Cap scope** — Any box present in the world counts toward the cap of 3,
   whether or not the player has opened it yet.
2. **Slot release timing** — A cap slot frees up immediately when a puzzle
   is detected solved, not when its pieces finish fading out.
3. **At-cap feedback** — Silent no-op when the spawn button is pressed at
   the cap, identical in shape to the existing catalog-exhaustion no-op.
4. **State location** — Both counters live in the `GameState` singleton,
   alongside the existing seen-puzzle tracking, rather than as plain
   `GameScene` fields.
