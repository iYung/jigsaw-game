# Splitscreen Checklist

Design doc: `docs/design/splitscreen.md`

All tasks below are independently completable in parallel — every
cross-file contract (function signature, field name, scissor rect, HUD
coordinate) is fixed by this checklist, so no task needs to read another
task's actual diff to conform to it. Every task touches a distinct file, so
there are no edit conflicts either.

## Fixed contracts (read this before starting any task)

- **`Camera.new(x, y, w, h, screen_x, screen_y)`** — two new optional
  trailing params, defaulting to `0`, stored as `self.screen_x = screen_x or
  0` and `self.screen_y = screen_y or 0`. All four existing params
  (`x`, `y`, `w`/`self._w`, `h`/`self._h`) keep their exact current
  defaults and meaning.
- **`Camera:attach()` translate formula** — changes from
  `love.graphics.translate(self._w / 2, self._h / 2)` to
  `love.graphics.translate(self.screen_x + self._w / 2, self.screen_y +
  self._h / 2)`. Every other line of `attach()`/`detach()` is unchanged.
  Since every existing call site (`Scene.new`, and any other `Camera.new`
  call) omits the two new params, `screen_x`/`screen_y` default to `0` and
  this formula reduces to exactly today's `self._w / 2, self._h / 2` —
  byte-for-byte unchanged behavior for every camera that doesn't pass them.
- **`GameScene:on_enter()` 2-player camera setup** — inside the existing
  `if GameState.player_count == 2 then ... end` block (the block that
  already constructs `self.player2`), two new lines are added:
  `self.camera._w = 640` and `self.camera2 = Camera.new(0, 0, 640, 720, 640,
  0)`. Field name is exactly `self.camera2` (not `self.player2_camera` or
  similar). In 1-player mode this block never runs, so `self.camera._w`
  stays `1280` (its `Scene.new(1280, 720)`-assigned default) and
  `self.camera2` is never set (reads as `nil`).
- **Scissor rects** — pane 1 (Player 1, left): `love.graphics.setScissor(0,
  0, 640, 720)`. Pane 2 (Player 2, right): `love.graphics.setScissor(640, 0,
  640, 720)`. Reset after both panes are drawn: `love.graphics.setScissor()`
  (no args).
- **Divider line** — drawn once, after the scissor reset (so it isn't
  clipped by either pane), as a vertical line at the pane boundary:
  `love.graphics.line(640, 0, 640, 720)`. Set color to opaque white
  beforehand (`love.graphics.setColor(1, 1, 1, 1)`) since the last thing
  drawn inside a pane may have left the color state changed.
- **HUD lines in `GameScene:draw()`** — the existing top instruction line
  (`"WASD: move   E: pick up / drop   R: rotate   ESC: save & menu"`) is
  printed exactly once, at `(16, 16)`, spanning the full canvas, in both
  1-player and 2-player mode — unchanged from today. The per-player
  coordinate debug line (`"player (%.0f, %.0f)"`) is printed using
  `self.player:centre()` at `(16, 36)` always (unchanged from today), and,
  only when `self.camera2` is set, printed a second time using
  `self.player2:centre()` at `(656, 36)`.
- **`lua/headless/stubs.lua` scissor stub** — `graphics_stub.setScissor =
  noop`, added alongside the other explicit `graphics_stub.*` no-op
  assignments (e.g. next to `graphics_stub.setBlendMode`).

- [x] Task A — `lua/core/camera.lua` — Change `function Camera.new(x, y, w,
  h)` to `function Camera.new(x, y, w, h, screen_x, screen_y)`. Add `self
  .screen_x = screen_x or 0` and `self.screen_y = screen_y or 0` alongside
  the existing `self.x`/`self.y`/`self._w`/`self._h`/`self.zoom`
  assignments (order doesn't matter, but keep them grouped with the other
  field assignments for readability). In `Camera:attach()`, change the
  `love.graphics.translate(self._w / 2, self._h / 2)` call to
  `love.graphics.translate(self.screen_x + self._w / 2, self.screen_y +
  self._h / 2)` per the "Fixed contracts" formula above. Do not change
  `Camera:detach()` or `Camera:follow()` at all — this task touches only
  `Camera.new` and the one `translate` line inside `Camera:attach()`.
  **Must not change**: default behavior of `Camera.new(x, y, w, h)` called
  with exactly 4 (or fewer) args — `screen_x`/`screen_y` must default to
  `0`, making `attach()` translate identically to today for every existing
  call site.

- [x] Task B — `lua/headless/stubs.lua` — Add `graphics_stub.setScissor =
  noop` to the "Explicit stubs" block of assignments (alongside
  `graphics_stub.setBlendMode`, `graphics_stub.setFilter`, etc. — insert it
  near those, before the catch-all `setmetatable(graphics_stub, ...)`
  call). No other changes to this file. **Must not change**: every other
  stubbed function, the catch-all `__index` fallback behavior, and the
  `make_stub_image` path-aware sizing logic.

