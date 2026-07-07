# Multiple Puzzle Images

## Goal
The jigsaw box currently always cuts up the same single image (`assets/puzzles/gradient_3x3.png`). Add two more 3x3 source images with visually distinct patterns, and have the box randomly pick one of the three whenever it's constructed, so replaying the game doesn't always show the same puzzle.

## Affected files
- `assets/puzzles/diagonal_3x3.png` — **new**: 192x192 source image, smooth diagonal gradient (see below)
- `assets/puzzles/stripes_3x3.png` — **new**: 192x192 source image, banded diagonal stripes (see below)
- `scripts/generate_puzzle_gradient.py` — **renamed** to `scripts/generate_puzzle_images.py` and expanded to generate all three PNGs (the existing `gradient_3x3.png` output is unchanged, just now generated alongside the two new ones from one script)
- `game/jigsaw_box.lua` — instead of hardcoding `assets/puzzles/gradient_3x3.png`, picks one path at random from a list of the three images each time a box is constructed
- `tests/test_jigsaw.lua` — no changes expected: the headless `love.graphics.newImage` stub (`lua/headless/stubs.lua`) returns a fixed 120x120 stub image regardless of path, and no existing test hardcodes the puzzle image path

## What changes

### New source images
Both new images are 192x192 px (same as `gradient_3x3.png`, so each 3x3 cell is still a clean 64x64 = `C.SLOT`). Both use position-dependent formulas anchored on diagonal axes (`x+y` / `x-y`) rather than the original's horizontal/vertical axes (`x` / `y`) — this keeps every cell's pattern asymmetric under 90° rotation (including the center cell), same guarantee the original gradient relies on, while looking visually distinct from it and from each other.

**`diagonal_3x3.png`** — smooth diagonal gradient:
- `u = x + y` (range `0..2*(W-1)`), `v = x - y` (range `-(W-1)..(W-1)`)
- `R = round(255 * u / (2*(W-1)))`
- `B = round(255 * (v + (W-1)) / (2*(W-1)))`
- `G = 150` (fixed — different from the original's `G = 60`, another visual differentiator)

**`stripes_3x3.png`** — banded diagonal stripes (higher-contrast, discrete look rather than a smooth blend):
- `band = floor((x + y) / 16)`
- Even bands → teal `(20, 120, 180)`; odd bands → coral `(220, 90, 60)`
- With a 64px cell, this produces several visible diagonal stripes per piece, so rotation is obvious at a glance

### `scripts/generate_puzzle_images.py`
- Replaces `scripts/generate_puzzle_gradient.py` (git rename)
- Same CLI-less, deterministic, overwrite-on-run behavior as today
- One function per image (`generate_gradient`, `generate_diagonal`, `generate_stripes`), `main()` writes all three files under `assets/puzzles/`

### `game/jigsaw_box.lua`
- Add a module-level list:
  ```lua
  local PUZZLE_IMAGES = {
      "assets/puzzles/gradient_3x3.png",
      "assets/puzzles/diagonal_3x3.png",
      "assets/puzzles/stripes_3x3.png",
  }
  ```
- In `JigsawBox.new`, replace the hardcoded path with `PUZZLE_IMAGES[math.random(#PUZZLE_IMAGES)]`
- Everything downstream (slicing into 9 quads, shuffle order, random per-piece rotation) is unchanged — it already reads the image's actual dimensions rather than assuming a specific file

## What stays the same
- Cell size, slicing math, quad generation, ejection order shuffle, per-piece random rotation — all untouched, since they already derive from the loaded image's own dimensions rather than any hardcoded file
- `JigsawSolver.is_assembled` and win-detection — unaffected; solving is based on grid position/rotation, not which image was used
- Pickup/drop/rotate mechanics, box placement/timing, world/camera/scene architecture
- Only one image is ever active per box (no mixing pieces from different images within a single puzzle)

## Open questions
None outstanding — confirmed with the user:
1. Visual style for the two new images: distinct pattern per image (not just more gradient-axis variants), while preserving the original's rotation-must-be-visible property.
2. Random selection happens once per `JigsawBox.new()` call (i.e., once per box/scene load) — matches the current single-image-per-box design.
