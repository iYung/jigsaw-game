# Progressive Difficulty Unlock

## Goal

Gate puzzle tiers behind completion progress: `med` puzzles must not appear until 3 `easy` puzzles have been solved, and `hard` puzzles must not appear until 3 `med` puzzles have been solved. `easy` is always available.

## Affected files

- `game/game_state.lua` — add per-tier solved counters and an unlock check.
- `game/jigsaw_box.lua` — filter the puzzle-selection pool to only unlocked tiers; track which tier the chosen puzzle belongs to.
- `game/scenes/game_scene.lua` — thread the puzzle's tier through `active_puzzles` entries so the solve hook can attribute the count to the right tier.
- `tests/test_game_state.lua` — cover the new counters/unlock logic.
- `tests/test_jigsaw.lua` — cover pool filtering by locked/unlocked tier.

## What changes

**`GameState`**
- New field `self.solved_by_tier = {easy = 0, med = 0, hard = 0}`, reset alongside existing fields in `reset()`.
- `puzzle_solved(tier)` now takes a `tier` argument and increments `self.solved_by_tier[tier]` in addition to the existing flat `solved_count`/`active_count` bookkeeping. (Currently called with no arguments; both call sites will pass the tier.)
- New `GameState.UNLOCK_THRESHOLD = 3` constant.
- New `GameState:is_tier_unlocked(tier)`:
  - `"easy"` → always `true`.
  - `"med"` → `true` once `solved_by_tier.easy >= UNLOCK_THRESHOLD`.
  - `"hard"` → `true` once `solved_by_tier.med >= UNLOCK_THRESHOLD`.

**`JigsawBox.new`**
- The pool-building loop (currently iterating all three tiers unconditionally) skips any tier where `GameState:is_tier_unlocked(tier)` is `false`, so a locked tier's puzzles are never selected.
- The box records `self.tier = chosen.tier` so the scene can read it back after construction.
- Behavior when every unlocked tier is exhausted is unchanged: `JigsawBox.new` returns `nil`, same as today's fully-exhausted case.

**`GameScene`**
- Both places that build an `active_puzzles` entry (`on_enter` and `_spawn_box`) add `tier = box.tier` to the entry table.
- The solve-detection loop calls `GameState:puzzle_solved(entry.tier)` instead of `GameState:puzzle_solved()`.

## What stays the same

- No persistence is introduced — this is in-memory/session-scoped, consistent with the rest of `GameState` (explicitly out of scope per its existing header comment).
- The flat `solved_count` counter, `active_count` cap, and trophy shelf display are untouched.
- Puzzle selection remains a single flat random pick across all *unlocked* tiers' unseen puzzles (unchanged weighting behavior, just a smaller candidate set while tiers are locked).
- No UI/indicator is added to show lock state or progress toward the next unlock — puzzles of a locked tier simply never get chosen.

## Known limitation (accepted)

`assets/puzzles/med` currently has only 2 images and `assets/puzzles/hard` has only 2. Since a puzzle can only be shown/solved once per session (no repeat mechanism), the flat "3 solved" threshold means `hard` cannot actually unlock until more `med` puzzle assets are added (max reachable `solved_by_tier.med` today is 2). This is a known, accepted gap for this feature — not something this implementation works around. Asset expansion is a separate future task.

## Open questions

None outstanding — the asset-count gap above was raised and the flat-threshold rule was confirmed as-is by the user.
