# 3x3 Puzzle Checklist

- [x] Task A — `scripts/generate_puzzle_gradient.py` (new) + `assets/puzzles/gradient_3x3.png` (new, committed) — generate the source puzzle image. **Independent — no dependencies, can run in parallel with everything else.**
  - New directory `assets/puzzles/` (does not exist yet).
  - Python script using Pillow (already available in this environment), following this repo's convention of small standalone scripts in `scripts/` (cf. `scripts/build_web.sh`).
  - Generates a 192x192 px RGB PNG. Per pixel `(x, y)`:
    - `R = round(255 * x / (W-1))`
    - `B = round(255 * y / (H-1))`
    - `G = 60` (fixed)
  - Script writes directly to `assets/puzzles/gradient_3x3.png` (e.g. `Image.new("RGB", (192, 192))`, set per-pixel, `.save(...)`) and is safely re-runnable (overwrites the file deterministically — same output every run).
  - Run the script once as part of this task and commit the resulting PNG alongside the script — the PNG is a static asset, not regenerated at runtime.
  - No other files touch this — this task does not require Love2D/Lua at all.

- [x] Task B — `lua/core/sprite.lua` — add optional quad (sub-rectangle) drawing support. **Independent — no dependencies, can run in parallel with Task A, C.**
  - `Sprite.new` already sets `self.image = nil` in the constructor (line 16); add `self.quad = nil` alongside it as a new default field.
  - In `Sprite:draw()` (currently lines 20-38), inside the `if self.image then` branch: if `self.quad` is also set, get the quad's viewport width/height (real Love2D `Quad:getViewport()` returns `x, y, w, h`) and use *those* for the `sx`/`sy` scale factors instead of `self.image:getWidth()/getHeight()`, then call `love.graphics.draw(self.image, self.quad, -self.width / 2, -self.height / 2, 0, sx, sy)`. If `self.quad` is `nil`, behavior is byte-for-byte unchanged from today (whole-image draw, or flat-color rectangle when `self.image` is nil).
  - Be aware the headless test stub (`lua/headless/stubs.lua`) has `love.graphics.newQuad` fall through the catch-all `new*` handler and return the same stub-image shape (`getWidth`/`getHeight`/`getDimensions`, no `getViewport`) rather than a real Quad object — don't assume `getViewport` exists unconditionally if you want this to be exercisable under the headless stub; guard for its absence or read whatever the stub provides so nothing errors in headless test runs. (Purely a correctness/robustness note for this task — no stub file changes are in scope here.)
  - No changes to `Sprite.new`'s signature or any other method.

