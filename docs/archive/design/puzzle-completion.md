# Puzzle Completion

## Goal
Detect when the 3x3 jigsaw has been assembled correctly, and make the pieces disappear when it
has. Today, `JigsawPiece` only carries visual info (`image`/`quad`) — nothing on the piece records
which cell of the source image it belongs to, and nothing ever checks the pieces' arrangement.
Grounded pieces just sit in `GameScene.pieces` forever; there's no win condition.

## What "assembled correctly" means
Pieces are dropped on a world-space grid (snapped to `C.SLOT`) and can be placed anywhere in the
level, not just next to the box — so correctness has to be checked *relationally*, not against
fixed world coordinates. The puzzle is solved when:
1. All 9 pieces are grounded (none held, none mid-fade already).
2. Every piece's rotation is unrotated (`rotation_step == 0`).
3. The pieces' relative grid positions match their source-image (row, col) layout — i.e. there's a
   single constant offset `(ox, oy)` such that every piece's grid position equals
   `(piece.col + ox, piece.row + oy)`. This makes the check independent of *where* in the world the
   player assembled the puzzle.

Because held pieces are already excluded from `GameScene.pieces` (per the prior held-item-priority
change, `docs/archive/held-item-draw-priority.md`), a simple `#pieces == 9` count check is enough to
guarantee nothing is currently held — no extra state check needed for that part.

## Affected files
- `game/constants.lua` — add `C.PIECE_FADE_DURATION = 0.5` (seconds) and `C.PUZZLE_PIECE_COUNT = 9`.
- `game/jigsaw_box.lua` — `_eject_next`'s spec table (and the `pieces_to_spawn` entries built in
  `JigsawBox.new`) gain `row`/`col` fields alongside `image`/`quad`, so each piece can carry its
  correct-cell identity through to `JigsawPiece.new`.
- `game/jigsaw_piece.lua`:
  - `JigsawPiece.new` reads `visual.row` / `visual.col` (in addition to `visual.image`/`visual.quad`)
    and stores them as `self.row`, `self.col`.
  - New `JigsawPiece:start_vanish()` — sets `self.state = "vanishing"` and
    `self.fade_timer = C.PIECE_FADE_DURATION`.
  - New `JigsawPiece:update_fade(dt)` — decrements `fade_timer`, writes the resulting ratio into
    `self.sprite.color[4]` (alpha), and returns `true` once the timer reaches zero (fade complete).
- `game/jigsaw_solver.lua` (**new file**) — exports `is_assembled(pieces)` implementing the check
  described above (count == `C.PUZZLE_PIECE_COUNT`, all `rotation_step == 0`, consistent relative
  offset). Kept separate from `game_scene.lua` so the arrangement logic is independently testable.
- `game/scenes/game_scene.lua`:
  - Requires `game/jigsaw_solver`.
  - After `self.player:update(...)`, if not already solved and `JigsawSolver.is_assembled(self.pieces)`
    is true, sets `self.puzzle_solved = true` and calls `piece:start_vanish()` on every piece.
  - Each frame, drives `update_fade(dt)` on any piece in the `"vanishing"` state; once it returns
    `true`, removes the piece from `self.pieces`, from `self.drawer` (`drawer:remove(piece)`), and
    from `self.pieces_in_drawer`.
- `tests/test_jigsaw.lua` — add coverage (see below).

## What changes
- Pieces carry a permanent `(row, col)` identity from spawn, set once in `JigsawBox` and never
  mutated afterward (rotating/moving a piece doesn't change what it *is*, only where/how it sits).
- A new `game/jigsaw_solver.lua` module owns the "is this solved?" question, decoupled from scene
  bookkeeping.
- `JigsawPiece` gains a third lifecycle state, `"vanishing"`, between `"grounded"` and removal —
  driven by a fade-out timer that fades `sprite.color`'s alpha to 0 over `C.PIECE_FADE_DURATION`
  seconds before the piece is dropped from the scene's arrays.
- `GameScene:update` gains a one-shot solved check (guarded by `self.puzzle_solved` so it only
  fires once) and a per-frame fade-update pass over vanishing pieces.

## What stays the same
- No fixed "assembly area" — pieces can be solved anywhere in the world, matching how the box
  already scatters them freely.
- `JigsawBox`'s 3x3 loop bounds, shuffle logic, and ejection animation are untouched — only the
  `spec` table it builds gains two extra fields.
- Held-piece drag/drop/rotate behavior, and the `"grounded"`/`"held"` states, are unchanged.
- No end-of-puzzle message/HUD text is added — pieces disappearing *is* the only feedback for now.
- `Sprite:draw()` needs no changes — alpha fade works through the existing `self.color` table it
  already passes to `love.graphics.setColor`.

## Open questions
None — resolved with the user before writing this doc:
- Correctness = relative position **and** rotation (not absolute world position, not
  position-only-ignoring-rotation).
- Disappearance = brief fade-out (`~0.5s`), not instant removal.
- No additional completion feedback (message/sound) for this pass.
