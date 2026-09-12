# Wall View — Pannable Camera with Fixed Zoom

## Goal

Replace the current wall-view camera behaviour (bounding-box zoom, frozen player) with a
fixed zoom level and free camera panning driven by the player's movement controls.

## Affected files

- `game/scenes/game_scene.lua` — camera update loop, `_toggle_wall_view`, `_compute_wall_target`
- `game/constants.lua` — new `WALL_VIEW_ZOOM` and `WALL_VIEW_PAN_SPEED` constants
- `game/player.lua` — expose movement direction while frozen so GameScene can pan the camera

## What changes

### Fixed zoom

`_compute_wall_target` currently derives zoom from the bounding box of all completed puzzles:
```lua
zoom = math.min(1.0, 0.9 * math.min(LOGICAL_W / bbox_w, LOGICAL_H / bbox_h))
```
This shrinks unboundedly as puzzles accumulate.

Replace with a single constant `WALL_VIEW_ZOOM = 0.35` (showing ~3650 × 2060 world-space px
in the 1280 × 720 viewport). The value lives in `constants.lua` so it is easy to tune.

### Pannable camera

Currently wall view freezes the player entirely and drives the camera to a fixed target
recomputed each frame.  The new behaviour:

1. **On enter**: initialize a `wall_pan_x / wall_pan_y` pair (per-player in 2P) to the
   bounding-box centre of completed puzzles (same as before), falling back to the player's
   own position when the shelf is empty (so the view is still usable).  Store this on
   GameScene as `self.wall_pan1` / `self.wall_pan2` (tables `{x, y}`).

2. **While in wall view**: read the player's directional input and advance `wall_pan_x/y`
   by `WALL_VIEW_PAN_SPEED * dt` (in world-space pixels/s, recommended starting value: 400).
   The pan position is clamped to the world bounds so the camera can't fly off into empty space.

3. **Camera target**: `camera:follow({x = wall_pan.x, y = wall_pan.y, zoom = C.WALL_VIEW_ZOOM}, 0.85)`
   — same lerp as normal play, same API, no new camera methods needed.

4. **Interact to exit**: the player remains "frozen" in the sense that it cannot pick up/drop
   pieces or move its world-space position.  The interact button (`E` / gamepad A) pressed near
   the wall tile still exits wall view, exactly as before.

5. **Input routing**: `Player:update()` already returns early when `frozen == true` after
   checking for wall/help tile interaction.  We need movement input to be readable by GameScene
   even when the player is frozen.  Add a `Player:movement_dir()` method that returns
   `{dx, dy}` (each ±1 or 0) by sampling `input:is_down()` directly — no state mutation,
   safe to call from GameScene before or after `player:update()`.

6. **No change to `_compute_wall_target`**: the method is still used on wall-view entry to
   pick the starting pan position.  It continues to return `nil` when the shelf is empty
   (pan starts at the player centre instead).

### 2P split-screen

Each player gets their own `wall_pan1` / `wall_pan2`; each pan is controlled by that
player's own input, mirroring the existing independent view1/view2 toggle.

## What stays the same

- The wall tile object, its position, and the interact radius are unchanged.
- `camera:follow()` API is unchanged.
- The "frozen" player contract (no piece pickup/drop, no world movement) is unchanged.
- Saving/loading is unaffected — `wall_pan` is transient UI state, not persisted.
- 1P and 2P code paths for wall view remain symmetric.

## Open questions

None — proceeding with implementation.
