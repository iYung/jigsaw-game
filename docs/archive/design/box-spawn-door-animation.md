# Box Spawn Door Animation

## Goal
Give newly-spawned jigsaw boxes a sense of origin instead of popping into existence at their random target cell. Relocate the spawn button to the top-left of the map, add a purely-visual "door" object near the top-middle of the map, and have `_spawn_box()` fly the new `JigsawBox` from the door's position to its randomly-chosen target cell over a short, fixed-duration ease-out animation before it settles into its normal `"waiting"` state.

This is a world-space relocation + a cosmetic entity + an animation tween on box spawn — no new interaction model, no new input, no new libraries.

## Affected files
- `game/scenes/game_scene.lua` — move the spawn button's world position to the top-left; instantiate a new `Door` near the top-middle; wire the door into the drawer; pass the door's position into `JigsawBox.new` from `_spawn_box()`; fix the box-occupancy check used when picking a random target cell so it compares against a box's *target* cell rather than its (possibly mid-flight) `sprite` position.
- `game/door.lua` — **new**: visual-only entity, modeled on `game/spawn_button.lua` minus the interaction. No `interact()`, no collision, never passed to `player:update()`.
- `game/jigsaw_box.lua` — add an optional `spawn_from` param to `JigsawBox.new`; add a `"flying"` state that precedes `"waiting"`; add flight fields and an eased-lerp update step.
- `game/constants.lua` — add `BOX_FLY_DURATION`, following the existing `PIECE_FADE_DURATION` naming/usage pattern.

