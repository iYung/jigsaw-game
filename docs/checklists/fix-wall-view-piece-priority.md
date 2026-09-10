## Fix Wall-View Piece Priority Checklist

- [x] Task A — `game/jigsaw_box.lua` — In `_eject_next` (around line 139, where
  `out_of_bounds` is computed), add a second exclusion condition for the wall
  tile's reserved cell. The wall tile is always at `(self.world_w - C.SLOT, 0)`.
  Change:
  ```lua
  local out_of_bounds = tx < 0 or tx >= self.world_w or ty < 0 or ty >= self.world_h
  ```
  to:
  ```lua
  local out_of_bounds = tx < 0 or tx >= self.world_w or ty < 0 or ty >= self.world_h
  local is_reserved = (tx == self.world_w - C.SLOT and ty == 0)
  ```
  And change the guard from `if not occupied and not out_of_bounds` to
  `if not occupied and not out_of_bounds and not is_reserved`.
  No other changes to `_eject_next` or `JigsawBox`. Independent — no
  dependencies.

- [x] Task B — `tests/test_jigsaw.lua` — Add a test (after the existing
  `_eject_next` / slot-search tests, around line 800–850 where the box ejection
  tests live) that confirms no ejected piece lands on the wall tile's cell.
  Use `new_easy_box` (or a direct `JigsawBox.new`) with the box placed
  immediately below the wall tile (e.g. `x = 19 * C.SLOT, y = C.SLOT` on a
  `20 * C.SLOT`-wide world), call `box:interact()` then drive `box:update(dt,
  pieces)` enough times to eject all pieces, then assert that none of the
  pieces in `pieces` have `sprite.x == 19 * C.SLOT and sprite.y == 0`.
  Depends on Task A (without the fix the test would fail by design).
