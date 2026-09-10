# Final Puzzle (7x7)

## Goal
Add a fourth puzzle tier, `final_puzzle`, containing exactly one 7x7-grid
puzzle image. Unlike `easy`/`med`/`hard` (which unlock progressively via a
solve-count threshold on the previous tier, and can overlap with it), this
tier is gated so its single puzzle is **guaranteed to be the literal last
puzzle drawn from the pile in any playthrough** — it only enters the draw
pool once every `easy`, `med`, and `hard` puzzle has already been drawn out
("come out") of the pile.

## Affected files
- `assets/puzzles/final_puzzle/1.png` (**new**) — 448x448 PNG (7 cols x 7
  rows at `C.SLOT`=64px/cell), following the same "grid size inferred from
  pixel dimensions" mechanism every other tier already uses
  (`docs/archive/design/infer-puzzle-size.md`). No code changes are needed
  for the grid-inference itself — `JigsawBox.new`/`from_save` already compute
  `cols = imgW / C.SLOT`, `rows = imgH / C.SLOT` generically.
- `game/puzzle_catalog.lua` — add `"final_puzzle"` to the hardcoded `TIERS`
  list (line 3: `{"easy", "med", "hard", "final_puzzle"}`). Everything else
  in this module (the scan loop, `list()`, `list_by_tier()`) is already
  tier-name-agnostic and needs no other change.
- `game/game_state.lua`:
  - `GameState.new()` / `:reset()` — add `final_puzzle = {}` to `self.seen`
    and `final_puzzle = 0` to `self.solved_by_tier`.
  - `:is_tier_unlocked(tier, by_tier)` — **signature changes** to accept an
    optional `by_tier` table (shaped like `PuzzleCatalog.list_by_tier()`).
    Existing `easy`/`med`/`hard` branches are unchanged (still pure
    solve-count-threshold checks, ignore `by_tier`). New branch:
    ```lua
    elseif tier == "final_puzzle" then
        return by_tier ~= nil
            and self:is_tier_exhausted("easy", by_tier.easy)
            and self:is_tier_exhausted("med", by_tier.med)
            and self:is_tier_exhausted("hard", by_tier.hard)
    ```
    Reuses the existing `is_tier_exhausted` helper (already defined, already
    used by `remaining_puzzle_count`) rather than inventing new machinery.
    "Exhausted" here means every path in that tier has been marked **seen**
    (i.e. already drawn out of the pile as a box) — not necessarily solved.
    This matches the resolved open question below: the final puzzle can come
    out once everything else *is out*, regardless of whether those puzzles
    have been finished yet.
  - `:apply_save(data)` — old saves (version 1, pre-`final_puzzle`) won't
    have `final_puzzle` keys in `data.seen`/`data.solved_by_tier`. Following
    the existing precedent for `player_count` (added post-hoc, defaulted
    rather than left nil), default-fill after assignment:
    ```lua
    self.seen.final_puzzle = self.seen.final_puzzle or {}
    self.solved_by_tier.final_puzzle = self.solved_by_tier.final_puzzle or 0
    ```
    No version bump needed — same reasoning as `player_count`.
- `game/jigsaw_box.lua` — `JigsawBox.new`'s pool-building loop
  (`GameState:is_tier_unlocked(tier)` at line 14) passes `by_tier` as the new
  second argument: `GameState:is_tier_unlocked(tier, by_tier)`. `by_tier` is
  already in scope (it's `PuzzleCatalog.list_by_tier()`, assigned at line
  11). No other change — pool construction, weighted-uniform pick, and
  `mark_seen` are tier-agnostic already.
- `game/puzzle_pile.lua`, `game/scenes/game_scene.lua` — **no changes**.
  `PuzzlePile:count()`/`remaining_puzzle_count` already iterate `by_tier`
  generically via `pairs()` and don't check `is_tier_unlocked`, so a locked
  `final_puzzle` tier's one unseen path is counted in the pile from the
  start, same as `hard`'s paths are today while `hard` is locked.
  `game_scene.lua` threads `tier` through opaquely (records it on save data,
  passes it to `GameState:puzzle_solved(tier)`) with no hardcoded tier list
  or per-tier visual branching, so a new tier name needs no changes there.
  The completed-puzzle shelf layout is already piece-count/cols/rows-driven,
  not tier-count-driven, so a 49-piece puzzle lays out on the shelf the same
  way a 9/16/25-piece one does.
