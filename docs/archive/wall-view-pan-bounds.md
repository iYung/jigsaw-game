## Wall View Pan Bounds Checklist

- [x] Fix pan clamp in wall view — `game/scenes/game_scene.lua` — in `GameScene:update()`, replace the `math.max(0, math.min(self.world_w, ...))` / `math.max(0, math.min(self.world_h, ...))` clamps for `wall_pan1` and `wall_pan2` with bounds derived from the bounding box of `self.completed_puzzles`. When the shelf is empty, fall back to `[0, world_w] × [0, world_h]`. Add a half-screen margin (`LOGICAL_W/2`, `LOGICAL_H/2`) on each side so the camera center can reach every edge of the shelf.
