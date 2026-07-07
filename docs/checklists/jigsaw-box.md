# Jigsaw Box Checklist

- [x] Task A — `game/jigsaw_box.lua` — **new file**: implement the full JigsawBox entity.
  - `Sprite` at SLOT×SLOT size, color `{1, 0.75, 0.2, 1}` (gold/orange)
  - Fields: `state` ("waiting"/"ejecting"/"done"), `pieces_to_spawn` (list of 3 color tables), `spawn_timer` (number), `spawned` (list of already-ejected pieces)
  - `JigsawBox.new(x, y)` — creates sprite, sets state to "waiting", initialises queue with 3 piece color specs
  - `box:interact()` — "waiting" → "ejecting", sets `spawn_timer = 0` so first piece fires immediately
  - `box:update(dt, pieces)` — when "ejecting": decrement timer; when ≤ 0, call `_eject_next(pieces)`; reset timer to 0.3
  - `box:_eject_next(pieces)` — find nearest empty SLOT-aligned slot (Manhattan distance search in all 4 directions, no y constraint); create `JigsawPiece` there; append to `pieces` and `self.spawned`; if queue now empty, set state to "done"
  - `box:centre()` — returns `{x = sprite.x + C.U, y = sprite.y + C.U}`
  - `box:draw()` — delegates to `self.sprite:draw()`
  - Slot search: iterate Manhattan distance d = 1, 2, 3, … ; for each d enumerate all (dx, dy) with |dx|+|dy| == d in left-to-right order; a slot at `(bx + dx*SLOT, by + dy*SLOT)` is empty if no piece in `pieces` is grounded there

- [x] Task B — `game/player.lua` — extend interact to check for a box.
  - Change `update` signature: `player:update(dt, pieces, box)` — `box` may be nil
  - In the `interact` branch (no held piece, no nearby grounded piece found): if `box` is non-nil and `box.state == "waiting"` and distance from player centre to `box:centre()` ≤ `1.5 * C.U`, call `box:interact()`
  - No other changes to player logic

- [x] Task C — `game/scenes/game_scene.lua` — remove pre-spawned pieces; add box; wire update/draw. **Depends on Task A and Task B.**
  - `require` JigsawBox at top
  - In `on_enter`: remove the 3 `JigsawPiece.new(…)` calls; set `self.pieces = {}`
  - Create `self.box = JigsawBox.new(5 * C.SLOT, 3 * C.SLOT)` and add `self.box` to drawer at z=5
  - In `update`: call `self.box:update(dt, self.pieces)` before player update; for each piece in `self.pieces`, if it is not already in the drawer, add it at z=5; after box update, if `self.box.state == "done"`, remove box sprite from drawer (set a flag so this only runs once)
  - Change player update call to `self.player:update(dt, self.pieces, self.box)`
  - When `box.state == "done"`, pass `nil` for box in subsequent player updates (or keep passing the box — player already checks `box.state == "waiting"` so it won't re-trigger)

- [x] Task D — `tests/test_jigsaw.lua` — add box tests. **Depends on Task A.**
  - Test: `JigsawBox.new` creates a box in state "waiting" with 3 items in the queue
  - Test: `box:interact()` transitions state to "ejecting" and sets timer ≤ 0
  - Test: `box:update(dt, pieces)` with dt large enough fires `_eject_next` and appends a piece to `pieces`
  - Test: after 3 ejects the state is "done" and pieces has 3 entries
  - Test: slot search skips occupied slots — place a fake grounded piece at distance-1 slot, verify the new piece lands at a different slot
