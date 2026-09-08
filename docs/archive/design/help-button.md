# Help Button

## Goal

Add a world-space interactable tile at the bottom-left corner of the floor that, when activated, toggles "help mode". In help mode every grounded piece (and the held piece, if any) is overlaid with a semi-transparent colour:

- **Green** — piece has ≥1 correct same-puzzle neighbor connection and 0 incorrect ones
- **Red** — piece has ≥1 incorrect same-puzzle neighbor connection
- **No highlight** — piece has no physically adjacent same-puzzle neighbors (isolated)

"Correct connection" between pieces A and B: same `rotation_step` k, and the rotated grid origin matches (`A.sprite.x/SLOT − gx_A == B.sprite.x/SLOT − gx_B`, same for y, where `gx = rotate_cell(row, col, k)`). This is exactly the pairwise subset of `JigsawSolver.is_assembled`.

Only pieces from the same puzzle (`path` field) can form a connection — pieces from different puzzles are ignored even if physically adjacent.

## Affected files

| File | Role |
|---|---|
| `game/help_tile.lua` | New. World-space interactable, mirrors `wall_view_tile.lua`. |
| `game/scenes/game_scene.lua` | Wire in `HelpTile`; add `help_mode` flag; extend `draw()` with world-space overlay; update hint text; include tile in `_spawn_box` occupancy check. |

## What changes

### `game/help_tile.lua` (new)
- Invisible footprint `Sprite` at the given position for occupancy checks.
- `:interact()` calls `on_press` callback.
- `:draw()` renders a magenta/pink square (distinct from WallViewTile's blue and PuzzlePile's orange); when help mode is active the colour is brighter to signal the "on" state.
- Exposes `self.active` boolean set by `GameScene` so the tile can render differently when help mode is on.

### `game/scenes/game_scene.lua`
- In `on_enter`: construct `HelpTile` at `(0, WORLD_H − C.SLOT)`, add to drawer at `C.PRIORITY_PIECE`, store as `self.help_tile`. Pass callback `function() self:_toggle_help() end`.
- Add `self.help_mode = false`.
- Add `GameScene:_toggle_help()`: flips `self.help_mode`, sets `self.help_tile.active`.
- In `_spawn_box`: include `self.help_tile` in the occupancy check alongside `self.wall_tile`.
- In `draw()`: after the main camera-space draw, re-enter camera transforms and call `self:_draw_help_overlay()` (single-player path; in 2P, overlay with camera1 then camera2, each over the same drawer area).
- Add `GameScene:_draw_help_overlay()`: iterates `self.pieces` (+ `player.held_piece` if any); for each piece computes `correct` and `incorrect` counts by scanning all other same-puzzle pieces; draws a coloured `love.graphics.rectangle("fill", ...)` at each piece's world position.
- Update HUD hint string to include `E: help (↙)`.

## What stays the same

- `JigsawSolver` — no changes; help uses its `rotate_cell` logic inline.
- `JigsawPiece` — no changes; overlay is drawn by `GameScene`, not by the piece itself.
- Save/load — `help_mode` is session-only, not persisted.
- All other scenes, player, box, pile — unchanged.

## Open questions

None outstanding.
