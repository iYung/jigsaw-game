## Controller Select Plain Middle Checklist

- [x] Task A — `game/scenes/controller_select_scene.lua` — Remove the `local PANEL_SELECTED = ...` load at the top (line 12) since it will no longer be used
- [x] Task B — `game/scenes/controller_select_scene.lua` — In `draw()`, change the middle column's panel draw call to use `PANEL_NORMAL` instead of `PANEL_SELECTED` (line 215)
