## Start Scene Image & Layout Checklist

- [x] Task A — `assets/ui/` — Copy `start_logo.png`, `menu_btn.png`, `menu_btn_selected.png` from `/root/wip/assets/images/` into `assets/ui/`
- [x] Task B — `game/scenes/start_scene.lua` — Remove module-level image constants (PANEL_NORMAL, PANEL_SELECTED, BACKGROUND) and load them as instance fields inside `on_enter()` alongside the new logo and button images; add explicit font load
- [x] Task C — `game/scenes/start_scene.lua` — Replace `love.graphics.printf("Jigsaw", ...)` title draw with a centered draw of `self._img_logo` at y=140
- [x] Task D — `game/scenes/start_scene.lua` — Replace scaled-panel button draw with natural-size `self._img_btn` / `self._img_btn_sel` draw; update `ITEM_H` from 60 → 54 and remove sx/sy scale args from all `love.graphics.draw` panel calls
