# Start Scene Background

## Goal
Give `game/scenes/start_scene.lua` a screen-wide background PNG instead of the
plain black backdrop it gets today from `love.graphics.clear(0, 0, 0)`
(`main.lua:100`). Follows the same "static PNG, drawn 1:1 at its exact target
size" precedent already used for `floor.png`
(`docs/archive/design/floor-png.md`) and the panel PNGs
(`docs/archive/design/menu-ui-pngs.md`).

Per user decisions:
- **Asset source**: script-generate a simple flat placeholder PNG, same
  convention as `floor.png` / `world_bg.png` / `panel_normal.png` /
  `panel_selected.png` (all placeholder art generated via a throwaway script,
  script itself not committed).
- **Fill behavior**: the placeholder PNG is generated already sized to
  exactly **1280x720** (`LOGICAL_W x LOGICAL_H`) and drawn 1:1 with no
  runtime scale factors — same pattern as `floor.png` being drawn at its
  exact target size (`game_scene.lua`'s `self.floor.draw`), not the
  non-uniform stretch-to-rect scaling the panel PNGs use.
- **Scope**: `start_scene.lua` only. `settings_scene.lua` and
  `controller_select_scene.lua` are explicitly **not** touched, unlike the
  menu-ui-pngs feature which deliberately covered all three menu screens.
- **Text legibility**: no scrim/darkening layer between the background and
  the "Jigsaw" title / menu item text. Text stays plain white
  `love.graphics.printf`, unchanged.

## Affected files

- **New asset** — `assets/backgrounds/start_bg.png`, 1280x720 px. A flat/
  simple placeholder image (solid color or subtle gradient, no pattern),
  generated via script, matching the flat-placeholder art style of every
  other asset in `assets/backgrounds/` and `assets/ui/`.

- **`game/scenes/start_scene.lua`**
  - Add a module-level image load next to the existing `PANEL_NORMAL` /
    `PANEL_SELECTED` loads (`:19-20`):
    ```lua
    local BACKGROUND = love.graphics.newImage("assets/backgrounds/start_bg.png")
    ```
  - In `:draw()` (`:182-211`), add a draw call for `BACKGROUND` as the
    **first** thing drawn — before the `"Jigsaw"` title `printf` and before
    the menu item loop — so it renders underneath everything else:
    ```lua
    function StartScene:draw()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(BACKGROUND, 0, 0)

        love.graphics.printf("Jigsaw", 0, 160, LOGICAL_W, "center")
        ...
    ```
    Drawn at `(0, 0)` with no scale arguments (image is already 1280x720,
    matching the logical canvas exactly) — mirrors `floor.png`'s
    `love.graphics.draw(self.image, 0, 0)` call, not the panels' scaled
    `w / panel:getWidth(), h / panel:getHeight()` calls.
  - No other changes to `start_scene.lua` — layout constants, input
    handling, item rects, selection logic all untouched.

- **Tests** — `tests/test_start_scene.lua`. `lua/headless/stubs.lua` already
  stubs `love.graphics.newImage` (returns a fake image with `getWidth`/
  `getHeight`) and `love.graphics.draw` as a no-op, matching the precedent
  noted in `docs/archive/design/menu-ui-pngs.md` — no test changes are
  strictly required for `draw()` to keep passing under headless stubs. Worth
  a final `:draw()` smoke-call in the verification pass to confirm nothing
  errors, but no new assertions are mandated by this change.

## What stays the same
- Logical canvas size (1280x720) and `main.lua`'s letterboxing/scaling
  (`main.lua`'s `love.draw()`, scale = `min(winW/1280, winH/720)`, centered
  with black bars) — the background is drawn onto the logical canvas like
  everything else in the scene, so it scales and letterboxes identically to
  the title text and menu panels. No raw-window-space drawing is introduced.
- `settings_scene.lua`'s `OPAQUE_BG_COLOR` full-screen fill and
  `controller_select_scene.lua`'s lack of any full-screen fill — both stay
  exactly as they are today. This is a start-scene-only change.
- Menu item layout, panel PNGs (`PANEL_NORMAL`/`PANEL_SELECTED`), navigation,
  selection, save/settings persistence, sound — none of this reads what's
  drawn behind the panels; this is a purely additive visual layer.
- Title and menu item text stay plain white `love.graphics.printf` calls, no
  shadow/outline/scrim added.
- `love.graphics.clear(0, 0, 0)` in `main.lua:100` is untouched — it still
  runs every frame before `manager:draw()`, it's just fully covered by the
  new background image whenever the start scene is active.

## Open questions
None outstanding — asset source (script-generated placeholder), fill
behavior (pre-sized to 1280x720, drawn 1:1, no runtime scaling), scope
(start scene only), and text legibility (no scrim, plain text stays) were
all confirmed with the user before writing this doc.
