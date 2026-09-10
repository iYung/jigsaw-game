## Fix Wall-View Stale Target Checklist

- [x] Task A — `game/scenes/game_scene.lua` — Extract the bounding-box +
  zoom computation from `_toggle_wall_view` into a new private method
  `GameScene:_compute_wall_target()`. The method should:
  - Iterate `self.completed_puzzles`, compute `min_x/min_y/max_x/max_y`
    exactly as the current inline code does.
  - Return `nil` when `self.completed_puzzles` is empty.
  - Otherwise return `{x = center_x, y = center_y, zoom = zoom}` using the
    same `math.min(1.0, 0.9 * math.min(LOGICAL_W/bbox_w, LOGICAL_H/bbox_h))`
    formula.
  - Update `_toggle_wall_view` to call `self:_compute_wall_target()` instead
    of doing the computation inline; keep the early-return-on-nil behavior
    (i.e. if `_compute_wall_target()` returns nil, don't enter wall view).
  Independent — no dependencies on Task B.

- [x] Task B — `game/scenes/game_scene.lua` — In `GameScene:update()`, where
  the camera follow target is set, recompute `wall_target1` (and
  `wall_target2` in 2-player mode) every frame while the view is `"wall"`,
  by calling `self:_compute_wall_target()`. Only update the stored target if
  `_compute_wall_target()` returns non-nil (guards against the edge case where
  `completed_puzzles` is emptied somehow). Current code to change (around line
  381):
  ```lua
  if self.view1 == "wall" then
      self.camera:follow(self.wall_target1, 0.85)
  ```
  Change to:
  ```lua
  if self.view1 == "wall" then
      local t = self:_compute_wall_target()
      if t then self.wall_target1 = t end
      self.camera:follow(self.wall_target1, 0.85)
  ```
  And same pattern for `view2`/`wall_target2`/`camera2`.
  Depends on Task A (needs `_compute_wall_target` to exist).

- [x] Task C — `tests/test_scene.lua` — Add a regression test after the
  existing `_toggle_wall_view` tests (~line 236) that verifies the dynamic
  target update:
  1. Enter wall view with one synthetic `completed_puzzles` entry.
  2. Add a second entry to `completed_puzzles` (simulating a puzzle completing
     while in wall view).
  3. Call `gs:update(0.016, ...)` (or directly call the update's camera-follow
     block, whatever is simpler in the headless harness).
  4. Assert that `wall_target1` has shifted to include the second entry's
     bounding box (the `x`/`y` center should now reflect both entries, not
     just the first).
  Depends on Tasks A and B.
