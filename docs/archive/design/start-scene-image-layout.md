# Start Scene — Image & Layout Overhaul

## Goal

Modernise `game/scenes/start_scene.lua` to load images the same way `/root/wip`'s launch scene
does: lazy loading inside `on_enter`, a proper logo image for the title, and natural-size button
images in place of the stretched 64×64 panel tiles.

## Affected files

- `game/scenes/start_scene.lua` — main change
- `assets/ui/start_logo.png` — **new asset** (to be created/provided; see Open Questions)
- `assets/ui/menu_btn.png` — **new asset** (can be copied from `/root/wip/assets/images/menu_btn.png`)
- `assets/ui/menu_btn_selected.png` — **new asset** (can be copied from wip)

## What changes

### 1. Image loading — module-level → `on_enter`

Currently the three images are created at `require()` time (module top-level constants):

```lua
local PANEL_NORMAL   = love.graphics.newImage("assets/ui/panel_normal.png")
local PANEL_SELECTED = love.graphics.newImage("assets/ui/panel_selected.png")
local BACKGROUND     = love.graphics.newImage("assets/backgrounds/start_bg.png")
```

These will move into `StartScene:on_enter()` as instance fields, exactly as wip does:

```lua
function StartScene:on_enter()
    self._img_bg      = love.graphics.newImage("assets/backgrounds/start_bg.png")
    self._img_logo    = love.graphics.newImage("assets/ui/start_logo.png")
    self._img_btn     = love.graphics.newImage("assets/ui/menu_btn.png")
    self._img_btn_sel = love.graphics.newImage("assets/ui/menu_btn_selected.png")
    ...
end
```

### 2. Title — text printf → logo image

Replace:
```lua
love.graphics.printf("Jigsaw", 0, 160, LOGICAL_W, "center")
```

With a centered draw of the logo image (wip places its logo at y=140; we'll do the same):
```lua
local iw = self._img_logo:getWidth()
love.graphics.draw(self._img_logo, (LOGICAL_W - iw) / 2, 140)
```

### 3. Buttons — scaled panel tiles → natural-size images

**Current:** `panel_normal.png` / `panel_selected.png` are 64×64 tiles scaled to `ITEM_W × ITEM_H`
(300×60) with an sx/sy scale factor.

**New:** `menu_btn.png` / `menu_btn_selected.png` are 300×54 pixels (same as wip). Drawn at
natural size — no sx/sy scaling needed. `ITEM_H` constant updates from 60 → 54.

Button draw becomes:
```lua
local img = (i == self.selected) and self._img_btn_sel or self._img_btn
love.graphics.draw(img, x, y)
love.graphics.printf(label, x, y + (ITEM_H - font_h) / 2, ITEM_W, "center")
```

The `_item_rect` helper and mouse hit-testing remain unchanged; only the height constant drops
from 60 → 54.

### 4. Font loading

wip loads its button font explicitly in `on_enter` with a size. Jigsaw's start scene currently
relies on whatever the default LÖVE font is. This PR will add an explicit `love.graphics.newFont`
call for button labels in `on_enter` to match wip's pattern, using the same size as the default
(~13px) so visuals are unchanged unless the user later adjusts it.

## What stays the same

- Scene logic (navigation, confirm, `_next_selectable`, player-count toggle, save detection)
- Input handling
- Background image (`start_bg.png`)
- Music (`Sound.play_music("menu")`)
- Overall menu item list and ordering
- `_item_rect` geometry (x centering, y positions, gap)
- `panel_normal.png` / `panel_selected.png` assets remain on disk (just no longer used by this scene)

## Open questions

_None — all resolved._

- **Logo asset**: copy `start_logo.png` from `/root/wip/assets/images/` (placeholder; can be swapped for a jigsaw-specific wordmark later).
- **Button images**: copy `menu_btn.png` and `menu_btn_selected.png` from `/root/wip/assets/images/`.
