## Background Wall Fill Checklist

- [x] Task A — `game/constants.lua` — add `BG_WALL_COLOR = { 220/255, 20/255, 20/255 }` constant and expose it in the return table
- [x] Task B — `game/scenes/game_scene.lua` — replace the `self.background` drawable with a closure-based version that draws a solid `BG_WALL_COLOR` rect from `shelf_row_bottom - LOGICAL_H` to `C.BG_OFFSET_Y` before drawing the image (only when `fill_top < C.BG_OFFSET_Y`)
