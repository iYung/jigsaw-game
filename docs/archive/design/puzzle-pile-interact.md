# Puzzle Pile Interact

## Goal
Retire the red spawn button (`game/spawn_button.lua`) as a separate world object and move its behavior — pressing **E** in range spawns a new `JigsawBox` via `GameScene:_spawn_box()` — onto the puzzle pile (`game/puzzle_pile.lua`) itself. The pile already visually represents "puzzles left to solve" and already originates the new box's flight animation (`pile:top_position()`); this change makes it the thing the player actually interacts with, so there's one less redundant object standing around the world.

## Affected files
- `game/spawn_button.lua` — deleted outright (same precedent as `game/door.lua`'s deletion when `puzzle_pile.lua` replaced it — see `docs/archive/design/puzzle-pile.md`).
- `game/puzzle_pile.lua` — gains an `on_press` constructor arg plus `interact()` and `centre()` methods, mirroring `SpawnButton`'s exactly. Header comment ("Visual-only, no interact()...") updated since that's no longer true.
- `game/scenes/game_scene.lua` — drop `self.spawn_button` entirely; `PuzzlePile.new` now takes the `_spawn_box` callback; `_spawn_box`'s occupancy check drops its spawn-button clause; `player:update()` is passed `self.pile` in the slot the button used to occupy.
- `game/player.lua` — no *behavioral* change (the `button` param is already duck-typed on `:centre()`/`:interact()`, so the pile drops in as-is). Rename the param `button` → `pile` for honesty, since it's never a button again.
- `README.md` — remove the spawn-button paragraph/bullet; fold "walk up and press E to spawn a new box" into the pile's description.
- `tests/test_jigsaw.lua` — remove the `SpawnButton`-specific tests (`interact()`, `centre()`, and the two `Player:update` "button:interact()" tests), since `game/spawn_button.lua` will no longer exist. The `_spawn_box` non-collision test's assertion against `gs.spawn_button.sprite.x/y` needs to drop (or be re-pointed at `gs.pile`, which is already collision-checked elsewhere).
- `tests/test_puzzle_pile.lua` — gains `interact()`/`centre()` coverage for `PuzzlePile`, and a player-priority test confirming a nearby waiting box still wins over the pile (mirroring the box-vs-button priority test being removed from `test_jigsaw.lua`).

## What changes

### `game/puzzle_pile.lua`
```lua
function PuzzlePile.new(x, y, on_press)
    local self = setmetatable({}, PuzzlePile)
    self.sprite = Sprite.new(x, y, C.SLOT, C.SLOT)
    self.sprite.visible = false
    self.on_press = on_press
    return self
end

function PuzzlePile:interact()
    if self.on_press then
        self.on_press()
    end
end

function PuzzlePile:centre()
    return {x = self.sprite.x + C.U, y = self.sprite.y + C.U}
end
```
Identical in shape to `SpawnButton:interact()`/`SpawnButton:centre()`. `centre()` works unchanged because the pile's base `sprite` is already the same `C.SLOT` × `C.SLOT` footprint the button used — no new geometry to reason about. `count()`, `top_position()`, and `draw()` are untouched.

### `game/scenes/game_scene.lua`
```lua
-- was:
-- self.spawn_button = SpawnButton.new(0, 0, function() self:_spawn_box() end)
-- self.drawer:add(self.spawn_button, C.PRIORITY_PIECE)
-- self.pile = PuzzlePile.new(WORLD_W / 2, 0)

self.pile = PuzzlePile.new(WORLD_W / 2, 0, function() self:_spawn_box() end)
self.drawer:add(self.pile, C.PRIORITY_PIECE)
```
`_spawn_box`'s occupancy loop drops its `self.spawn_button.sprite.x == cx and ...` clause (nothing left to occupy that cell). The `self.pile.sprite.x == cx and ...` clause stays exactly as-is — the pile still occupies a world cell that new boxes shouldn't spawn onto, completely independent of the fact that it's now also the interact trigger.

`player:update()`'s call site changes from `self.spawn_button` to `self.pile`:
```lua
self.player:update(dt, self.pieces, self.boxes, self.pile, self.drawer)
```

### `game/player.lua`
No logic changes. The 4th parameter is already generic — it only ever calls `:centre()` and `:interact()` on whatever's passed in, at the same point in the interact-priority chain (held-piece drop → nearest loose-piece pickup → nearest waiting-box interact → this param's interact, only if nothing else fired). Renaming the parameter from `button` to `pile` (and the local `bc` variable's comment, if any) is a same-behavior clarity fix riding along with this change.

### Can the player stand next to the pile and spawn a box that visibly flies out of that same pile?
Yes, and this already works with no extra effort: `_spawn_box`'s `spawn_from` argument was already sourced from `self.pile:top_position()` (done in the prior puzzle-pile feature, in anticipation of the button eventually moving here or just as a sensible default). The resting cell for the new box is still chosen randomly elsewhere on the grid — `top_position()` only ever supplied the flight's *origin*, never its destination — so nothing about the spawn/flight mechanic needs to change.

### Empty / capped pile behavior
No new logic needed. `_spawn_box()` already no-ops safely — via `GameState:can_start_puzzle()` at the active-puzzle cap, and via `JigsawBox.new` returning `nil` once the catalog's unseen pool is exhausted — regardless of what called it. Pressing E next to a capped-out or emptied pile silently does nothing, identical to pressing the button did today.

## What stays the same
- `game/jigsaw_box.lua`'s flight animation (duration, arc height, lerp) — untouched.
- `PuzzlePile:count()`, `:top_position()`, `:draw()` — untouched.
- The interact-priority ordering in `game/player.lua` (held-piece drop → pickup piece → box interact → pile interact) — the pile occupies exactly the slot the button used to, so a nearby waiting box still wins over the pile if both are in range, same as it won over the button.
- `GameState.MAX_ACTIVE_PUZZLES` cap and per-tier unlock gating — untouched.
- The initial `on_enter` box — still spawns with no `spawn_from`/flight animation, unaffected by this change.
- The 1.5 × `C.U` proximity radius used for the interact check — untouched, same constant, same formula.

## Open questions
None outstanding — confirmed with the user:
- **Visual affordance** is out of scope for this pass. The pile keeps its current look (a stack of orange boxes); no new highlight/outline/color treatment is added to signal interactivity. Any such polish is a follow-up, not part of this change.
