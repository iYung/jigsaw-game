# Splitscreen

## Goal

When two players are active in the game scene, give each player their own
camera and their own half of the screen instead of both sharing a single
camera that only follows Player 1. Vertical split: Player 1 gets the left
640x720 half, Player 2 the right 640x720 half, divided by a thin vertical
line. 1-player mode is completely unaffected — single camera, full 1280x720
view, exactly as today.

## Affected files

- `lua/core/camera.lua` — `Camera.new(x, y, w, h, screen_x, screen_y)` gains
  two new optional trailing params, `screen_x`/`screen_y` (default `0`),
  stored as `self.screen_x`/`self.screen_y`. `Camera:attach()` translates by
  `(self.screen_x + self._w / 2, self.screen_y + self._h / 2)` instead of
  `(self._w / 2, self._h / 2)`. Every existing call site (`Scene.new`, and
  anywhere else that constructs a `Camera`) omits the new params, so
  `screen_x`/`screen_y` default to `0` and `attach()` behaves byte-for-byte
  as it does today. This is what lets a second camera's viewport be
  anchored to the right half of the canvas instead of drawing centered over
  the whole thing.
- `lua/headless/stubs.lua` — add `graphics_stub.setScissor = noop`, alongside
  the existing stubbed `love.graphics.*` functions, so headless test runs
  (and any code path that calls `GameScene:draw()` under `--headless`) don't
  error when splitscreen's scissor calls run.
- `game/scenes/game_scene.lua`:
  - `on_enter()` — immediately after the existing `if GameState.player_count
    == 2 then ... end` block that constructs `self.player2`, extend that
    same block: shrink `self.camera._w` from `1280` to `640` (P1's pane is
    now the left half, not the full canvas), and construct `self.camera2 =
    Camera.new(0, 0, 640, 720, 640, 0)` (same initial `(0,0)` focus as
    `self.camera` started with, so it lerps toward Player 2 the same way
    `self.camera` already lerps toward Player 1; `screen_x = 640` anchors
    its viewport to the right pane). In 1-player mode, `self.camera` is
    untouched (`_w` stays `1280`, `self.camera2` is never created).
  - `update(dt)` — immediately after the existing `self.camera:follow(self
    .player:centre(), 0.85)` call, add: `if self.camera2 then self.camera2
    :follow(self.player2:centre(), 0.85) end`.
  - `draw()` — branch on `self.camera2`. When absent (1-player, or 2-player
    before this feature would have looked identical): unchanged, exactly
    today's `Scene.draw(self)` plus the two existing HUD `print` calls. When
    present (2-player): scissor to `(0, 0, 640, 720)`, `self.camera
    :attach()`, `self.drawer:draw()`, `self.camera:detach()`; scissor to
    `(640, 0, 640, 720)`, `self.camera2:attach()`, `self.drawer:draw()`,
    `self.camera2:detach()`; reset scissor (`love.graphics.setScissor()`
    with no args); draw a thin vertical divider line at the pane boundary.
    The top instruction line (`"WASD: move   E: pick up ..."`) is printed
    once, spanning the full canvas, as today. The per-player coordinate
    debug line is printed twice, once per pane, at each pane's own `(16,
    36)`-relative position (i.e. P1's at `(16, 36)`, P2's at `(656, 36)`)
    using each player's own `:centre()`.
- `tests/test_camera.lua` — cover the new `screen_x`/`screen_y` params:
  defaulting to `0` when omitted, and being stored correctly when passed.
- `tests/test_scene.lua` — extend the existing "player_count == 2" test (or
  add a new one) to cover: `gs.camera2 ~= nil` and `gs.camera2._w == 640`
  and `gs.camera2.screen_x == 640` when `player_count == 2`; `gs.camera._w
  == 640` in that same case; `gs.camera2 == nil` and `gs.camera._w == 1280`
  when `player_count == 1` (regression, unchanged from today).

## What changes

- 2-player mode: the game scene renders twice per frame — once from each
  player's camera — into scissored left/right halves of the existing
  1280x720 canvas, with a divider line between them. Both cameras follow
  their own player independently with the same `0.85` lerp already used for
  Player 1's camera today.
- `Camera` supports an optional screen-space viewport offset
  (`screen_x`/`screen_y`), needed so a second camera's viewport can be
  anchored to the right half of the canvas instead of overlapping the
  first.

## What stays the same

- 1-player mode: identical rendering path, one full-canvas camera, no
  scissoring, no divider, pixel-for-pixel unchanged.
- The world, physics, drawer contents, and draw priorities: splitscreen is
  purely a camera/rendering concern. Both panes draw the exact same
  `self.drawer` contents (the whole world), just from two different camera
  viewpoints — no per-player culling or duplication of world objects.
- `main.lua`'s canvas setup and letterbox-scaling logic: the game scene
  still renders into the same single 1280x720 canvas it always has; nothing
  about how that canvas is presented to the window changes.
- Save file shape/version: unchanged. Splitscreen is session-only rendering
  state, not persisted.
- Every existing `Camera.new(...)` call site that doesn't pass
  `screen_x`/`screen_y`: behavior unchanged (defaults to `0, 0`).

## Open questions

None outstanding — resolved during design:
- **Split orientation**: vertical (left/right), per user preference — the
  classic splitscreen convention, over a horizontal split that would have
  kept more of the world's width visible per player.
