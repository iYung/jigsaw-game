# Puzzle Pile Checklist

- [x] Task A — `game/game_state.lua` — add `GameState:remaining_puzzle_count(by_tier)`, summing `#self:unseen_paths(tier, paths)` across every key in `by_tier` (all tiers, including locked ones — deliberately does not check `is_tier_unlocked`). Callers pass `PuzzleCatalog.list_by_tier()`. Add a doc comment matching the style of the other methods in this file, explaining that locked-tier paths are never marked seen while locked so counting them causes no double-counting and no discontinuity when a tier unlocks.

- [x] Task B — `game/constants.lua` — add two new constants to both the `local` declarations and the returned table: `PILE_BOX_SIZE = 0.5 * SLOT` (32px, edge length of one stacked box) and `PILE_BOX_STACK_OFFSET = 6` (px each successive box is drawn higher than the one below it). Follow the existing file's pattern (locals declared near the top, then included in the final `return { ... }` table).

- [x] Task C — `game/puzzle_pile.lua` (**new file**) — **Depends on Task A, Task B.** Create the `PuzzlePile` module exactly as specified in `docs/design/puzzle-pile.md`'s "What changes" section:
  - `PuzzlePile.new(x, y)` — creates an invisible `SLOT x SLOT` footprint sprite (`self.sprite.visible = false`) at `(x, y)`, same role the door's sprite played for occupancy checks.
  - `PuzzlePile:count()` — returns `GameState:remaining_puzzle_count(PuzzleCatalog.list_by_tier())`. No stored/cached count.
  - `PuzzlePile:top_position()` — returns `{x, y}` of the current topmost box in the stack: `y = self.sprite.y - (n - 1) * C.PILE_BOX_STACK_OFFSET` where `n = math.max(self:count(), 1)`.
  - `PuzzlePile:draw()` — draws `count()` filled rectangles of `{1, 0.75, 0.2, 1}` (same orange as `JigsawBox`'s sprite color, `jigsaw_box.lua:33`), each `PILE_BOX_SIZE x PILE_BOX_SIZE`, centered within the `SLOT` footprint (`inset = (SLOT - PILE_BOX_SIZE) / 2`), stacked upward by `PILE_BOX_STACK_OFFSET` per box, then resets the draw color to white.
  - Requires: `lua/core/sprite`, `game/constants`, `game/game_state`, `game/puzzle_catalog`.

- [x] Task D — `game/scenes/game_scene.lua` + delete `game/door.lua` — **Depends on Task C.**
  - Change `local Door = require("game/door")` to `local PuzzlePile = require("game/puzzle_pile")`.
  - Change `self.door = Door.new(WORLD_W / 2, 0)` to `self.pile = PuzzlePile.new(WORLD_W / 2, 0)` (`on_enter`, ~line 92).
  - In `_spawn_box` (~line 116), change the occupancy check `self.door.sprite.x == cx and self.door.sprite.y == cy` to `self.pile.sprite.x == cx and self.pile.sprite.y == cy`.
  - In `_spawn_box` (~line 121-122), change the `JigsawBox.new` call's `spawn_from` argument from `{ x = self.door.sprite.x, y = self.door.sprite.y }` to `self.pile:top_position()`.
  - Delete `game/door.lua` — confirm no other references remain (`grep -rn "door\|Door" game/ lua/ tests/` should return nothing after this task, aside from this checklist/design doc and README, which Task E handles).

- [x] Task E — `README.md` — **Depends on Task D.** Update line 14's door description (currently: *"A purely-visual blue-violet **door** sits at the top-centre of the world; each new box flies from the door to its randomly-chosen, grid-aligned resting cell over a brief ease-out animation (~0.4s) before settling into its normal interactable state — the door has no interaction of its own."*) to describe the pile instead: it's a stack of small orange boxes, one per puzzle image not yet spawned this session (across all tiers, including locked ones), that shrinks by one each time a new box is spawned; new boxes fly from the current top of the pile to their resting cell. Drop the stale "~0.4s ease-out" detail (actual current animation is a 1.0s linear-lerp-plus-arc — not introduced by this change, just don't propagate the existing inaccuracy). Update line 21's file-map bullet (`door.lua        Door entity — ...`) to describe `puzzle_pile.lua` instead.

- [x] Task F — `tests/test_puzzle_pile.lua` (**new file**) — **Depends on Task D.** Add headless tests (matching the style/harness of `tests/test_game_state.lua` and `tests/test_jigsaw.lua`) covering:
  - `GameState:remaining_puzzle_count(by_tier)` sums unseen paths across all tiers, including a tier with nothing marked seen and a tier fully marked seen (count 0 for that tier); confirm it does NOT check `is_tier_unlocked` (a locked tier's unseen paths still count).
  - `PuzzlePile:count()` reflects `GameState:remaining_puzzle_count` for the real catalog (reset `GameState` between tests, matching the `GameState:reset()` pattern already used in `test_game_state.lua`).
  - `PuzzlePile:top_position()` returns the base `sprite.y` when `count() == 1`, and a strictly smaller `y` (higher up) as `count()` increases, changing by exactly `PILE_BOX_STACK_OFFSET` per unit of count.
  - `PuzzlePile:top_position()` at `count() == 0` returns the same position as `count() == 1` (the `math.max(n, 1)` floor).

- [x] Task G — `tests/test_scene.lua` — **Depends on Task D.** There is no existing door/spawn_from-based test in this file today (confirmed — only one existing test asserting `GameScene` inherits `drawer`/`camera` from `Scene`); this task adds new coverage rather than updating an existing test. Add a test that: constructs a `GameScene`, calls `on_enter()`, calls `self:_spawn_box()` (may need to loop/retry a couple of times if the RNG lands on an occupied cell, or call it once and assert loosely), and confirms the newly-added box's `spawn_x`/`spawn_y` equals `self.pile:top_position()` captured immediately before the call (not a fixed constant like the old door's `(WORLD_W/2, 0)`). Reset `GameState` before the test (matching `test_game_state.lua`'s pattern) so the catalog pool is in a known state.
