# Spawn Button

## Goal
Add a grid-aligned "spawn button" object placed at the top-centre of the world. The player walks up
to it and presses interact (`E`), just like the existing jigsaw box, and it spawns a brand-new
`JigsawBox` at a random grid-aligned position somewhere in the world. This lets the player generate
additional puzzle boxes on demand instead of only ever having the one box placed at scene start.

Today the world only has a defined horizontal extent (`world_w`, `game/scenes/game_scene.lua:18-20`)
— there is no vertical bound, so "a random spot in the world" is currently undefined on the Y axis.
Per user decision, the world becomes a fixed square: `world_h = world_w` (2560px). Also per user
decision, the button is a world object (not a mouse/UI element — the game has no mouse input today),
it spawns a full `JigsawBox` (not a plain crate), and it sits horizontally centred at the world's top
edge (`x = world_w / 2`, `y = 0`), which is already grid-aligned since `world_w` is a multiple of
`C.SLOT`.

`GameScene` currently only supports a single box (`self.box`, singular) that starts existing at scene
enter and gets discarded once it finishes ejecting all its pieces (`game/scenes/game_scene.lua:35,49-52`).
Supporting on-demand spawning means the scene needs to manage a *list* of boxes instead of one, and
`Player:update` (`game/player.lua:26-105`) needs to interact with "nearest waiting box in a list" plus
the new button, instead of a single fixed box reference.

## Affected files
- `game/constants.lua` — no changes; reuse `C.SLOT`, `C.U`, `C.PRIORITY_PIECE` for the button too.
- `game/spawn_button.lua` (new) — a small world object modeled on `game/jigsaw_box.lua`'s shape
  (`sprite`, `:centre()`, `:draw()`), but with no internal state machine. Its `:interact()` simply
  invokes an `on_press` callback supplied at construction, so all world-generation logic (random grid
  position, collision avoidance, bounds) stays in `GameScene`, which is the only thing that knows
  `world_w`/`world_h`.
- `game/scenes/game_scene.lua` —
  - Defines `WORLD_H = WORLD_W` and stores `self.world_h`.
  - Replaces `self.box` (singular) with `self.boxes` (array), seeded with the existing start-of-scene
    box.
  - Creates `self.spawn_button = SpawnButton.new(WORLD_W / 2, 0, function() self:_spawn_box() end)` and
    adds it to the drawer at `C.PRIORITY_PIECE`.
  - Adds a `GameScene:_spawn_box()` method: picks a random grid cell (`x` in `[0, world_w - SLOT]`,
    `y` in `[0, world_h - SLOT]`, both multiples of `C.SLOT`) that isn't already occupied by another
    box or the spawn button itself, retrying a bounded number of times; creates a `JigsawBox` there,
    appends it to `self.boxes`, and adds it to the drawer.
  - `GameScene:update` iterates `self.boxes` (instead of the single `self.box`) to call `:update(dt,
    self.pieces)` and to retire any box whose `state == "done"` (hide sprite, remove from the array —
    same per-box cleanup the singular version already does, just applied per entry).
  - Clamps `self.player.sprite.y` to `[0, self.world_h - 48]`, mirroring the existing X clamp, now that
    the world has a real vertical extent.
  - Passes `self.boxes` and `self.spawn_button` into `self.player:update(...)` instead of `self.box`.
- `game/player.lua` — `Player:update`'s signature changes from `(dt, pieces, box, drawer)` to `(dt,
  pieces, boxes, button, drawer)`. The existing "if not holding anything and didn't just pick up a
  piece" branch (`game/player.lua:85-92`) is generalized: instead of checking one fixed `box`, it scans
  `boxes` for the nearest one with `state == "waiting"` within `1.5 * C.U` and interacts with that one;
  then, if nothing was picked up or box-interacted this press, it separately checks distance to
  `button:centre()` and calls `button:interact()` if in range. Movement, piece pickup/drop/rotate logic
  is untouched.
- `tests/test_jigsaw.lua` — add coverage for: `SpawnButton:interact()` invoking its callback;
  `GameScene:_spawn_box()`-equivalent random-position logic landing on a grid-aligned cell inside world
  bounds and not colliding with existing boxes; `Player:update` interacting with the nearest waiting box
  out of several, and with the button when no box/piece is in range.

## What changes
- The world gains a real vertical extent: `world_h = world_w` (2560px square world).
- A new interactable `SpawnButton` object sits at `(world_w / 2, 0)` — grid-aligned, drawn like the
  jigsaw box (a colored square) at the top-centre of the world.
- Pressing interact near the button spawns a new `JigsawBox` at a random grid-aligned `(x, y)` anywhere
  in the world (not just along the ground), skipping cells already occupied by another box or the
  button, so boxes don't visually stack on top of each other or the button.
- `GameScene` now tracks any number of jigsaw boxes (starting with the original one from scene-enter)
  instead of exactly one.
- The player's vertical position is now clamped to the world bounds (`0` to `world_h - 48`), matching
  the existing horizontal clamp — previously Y was unbounded because no vertical extent existed.
- `Player:update`'s parameter list grows to include the button alongside the boxes list.

## What stays the same
- `JigsawBox` itself (state machine, piece ejection, radial placement search for its own pieces) is
  completely unchanged — the button only ever constructs new boxes via the existing `JigsawBox.new`.
- Grid alignment rules for all non-player objects are unchanged and continue to apply: the button and
  every spawned box sit on `C.SLOT` multiples.
- The player remains the only non-grid-aligned entity, and free (non-grid) movement in both axes is
  unchanged aside from the new bounding clamp.
- Piece pickup/drop/rotate behavior, drop-target ghost preview, and puzzle-solved/vanish logic are
  untouched.
- No mouse/UI input is introduced; the button is a world object interacted with via the existing `E`
  key, consistent with everything else in the game.

## Open questions
None outstanding — confirmed with the user:
- Button is a world object (walk up + press E), not a screen-space UI button.
- It spawns a full `JigsawBox` (a new puzzle to solve), not a plain decorative crate.
- The world is fixed at `world_h = world_w` (square), and the random spawn spot uses the full 2D
  area (not just a random X along the ground).
- The button sits horizontally centred at the world's top edge.
