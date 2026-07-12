## Wall View Tile Checklist

Source design doc: `docs/design/wall-view-tile.md`. Read it in full before
starting any task below — it has the rationale, file/line references, and
the three assumed defaults (empty-wall no-op, zoom margin formula, plain
rectangle visuals) that each task must follow.

Tasks A, B, C touch disjoint files and have no dependencies on each other —
safe to run in parallel. Task D depends on A, B, and C all being complete (it
wires their APIs together in `game_scene.lua`). Task E depends on D (it tests
the wired-up behavior).

- [x] **Task A** — `game/wall_view_tile.lua` (new file) — Create a
  `WallViewTile` object modeled directly on `game/puzzle_pile.lua`'s
  structure/style (including its comment conventions). Constructor
  `WallViewTile.new(x, y, on_press)` stores an invisible `Sprite`
  footprint (`C.SLOT` x `C.SLOT`) at `(x, y)` for grid-cell bookkeeping,
  plus `on_press`. Expose `:centre()` (returns `{x = sprite.x + C.U, y =
  sprite.y + C.U}`, same formula as `PuzzlePile:centre()`), `:interact()`
  (calls `self.on_press()` if set), and `:draw()` (a plain flat-colored
  `love.graphics.rectangle("fill", ...)` sized/inset like
  `PuzzlePile:draw()`, but a visually distinct color from the pile's
  orange — e.g. a cool blue/teal — so it reads as a different kind of
  object). No camera/zoom logic belongs in this file — it's purely the
  interactable object, matching `PuzzlePile`'s scope.