No changes needed to `game/spawn_button.lua` or `game/player.lua` — both are already position-agnostic (the button's world coordinates are passed in by the caller, and player interaction already gates on `box.state == "waiting"`, which a flying box is not).

## What changes

### Button relocation (`game_scene.lua`)
`self.spawn_button = SpawnButton.new(WORLD_W / 2, 0, ...)` moves from top-middle to top-left:
```lua
self.spawn_button = SpawnButton.new(0, 0, function() self:_spawn_box() end)
```
`(0, 0)` is the world's top-left grid cell — inside world bounds (`world_w`/`world_h` are unchanged), no margin adjustment needed since `(0,0)` is already a valid floor tile per the existing bounds-clamping in `update()`.

### New `Door` entity (`game/door.lua`)
A minimal visual-only object, structurally parallel to `SpawnButton`/`JigsawBox` but with no `interact()` and no state:
```lua
local Sprite = require("lua/core/sprite")
local C = require("game/constants")

local Door = {}
Door.__index = Door

function Door.new(x, y)
    local self = setmetatable({}, Door)
    self.sprite = Sprite.new(x, y, C.SLOT, C.SLOT)
    self.sprite.color = {0.3, 0.35, 0.85, 1}  -- distinct blue-violet, vs. red button / orange box
    return self
end

function Door:draw()
    self.sprite:draw()
end

return Door
```
Drawn with a plain `love.graphics.rectangle` via `Sprite:draw()` (same primitive-shape mechanism the button and box already use — a colored `SLOT × SLOT` square). Not added to `self.pieces`, `self.boxes`, or passed to `player:update()`, so it has zero interaction/collision surface.

In `game_scene.lua:on_enter`:
```lua
self.door = Door.new(WORLD_W / 2, 0, function() self:_spawn_box() end)
self.drawer:add(self.door, C.PRIORITY_PIECE)
```
(the door takes the old button spot, top-middle, at `(WORLD_W / 2, 0)`).

### Flight animation on box spawn (`jigsaw_box.lua`, `game_scene.lua`)
`_spawn_box()` keeps its existing 50-attempt random-cell-selection loop untouched — it still picks `(cx, cy)` the same way. The only change to that loop is what it compares against when checking whether a cell is already claimed by another box (see "Occupancy check fix" below).

Once a free `(cx, cy)` is found, instead of the box appearing there immediately, it's constructed with a `spawn_from` origin:
```lua
local box = JigsawBox.new(cx, cy, self.world_w, self.world_h,
    { x = self.door.sprite.x, y = self.door.sprite.y })
```

`JigsawBox.new(x, y, world_w, world_h, spawn_from)`:
- `x, y` are still the box's final resting cell (unchanged meaning).
- `spawn_from` is optional. When present, the box starts in a new `"flying"` state at `spawn_from`'s position and animates to `(x, y)`. When absent (the `on_enter` initial box, which has no door to fly from), behavior is unchanged — the box starts directly in `"waiting"` at `(x, y)`, exactly as today.
- New fields when flying: `self.target_x, self.target_y = x, y`; `self.spawn_x, self.spawn_y = spawn_from.x, spawn_from.y`; `self.sprite.x, self.sprite.y = self.spawn_x, self.spawn_y`; `self.fly_timer = C.BOX_FLY_DURATION`. (`spawn_x/spawn_y` are stored separately from `sprite.x/y` because the lerp needs a fixed origin to interpolate from — `sprite.x/y` moves every frame during flight.)
- `self.target_x`/`self.target_y` are always set (even for non-flying boxes, where they just equal `x, y`), so callers can consistently ask "where will/does this box end up" regardless of flight state.

`JigsawBox:update(dt, pieces)` gains a branch for `"flying"`, following the same countdown-timer idiom as `JigsawPiece:update_fade`:
```lua
if self.state == "flying" then
    self.fly_timer = self.fly_timer - dt
    local t = 1 - math.max(0, self.fly_timer) / C.BOX_FLY_DURATION
    local eased = 1 - (1 - t) ^ 3  -- ease-out cubic
    self.sprite.x = self.spawn_x + (self.target_x - self.spawn_x) * eased
    self.sprite.y = self.spawn_y + (self.target_y - self.spawn_y) * eased
    if self.fly_timer <= 0 then
        self.sprite.x, self.sprite.y = self.target_x, self.target_y
        self.state = "waiting"
    end
    return
end
-- existing "ejecting" handling below, unchanged
```
The pre-existing `"waiting" → "ejecting" → "done"` machinery is untouched; `"flying"` is a state that only exists *before* `"waiting"`, and only for button-spawned boxes.

`C.BOX_FLY_DURATION = 0.4` added to `constants.lua`, alongside `C.PIECE_FADE_DURATION = 0.5`.

Player interaction requires `b.state == "waiting"` (already true in `player.lua`), so a flying box is automatically un-interactable — no `player.lua` change needed.

### Occupancy check fix (`game_scene.lua`, `_spawn_box`)
The existing loop rejects a candidate cell if it matches an existing box's position:
```lua
if box.sprite.x == cx and box.sprite.y == cy then
```
With flight animation, `box.sprite.x/y` is a box's *current, possibly mid-flight* position, not its destination — so this check would fail to notice that a flying box already claims a target cell, letting a second box be aimed at the same cell mid-flight. Since `JigsawBox` now always tracks `target_x`/`target_y` (see above), the check is updated to compare against that instead:
```lua
if box.target_x == cx and box.target_y == cy then
```
This is a one-line fix required for correctness under animation; it does not change the random-selection algorithm itself. While here, the same loop's door-avoidance check (mirroring the existing button-avoidance check) is added so a box's target cell can't coincide with the door's tile either — purely cosmetic (door has no collision), just avoids a box visually spawning "inside" the door tile at rest.

## What stays the same
- The 50-attempt uniform-random target-cell selection algorithm in `_spawn_box()` (which columns/rows it considers, rejection-and-retry structure) is unchanged.
- `JigsawBox`'s existing `"waiting" → "ejecting" → "done"` state machine and piece-ejection logic (`_eject_next`, Manhattan-distance slot search, 0.3s per-piece timer) — untouched.
- `SpawnButton`'s implementation, walk-up-and-press-`E` interaction model, and `Sprite`-based rendering — untouched; only its world coordinates change at the call site.
- No mouse input added anywhere.
- No new tweening/animation library — the ease-out lerp is a few inline lines in `JigsawBox:update`, matching the existing hand-rolled timer+state idiom already used by `JigsawPiece:start_vanish()`/`update_fade()`.
- The `on_enter` initial box (spawned before any button press) keeps appearing directly in `"waiting"` state with no flight, since it has no `spawn_from`.
- World dimensions, ground position, camera follow, grid snapping, drawer/scene architecture — untouched.

## Open questions
None blocking. Two non-blocking notes left to implementer discretion, per the user's go-ahead that "simple primitive shape" is sufficient:
- Exact door color/shape beyond "a distinct-colored `SLOT × SLOT` rectangle" (e.g. whether to add a small arc/line as a doorknob detail) — proposed `{0.3, 0.35, 0.85, 1}` blue-violet above, easily changed.
- Exact ease-out curve (proposed cubic, `1 - (1-t)^3`) and duration (proposed `0.4s`, within the user-suggested 0.35–0.45s range) — both easy to retune as constants without touching call sites.
