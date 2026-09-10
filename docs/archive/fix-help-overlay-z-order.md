## Fix Help Overlay Z-Order Checklist

- [x] Task A — `game/scenes/game_scene.lua` — In `on_enter()`, after adding `help_tile` to the drawer, create a `self.help_overlay_drawable` table with a `draw` method that calls `self:_draw_help_overlay()` when `self.help_mode` is true, then add it to the drawer at priority 9.

- [x] Task B — `game/scenes/game_scene.lua` — In `GameScene:draw()`, remove the three places where `_draw_help_overlay()` is called explicitly: the single-player `if self.help_mode then camera:attach() / _draw_help_overlay() / camera:detach() end` block, and the two `if self.help_mode then self:_draw_help_overlay() end` lines in the two-player path.