- [x] **Task B** — `lua/core/camera.lua` — Extend `Camera:follow(target,
  lerp)` (currently line 28) so that when `target.zoom` is not nil, it
  additionally lerps `self.zoom` toward `target.zoom` using the same `f = 1
  - lerp` factor already used for `x`/`y`. When `target.zoom` is nil,
  behavior must be byte-for-byte identical to today (no regression for the
  existing `self.camera:follow(self.player:centre(), 0.85)` call in
  `game_scene.lua:306`, whose target table has no `zoom` field). Add a
  short comment noting this is the first real consumer of `self.zoom`
  (today it's a dead field per `docs/design/wall-view-tile.md`).

- [x] **Task C** — `game/player.lua` — Modify `Player:update(dt, pieces,
  boxes, pile, drawer)` (line 76) to accept two more parameters:
  `wall_tile` and `frozen`. At the very top of the function, always call
  `self.input:update()` first (unconditionally — this must run every frame
  regardless of `frozen` so `lua/core/input.lua`'s edge-triggered
  `_pressed`/`_down` state doesn't desync). If `frozen` is true, return
  immediately after that call — no movement, no piece/box/pile interact
  chain runs. If `frozen` is false/nil, keep all existing behavior
  unchanged, and additionally: after the existing pile check (lines
  157-164), add an equivalent proximity check against `wall_tile` (skip if
  `wall_tile == nil`) — same `1.5 * C.U` radius pattern, calling
  `wall_tile:interact()` when in range and `self.input:pressed("interact")`
  fired this frame. Note `self.input:update()` currently sits at the top of
  the function (`player.lua:77`) inside the existing code — moving it
  earlier/keeping it first is the key change; don't call it twice.

- [x] **Task D** *(after A, B, C)* — `game/scenes/game_scene.lua` — Wire
  the pieces above together:
  - `require("game/wall_view_tile")` alongside the existing `PuzzlePile`
    require.
  - In `on_enter()` (near line 182, right after `self.pile` is built):
    construct `self.wall_tile = WallViewTile.new(WORLD_W - C.SLOT, 0,
    function() self:_toggle_wall_view("p1") end)` and `self.drawer:add(self.wall_tile,
    C.PRIORITY_PIECE)`. If `self.player2` exists (2P branch, lines
    169-180), the single shared `self.wall_tile` is still fine (both
    players interact with the same tile instance), but each player needs
    independent view/freeze state — see below.
  - Add per-player state: `self.view1 = "play"`, `self.wall_target1 = nil`,
    and (only when 2P) `self.view2 = "play"`, `self.wall_target2 = nil`.
  - New method `GameScene:_toggle_wall_view(which)` (`which` is `"p1"` or
    `"p2"`): flips the corresponding `view` field between `"play"` and
    `"wall"`. When transitioning *into* `"wall"`: if `self.completed_puzzles`
    is empty, no-op per the design doc's empty-wall default (don't toggle
    at all — leave `view` as `"play"`). Otherwise compute the bounding box
    over all entries in `self.completed_puzzles` (each has `x, y, cols,
    rows`; width/height = `cols * C.SLOT`, `rows * C.SLOT`), then set
    `wall_target = {x = center_x, y = center_y, zoom = target_zoom}` using
    the formula from the design doc: `target_zoom = math.min(1.0, 0.9 *
    math.min(LOGICAL_W / bbox_w, LOGICAL_H / bbox_h))` (`LOGICAL_W,
    LOGICAL_H = 1280, 720`, matching `main.lua`'s constants — either
    require them or inline the literals with a comment pointing at
    `main.lua`).
  - In `_spawn_box()` (lines 196-205): extend the occupancy check that
    already excludes `self.pile.sprite.x/y`'s cell to also exclude
    `self.wall_tile.sprite.x/y`'s cell, same pattern.
  - In `update()`: replace the direct calls at lines 253-254
    (`self.player:update(...)` / `self.player2:update(...)`) with calls
    that pass `self.wall_tile` and the correct `frozen` flag
    (`frozen = (self.view1 == "wall")` for player 1, etc.). Replace the
    camera-follow calls at lines 306-307: when a player's view is
    `"play"`, follow `{x = centre.x, y = centre.y, zoom = 1.0}` (explicit
    zoom so it eases back from a wall-view zoom); when `"wall"`, follow
    `self.wall_target1` (or `2`) directly, e.g. `self.camera:follow(self.wall_target1,
    0.85)`.
  - No changes expected to `draw()` — the tile draws via the existing
    `self.drawer` pipeline, no new screen-space HUD element per the design.

- [x] **Task E** *(after D)* — Tests:
  - New `tests/test_wall_view_tile.lua` — construct a `WallViewTile`,
    assert `:centre()` math, assert `:interact()` invokes the stored
    `on_press` callback. Follow this repo's existing flat
    `do...end`/`assert(...)`/`print("PASS: ...")` style (see
    `tests/test_camera.lua` for the shortest example) and remember to add
    the new file to the test runner list (`lua/headless/runner.lua`,
    grep for how `test_camera.lua` is registered there).
  - Extend `tests/test_camera.lua` — a case asserting `Camera:follow`
    lerps `zoom` toward `target.zoom` when provided, and a case asserting
    zoom is left untouched when `target.zoom` is nil (regression guard for
    the existing player-follow call).
  - Extend `tests/test_jigsaw.lua` (near the existing shelf/trophy tests
    around lines 2014-2200) or `tests/test_scene.lua` — using the same
    "synthesize a solved/shelved puzzle by directly manipulating
    `gs.completed_puzzles`" pattern already established there, assert:
    `_toggle_wall_view` computes the expected bounding-box center and
    target zoom from a known synthetic `completed_puzzles` set; toggling
    twice returns `view` to `"play"`; toggling with an empty
    `completed_puzzles` is a no-op (view stays `"play"`); `Player:update`
    called with `frozen = true` does not move the player's sprite even
    when a movement key is held down (this is the one place a frozen-input
    regression would silently break gameplay).
  - Run the full suite (however this repo runs it headless — see
    `.github/workflows/*.yml` / `love . --headless`) and confirm everything
    passes, including all pre-existing tests (no regressions).
