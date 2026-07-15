# Final Puzzle (7x7) Checklist

Note: unlike a typical NFF checklist, nearly every task here depends on the
one before it (new tier name → new GameState fields → is_tier_unlocked
signature change → jigsaw_box call site → tests that exercise all of the
above → catalog/save tests that need the artwork file on disk). Executing
sequentially in one pass rather than parallel task-agents.

- [x] Task A — `assets/puzzles/final_puzzle/1.png` — generate a new 448x448
      PNG (7 cols x 7 rows at 64px/cell) in the same flat-shape,
      diagonal-striped-background style as the existing puzzle set.
- [x] Task B — `game/puzzle_catalog.lua` — add `"final_puzzle"` to the
      `TIERS` array (line 3).
- [x] Task C — `game/game_state.lua` — add `final_puzzle` to `self.seen` and
      `self.solved_by_tier` in both `GameState.new()` and `:reset()`; change
      `:is_tier_unlocked(tier)` to `:is_tier_unlocked(tier, by_tier)` and add
      the `final_puzzle` exhaustion branch; default-fill
      `self.seen.final_puzzle`/`self.solved_by_tier.final_puzzle` in
      `:apply_save()` for saves that predate this tier.
- [x] Task D — `game/jigsaw_box.lua` — update the `GameState:is_tier_unlocked(tier)`
      call (line 14) to `GameState:is_tier_unlocked(tier, by_tier)`.
- [x] Task E — `tests/test_puzzle_catalog.lua` — add `"final_puzzle"` to
      `TIER_NAMES`; update both `#keys == 3` assertions to `#keys == 4`
      (with the 4th key in the sorted position `list_by_tier()` actually
      produces).
- [x] Task F — `tests/test_game_state.lua` — add tests: `final_puzzle` stays
      locked while any of easy/med/hard has an unseen path (per a synthetic
      `by_tier`), unlocks once all three are fully seen; `apply_save()` on a
      pre-`final_puzzle`-shaped save default-fills `final_puzzle` to `{}`/`0`
      instead of leaving it nil.
- [x] Task G — `tests/test_jigsaw.lua` — add a test that marks every
      easy/med/hard path seen via a synthetic `by_tier`, then spawns a
      `JigsawBox` and asserts its `tier == "final_puzzle"` and
      `rows == 7`/`cols == 7`/`piece_count == 49`.
- [x] Task H — run the full test suite; fix any regressions. Found one
      regression not anticipated in the original design doc:
      `lua/headless/stubs.lua`'s path-aware `make_stub_image()` only handled
      `/med/`/`/hard/` (defaulting everything else to 192x192), so headless
      tests loading a `final_puzzle/` path got a fake 3x3 grid instead of
      7x7. Added a `/final_puzzle/` -> 448x448 case alongside the existing
      two. All 16 test files pass (`love . --headless`).
