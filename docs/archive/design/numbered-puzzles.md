# Numbered Puzzles

## Goal
The user wants "our puzzles" switched to be numbers instead. Clarified with the user: this refers
specifically to the **puzzle *image* identity** — today `JigsawBox` randomly picks one of 3
descriptively-named source images (`assets/puzzles/gradient_3x3.png`, `diagonal_3x3.png`,
`stripes_3x3.png`, defined in `PUZZLE_IMAGES`, `game/jigsaw_box.lua:5-9`) each time a box is
constructed, and nothing about that choice is exposed anywhere — there's no field a box carries
that says which image it got. The user wants the image files renamed/renumbered so each puzzle
variant is identified by a number instead of a descriptive name, and wants that number to be
readable off the resulting `JigsawBox` (e.g. `box.puzzle_number`) so it can be used by some
not-yet-defined future feature.

This is explicitly **not** about rendering digit graphics onto the pieces, and **not** about a
spawn-order/per-box id (multiple simultaneously-spawned boxes can share the same puzzle number if
they happen to pick the same image, exactly as they can share the same image today) — it is purely
the *image variant identity* becoming numeric. Per this repo's convention (see
`docs/archive/design/box-disappear-on-interact.md`, `docs/archive/design/spawn-button.md`), this
phase only makes the number exist and be readable — it does not build any UI display, matching, or
scoring logic on top of it.

## Affected files
- `assets/puzzles/gradient_3x3.png` → renamed to `assets/puzzles/1.png`
- `assets/puzzles/diagonal_3x3.png` → renamed to `assets/puzzles/2.png`
- `assets/puzzles/stripes_3x3.png` → renamed to `assets/puzzles/3.png`
  (`git mv`, pixel content unchanged — only the filename changes; see "What stays the same")
- `scripts/generate_puzzle_images.py` — the three `*_OUTPUT_PATH` constants
  (`GRADIENT_OUTPUT_PATH`, `DIAGONAL_OUTPUT_PATH`, `STRIPES_OUTPUT_PATH`) are repointed at the new
  filenames (`assets/puzzles/1.png`, `2.png`, `3.png`). The `generate_gradient()` /
  `generate_diagonal()` / `generate_stripes()` function names and their pixel formulas are
  unchanged — those names describe the *pattern*, not the file, and stay accurate.
- `game/jigsaw_box.lua` — `PUZZLE_IMAGES` changes shape from a flat list of path strings to a list
  of `{ number = <n>, path = <path> }` entries (see "What changes" for why). `JigsawBox.new` picks
  one entry at random, loads `entry.path`, and stores `self.puzzle_number = entry.number`.
- `tests/test_jigsaw.lua` — the existing "`JigsawBox.new` randomly selects one of the 3 puzzle
  images" block (around line 526) currently spies on `love.graphics.newImage` and asserts captured
  paths are one of the 3 old filenames — its expected-paths set updates to the 3 new filenames.
  Add one small additional assertion alongside it: after construction, `box.puzzle_number` is one
  of `{1, 2, 3}` and matches whichever path was actually loaded for that instance (i.e. path
  `assets/puzzles/1.png` ⇒ `puzzle_number == 1`, etc.), so the field is proven wired correctly, not
  just present.

## What changes
- The 3 existing puzzle source images are renamed from descriptive names to plain numbers:
  `1.png`, `2.png`, `3.png` (see "Open questions" for the exact naming format).
- `PUZZLE_IMAGES` (`game/jigsaw_box.lua`) becomes a list of `{ number, path }` entries instead of
  bare path strings, e.g.:
  ```lua
  local PUZZLE_IMAGES = {
      { number = 1, path = "assets/puzzles/1.png" },
      { number = 2, path = "assets/puzzles/2.png" },
      { number = 3, path = "assets/puzzles/3.png" },
  }
  ```
  The number is stored explicitly per entry rather than derived from the entry's position in the
  array (i.e. *not* just `math.random(#PUZZLE_IMAGES)` used directly as the number). This is
  slightly more code than reusing the array index, but it decouples "which number a puzzle is"
  from "where it happens to sit in the list" — if a 4th puzzle is inserted in the middle of the
  list later, index-based numbering would silently renumber every entry after it, while an
  explicit `number` field on each entry can't drift. Given the user wants to reference these
  numbers in a future feature, avoiding that silent-renumbering failure mode is worth the one extra
  field per entry.
- `JigsawBox.new` picks a random entry from `PUZZLE_IMAGES`, loads its `path` via
  `love.graphics.newImage`, and sets a new field `self.puzzle_number` on the box to that entry's
  `number`. This is the only new piece of state `JigsawBox` gains.

## What stays the same
- The actual pixel content of all 3 images is unchanged — same gradient/diagonal/stripes formulas,
  same 192x192 dimensions, same generation logic in `scripts/generate_puzzle_images.py`. Only the
  output filenames change.
- Random selection still happens once per `JigsawBox.new()` call, still via `math.random`, still
  with all 3 candidates equally likely — unchanged from `docs/archive/design/multiple-puzzle-images.md`.
- Image slicing into 9 quads, ejection-order shuffle, per-piece random initial rotation — all
  already derive from the loaded image's own dimensions, untouched by this change.
- `JigsawSolver.is_assembled` (`game/jigsaw_solver.lua`) is completely unaffected — solving is
  still based purely on each piece's `row`/`col`/`rotation_step`, never on which image or number a
  box had. `puzzle_number` is inert metadata; it does not participate in any completion check.
- No visual change: the box still renders as a plain gold sprite, and the ejected pieces still show
  the sliced photo-like pattern — no digits are drawn anywhere on screen. `puzzle_number` is a data
  field only; nothing currently reads or displays it.
- Multiple simultaneously-spawned boxes are still independent random picks and can still coincide
  on the same image/number, exactly as they can coincide on the same image today — this change adds
  no uniqueness constraint across boxes.
- Everything else about box/piece/spawn-button behavior (spawn timing, ejection stagger, world
  bounds, drop/rotate mechanics) is untouched.

## Open questions
- **Exact filename format.** Defaulting to bare `1.png` / `2.png` / `3.png` under
  `assets/puzzles/` (simplest option, matches "the image file name/number" as stated). If a
  different convention is preferred instead (e.g. zero-padded `01.png`, or a prefixed
  `puzzle_1.png` to make the directory listing self-describing without needing the parent folder
  name for context), that's a pure rename with no other design impact — flag before Phase 3 if so.
