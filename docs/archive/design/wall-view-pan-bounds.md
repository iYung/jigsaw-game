# Wall View Pan Bounds Fix

## Goal

When entering wall view (top-right button), the camera should be able to pan to see all completed puzzles on the shelf. Currently the pan is hard-clamped to `[0, world_w] × [0, world_h]`, but the shelf grows **upward from y=0 into negative y territory**, so puzzles above the first row are unreachable.

## Affected files

- `game/scenes/game_scene.lua` — wall view update loop (pan clamp bounds)

## What changes

### Expand pan bounds to cover the full shelf

In `GameScene:update()`, replace the hardcoded `[0, world_w] × [0, world_h]` clamp with bounds derived from the actual completed-puzzle bounding box (plus a half-screen margin so the camera center can reach every edge of the wall).

When there are no completed puzzles, fall back to the current world bounds.

## What stays the same

- Zoom is fixed at `C.WALL_VIEW_ZOOM = 0.85` — no change.
- Entry point: wall view is still toggled by the WallViewTile button.
- Pan controls: WASD / stick still pan the camera at `C.WALL_VIEW_PAN_SPEED`.
- The camera-follow lerp (0.85) is unchanged.
- 2P split-screen: both `wall_pan1` and `wall_pan2` get the same treatment.
- `_compute_wall_target()` and `_toggle_wall_view()` are unchanged.

## Open questions

None — root cause is clear and the fix is self-contained.
