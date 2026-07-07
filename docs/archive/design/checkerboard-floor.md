# Checkerboard Floor

## Goal
Right now the "ground" is a single flat-colored `Sprite` — a thin 30px-tall strip
(`game/scenes/game_scene.lua:30-32`, `Sprite.new(0, GROUND_Y, WORLD_W, 30)`) sitting at
`GROUND_Y = 4 * C.SLOT`. It doesn't represent the world the player can actually walk in (which is
the full `WORLD_W x WORLD_H` area — player movement is pixel-based and clamped to those bounds at
`game_scene.lua:142-143`), and it gives no visual sense of where grid cells fall.

This feature replaces that strip with a **checkerboard floor covering the entire world**, alternating
between two colors per `C.SLOT` (64px) cell, purely so cell boundaries are visible during
development. Per discussion, this also **halves the world size in both dimensions**: `WORLD_W` and
`WORLD_H` go from `40 * C.SLOT` (2560px) to `20 * C.SLOT` (1280px) each, so the checkerboard is a
20x20 grid of cells instead of 40x40.

This is a visual-only change — no new collision, movement, or gameplay logic. `Sprite` (the shared
draw primitive) only knows how to draw a single flat-colored rectangle or image
(`lua/core/sprite.lua:21-54`), so it can't represent a multi-cell checkerboard on its own; a small
new drawable is needed.

## Affected files
- `game/scenes/game_scene.lua` — no new file. A dedicated `Floor` module would only be justified if
  something else needed to reuse, update, or extend it; nothing does — it's static, has no
  `:update()`, and is only ever instantiated once. The `Drawer` only requires layer entries to have
  a `:draw()` method (`lua/core/drawer.lua:24-27`), so the checkerboard is a small inline drawable
  built directly in `game_scene.lua`, the same way HUD text is already drawn inline in
  `GameScene:draw()` (`game_scene.lua:148-155`) rather than factored into its own file.
  - `WORLD_W`/`WORLD_H` change from `40 * C.SLOT` to `20 * C.SLOT` (`game_scene.lua:19-20`).
  - `self.ground` (the flat-color strip, `game_scene.lua:30-32`) is removed and replaced with
    `self.floor = { draw = function() ... end }` (a plain table with a `draw` function, matching the
    `entry.sprite:draw()` call the `Drawer` makes): it loops over `WORLD_W/C.SLOT` columns and
    `WORLD_H/C.SLOT` rows, and for each cell fills a `C.SLOT x C.SLOT` rectangle at world position
    `(col*C.SLOT, row*C.SLOT)`, alternating between two fixed gray shades
    (e.g. `{0.55,0.55,0.55,1}` / `{0.45,0.45,0.45,1}`) based on `(row + col) % 2`.
  - `self.floor` is added to the drawer at priority `0` (below player=10 and pieces/boxes=
    `C.PRIORITY_PIECE`=5, since it's now the full-world background rather than a priority-1 strip).
  - `GROUND_Y` (`game_scene.lua:25`) is unchanged and kept — it's still used to position the
    player's spawn point (`Player.new(0, GROUND_Y - 48)`) and is independent of the ground sprite
    that's being removed.
  - `require("lua/core/sprite")` stays in place (still used for the player, pieces, etc.), even
    though it's no longer used for the ground itself.

## What stays the same
- `C.SLOT` (64px, `game/constants.lua:2`) stays the grid unit — the checkerboard cell size matches
  it exactly, so visible cells line up with the same grid pieces/boxes already snap to.
- Player movement stays pixel-based (unchanged in `game/player.lua`); the floor is a purely visual
  backdrop and introduces no new collision or snapping behavior.
- `GROUND_Y`, piece-resting logic (`game/jigsaw_piece.lua:7-11`), and box/piece placement are all
  untouched — none of them depend on the `self.ground` sprite object being removed, only on the
  `GROUND_Y` numeric constant, which isn't changing.
- Box/spawn-button placement logic (`_spawn_box`, `game_scene.lua:50-81`) already derives its grid
  from `self.world_w / C.SLOT`, so it automatically adapts to the smaller 20x20 world with no code
  change.

## Open questions
None outstanding — extent (full world), replace-vs-coexist (replace), and cell size (`C.SLOT`) were
confirmed with the user; world size is halved in both dimensions per the user's request; exact
checkerboard colors are a non-blocking debug-visualization choice made in this doc.
