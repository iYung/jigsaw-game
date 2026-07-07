# Checkerboard Floor Checklist

- [x] Task A — `game/scenes/game_scene.lua`, `tests/test_jigsaw.lua` — Implement the checkerboard
  floor and cover it with tests.
  - In `game/scenes/game_scene.lua`: change `WORLD_W`/`WORLD_H` (`game_scene.lua:19-20`) from
    `40 * C.SLOT` to `20 * C.SLOT`.
  - Remove `self.ground` (the flat-color `Sprite` strip, `game_scene.lua:30-32`) and replace it
    with `self.floor`, a plain Lua table `{ draw = function() ... end }` (not a `Sprite` — the
    `Drawer` only requires a `:draw()` method, per `lua/core/drawer.lua:24-27`). The `draw`
    function loops `row = 0, (WORLD_H/C.SLOT)-1` and `col = 0, (WORLD_W/C.SLOT)-1`, and for each
    cell does `love.graphics.setColor(...)` + `love.graphics.rectangle("fill", col*C.SLOT,
    row*C.SLOT, C.SLOT, C.SLOT)`, picking one of two fixed gray shades — e.g.
    `{0.55,0.55,0.55,1}` for `(row+col) % 2 == 0`, `{0.45,0.45,0.45,1}` otherwise. Reset color to
    `{1,1,1,1}` at the end (matching the convention `Sprite:draw()` already follows at
    `lua/core/sprite.lua:52`).
  - Add `self.floor` to the drawer at priority `0`: `self.drawer:add(self.floor, 0)` — below
    player (10) and pieces/boxes (`C.PRIORITY_PIECE` = 5).
  - Leave `GROUND_Y` (`game_scene.lua:25`) and everything that depends on it (player spawn
    position, `game/jigsaw_piece.lua`'s own `GROUND_Y`) untouched.
  - In `tests/test_jigsaw.lua`, add test coverage for:
    - `gs.world_w` / `gs.world_h` equal `20 * C.SLOT` (1280) after `on_enter()`.
    - `gs.ground` no longer exists (`gs.ground == nil`).
    - `gs.floor` exists and has a `draw` function.
    - `gs.floor` is present in the drawer's layers at priority `0` (drawer internals are
      `self.drawer.layers`, each entry `{ sprite = ..., priority = ... }` per
      `lua/core/drawer.lua:10-13`) — assert an entry exists where `entry.sprite == gs.floor` and
      `entry.priority == 0`.
    - Calling `gs.floor.draw()` does not error under the existing headless `love.graphics` stub
      (`lua/headless/stubs.lua`) — this exercises the full double loop without needing pixel
      assertions, consistent with this repo's existing no-pixel-assertion test style
      (`tests/test_scene.lua`, `tests/test_camera.lua`).
  - Run the full test suite (`tests/*.lua` via the project's test runner) locally and confirm it
    passes before marking this task done.