- Tests — update tier lists / add coverage (delegated to the checklist, not
  detailed exhaustively here):
  - `tests/test_puzzle_catalog.lua` — `TIER_NAMES` (line 3) and the two
    `#keys == 3` assertions (lines 145, 198) need a 4th entry/count once
    `final_puzzle/` exists on disk.
  - `tests/test_game_state.lua` — new tests for the `final_puzzle` branch of
    `is_tier_unlocked` (locked while any of easy/med/hard has an unseen
    path; unlocks once all three are fully seen) and for `apply_save`
    defaulting `final_puzzle` on an old-shaped save.
  - `tests/test_jigsaw.lua` — a test driving `easy`/`med`/`hard` fully seen
    via `GameState:mark_seen` for every path in a synthetic `by_tier`, then
    asserting a spawned box's `tier == "final_puzzle"`.
- `README.md` — the puzzle-system description (tier list, unlock rules,
  pixel-size-to-grid mapping) needs the `final_puzzle`/7x7/448x448 entry.
  Per NFF convention, README updates are owned by the Phase 4 Verification
  agent, not the task agents.

## What changes
- A 4th tier, `final_puzzle`, with one 448x448 (7x7 = 49-piece) image.
- `GameState:is_tier_unlocked` gains a second, optional `by_tier` parameter
  and a `final_puzzle` branch with fundamentally different unlock semantics
  from the other three tiers: **full exhaustion of every other tier**
  (all paths seen), not a fixed solve-count threshold. This deliberately
  does not reuse `UNLOCK_THRESHOLD` — a threshold-based unlock (e.g. "after
  3 hard solves") would NOT guarantee last-ness, since `med`→`hard`'s own
  threshold already allows tiers to overlap (a tier can unlock while its
  predecessor still has unseen puzzles left in the pool). Exhaustion-based
  gating is the only way to make "the last possible puzzle" a structural
  guarantee rather than a probabilistic likelihood.
- `GameState.new()`/`:reset()`/`:apply_save()` grow a 4th key across `seen`
  and `solved_by_tier`.

## What stays the same
- Grid-size inference from pixel dimensions (`imgW/C.SLOT`, `imgH/C.SLOT`) —
  totally unmodified; a 448x448 image just infers 7x7 for free.
- Draw-pool construction, uniform random pick among the pool, `mark_seen`,
  `MAX_ACTIVE_PUZZLES` cap, piece ejection/shuffle/rotation, per-box
  completion tracking, save/load plumbing beyond the two defaulted fields
  above.
- `easy`/`med`/`hard` unlock semantics (solve-count threshold, can overlap)
  — untouched; `final_puzzle` is additive, not a replacement.
- World size (1280x640px = 200 cells) comfortably fits 49 pieces via the
  existing outward-spiral placement search in `JigsawBox:_eject_next` — the
  same unmodified mechanism 25-piece `hard` puzzles already use.

## Open questions

1. **RESOLVED — how to guarantee "last possible puzzle."** Asked the user
   directly: chaining `final_puzzle` the same threshold-based way `hard` is
   chained after `med` would not actually guarantee it's the literal last
   puzzle drawn, since tiers can overlap. User confirmed: "it can come out
   as long as everything is out first" — i.e. full-exhaustion gating (see
   "What changes" above), not threshold-based.
2. Artwork for `assets/puzzles/final_puzzle/1.png`: no existing art tool or
   generator script in this repo produces new puzzle images (the prior
   `scripts/generate_puzzle_images.py` was deleted once all `easy`/`med`/
   `hard` images existed, per `docs/archive/design/puzzle-difficulty-folders.md`).
   Proceeding by generating one flat-style 448x448 PNG image (matching the
   existing set's bold-flat-shape, diagonal-striped-background aesthetic) via
   a one-off script, since no other art pipeline exists in this repo.
