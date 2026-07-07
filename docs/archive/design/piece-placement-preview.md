# Piece Placement Preview

## Goal
While the player is holding a jigsaw piece (`player.held_piece` set, piece `state == "held"`), draw a
faint (low-alpha) copy of that piece's own artwork on the ground at the exact spot it would land if
the player pressed interact right now. This is a pure "drop preview" — it mirrors whatever
`Player:update`'s interact-drop branch would compute, with no notion of a "correct" solved position.

Today `Player:update` (`game/player.lua:34-58`) only computes the snap target (`target_x/y`,
`snap_x/y`) at the moment interact is pressed, purely to perform the drop. Nothing computes that
target on other frames, and nothing renders a preview. `Player:draw()` (`game/player.lua:116-121`)
just draws `self.sprite` then `self.held_piece` at its carried (floating) position.

## Affected files
- `game/player.lua` — factor the snap-target math (`game/player.lua:36-40`) out of the interact
  handler into a small reusable method (e.g. `Player:drop_target()`), so both the actual drop and the
  new preview use identical math and never drift apart. `Player:draw()` calls the new ghost-draw step
  whenever `self.held_piece` is set.
- `game/jigsaw_piece.lua` — add a way to draw the piece's sprite at an arbitrary position and reduced
  alpha without mutating the piece's real state (`self.sprite.x/y`, `self.state`). E.g.
  `JigsawPiece:draw_ghost(x, y)`, which temporarily swaps `sprite.x/y` and `sprite.color[4]`, draws,
  and restores them.
- `tests/test_jigsaw.lua` — add coverage for the extracted `Player:drop_target()` snap math and for
  `JigsawPiece:draw_ghost` leaving the piece's real state untouched.

## What changes
- New `Player:drop_target()` returns `{ x, y, snap_x, snap_y }` using the exact same centre/offset/
  floor-to-grid math currently inlined at `game/player.lua:36-40`. The existing interact handler is
  updated to call this instead of repeating the math.
- New `JigsawPiece:draw_ghost(x, y, alpha)` (default alpha e.g. `0.35`): saves current
  `sprite.x/y/color[4]`, sets them to the ghost position and faint alpha, calls `self.sprite:draw()`,
  then restores the saved values. Piece keeps its current held rotation (no forced rotation reset —
  there is no "correct" rotation concept here).
- `Player:draw()` — when `self.held_piece ~= nil`, compute `drop_target = self:drop_target()` and call
  `self.held_piece:draw_ghost(drop_target.snap_x, drop_target.snap_y)` *before* drawing the held piece
  itself, so the faint ground preview renders under the piece floating above the player's head.
- No occupancy check for the ghost — it renders at the snap target regardless of whether another piece
  currently occupies it; the existing occupied-slot block still runs only at actual drop time and can
  still reject the drop.

## What stays the same
- Pick-up / drop / rotate / grid-snap behavior and the occupied-slot check at drop time are unchanged.
- No jigsaw-solver, "anchor", or "correct position" concept is introduced — this feature has nothing to
  do with whether the puzzle is solved correctly; it is purely a drop-location preview.
- The held piece's carried position/rendering (floating above the player, current rotation) is
  unchanged.

## Open questions
None outstanding — confirmed with the user:
- Ghost = faint real artwork (not an outline), at the piece's current rotation, at low alpha (~0.35).
- Ghost shows only for the currently-held piece (not all unsolved pieces).
- Ghost position = wherever the piece would land if dropped right now (mirrors the existing snap-to-
  grid drop math), not any "correct" solved-puzzle position — this game has no fixed board/anchor and
  this feature does not add one.
