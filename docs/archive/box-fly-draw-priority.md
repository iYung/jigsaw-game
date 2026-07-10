# Box Fly Draw Priority Checklist

Design doc: `docs/design/box-fly-draw-priority.md`

- [x] Task A — `game/constants.lua` — Add a new priority constant
  `PRIORITY_BOX_FLYING = 20` (a value above the player's hardcoded priority
  of `10`, used in `game/scenes/game_scene.lua`'s `self.drawer:add(self.player, 10)`).
  Add a one-line comment noting it's for the box's `"flying"` pile→slot
  animation only. Export it from the module's returned table alongside
  `PRIORITY_PIECE`. No other file needs to change for this task.

- [x] Task B — `lua/core/drawer.lua` — Add a `Drawer:set_priority(sprite, priority)`
  method, following the existing style of `Drawer:remove(sprite)` (iterate
  `self.layers`, find the entry whose `.sprite == sprite`, set its
  `.priority = priority`), then re-sort `self.layers` the same way
  `Drawer:add` does (`table.sort(self.layers, function(a, b) return a.priority < b.priority end)`).
  If no matching entry is found, it's a no-op (mirrors `remove`'s behavior).
  Add test coverage in `tests/test_jigsaw.lua` (or a new `tests/test_drawer.lua`
  if that reads cleaner — check how `tests/test_basics.lua` registers test
  files with the runner and follow the same pattern if adding a new file):
  construct a `Drawer`, add two sprites at priorities `5` and `10`, call
  `set_priority` to move the first one above the second (e.g. to `20`), then
  assert `drawer.layers` draws in the new order (the sprite that was first is
  now last). Also test the no-op case: calling `set_priority` on a sprite
  never added to the drawer doesn't error and doesn't touch `self.layers`.

- [x] Task C — `game/scenes/game_scene.lua` — Depends on Task A and Task B
  (needs `C.PRIORITY_BOX_FLYING` and `Drawer:set_priority` to exist first;
  run this task after A and B are both done). Two changes:
  1. In `GameScene:_spawn_box()` (~line 197), the box created via
     `JigsawBox.new(cx, cy, self.world_w, self.world_h, self.pile:top_position())`
     — the one with `spawn_from`, which starts in `"flying"` state — change
     `self.drawer:add(box, C.PRIORITY_PIECE)` to
     `self.drawer:add(box, C.PRIORITY_BOX_FLYING)`.
  2. In `GameScene:update()` (~line 214-217), the loop
     `for _, box in ipairs(self.boxes) do box:update(dt, self.pieces) end`
     needs to detect when a box transitions out of `"flying"` this frame and
     restore its normal layer:
     ```lua
     for _, box in ipairs(self.boxes) do
         local was_flying = box.state == "flying"
         box:update(dt, self.pieces)
         if was_flying and box.state ~= "flying" then
             self.drawer:set_priority(box, C.PRIORITY_PIECE)
         end
     end
     ```
  Do not change the other two `self.drawer:add(box, C.PRIORITY_PIECE)` call
  sites (`on_enter`'s non-`spawn_from` starter box, and the save-restore
  path) — those boxes never start in `"flying"`, per the design doc.

- [x] Task D — `tests/test_jigsaw.lua` — Depends on Task C. Add test coverage
  for the game-scene-level behavior (not just the Drawer unit behavior from
  Task B): a box spawned via the pile's `spawn_from` path is added to the
  drawer at `C.PRIORITY_BOX_FLYING`, and once its `state` flips from
  `"flying"` to `"waiting"` (drive it with `box:update(C.BOX_FLY_DURATION + 1.0, pieces)`
  or via a full `GameScene:update()` call, whichever matches how nearby tests
  in this file already drive `GameScene`), its drawer entry's priority is
  back to `C.PRIORITY_PIECE`. Follow the existing test style/assertions in
  this file (see the `C.PRIORITY_PIECE` assertion around line ~1296 for the
  pattern of reading a sprite's priority back out of `drawer.layers`).
