## Goal

Fix the wall-view tile so it reliably toggles the camera to show all completed
puzzles when the player presses E on it. Currently the feature silently fails
when a puzzle piece occupies the wall tile's grid cell.

## Root cause

`JigsawBox._eject_next` places pieces on any unoccupied, in-bounds grid cell
starting from the box's position and expanding outward. It excludes other
pieces but does **not** exclude the wall tile's cell
`(WORLD_W - C.SLOT, 0) = (1216, 0)`. If a box spawns at or near that column
(e.g. `(1216, 64)` — one row below the tile), the very first candidate at
`d = 1` is `(1216, 0)`: the tile's own cell. A piece placed there is
indistinguishable from any other grounded piece.

In `player.lua`'s non-frozen interact chain the order is:
1. Pick up nearest grounded piece (if in range)
2. Interact with nearest waiting box
3. Interact with pile
4. Interact with wall tile

Step 1 runs before step 4. When a piece sits on the tile cell and the player
stands there, `self.held_piece` is set at step 1. The wall-tile check at step 4
guards on `self.held_piece == nil`, so it never fires. The wall view toggle is
inaccessible until the player moves the obstructing piece away — which they
may not realise is the issue.

## Affected files

- **`game/jigsaw_box.lua`** — `_eject_next`: add the wall tile's cell to the
  exclusion check. The wall tile position is always `(world_w - C.SLOT, 0)`;
  both `self.world_w` and `C.SLOT` are already available inside `_eject_next`.
  One additional `or` clause alongside the existing `out_of_bounds` check:
  `local is_reserved = (tx == self.world_w - C.SLOT and ty == 0)`.

- **`tests/test_jigsaw.lua`** — add a test confirming that `_eject_next` never
  places a piece at `(WORLD_W - C.SLOT, 0)`, even when the box is immediately
  below that cell.

## What changes

- Pieces ejected from a box can no longer land on the wall tile's cell.
- The wall-view toggle reliably fires when the player stands on the tile and
  presses E, regardless of how many pieces exist in the world.

## What stays the same

- Every other piece placement rule (out-of-bounds, occupied-by-piece) is
  unchanged.
- The pile's cell is NOT added as a reserved position in this fix — a separate
  investigation can decide if that matters.
- `player.lua`'s interaction order is unchanged; the fix is in the source of
  the conflict, not the symptom.
- Wall-tile toggle logic (`_toggle_wall_view`, camera lerp, frozen state) is
  untouched.

## Open questions

None — root cause is confirmed, fix is targeted.
