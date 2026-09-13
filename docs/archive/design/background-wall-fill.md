## Goal

As completed puzzles accumulate on the wall, `shelf_row_bottom` grows increasingly negative (the shelf extends upward in world-space). The wall-view camera can pan to follow — but the background image (`world_bg.png`) is fixed in size, so panning far enough exposes its top edge, revealing empty space above it.

Fill the gap above the background image with a solid color that matches the image's top edge so the seam is invisible and the background appears to extend infinitely upward.

## Affected files

- `game/constants.lua` — add `BG_WALL_COLOR` constant
- `game/scenes/game_scene.lua` — change `self.background`'s draw closure to fill upward before drawing the image

## What changes

### `game/constants.lua`

Add:

```lua
-- Solid fill color matching the top edge of world_bg.png, used to extend
-- the background infinitely upward as the completed-puzzle wall grows.
local BG_WALL_COLOR = { 220/255, 20/255, 20/255 }
```

Expose it in the return table.

### `game/scenes/game_scene.lua`

The `self.background` drawable is currently a standalone table that only draws the image. It needs to become a closure over the scene so it can read `self.shelf_row_bottom` and compute how far upward to extend the fill.

Change the construction of `self.background` in `on_enter` from:

```lua
self.background = {
    image = love.graphics.newImage("assets/backgrounds/world_bg.png"),
    draw = function(self)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.image, C.BG_OFFSET_X, C.BG_OFFSET_Y)
    end,
}
```

to a form that captures the scene (`scene` = the outer `self`) and in its `draw`:

1. Computes `fill_top`: the minimum y the wall fill needs to start from.
   - The camera in wall view centers on `wall_pan1.y` and can see `(LOGICAL_H / 2) / C.WALL_VIEW_ZOOM` pixels above. Conservatively: `fill_top = scene.shelf_row_bottom - LOGICAL_H`.
   - Clamp: only draw fill if `fill_top < C.BG_OFFSET_Y`; if the shelf is shallow the background image already covers everything.
2. Draws a solid rectangle with color `C.BG_WALL_COLOR` from `(C.BG_OFFSET_X, fill_top)` sized `(C.BG_W, C.BG_OFFSET_Y - fill_top)`.
3. Then draws the image as before (`love.graphics.setColor(1,1,1,1)` first).

The fill rectangle uses the same x/width as the background image so no horizontal seam appears. It draws only above the image's top edge (`C.BG_OFFSET_Y`), so the floor area is unaffected.

## What stays the same

- The background image itself — not resized, replaced, or reloaded.
- `BG_OFFSET_X`, `BG_OFFSET_Y`, `BG_W`, `BG_H` — existing constants unchanged.
- All camera, pan, and zoom logic.
- Floor, player, pieces, shelf — no changes.
- The fill does not appear at all until `shelf_row_bottom` is negative enough that `fill_top < C.BG_OFFSET_Y`.

## Open questions

None — user confirmed: non-tileable scene background, extend with solid color fill.
