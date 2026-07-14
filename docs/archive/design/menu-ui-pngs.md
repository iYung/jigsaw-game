# Menu UI PNGs

## Goal
Replace the vector-drawn row/panel backgrounds in the three menu screens
(`settings_scene.lua`, `start_scene.lua`, `controller_select_scene.lua`) with
PNG images, following the same "swap `rectangle("fill", ...)` for
`love.graphics.draw(image, ...)`" precedent already used for the world floor
(`docs/archive/design/floor-png.md`).

Per user decisions:
- **Scope**: all three menu screens (they currently share one identical
  vector style, per `settings_scene.lua:39-40`, `start_scene.lua:19-20`,
  `controller_select_scene.lua:11-12`), not just Settings.
- **Art style**: flat placeholder art — plain solid-color images, no border,
  gradient, or rounded corners — matching the flat rectangles they replace.
  Generated via a throwaway script (same precedent as `floor.png`: script
  used to produce the asset, script itself not committed).
- **Volume rows**: stay text-only ("SFX Volume: 70%"). No slider track/handle
  graphic is being added — only the row *background* becomes an image.
- **States**: two images — normal and selected — matching today's
  `NORMAL_COLOR` / `SELECTED_COLOR`. The disabled "Continue" row
  (`start_scene.lua:194-200`) keeps working exactly as it does today: draw
  the *normal* image at alpha 0.4, rather than a dedicated disabled PNG.

Text labels (titles, row labels, the controller-select instructions line)
are **not** being converted to images — they stay `love.graphics.printf`
calls. Converting per-string text to image assets is a much bigger,
unrelated change (font atlas / text-to-texture pipeline) that wasn't asked
for here.

## Affected files

- **New assets** — `assets/ui/panel_normal.png` and
  `assets/ui/panel_selected.png`. Small flat solid-color squares (64x64),
  colored to match today's `NORMAL_COLOR = {0.35,0.35,0.35,1}` and
  `SELECTED_COLOR = {0.55,0.55,0.55,1}` respectively, generated via a
  Python + PIL script (not committed, same as `floor.png`'s precedent). One
  pair of images is reused across all three screens by scaling on draw —
  the three screens use three different row/panel sizes today (Settings and
  Start Menu rows are `300x60`; Controller Select columns are `360x200`), so
  a small flat-color square scales cleanly to any of them with
  `love.graphics.draw(image, x, y, 0, w / image:getWidth(), h /
  image:getHeight())` since there's no pattern/border to distort.

- **`game/scenes/settings_scene.lua`**
  - Add module-level image loads next to the existing color constants
    (`:39-40`):
    ```lua
    local PANEL_NORMAL   = love.graphics.newImage("assets/ui/panel_normal.png")
    local PANEL_SELECTED = love.graphics.newImage("assets/ui/panel_selected.png")
    ```
  - In `:draw()`'s row loop (`:309-322`), replace the
    `love.graphics.setColor(...)` + `rectangle("fill", x, y, w, h)` pair with
    an image draw using `PANEL_SELECTED` when `i == self.selected`,
    `PANEL_NORMAL` otherwise, scaled to `(w, h)` as above.
  - `NORMAL_COLOR` / `SELECTED_COLOR` (`:39-40`) become unused once this
    lands (grep confirms no other use in this file) — delete them.
  - `OPAQUE_BG_COLOR` full-screen fill (`:295-296`) and the pause-overlay
    scrim (`:302-303`) are **not** touched — see "What stays the same".

- **`game/scenes/start_scene.lua`**
  - Same module-level image loads next to `:19-20`.
  - In `:draw()` (`:182-215`), replace both branches' `rectangle("fill",
    ...)` calls (the disabled-Continue branch at `:194-200` and the
    normal/selected branch at `:201-211`) with image draws: disabled draws
    `PANEL_NORMAL` at `setColor(1,1,1,0.4)`; the normal/selected branch draws
    `PANEL_SELECTED` or `PANEL_NORMAL` at full alpha, matching Settings'
    treatment.
  - `NORMAL_COLOR` / `SELECTED_COLOR` (`:19-20`) become unused (the disabled
    branch's only other read of `NORMAL_COLOR`, `:195`, goes away since the
    image itself is already that color) — delete them.

- **`game/scenes/controller_select_scene.lua`**
  - Same module-level image loads next to `:11-12`.
  - In `:draw()`, replace the three panel fills — Player 1 (`:178-179`),
    the middle "Devices" legend (`:188-189`), Player 2 (`:197-198`) — with
    image draws: Player 1 and Player 2 use `PANEL_NORMAL`, the middle legend
    uses `PANEL_SELECTED` (this mirrors today's color choice — the legend
    isn't a "selected" state, it's just visually distinguished from the
    player columns, same as now).
  - `NORMAL_COLOR` / `SELECTED_COLOR` (`:11-12`) become unused — delete them.

- **Tests** — `tests/test_settings_scene.lua`, `tests/test_start_scene.lua`,
  `tests/test_controller_select_scene.lua` currently assert none of
  `draw()`'s colors/shapes (confirmed by grep: no `draw`, `rectangle`,
  `COLOR`, or `Image` references in any of the three). `lua/headless/stubs.lua`
  already stubs `love.graphics.newImage` (returns a fake image with
  `getWidth`/`getHeight`) and `love.graphics.draw`/`rectangle` as no-ops, so
  this swap needs **no test changes** — existing tests keep passing
  unmodified. Worth a final `:draw()` smoke-call per scene in the
  verification pass to confirm nothing errors under headless stubs, but no
  new assertions are required by this change.

## What stays the same
- Row/column layout, sizing constants (`ITEM_W/H/GAP`, `ITEMS_TOP`,
  `COLUMN_W/TOP/H`), navigation, input handling, save/settings persistence —
  none of this reads how a row is *drawn*, purely a visual swap.
- All text rendering stays `love.graphics.printf` with the default Love2D
  font — no font/text-as-image work.
- Settings' full-screen opaque background (`OPAQUE_BG_COLOR`) and the
  pause-overlay scrim (`0,0,0,0.55`) stay plain
  `rectangle("fill", 0, 0, LOGICAL_W, LOGICAL_H)` calls — they're
  full-canvas solid fills with no edges/shape to benefit from being a
  texture, and the user's ask was about "settings buttons" / "everything"
  in the sense of the interactive rows, not the backdrop.
- The volume rows keep showing volume as text only — no slider track/fill/
  handle graphic is being introduced.
- No new shared theme module — image loads are duplicated per scene file,
  matching the codebase's existing convention of duplicating
  `NORMAL_COLOR`/`SELECTED_COLOR` per file rather than centralizing them.

## Open questions
None outstanding — scope (all three menu screens), art style (flat
placeholder, script-generated), volume-row treatment (text-only, no
slider), and button-state count (normal + selected, disabled = dimmed
normal) were all confirmed with the user before writing this doc. The
full-screen background/scrim exclusion above is a judgment call, not a
question — flagged here for visibility during doc review in case the user
wants those included too.
