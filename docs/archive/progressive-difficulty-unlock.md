# Progressive Difficulty Unlock Checklist

Task A must finish before Task B starts — B's tests exercise the code A writes, so they are not parallelizable.

- [x] Task A — `game/game_state.lua`, `game/jigsaw_box.lua`, `game/scenes/game_scene.lua` — Implement per-tier unlock logic.
  - In `game/game_state.lua`:
    - Add `self.solved_by_tier = {easy = 0, med = 0, hard = 0}` in `GameState.new()`, and reset it the same way in `GameState:reset()`.
    - Add module constant `GameState.UNLOCK_THRESHOLD = 3`.
    - Change `GameState:puzzle_solved()` to `GameState:puzzle_solved(tier)`: keep existing `solved_count`/`active_count` behavior, and additionally do `self.solved_by_tier[tier] = self.solved_by_tier[tier] + 1`.
    - Add `GameState:is_tier_unlocked(tier)`: `"easy"` → always `true`; `"med"` → `true` iff `self.solved_by_tier.easy >= GameState.UNLOCK_THRESHOLD`; `"hard"` → `true` iff `self.solved_by_tier.med >= GameState.UNLOCK_THRESHOLD`.
  - In `game/jigsaw_box.lua`:
    - In `JigsawBox.new`, the pool-building loop (`for tier, paths in pairs(by_tier) do ... end`) should skip a tier entirely when `GameState:is_tier_unlocked(tier)` is `false` — don't add its unseen paths to `pool`.
    - After the puzzle is chosen (`local chosen = pool[...]`), store `self.tier = chosen.tier` on the box instance so callers can read which tier this box's puzzle belongs to.
  - In `game/scenes/game_scene.lua`:
    - In both places an `active_puzzles` entry is built (`on_enter` and `_spawn_box`), add `tier = box.tier` to the entry table alongside the existing `pieces`, `piece_count`, `solved`, `image`, `cols`, `rows` fields.
    - In the solve-detection loop (`GameState:puzzle_solved()` call), change it to `GameState:puzzle_solved(entry.tier)`.
  - Run `love . --headless` (per this repo's test runner) to confirm the existing suite still passes before marking this task done — a broken signature change here will surface immediately in `test_game_state.lua`/`test_jigsaw.lua`, which is expected until Task B updates them; note in your final report if pre-existing tests fail due to the signature change (that's expected and Task B will fix it, not a regression to chase).

- [x] Task B — `tests/test_game_state.lua`, `tests/test_jigsaw.lua` — Add coverage for per-tier unlock logic. (Do not start until Task A is complete and its files are in their final state.)
  - In `tests/test_game_state.lua`, add cases (following the file's existing plain-Lua `assert`/`print("PASS: ...")` block style, using `GameState:reset()` to isolate each case since it's a process-lifetime singleton):
    - `is_tier_unlocked("easy")` is `true` on a fresh/reset state.
    - `is_tier_unlocked("med")` is `false` until `puzzle_solved("easy")` has been called 3 times, then `true`.
    - `is_tier_unlocked("hard")` is `false` until `puzzle_solved("med")` has been called 3 times, then `true`.
    - `puzzle_solved(tier)` increments `solved_by_tier[tier]` without affecting the other tiers' counts, and still increments the existing flat `solved_count` / decrements `active_count` as before.
    - `reset()` clears `solved_by_tier` back to `{easy = 0, med = 0, hard = 0}`.
  - In `tests/test_jigsaw.lua`, add case(s) (check how the file currently mocks/stubs `PuzzleCatalog`/`GameState` for the existing tier-exhaustion tests, e.g. around spawn pooling, and follow the same pattern):
    - With `med` and `hard` locked (fresh `GameState:reset()`), repeated `JigsawBox.new(...)` calls only ever pick `easy`-tier paths (assert `box.tier == "easy"` across many draws, or assert no `med`/`hard` path is ever chosen).
    - After artificially driving `solved_by_tier.easy` to 3 (e.g. calling `GameState:puzzle_solved("easy")` three times, or `reset()` + direct field set if that's more consistent with existing test style), `med`-tier paths become eligible for selection (and `hard` still is not, until `med` also reaches 3).
  - Run `love . --headless` and confirm the full suite passes (this closes out the "expected failure" noted at the end of Task A).
