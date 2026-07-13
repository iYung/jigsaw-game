# Floor PNG

## Goal
Replace the procedurally-drawn checkerboard floor with a single static PNG image, matching
how `self.background` already draws `assets/backgrounds/world_bg.png`
(`game/scenes/game_scene.lua:63-70`). The checkerboard (`game_scene.lua:72-89`) was originally
built as a dev/debug visualization to show `C.SLOT` (64px) grid-cell boundaries
(`docs/archive/design/checkerboard-floor.md`); it's now being replaced with real art.

Per user decision: a new placeholder PNG will be generated (not user-supplied) and drawn as a
**single full-size image** (1280x640, matching `WORLD_W x WORLD_H`) rather than a small tile
repeated via quads — the same one-draw-call approach `self.background` already uses.

## Affected files
- **New asset** — `assets/backgrounds/floor.png`, 1280x640 (`WORLD_W = 20 * C.SLOT`,
  `WORLD_H = 10 * C.SLOT`, `C.SLOT = 64`). A simple placeholder image (flat/subtle solid tone,
  no procedural checkerboard pattern), generated via script, sized to exactly cover the world with
  no offset needed (unlike `world_bg.png`, which uses `C.BG_OFFSET_X/Y` because it's larger than
  the world and scrolls/pans; the floor image is drawn 1:1 at world origin `(0, 0)`).
- **`game/scenes/game_scene.lua:72-89`** — `self.floor`'s `draw` function changes from the
  procedural double-loop + `rectangle("fill", ...)` calls to the same image-drawable shape already
  used for `self.background` (`game_scene.lua:63-70`):
  ```lua
  self.floor = {
      image = love.graphics.newImage("assets/backgrounds/floor.png"),
      draw = function(self)
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.draw(self.image, 0, 0)
      end,
  }
  self.drawer:add(self.floor, 0)
  ```
  Drawer priority stays `0` (below player=10, pieces/boxes=`C.PRIORITY_PIECE`, above
  background=-1) — unchanged, since draw order relative to everything else is not part of this
  change.
- **`tests/test_jigsaw.lua:2640-2670`** — the existing checkerboard-floor test block asserts
  `gs.floor` is a table with a `draw` function, is registered in the drawer at priority 0, and that
  `gs.floor.draw()` doesn't error under the headless `love.graphics` stub. These structural
  assertions hold for an image-based drawable too, but the test currently calls `gs.floor.draw()`
  with no `self` argument (`draw = function() ... end`, no `self` param) — the new `draw` takes
  `self` (to read `self.image`, same as `self.background`'s `draw`), so the test's call site needs
  to become `gs.floor.draw(gs.floor)` (matching how `self.background`'s equivalent test — see
  `game_scene.lua:2729` area — must already call it, worth checking that pattern directly rather
  than guessing). Comments referencing "checkerboard" in this block should be updated to describe
  the image-based floor instead.

## What stays the same
- `WORLD_W`/`WORLD_H`, `C.SLOT`, `GROUND_Y`, drawer priority (`0`), and the fact that `self.floor`
  is a plain table (not a `Sprite`) exposing only `draw()` (`lua/core/drawer.lua:24-27` only
  requires a `:draw()` method) — no architectural change, just swapping what `draw()` does.
  A dedicated `Floor` module is still not justified — it stays static, has no `:update()`, and is
  instantiated once, same reasoning as the original checkerboard doc.
- Player movement, piece-resting logic, box/spawn-button placement — none of this reads
  `self.floor`'s draw contents; purely a visual swap.
- `self.background`'s scrolling `world_bg.png` is untouched; it stays a separate, larger,
  offset-panned image layered below the floor.

## Open questions
None outstanding — asset source (generate a placeholder) and sizing approach (single full-size
1280x640 image, not a repeated tile) were confirmed with the user.
