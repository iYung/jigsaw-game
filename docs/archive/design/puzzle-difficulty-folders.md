# Puzzle Difficulty Folders

## Goal
Reorganize the puzzle source images under `assets/puzzles/` into per-difficulty
subfolders (`easy/`, `med/`, `hard/`), commit the 4x4 and 5x5 puzzle images that
already exist on disk (untracked) for `med` and `hard`, and replace the
hardcoded `PUZZLE_IMAGES` table in `game/jigsaw_box.lua` with a launch-time
directory scan so the game infers its full puzzle list from disk instead of a
code literal. Selection stays a **flat uniform random pick across every
discovered image**, regardless of which difficulty folder it lives in — a
5-image catalog (3 easy + 1 med + 1 hard) gives each image a 1/5 chance, *not*
a 1/3-per-tier-then-1/count-within-tier weighting.

## Affected files
- `game/jigsaw_box.lua` — delete the hardcoded `PUZZLE_IMAGES` table
  (lines 5-9); `JigsawBox.new` gets its image list from the new catalog module
  instead and picks uniformly at random from it exactly as it does today
  (`math.random(#list)`). The per-image grid-size inference that follows stays
  untouched.
- `game/puzzle_catalog.lua` (**new**) — small module that scans
  `assets/puzzles/easy/`, `assets/puzzles/med/`, `assets/puzzles/hard/` via
  `love.filesystem.getDirectoryItems`, builds one flat array of image paths
  across all three folders, memoizes it (scan happens once per process, not
  once per box), and exposes it (e.g. `PuzzleCatalog.list()`). Kept separate
  from `jigsaw_box.lua` so the discovery/caching logic is independently
  testable (spy on `love.filesystem.getDirectoryItems`, same pattern already
  used for `love.graphics.newQuad`/`newImage` in `tests/test_jigsaw.lua`)
  without needing a full `JigsawBox.new()` call, and so `jigsaw_box.lua` stays
  focused on box/piece construction.
- `assets/puzzles/easy/1.png`, `2.png`, `3.png` — become the canonical 3x3
  puzzles, replacing today's top-level `assets/puzzles/1.png`/`2.png`/`3.png`.
  See Open Question 1 for how these should be produced (recommendation:
  `git mv` the top-level files rather than keep the already-present untracked
  `easy/*.png` copies).
- `assets/puzzles/1.png`, `2.png`, `3.png` (top-level) — removed once moved
  into `easy/` (see Open Question 1). Nothing should reference the top-level
  paths after this change; the reorg is a move, not a duplication.
- `assets/puzzles/med/1.png` — already exists untracked (256x256, 4x4 grid at
  64px/cell). Verified its pixel content follows the same
  asymmetric-under-90°-rotation design as `generate_puzzle_images.py`'s
  `generate_diagonal()`, just evaluated over a 256px canvas instead of 192px
  (corner-pixel math matches the formula exactly). Needs to be `git add`-ed;
  see Open Question 2 on whether to keep the file as-is or regenerate it via
  an extended script.
- `assets/puzzles/hard/1.png` — already exists untracked (320x320, 5x5 grid at
  64px/cell). Verified its pixel content matches `generate_puzzle_images.py`'s
  `generate_stripes()` formula/colors evaluated over a 320px canvas. Same
  `git add` + Open Question 2 as above.
- `scripts/generate_puzzle_images.py` — **deleted**. Decided (see Open
  Question 2, resolved): the script was only ever needed to produce the
  images once; now that all 5 target images exist as real files, there's no
  ongoing need for a generator. No replacement script for `med`/`hard`.
- `lua/headless/stubs.lua` — `make_stub_image()` (the return value of every
  stubbed `love.graphics.new*` call, including `newImage`) currently ignores
  its arguments and always returns a fixed 192x192 image. That's fine for
  today's all-192x192 catalog, but once `med`/`hard` images (256/320) are
  real catalog entries, headless tests can't observe or assert per-image grid
  inference (3x3 vs 4x4 vs 5x5) unless the stub image's dimensions vary by the
  path passed to `love.graphics.newImage(path)`. Needs to become path-aware
  (e.g. a small lookup: paths under `/med/` → 256x256, `/hard/` → 320x320,
  else → 192x192). This only affects `newImage`'s stub — `newQuad` and other
  `new*` stubs are unaffected since tests already spy on those directly.
