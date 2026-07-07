## Numbered Puzzles Checklist

- [x] Task A — `assets/puzzles/gradient_3x3.png`, `assets/puzzles/diagonal_3x3.png`, `assets/puzzles/stripes_3x3.png` — Rename the 3 existing puzzle source images to plain numbers using `git mv` (no pixel content changes): `git mv assets/puzzles/gradient_3x3.png assets/puzzles/1.png`, `git mv assets/puzzles/diagonal_3x3.png assets/puzzles/2.png`, `git mv assets/puzzles/stripes_3x3.png assets/puzzles/3.png`. This is a pure rename — do not touch any other file in this task. **No dependencies — do this first**, since Task C and Task D both reference the new filenames and (via `love.graphics.newImage` actually loading the file at test time) need the renamed files to exist on disk.

- [x] Task B — `scripts/generate_puzzle_images.py` — Repoint the 3 output-path constants at the new filenames: change line 41 `GRADIENT_OUTPUT_PATH = PUZZLES_DIR / "gradient_3x3.png"` to `GRADIENT_OUTPUT_PATH = PUZZLES_DIR / "1.png"`, line 42 `DIAGONAL_OUTPUT_PATH = PUZZLES_DIR / "diagonal_3x3.png"` to `DIAGONAL_OUTPUT_PATH = PUZZLES_DIR / "2.png"`, and line 43 `STRIPES_OUTPUT_PATH = PUZZLES_DIR / "stripes_3x3.png"` to `STRIPES_OUTPUT_PATH = PUZZLES_DIR / "3.png"`. Do not rename or touch `generate_gradient()`, `generate_diagonal()`, `generate_stripes()`, or any pixel-formula code — those function names describe the pattern, not the output file, and stay as-is. No dependency on Task A (this only edits Python source, it doesn't read the asset directory), but conceptually it keeps the generator consistent with the renamed assets — safe to do in parallel.

- [x] Task C — `game/jigsaw_box.lua` — Two changes: (1) Replace the flat `PUZZLE_IMAGES` list at lines 5-9 with a list of tables carrying an explicit number:
  ```lua
  local PUZZLE_IMAGES = {
      { number = 1, path = "assets/puzzles/1.png" },
      { number = 2, path = "assets/puzzles/2.png" },
      { number = 3, path = "assets/puzzles/3.png" },
  }
  ```
  (2) In `JigsawBox.new` (currently line 23: `local puzzle_image = love.graphics.newImage(PUZZLE_IMAGES[math.random(#PUZZLE_IMAGES)])`), pick a random entry, load its `path`, and store the entry's `number` on the box as `self.puzzle_number`, e.g.:
  ```lua
  local puzzle_entry = PUZZLE_IMAGES[math.random(#PUZZLE_IMAGES)]
  local puzzle_image = love.graphics.newImage(puzzle_entry.path)
  self.puzzle_number = puzzle_entry.number
  ```
  Everything downstream of `puzzle_image` (dimensions, quad slicing at lines 24-34) is unchanged. **Depends on Task A**: this file's `PUZZLE_IMAGES.path` values must point at files that actually exist on disk (`assets/puzzles/1.png` etc.), so Task A must be complete (or the assets already renamed) before this task can be verified — run sequentially after Task A, not in parallel.

- [x] Task D — `tests/test_jigsaw.lua` — Update the "`JigsawBox.new` randomly selects one of the 3 puzzle images" block (currently lines 526-574): (1) Update `expected_paths` (lines 532-536) from `assets/puzzles/gradient_3x3.png` / `diagonal_3x3.png` / `stripes_3x3.png` to `assets/puzzles/1.png` / `2.png` / `3.png`. (2) The trial loop at lines 545-547 currently discards the constructed box (`JigsawBox.new(128, 128)` with no assignment) — change it to capture each box instance (e.g. `local boxes = {}` before the loop, `boxes[trial] = JigsawBox.new(128, 128)` inside it), so each trial's `puzzle_number` can be checked against the path captured for that same trial via the existing `love.graphics.newImage` spy (`captured_paths`, already populated at lines 538-543). (3) After the existing assertions in this block (i.e. after the "picks varied puzzle images" check ending at line 573), add a new assertion loop that for each trial `i`: asserts `boxes[i].puzzle_number` is one of `{1, 2, 3}`, and asserts it matches the number implied by `captured_paths[i]` (e.g. build a small local map `{ ["assets/puzzles/1.png"] = 1, ["assets/puzzles/2.png"] = 2, ["assets/puzzles/3.png"] = 3 }` and assert `boxes[i].puzzle_number == path_to_number[captured_paths[i]]`). Follow the existing file's assertion/print-message style (see the `PASS: ...` prints throughout this file). **Depends on Task A and Task C**: the expected filenames must exist (Task A) and `box.puzzle_number` must exist as a field (Task C) before this test can pass — run sequentially after both, not in parallel.
