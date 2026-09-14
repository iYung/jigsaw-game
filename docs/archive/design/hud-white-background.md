# HUD White Background

## Goal
Replace the gray `panel_normal.png` background of the contextual HUD text area with a solid white rectangle, making the hint text easier to read.

## Affected files
- `game/scenes/game_scene.lua` — `_draw_hud` method (lines ~619–654)

## What changes
- In `GameScene:_draw_hud`, replace the `love.graphics.draw(self._hud_panel, ...)` call with `love.graphics.rectangle("fill", box_x, box_y, box_w, box_h)` drawn with color `(1, 1, 1, 1)` (opaque white).
- The `self._hud_panel` image and the `love.graphics.newImage` call in `init` can be removed since nothing else uses it.

## What stays the same
- HUD positioning (bottom-left, 12 px margin, sized to fit hint text).
- Text color (`0.1, 0.1, 0.1` dark-near-black) and font.
- Padding, line-height calculations, and all multi-player offset logic.

## Open questions
None — the request is unambiguous.