- `tests/test_jigsaw.lua` — the block asserting `love.graphics.newImage` is
  always called with one of exactly 3 hardcoded paths (`assets/puzzles/1.png`
  /`2.png`/`3.png`, lines ~547-595) must be rewritten to check against the
  catalog's actual discovered list (via `PuzzleCatalog.list()`) instead of a
  fixed literal set. New tests should cover: (a) the catalog discovers images
  from all three folders into one flat list, (b) selection is uniform across
  the *whole* list, not per-folder-then-per-image (with folder counts of 3/1/1
  today, a per-folder-first scheme would be statistically distinguishable from
  flat-uniform with enough trials — worth a probabilistic test similar to the
  existing shuffle/rotation variety checks in this file), and (c) grid
  inference still produces the right `rows`/`cols`/`piece_count` for a 4x4 and
  a 5x5 image (needs the stub update above to be meaningful).
- `README.md` — the "Structure" section's `assets/` bullet and the
  `jigsaw_box.lua` description both currently describe a flat
  `assets/puzzles/*.png` layout with "one picked at random per box." Needs
  updating to describe the `easy/`/`med`/`hard`/ folder layout and launch-time
  discovery. **Not touched by this design doc or its implementation** — flag
  for the Phase 4 Verification agent, which per NFF rules owns README updates.

## What changes
- **Folder layout**: `assets/puzzles/` contains only three subfolders —
  `easy/` (3x3 images, currently `1.png`/`2.png`/`3.png`), `med/` (4x4 images,
  currently `1.png`), `hard/` (5x5 images, currently `1.png`) — no loose
  top-level `.png` files.
- **Discovery**: `game/puzzle_catalog.lua` hardcodes the 3 known tier folder
  names (`{"easy", "med", "hard"}` under `assets/puzzles/`) rather than doing
  a generic recursive directory walk. For each tier it calls
  `love.filesystem.getDirectoryItems("assets/puzzles/" .. tier)` and keeps
  entries ending in `.png` (same extension-filter pattern
  `lua/headless/runner.lua:75-81` already uses for `tests/*.lua` discovery —
  confirms `getDirectoryItems` is available and already exercised in both
  real and headless/`love . --headless` runs, including CI, without needing
  `love.filesystem.getInfo`). This deliberately avoids
  `love.filesystem.getInfo`, which `lua/headless/stubs.lua:68` currently
  hard-stubs to always return `nil` — using it for directory-type detection
  would require updating that stub too, for no benefit since the set of tier
  folders is small, fixed, and known up front (not something that needs to be
  auto-detected).
- **Flat list construction**: for each tier, prepend
  `"assets/puzzles/" .. tier .. "/"` to each filename found, and append to one
  combined array across all three tiers. No per-tier grouping is kept in the
  final list — it's a flat array of path strings, so `math.random(#list)`
  gives every image, in every tier, equal probability. This is what makes the
  selection "flat uniform," not weighted by difficulty.
- **When the scan runs**: once per process (memoized), not once per
  `JigsawBox.new()` call. `PuzzleCatalog.list()` scans on its first call and
  caches the result for the rest of the run; every subsequent call (including
  every box spawned via the spawn button) reuses the cached list. This matches
  "infer... at launch" — the scan happens once, near startup, not repeatedly
  as boxes are created during play.