- [x] Task C — `game/scenes/game_scene.lua` — Three changes to this one
  file, all described exactly below (build against the "Fixed contracts"
  section above — no need to read `lua/core/camera.lua`'s actual diff):
  - **`on_enter()`**: inside the existing `if GameState.player_count == 2
    then ... end` block — the block that already does `self.player2 =
    Player.new(...)`, sets `self.player2.sprite.color`, and calls
    `self.drawer:add(self.player2, 10)` — append two lines at the end of
    that block: `self.camera._w = 640` then `self.camera2 = Camera.new(0,
    0, 640, 720, 640, 0)`. Nothing else in `on_enter()` changes; in
    particular the save-restore branch, the box/pile/background/floor
    setup, and the `player2` construction lines themselves are untouched.
  - **`update(dt)`**: immediately after the existing line `self.camera
    :follow(self.player:centre(), 0.85)`, add: `if self.camera2 then self
    .camera2:follow(self.player2:centre(), 0.85) end`. No other line in
    `update(dt)` changes.
  - **`draw()`**: replace the current body's first line (`Scene.draw(self)`)
    with a branch: when `self.camera2` is `nil`, call `Scene.draw(self)`
    exactly as today (unchanged 1-player path — full-canvas camera, no
    scissoring, no divider). When `self.camera2` is set, instead: scissor to
    `(0, 0, 640, 720)`, `self.camera:attach()`, `self.drawer:draw()`, `self
    .camera:detach()`; scissor to `(640, 0, 640, 720)`, `self.camera2
    :attach()`, `self.drawer:draw()`, `self.camera2:detach()`; reset scissor
    with `love.graphics.setScissor()`; `love.graphics.setColor(1, 1, 1, 1)`;
    draw the divider with `love.graphics.line(640, 0, 640, 720)`. After that
    branch (both paths converge here), keep the existing `love.graphics
    .setColor(1, 1, 1, 1)` and top instruction-line `print` call at `(16,
    16)` unchanged, and the existing per-player coordinate `print` at `(16,
    36)` using `self.player:centre()` unchanged. Then add: when `self
    .camera2` is set, compute `self.player2:centre()` and `print` a second
    coordinate line, same `"player (%.0f, %.0f)"` format, at `(656, 36)`.
  **Must not change**: `_spawn_box()`, `to_save()`, `_shelve()`, `on_exit()`,
  and every other line of `on_enter()`/`update()`/`draw()` not called out
  above — in particular the 1-player render path must remain pixel-for-pixel
  identical (still exactly `Scene.draw(self)` plus the same two HUD prints
  at the same coordinates).

- [x] Task D — `tests/test_camera.lua` — Add coverage for the new
  `screen_x`/`screen_y` params from the "Fixed contracts" section above,
  following this file's existing `do ... end` block-per-test style with
  `assert`/`print("PASS: ...")`: (1) `Camera.new(0, 0, 1280, 720)` (params
  omitted) has `c.screen_x == 0` and `c.screen_y == 0`. (2) `Camera.new(0,
  0, 640, 720, 640, 0)` has `c.screen_x == 640` and `c.screen_y == 0`. (3)
  `Camera.new(0, 0, 640, 720, 0, 360)` has `c.screen_x == 0` and `c
  .screen_y == 360` (both params stored independently, not just the first
  one). Keep the final `print("ALL TESTS PASSED")` at the end of the file.
  **Must not change**: the three existing tests (default dimensions,
  custom dimensions, position/dimensions independence) — do not alter their
  assertions or expected values.

- [x] Task E — `tests/test_scene.lua` — Extend the existing "Test 5" block
  (`GameState.player_count == 2` → `gs.player2` spawn check) or add a new
  test immediately after it, per the "Fixed contracts" section above:
  after `GameState.player_count = 2` and `gs:on_enter()`, assert `gs
  .camera2 ~= nil`, `gs.camera2._w == 640`, `gs.camera2.screen_x == 640`,
  and `gs.camera._w == 640`. Then add a regression test for 1-player mode:
  `GameState:reset()` (leaving `player_count` at its default of `1`),
  `GameScene.new()`, `gs:on_enter()`, assert `gs.camera2 == nil` and `gs
  .camera._w == 1280` (unchanged from today). Call `GameState:reset()`
  after each test block, matching this file's existing convention of
  resetting `GameState` after tests that mutate it. Keep the final `print
  ("ALL TESTS PASSED")` at the end of the file. **Must not change**: Tests
  1–4 (Scene dimension threading, drawer creation, GameScene camera
  inheritance, `_spawn_box()` sourcing) and the existing player2
  spawn-position/color assertions already in Test 5 — only add to them.

## Sequencing

All five tasks (A–E) can run fully in parallel. Task A changes `Camera`'s
signature and `attach()` formula, but Tasks C, D, and E are written against
the "Fixed contracts" section above rather than Task A's actual diff, so
none of them needs Task A to land first. Likewise Task C's `game_scene.lua`
changes are fully specified by the fixed `self.camera2` / `self.camera._w =
640` / scissor-rect / HUD-coordinate contracts above, so Tasks D and E (which
assert against those same fields) don't need to read Task C's diff either.
