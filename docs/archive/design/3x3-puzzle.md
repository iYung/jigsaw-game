# 3x3 Image Puzzle

## Goal
Replace the current 3 solid-color placeholder pieces with a real **9-piece (3x3) jigsaw** cut from a single source image. The source image uses an x/y color gradient so each piece's correct position *and* correct rotation are visually obvious once placed (today's solid-color squares look identical no matter how they're rotated, so mis-rotation is invisible — that's the whole reason this needs a gradient, not just more colors). The box now divides that image into 9 cells and ejects them in a shuffled order.

## Affected files
- `assets/puzzles/gradient_3x3.png` — **new**: the 3x3 source image (see "What changes" for exact spec)
- `scripts/generate_puzzle_gradient.py` — **new**: small Python/Pillow script that generates the PNG above; committed alongside its output so the asset is reproducible/tweakable
- `lua/core/sprite.lua` — gains optional quad-drawing support so a `Sprite` can show a sub-rectangle of an image instead of the whole thing
- `game/jigsaw_piece.lua` — `JigsawPiece.new` accepts an optional image+quad visual in addition to the existing flat color
- `game/jigsaw_box.lua` — loads the puzzle image once, slices it into 9 quads (3x3), shuffles the ejection order, replaces the hardcoded 3-color list with 9 image-backed pieces
- `tests/test_jigsaw.lua` — counts/assertions that currently hardcode "3 pieces" become "9 pieces"; add coverage for the new slicing/shuffle behavior

## What changes

### Source image (`assets/puzzles/gradient_3x3.png`)
- **192x192 px**, so each of the 9 cells is exactly `64x64` — the same as `C.SLOT` — meaning no runtime scaling is needed for the slice math to line up cleanly (Love2D still scales whatever the final sprite size is, same as today).
- Gradient formula, per pixel `(x, y)`:
  - `R = 255 * x / (W-1)` (increases left → right)
  - `B = 255 * y / (H-1)` (increases top → bottom)
  - `G = 60` (fixed, just keeps colors from looking washed out)
  - This makes every cell a visually distinct color, and — critically — makes a 90°-rotated piece look *wrong* (the gradient direction inside that piece no longer matches its neighbors), which a flat color never would.
- Generated once by `scripts/generate_puzzle_gradient.py` (uses Pillow, already available in this environment) and the resulting PNG is committed like any other asset — it is not regenerated at runtime.

### `lua/core/sprite.lua`
- Add an optional `self.quad` field (a `love.graphics.Quad`, or `nil`).
- In `Sprite:draw()`, when `self.quad` is set, draw `(self.image, self.quad, ...)` and scale using the quad's own width/height (not the full image's) so a single cell fills the sprite's `width`/`height` box exactly like whole-image sprites do today.
- When `self.quad` is `nil`, behavior is unchanged (whole image, or flat-color rectangle) — fully backward compatible with `player.png` and any test that builds a `Sprite` directly.

### `game/jigsaw_piece.lua`
- `JigsawPiece.new(x, color, visual)`:
  - `color` keeps its current meaning/behavior (tint / flat-rectangle fallback) so every existing direct call (including all the ones in `tests/test_jigsaw.lua`) keeps working unchanged.
  - New optional 3rd arg `visual = { image = ..., quad = ... }`. When present, `self.sprite.image` and `self.sprite.quad` are set from it and the piece renders as that image cell instead of a flat rectangle.
- Nothing else about pickup/drop/rotate/centre changes.

### `game/jigsaw_box.lua`
- Loads `assets/puzzles/gradient_3x3.png` once (e.g. in `JigsawBox.new`), reads its actual width/height, and builds a `3x3` grid of `love.graphics.newQuad(col * cellW, row * cellH, cellW, cellH, imgW, imgH)` (9 quads, `cellW = imgW/3`, `cellH = imgH/3` — computed from the real image, so this also works against the headless test stub, which reports a fixed 120x120 image and yields three clean 40x40 quads).
- `self.pieces_to_spawn` becomes a list of 9 entries (one per grid cell), each carrying `{ image = puzzle_image, quad = cell_quad }`, **shuffled** (Fisher–Yates) once at construction time so the ejection order doesn't reveal the solved layout row-by-row.
- `_eject_next` is otherwise unchanged: same expanding-Manhattan-distance empty-slot search, same 0.3 s timer, same `"waiting" → "ejecting" → "done"` state machine — just now it calls `JigsawPiece.new(x, {1,1,1,1}, spec)` (white tint so the image isn't recolored) instead of `JigsawPiece.new(x, color)`.
- **Random initial orientation:** right after each piece is constructed in `_eject_next`, call `piece:rotate()` a random 0–3 times (`math.random(0, 3)`) so it spawns already rotated. This reuses the existing `JigsawPiece:rotate()` / `rotation_step` mechanic unchanged — the box just calls it a random number of times instead of leaving pieces at `rotation_step = 0`.
- Box itself (its own sprite/color/position) is unchanged.

## What stays the same
- Pickup, drop, grid-snap, and rotate mechanics for pieces (a piece can still be rotated with `R`; this is unchanged and is in fact why the gradient exists — rotation now visibly matters)
- No win/solve-check is introduced — the game today has no logic anywhere that validates pieces are in their "correct" grid slot/rotation, and this feature doesn't add one. Assumption: that stays out of scope here; only the visual/spawn side changes.
- Box placement, appearance, timing (0.3 s/piece), and its "waiting/ejecting/done" state machine
- Slot search / occupied-slot logic in both the box and the player's drop logic
- World size, camera, ground, `Scene`/`Drawer` architecture

## Open questions — resolved
These were flagged as assumptions in the initial draft and have since been confirmed with the user:

1. **Image size (192x192, 64px/cell) and gradient formula (R over x, B over y, fixed G).** Confirmed as designed.
2. **"Randomize the pieces" = shuffle ejection order *and* orientation.** Confirmed: both which of the 9 grid cells ejects 1st..9th (order) AND each piece's initial rotation (0/90/180/270°, via existing `rotate()`/`rotation_step`) are randomized. The scatter/landing-slot search algorithm itself is still untouched — only order and rotation are randomized, not landing position.
3. **Asset generation approach: committed Python/Pillow script producing a static PNG.** Confirmed.
4. **No solve/win detection is added.** Confirmed out of scope.
