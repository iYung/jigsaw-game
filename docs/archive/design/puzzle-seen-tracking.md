## Goal

Right now `JigsawBox.new` picks a puzzle image uniformly at random from the
entire catalog (`PuzzleCatalog.list()`), with no memory of what's already
been shown. The same puzzle can appear over and over in one play session.

We want each puzzle image to appear at most once per session: once a puzzle
has been seen, it should not be picked again. Tracking is scoped per
difficulty (easy/med/hard folder), and once a difficulty's puzzles have all
been seen, that difficulty simply stops contributing candidates — box
spawning keeps going on whichever difficulties still have unseen puzzles,
and only stops globally once all three are exhausted.

## Affected files

- `game/puzzle_catalog.lua` — needs a tier-aware listing so callers can tell
  which tier a given path belongs to (currently `list()` returns one flat
  array of path strings with no tier metadata attached).
- `game/puzzle_seen_tracker.lua` (**new file**) — in-memory, per-tier "seen"
  set; the module owning session state for this feature.
- `game/jigsaw_box.lua` — `JigsawBox.new`'s selection logic changes from
  "pick uniformly from the full flat list" to "pick uniformly from the
  unseen paths across all tiers, mark it seen, or signal exhaustion."
- `game/scenes/game_scene.lua` — `on_enter()` and `:_spawn_box()` both call
  `JigsawBox.new(...)` and assume it always returns a box; both need to
  handle the "nothing left unseen" case.
- `tests/test_puzzle_catalog.lua` — covers `PuzzleCatalog.list()`; will need
  a companion test for the new tier-aware listing function.
- `tests/test_jigsaw.lua` — already has tests asserting `JigsawBox.new`
  picks flat-uniformly across the whole catalog (not weighted by tier) and
  that individual tiers (med/hard) do get picked over repeated trials; these
  assumptions need to be reconciled with "no repeats," since repeated trials
  in a shared process will now exhaust the catalog after a few calls instead
  of sampling with replacement forever.

## What changes

- **`PuzzleCatalog`**: add a tier-aware accessor, e.g.
  `PuzzleCatalog.list_by_tier()`, returning `{easy = {...paths}, med =
  {...paths}, hard = {...paths}}`. Implemented as a memoized companion to
  the existing scan (or the existing scan restructured to build both the
  flat list and the per-tier tables in one pass). `PuzzleCatalog.list()`
  keeps its current flat-array-of-strings shape so no other caller breaks.

- **`PuzzleSeenTracker`** (new module): holds `seen = {easy = {}, med = {},
  hard = {}}` — a set of already-shown paths per tier, living only in
  process memory (module-level table, same lifetime pattern as
  `PuzzleCatalog`'s `cached_list`; nothing touches disk). Exposes something
  like:
  - `mark_seen(tier, path)`
  - `is_seen(tier, path)`
  - `unseen_paths(tier, all_paths_for_tier)` — filters a tier's full path
    list down to the ones not yet marked seen
  - `is_tier_exhausted(tier, all_paths_for_tier)` — true once every path in
    that tier has been seen

- **`JigsawBox.new`**: instead of `list[math.random(#list)]` against the
  flat catalog, it:
  1. Calls `PuzzleCatalog.list_by_tier()` and, for each tier, filters to
     unseen paths via `PuzzleSeenTracker.unseen_paths(tier, ...)`.
  2. Concatenates the unseen paths across all three tiers into one pool
     (preserving today's flat-uniform-across-catalog selection behavior,
     just restricted to unseen entries — a tier with more remaining unseen
     puzzles is proportionally more likely to be picked, matching current
     behavior rather than doing an even pick-a-tier-then-pick-within-it
     step).
  3. If the pool is empty, `JigsawBox.new` returns `nil` — no puzzle image
     left to assign, so no box is constructed.
  4. Otherwise picks uniformly from the pool, calls
     `PuzzleSeenTracker.mark_seen(tier, path)` for the chosen path, and
     proceeds with box construction exactly as today.

- **`GameScene:on_enter()`**: the initial box creation
  (`JigsawBox.new(5 * C.SLOT, 3 * C.SLOT, ...)`) must check for `nil` before
  adding it to `self.boxes`, `self.drawer`, and `self.active_puzzles`. In
  practice this can't happen on a fresh session (nothing has been seen yet),
  but the call site needs to handle the contract now that `nil` is possible.

- **`GameScene:_spawn_box()`**: same guard — if `JigsawBox.new(...)` returns
  `nil` (every difficulty exhausted), the function returns without touching
  `self.boxes`/`self.drawer`/`self.active_puzzles`. Pressing the spawn
  button after full exhaustion is simply a no-op: no new box appears, no
  message is shown, nothing else about the button changes.

- Exhaustion is naturally global-but-per-tier: a tier with no unseen paths
  left contributes nothing to the pool, but other tiers keep spawning as
  normal. Spawning only stops entirely once the union across all three
  tiers is empty, i.e., every difficulty has had every one of its puzzles
  shown.

## What stays the same

- Persistence: still nothing is written to disk. Seen-state is an
  in-memory module table, reset every time the process restarts, exactly
  like `PuzzleCatalog`'s existing memoized `cached_list`.
- Single profile: no accounts, no save slots — one shared seen-set for the
  whole session, matching the current single-player, no-save architecture.
- `PuzzleCatalog.list()`'s existing flat return shape is untouched; other
  callers (if any appear later) keep working unmodified.
- `JigsawBox`'s piece-spawning, ejection, rotation, and placement logic
  (`_eject_next`, `interact`, `update`, `centre`, `draw`) are unaffected —
  only the puzzle-image *selection* step at the top of `JigsawBox.new`
  changes.
- The spawn button (`game/spawn_button.lua`) itself is unchanged — it just
  invokes its `on_press` callback; the no-op behavior on exhaustion lives
  entirely in `GameScene:_spawn_box()`, not in the button.
- No UI/message is added anywhere to announce exhaustion — per the
  resolved scope, boxes simply stop being produced.

## Open questions

All four items below were resolved by the user before this doc was written;
none are open anymore. Recorded here as agreed decisions:

1. **Persistence scope** — Session-only (in-memory). Resets every time the
   game launches. No disk save/load.
2. **Player identity** — Single profile, matching current code (no
   accounts or save slots).
3. **Exhaustion behavior** — Stop spawning new boxes once every puzzle in
   scope has been seen. No repeat-cycle reset, no message shown; new box
   production simply stops.
4. **Scope of "no repeats"** — Per-difficulty. Seen puzzles are tracked
   separately within easy/med/hard; seeing an easy puzzle has no effect on
   med/hard eligibility.

A fifth question (a manual reset trigger) was drafted but ruled out of
scope: since persistence is session-only, restarting the game already
clears all seen-state, so no in-game reset mechanic is needed.