- **`JigsawBox.new`**: replaces
  `PUZZLE_IMAGES[math.random(#PUZZLE_IMAGES)].path` with
  `local list = PuzzleCatalog.list(); local path = list[math.random(#list)]`,
  then proceeds exactly as today (`love.graphics.newImage(path)`, infer
  `cols`/`rows` from `imgW/C.SLOT`, `imgH/C.SLOT`, assert whole numbers, slice
  into quads). The vestigial `number` field on today's `PUZZLE_IMAGES` entries
  (confirmed unused anywhere outside the table itself — `git log` shows a
  prior commit "Don't store puzzle_number on JigsawBox" already removed its
  last consumer) is dropped; the catalog is just an array of path strings.
- **`generate_puzzle_images.py`**: becomes the reproducible generator for all
  5 images across all 3 tiers (see Open Question 2 for the recommendation to
  actually do this now vs. leave `med`/`hard` hand-authored).

## What stays the same
- Per-image grid-size inference in `JigsawBox.new` (`cols = imgW / C.SLOT`,
  `rows = imgH / C.SLOT`, asserting both are whole numbers) — this is exactly
  the mechanism that already lets `med`'s 256x256 image infer a 4x4 grid and
  `hard`'s 320x320 image infer a 5x5 grid with zero extra code, per
  `docs/archive/design/infer-puzzle-size.md`. Nothing about this feature
  changes that logic; it only changes where the *list of candidate image
  paths* comes from.
- Piece slicing into quads, ejection shuffle order, ejection stagger timing,
  spawn-position search/world-bounds handling, per-piece random initial
  rotation, drop/rotate/pick-up mechanics, the spawn button, and per-box
  completion tracking (`game/jigsaw_solver.lua`, `active_puzzles` in
  `game/scenes/game_scene.lua`) — all untouched.
- `C.SLOT` (64px cell size) and `C.U` — untouched.
- `JigsawBox.new(x, y, world_w, world_h)`'s signature and all call sites in
  `game/scenes/game_scene.lua` — untouched.
- Only one image is ever active per box (no mixing pieces from different
  images within a single puzzle) — untouched, per
  `docs/archive/design/multiple-puzzle-images.md`.

## Open questions

Both questions below were put to the user and are now resolved; kept here for
Phase 2/3 traceability.

1. **RESOLVED — move vs. copy for the `easy` 3x3 images.** Decision:
   `git mv assets/puzzles/{1,2,3}.png` to `assets/puzzles/easy/{1,2,3}.png`
   (preserves file history, uses exactly today's shipped pixel content, zero
   regeneration risk), then delete the currently-untracked
   `assets/puzzles/easy/{1,2,3}.png` (redundant near-duplicates of unknown
   provenance, superseded by the moved files).

2. **RESOLVED — `scripts/generate_puzzle_images.py` fate.** Decision: delete
   the script entirely. It was only ever needed to produce the images once;
   now that all 5 target images exist as real files (easy via the git-mv
   above, med/hard already present untracked), there's no ongoing need to
   regenerate them, so no extended/parameterized version is created. The
   untracked `med/1.png`/`hard/1.png` are committed as-is.

3. **Discovery mechanism: hardcode 3 tier names vs. generic directory walk.**
   Covered under "What changes" above — recommendation is to hardcode
   `{"easy", "med", "hard"}` rather than have `puzzle_catalog.lua` discover
   *which* subfolders of `assets/puzzles/` exist (which would need
   `love.filesystem.getInfo` for directory-type checks, currently hard-stubbed
   to `nil` in headless tests). Flagging as an open question only because it's
   a real design fork, not because I think it's a close call — a generic walk
   adds complexity (and a headless-stub change) for a folder set that isn't
   expected to grow arbitrarily.

4. **New module vs. inlining the scan into `jigsaw_box.lua`.** Covered under
   "Affected files" above — recommendation is the new `game/puzzle_catalog.lua`
   module for testability (independently spy-able/mockable, matches this
   codebase's existing pattern of small single-purpose modules like
   `jigsaw_solver.lua`/`spawn_button.lua`) over inlining the scan at the top of
   `jigsaw_box.lua` (which would also work, since `require` caches modules and
   so would naturally memoize a module-load-time scan, but would make the
   scan harder to isolate in tests and would blur `jigsaw_box.lua`'s single
   responsibility).
