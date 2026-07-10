# Cell Hover Highlight

## Goal

Give the player visual feedback for which grid cell they are currently
standing over, mirroring the existing "ghost preview" feedback shown when
holding a piece — but shown only when the player is **not** holding a piece.

Note: this game has no mouse input (WASD-only, no `love.mouse` usage
anywhere). The existing "hover" the player is referencing is the
piece-drop ghost preview in `player.lua`, which is driven by the player
sprite's own position, not a cursor. This feature follows that same model:
"hover" = the grid cell under the player's current position.

## Affected files

- `game/player.lua` — `Player:draw()` (lines 144-153) and `Player:drop_target()`
  (lines 135-142)
- `tests/test_jigsaw.lua` — add coverage alongside the existing
  `drop_target()` tests (lines 217-246) and `Player:draw()` draw-order test
  (lines 1099-1134)

## What changes

- `Player:draw()` gains a branch for the "not holding a piece" case:
  - When `self.held_piece == nil`, draw a semi-transparent fill rectangle
    over the grid cell the player currently occupies, using the same
    snap-to-grid math already computed by `Player:drop_target()`
    (`snap_x`, `snap_y`, sized `C.SLOT` x `C.SLOT`).
  - When `self.held_piece ~= nil`, behavior is unchanged (draws the piece
    ghost preview as today).
  - `Player:drop_target()` is reused as-is — its snap math already answers
    "what grid cell corresponds to the player's current centre position"
    regardless of whether a piece is held, so no new snapping logic is
    needed.
- Highlight is drawn unconditionally for whatever cell the player is over
  (matching `drop_target()`'s existing unconditional behavior) — no check
  against board bounds, occupied slots, etc.
- Visual style: a low-alpha white fill rectangle,
  `love.graphics.setColor(1, 1, 1, 0.25)` then
  `love.graphics.rectangle("fill", snap_x, snap_y, C.SLOT, C.SLOT)`,
  followed by `love.graphics.setColor(1, 1, 1, 1)` to restore state — same
  reset-color convention used elsewhere in `game_scene.lua`'s floor draw
  and `puzzle_pile.lua`. No shader involved, consistent with the recent
  removal of the rounded-corner shader from active-piece rendering
  (commit `1d17823`).

## What stays the same

- No new input system — everything is still keyboard/WASD driven, no
  `love.mouse` introduced.
- `Player:drop_target()`'s signature and return values are unchanged; it's
  called from an additional call site but its behavior is untouched.
- Piece-ghost preview behavior/appearance when holding a piece is
  unchanged.
- Draw order is unchanged for the held-piece case (ghost → player sprite →
  held piece). The new highlight, when shown, draws in the same "before
  player sprite" slot the ghost currently occupies.

## Open questions

None outstanding — resolved with the user before writing this doc:
- Hover source: player-position-based (not mouse). ✅
- Visual style: semi-transparent fill (not outline). ✅
- Scope: highlight any cell the player is over, not just valid board
  slots. ✅
