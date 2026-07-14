# Vector-to-PNG Conversion

## Goal
Replace the remaining procedurally-drawn (`love.graphics.rectangle`) visuals with PNG images,
following the same precedent already used for the world floor
(`docs/archive/design/floor-png.md`) and the menu panels
(`docs/archive/design/menu-ui-pngs.md`): swap `rectangle("fill", ...)` for
`love.graphics.draw(image, ...)`, using flat solid-color placeholder PNGs generated via a
throwaway script.

Per user decision (asked directly, since a full audit turned up five vector-drawn candidates and
not all are good fits): convert three of them.

- **`game/puzzle_pile.lua:66`** — the stack of remaining-puzzle boxes, currently orange
  `rectangle("fill", ...)` calls, one per box in the stack.
- **`game/wall_view_tile.lua:38`** — the wall-view interactable, currently a single teal/blue
  `rectangle("fill", ...)`.
- **`game/scenes/settings_scene.lua:296,303`** — the settings screen's full-canvas backdrop, in
  both its opaque mode (solid `OPAQUE_BG_COLOR` fill) and overlay mode (semi-transparent black
  scrim over the frozen game world beneath it). Note: this was explicitly *excluded* from the
  menu-ui-pngs conversion as a judgment call (see that doc's "What stays the same") — this time
  the user asked for it to be included.

**Not** being converted in this pass (explicitly declined):
- `game/player.lua:236` — the drop-target preview highlight. It's a translucent (`alpha 0.25`)
  overlay whose look depends on runtime alpha blending against whatever piece/floor is underneath;
  there's no single static color to bake into a PNG.
- `game/scenes/game_scene.lua:454` — the 1px `love.graphics.line` seam between the two
  split-screen camera viewports. A rendering primitive marking an exact pixel boundary, not a
  piece of art.

## Affected files

- **New assets**:
  - `assets/ui/pile_box.png` — small flat solid-color square (`C.PILE_BOX_SIZE` px, currently
    `SLOT` = 64), colored to match today's `love.graphics.setColor(1, 0.75, 0.2, 1)` (RGB
    255,191,51, fully opaque). Generated via a throwaway Python + PIL script (not committed, same
    precedent as `floor.png`/`panel_normal.png`).
  - `assets/ui/wall_view_tile.png` — same size/approach, colored to match today's
    `love.graphics.setColor(0.2, 0.6, 0.9, 1)` (RGB 51,153,230, fully opaque).
  - `assets/ui/solid.png` — one shared small flat **white** square, fully opaque, reused for
    *both* settings backdrop modes (rather than two near-identical PNGs): a plain white image lets
    `setColor` fully control the final color/alpha before drawing, exactly like
    `pile_box.png`/`wall_view_tile.png` are tinted via `setColor(1,1,1,1)` — just with a non-white
    tint here. Opaque mode keeps `setColor(OPAQUE_BG_COLOR)` (RGB 20,20,20, alpha 1) before
    drawing; overlay mode keeps `setColor(0, 0, 0, 0.55)` before drawing (tinting white black at
    55% alpha reproduces today's `rectangle("fill", ...)` scrim exactly, and keeps the alpha
    dynamic rather than baking a fixed semi-transparent value into the PNG). Both draws scale the
    image up to `LOGICAL_W x LOGICAL_H` — same scale-to-fit approach `panel_normal.png` already
    uses.

- **`game/puzzle_pile.lua`**
  - Add a module-level image load: `local PILE_BOX = love.graphics.newImage("assets/ui/pile_box.png")`.
  - In `:draw()` (`:58-69`), replace the `setColor(1, 0.75, 0.2, 1)` + `rectangle("fill", ...)`
    loop body with `love.graphics.setColor(1, 1, 1, 1)` (no tint needed — color is baked into the
    PNG) then `love.graphics.draw(PILE_BOX, self.sprite.x + inset, by + inset, 0, C.PILE_BOX_SIZE /
    PILE_BOX:getWidth(), C.PILE_BOX_SIZE / PILE_BOX:getHeight())`, keeping the same loop over
    `1, n` and the same `inset`/`by` math.

- **`game/wall_view_tile.lua`**
  - Add a module-level image load: `local TILE_IMAGE = love.graphics.newImage("assets/ui/wall_view_tile.png")`.
  - In `:draw()` (`:33-40`), replace the `setColor(0.2, 0.6, 0.9, 1)` + `rectangle("fill", ...)`
    with `setColor(1, 1, 1, 1)` then `love.graphics.draw(TILE_IMAGE, self.sprite.x + inset,
    self.sprite.y + inset, 0, C.PILE_BOX_SIZE / TILE_IMAGE:getWidth(), C.PILE_BOX_SIZE /
    TILE_IMAGE:getHeight())`.

- **`game/scenes/settings_scene.lua`**
  - Add a module-level image load next to the existing `PANEL_NORMAL`/`PANEL_SELECTED` loads
    (`:39-40`): `local SOLID = love.graphics.newImage("assets/ui/solid.png")`.
  - In `:draw()` (`:290-304`): opaque-mode branch keeps `setColor(OPAQUE_BG_COLOR)` then draws
    `love.graphics.draw(SOLID, 0, 0, 0, LOGICAL_W / SOLID:getWidth(), LOGICAL_H /
    SOLID:getHeight())`; overlay-mode branch keeps `setColor(0, 0, 0, 0.55)` then draws `SOLID`
    scaled the same way. `OPAQUE_BG_COLOR` (`:42` local) stays — it's still read by `setColor`,
    just no longer paired with `rectangle`.

- **Tests**:
  - `tests/test_puzzle_pile.lua`, `tests/test_wall_view_tile.lua` — currently no `draw()`
    assertions (confirmed by grep). Add one smoke test each: `pile:draw()` /
    `tile:draw()` doesn't error under the headless `love.graphics` stub, now that `draw()` calls
    `love.graphics.newImage`/`draw` instead of only `rectangle`. Follows the same precedent as
    `tests/test_settings_scene.lua`'s Test 25 (added for the menu-ui-pngs conversion).
  - `tests/test_settings_scene.lua` — existing Test 25 already smoke-tests `:draw()` in both
    opaque and overlay mode; no new test needed, just confirm it still passes once the backdrop
    also goes through `love.graphics.draw`.

## What stays the same
- `C.PILE_BOX_SIZE`, `C.PILE_BOX_STACK_OFFSET`, `C.SLOT`, all positioning/inset math, stack-count
  logic (`PuzzlePile:count()`), and `WallViewTile`'s occupancy/interact behavior — purely a visual
  swap in each `:draw()`.
- `LOGICAL_W`/`LOGICAL_H`, opaque-vs-overlay mode selection logic, and the settings scrim's alpha
  (`0.55`) — unchanged; still controlled by `setColor` exactly as today, just paired with an image
  draw instead of `rectangle`.
- The drop-target highlight (`player.lua:236`) and the split-screen divider line
  (`game_scene.lua:454`) stay procedural — declined by the user as noted above.
- No shared "theme" module — each file keeps its own module-level image load, matching this
  codebase's existing convention (confirmed by `menu-ui-pngs.md`'s "What stays the same").

## Open questions
None outstanding — scope (puzzle pile, wall view tile, settings backdrop; not the drop-target
highlight or split-screen divider) was confirmed with the user before writing this doc.
