## Goal

Add a new interactable tile, positioned in the top-right corner of the floor,
that lets the player toggle the camera into a zoomed-out view framing the
*entire* completed-puzzles wall/shelf (`self.completed_puzzles`, built by
`GameScene:_shelve()`, `game/scenes/game_scene.lua:354-394`), then toggle back
to normal player-follow play.

Decisions already made with the user (do not re-litigate):
- The tile is a **world-space object** the player walks up to and presses the
  interact key on — same pattern as `PuzzlePile`/`JigsawBox` — not a
  mouse-clickable screen-space HUD icon. The game has no mouse input
  anywhere today (`grep -rn "mousepressed\|love.mouse"` returns nothing), so
  this keeps the feature consistent with every existing interactable.
- Exit is **press interact again** (not auto-timeout, not "any movement key").
- Player **movement freezes** while the wall view is active.
- In 2-player split-screen, the two camera panes and freeze states are
  **independent** — one player entering wall view only affects their own
  pane; the other player keeps playing normally in theirs.

## Affected files

- **New file `game/wall_view_tile.lua`** — modeled directly on
  `game/puzzle_pile.lua`. A plain interactable object exposing `:centre()`,
  `:interact()`, `:draw()`, constructed as
  `WallViewTile.new(x, y, on_press)`. No new input system needed — it plugs
  into the same proximity-check pattern already used for the pile.

- **`game/scenes/game_scene.lua`**
  - `on_enter()` (near line 182, where `self.pile` is built): construct
    `self.wall_tile = WallViewTile.new(WORLD_W - C.SLOT, 0, function() self:_toggle_wall_view() end)`
    and `self.drawer:add(self.wall_tile, C.PRIORITY_PIECE)`. Position is the
    floor's top-right grid cell — `y = 0` is the floor's top edge (where the
    shelf baseline starts, see `_shelve()`'s `shelf_row_bottom` starting at
    `-C.SLOT`), `x = WORLD_W - C.SLOT` is the rightmost floor column.
  - New fields: `self.view` (`"play"` or `"wall"`, default `"play"`) and
    `self.wall_target` (`{x, y, zoom}`, computed on entering `"wall"`).
  - `_spawn_box()` (lines 196-205): extend the occupancy check that already
    excludes the pile's cell so a box can never spawn on the wall tile's cell
    either.
  - `update()` (lines 253-254 and 306-307): gate movement/interaction
    application on `self.view` — see `game/player.lua` change below — and
    drive `self.camera:follow(...)`'s target from `self.wall_target` when
    `self.view == "wall"`, or from the player's centre (with explicit
    `zoom = 1.0`) when `self.view == "play"`. Each player's `view`/freeze
    state is tracked and applied independently (two separate fields/targets
    in 2P mode, one per camera).
  - New `GameScene:_toggle_wall_view()` (per-player) — flips that player's
    `view` field; when transitioning into `"wall"`, computes `wall_target`
    once from the current bounding box of `self.completed_puzzles` (shared
    data — both players see the same wall).

- **`game/player.lua`** — `Player:update(dt, pieces, boxes, pile, drawer)`
  (line 76): add a `frozen` boolean parameter. When `frozen`, still call
  `self.input:update()` first (so `_pressed`/`_down` edge-state in
  `lua/core/input.lua:73-97` stays correct frame-to-frame — skipping this
  entirely while frozen would desync edge detection for whenever movement
  resumes), then return early before applying movement or the
  piece/box/pile interact chain. Also add a `wall_tile` param alongside
  `pile`, checked with the same proximity pattern as the pile
  (`player.lua:157-164`) when not frozen.

- **`lua/core/camera.lua`** — `Camera:follow(target, lerp)` (line 28):
  extend to also lerp `self.zoom` toward `target.zoom` when the target table
  provides one, leaving `x`/`y` lerp behavior unchanged. This is the first
  real use of `self.zoom`, which today is dead beyond its `1.0` default
  (confirmed via repo-wide grep).

- **`game/constants.lua`** — no new drawer-priority constant needed (the
  tile reuses `C.PRIORITY_PIECE`, like the pile). May add named constants for
  the zoom-out margin and/or lerp rate if that helps tuning/testing.

- **Tests** — new `tests/test_wall_view_tile.lua` (construction, `:interact()`
  callback) plus additions to `tests/test_camera.lua` (zoom-lerp behavior of
  `Camera:follow`) and `tests/test_jigsaw.lua` / `tests/test_scene.lua`
  (bounding-box → target zoom/center math using the existing synthetic
  "solved and shelved" puzzle pattern already used around lines 2014-2200;
  `GameScene` view-toggle state transitions; `Player:update` frozen
  behavior).

## What changes

- Walking onto the tile at the floor's top-right corner and pressing
  interact smoothly pans/zooms the camera out to frame the full bounding box
  of every shelved puzzle, and freezes that player's movement.
- Pressing interact again smoothly returns the camera to following the
  player at normal zoom (1.0) and unfreezes movement.
- `Camera:follow` gains zoom-lerp support.

## What stays the same

- No mouse/click input is introduced anywhere in the game.
- `_shelve()`'s row-wrapping shelf layout math is untouched — this feature
  only *reads* `self.completed_puzzles` to compute a bounding box.
- Save/load format is untouched — `view`/`wall_target` are transient,
  matching how the camera's own position is already never persisted
  (`to_save()` only stores `player.x/y`, `game_scene.lua:445-447`).
- Drawer priority scheme is untouched; the tile reuses `C.PRIORITY_PIECE`.
- Every existing interactable (piece pickup/drop, boxes, pile) behaves
  exactly as today while a player's `view == "play"`.

## Open questions

Defaults assumed below — flag any you want changed before the checklist is
written:

1. **Empty wall.** If a player interacts with the tile before any puzzle has
   been completed (`self.completed_puzzles` is empty), there's no bounding
   box to fit. Default: no-op — the tile does nothing until at least one
   puzzle has been shelved.
2. **Zoom margin/clamp.** Default target zoom =
   `min(1.0, 0.9 * min(LOGICAL_W / bbox_w, LOGICAL_H / bbox_h))` — fits the
   wall with a 10% margin, and never zooms in *past* normal gameplay scale
   even if the wall is still small.
3. **Tile visuals.** Default to a plain flat-colored rectangle, matching
   `PuzzlePile:draw()`'s existing plain-rectangle style — no new art asset
   assumed.