- [x] Task C — `game/jigsaw_piece.lua` — accept an optional visual (image+quad) argument. **Independent — no dependencies, can run in parallel with Task A, B.**
  - Change `JigsawPiece.new(x, color)` to `JigsawPiece.new(x, color, visual)`.
  - `color` behavior is completely unchanged — every existing call site (all of `tests/test_jigsaw.lua`'s ~10 direct `JigsawPiece.new(x, {r,g,b,a})` calls, two-arg only) keeps working with no changes needed there.
  - When `visual` (3rd arg) is present, it is a table `{ image = <love Image>, quad = <love Quad> }`; after building `self.sprite` as today, set `self.sprite.image = visual.image` and `self.sprite.quad = visual.quad`. When `visual` is nil/omitted, leave `self.sprite.image`/`self.sprite.quad` at their `Sprite.new` defaults (nil), i.e. today's flat-color-rectangle rendering.
  - Nothing else in the file changes (rotate/pick_up/drop/update/centre/draw all untouched).
  - Note: this task only needs `Sprite.new` to already accept/store arbitrary fields (true today) — it does not need to wait on Task B's `Sprite:draw()` quad-rendering logic to *exist* in order to write or compile this file. Visual correctness of the rendered quad depends on Task B being done too, but that's an integration concern for Task D, not a blocker for writing this task.

- [x] Task D — `game/jigsaw_box.lua` — load the puzzle image, slice into 9 quads, shuffle order + randomize initial rotation. **Depends on Task A (needs the PNG file to exist at `assets/puzzles/gradient_3x3.png`), Task B (needs `Sprite`/quad-draw support to render correctly), and Task C (needs `JigsawPiece.new`'s 3rd `visual` arg). Must run after A, B, and C are all done.**
  - In `JigsawBox.new(x, y)`: load the puzzle image once via `love.graphics.newImage("assets/puzzles/gradient_3x3.png")` (store e.g. `self.puzzle_image` or a local used only at construction), read its actual width/height via `getWidth()/getHeight()` (or `getDimensions()`), and compute `cellW = imgW / 3`, `cellH = imgH / 3`.
  - Build a 3x3 grid of 9 quads with `love.graphics.newQuad(col * cellW, row * cellH, cellW, cellH, imgW, imgH)` for `row = 0..2`, `col = 0..2`.
  - Replace `self.pieces_to_spawn`'s current 3 hardcoded color tables (lines 14-18) with a list of 9 entries, one per grid cell, each `{ image = puzzle_image, quad = cell_quad }`.
  - Shuffle that 9-entry list in place with Fisher–Yates immediately after building it (still inside `JigsawBox.new`, before `self.spawned = {}`), using `math.random`.
  - In `_eject_next` (currently lines 39-88): change `local color = table.remove(self.pieces_to_spawn, 1)` to pop a `spec` (the `{image, quad}` table) instead, and change the piece construction at line 79 from `JigsawPiece.new(cx, color)` to `JigsawPiece.new(cx, {1,1,1,1}, spec)` (white tint so the image isn't recolored).
  - Immediately after constructing `piece` (still in `_eject_next`, before appending to `pieces`/`self.spawned`), call `piece:rotate()` a random `math.random(0, 3)` number of times so each ejected piece spawns with a random initial orientation. This reuses `JigsawPiece:rotate()`/`rotation_step` unchanged.
  - Everything else in the file (slot search, timer, state machine, `centre()`, `draw()`, box's own sprite/color) is unchanged.
  - Since real image width/height are read at runtime, this also works unmodified against the headless test stub (`love.graphics.newImage` returns a fixed 120x120 stub image regardless of path, giving clean 40x40 cells) — no special-casing needed for tests.

- [x] Task E — `tests/test_jigsaw.lua` — update piece-count assertions and add coverage for new box behavior. **Depends on Task D (assertions must match the final `JigsawBox` implementation). Run after Task D.**
  - Update the 3 existing count-based assertions that hardcode 3 pieces to 9:
    - `JigsawBox.new` test (~line 209): `#box.pieces_to_spawn == 3` → `== 9`.
    - "update() ejects one piece per call" test (~lines 225-233): unaffected in shape but re-verify comment/assert still reads correctly ("state stays 'ejecting'" — still true with 9, just no longer "2 pieces remaining", update wording).
    - "update() x3 ejects all pieces, state becomes done" test (~lines 237-247): change to 9 `box:update(1.0, pieces)` calls, assert `#pieces == 9` and `box.state == "done"` only after the 9th.
  - The "slot search skips occupied slots" test (~lines 251-269) needs no count change, just keep using the box after one eject.
  - Add new coverage:
    - Shuffle: construct two `JigsawBox` instances (or seed `math.random` differently / just assert structurally) and verify `pieces_to_spawn` contains 9 distinct quad specs covering all 3x3 cells exactly once (e.g. by checking the 9 entries' underlying quad coordinates are a permutation of the 9 expected cells, not row-major order every time — acceptable to assert "not always identical to unshuffled order across repeated construction" or, more robustly, assert the *set* of cells is exactly the 9 expected ones regardless of order).
    - Random initial rotation: after ejecting a piece via `box:update`, assert `piece.rotation_step` is in `{0,1,2,3}` (sanity bound, since exact value is random) — this alone doesn't prove randomness, so also consider asserting across many ejections that not all rotation_steps are identical (probabilistic, but fine for this codebase's existing test style).
    - Visual wiring: assert an ejected piece's `sprite.image` and `sprite.quad` are non-nil (proving `JigsawPiece.new`'s 3rd arg was passed through), without needing to inspect pixel contents.
  - No changes needed to the earlier standalone `JigsawPiece.new(x, {color})` tests (two-arg calls) — those remain valid unchanged per Task C's backward-compatibility guarantee.
