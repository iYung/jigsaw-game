# HUD White Background Checklist

- [x] Task A — `game/scenes/game_scene.lua` — Remove the `love.graphics.newImage("assets/ui/panel_normal.png")` line from `GameScene:init` and delete `self._hud_panel` assignment (~line 252)
- [x] Task B — `game/scenes/game_scene.lua` — In `GameScene:_draw_hud`, replace the `love.graphics.draw(self._hud_panel, ...)` block with `love.graphics.rectangle("fill", box_x, box_y, box_w, box_h)` (color already set to white on the preceding line)
