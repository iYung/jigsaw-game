# Wall View Pan Checklist

- [x] Task A — `game/constants.lua` — Add `WALL_VIEW_ZOOM = 0.35` and `WALL_VIEW_PAN_SPEED = 400` constants to the return table
- [x] Task B — `game/player.lua` — Add `Player:movement_dir()` method that returns `{dx, dy}` (each -1, 0, or 1) by reading `self.input:is_down("left"/"right"/"up"/"down")` with no side effects
- [x] Task C — `game/scenes/game_scene.lua` — On wall-view enter (`_toggle_wall_view`), initialize `self.wall_pan1` / `self.wall_pan2` tables `{x, y}` from `_compute_wall_target()` centre (or player centre if shelf empty); remove the per-frame `_compute_wall_target()` call from `update()` (wall_target1/wall_target2 and the stale-target re-check are no longer needed)
- [x] Task D — `game/scenes/game_scene.lua` — In `update()`, when `view1 == "wall"`, call `self.player:movement_dir()` and advance `self.wall_pan1.x/y` by `C.WALL_VIEW_PAN_SPEED * dt`, clamped to `[0, self.world_w]` × `[0, self.world_h]`; pass `{x = self.wall_pan1.x, y = self.wall_pan1.y, zoom = C.WALL_VIEW_ZOOM}` to `self.camera:follow()`; mirror for camera2/wall_pan2 in 2P
