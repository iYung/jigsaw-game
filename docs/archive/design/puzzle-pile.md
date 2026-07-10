# Puzzle Pile

## Goal
Replace the purely-visual blue-violet door (`game/door.lua`, instantiated at `game/scenes/game_scene.lua:92-93`) with a visual pile of small orange boxes, one per puzzle still left to be solved this session, so the player can see at a glance how many puzzles remain. When the red spawn button (`game/spawn_button.lua`) is pressed, the newly-spawned box's flight animation (`game/jigsaw_box.lua:85-104`, driven by the `spawn_from` point passed into `JigsawBox.new`) should originate from the top of that pile — currently a fixed point (the door's `sprite.x/y`) — and the pile should visibly shrink by one box the moment the pool of unseen puzzles it represents shrinks.

## Affected files
- `game/door.lua` — deleted; replaced by `game/puzzle_pile.lua`.
- `game/puzzle_pile.lua` — **new**. Same footprint/role as `door.lua` (visual-only, no `interact()`), but draws a stack of small boxes instead of one flat tile, and exposes the remaining count + top-of-stack position.
- `game/game_state.lua` — add `remaining_puzzle_count(by_tier)`, summing unseen paths across ALL tiers (easy/med/hard), regardless of lock status.
- `game/scenes/game_scene.lua` — swap `Door.new` for `PuzzlePile.new`; `self.door` → `self.pile`; update the occupancy check and `spawn_from` source in `_spawn_box`.
- `game/constants.lua` — add `PILE_BOX_SIZE`, `PILE_BOX_STACK_OFFSET`.
- `README.md` — update the door description (line 14) and the file-map bullet (line 21) to describe the pile instead.
- `tests/test_jigsaw.lua` or a new `tests/test_puzzle_pile.lua` — cover count derivation and top-of-stack position.

## What changes

### `game/game_state.lua` — remaining count
```lua
-- Returns the number of puzzle images not yet spawned this session, summed
-- across ALL tiers (including locked ones -- a locked tier's images are
-- still "left to solve," they're just not selectable yet). Callers pass
-- PuzzleCatalog.list_by_tier() so this stays decoupled from the catalog
-- module.
function GameState:remaining_puzzle_count(by_tier)
    local total = 0
    for tier, paths in pairs(by_tier) do
        total = total + #self:unseen_paths(tier, paths)
    end
    return total
end
```
Deliberately tier-lock-agnostic: `mark_seen` is only ever called for a path drawn from an *unlocked* tier's pool (`jigsaw_box.lua:14-15`), so a locked tier's paths are never marked seen while locked. Counting them anyway doesn't cause double-counting, and there's no discontinuity at the moment a tier unlocks — the number just keeps counting down smoothly through that event instead of jumping.

### `game/puzzle_pile.lua` (new, replaces `game/door.lua`)
```lua
local Sprite = require("lua/core/sprite")
local C = require("game/constants")
local GameState = require("game/game_state")
local PuzzleCatalog = require("game/puzzle_catalog")

local PuzzlePile = {}
PuzzlePile.__index = PuzzlePile

function PuzzlePile.new(x, y)
    local self = setmetatable({}, PuzzlePile)
    -- Base footprint sprite: same role the door's sprite played for
    -- occupancy checks in game_scene.lua's _spawn_box (blocks this grid
    -- cell from being picked as a new box's resting cell). Invisible --
    -- the stack itself is drawn in :draw().
    self.sprite = Sprite.new(x, y, C.SLOT, C.SLOT)
    self.sprite.visible = false
    return self
end

function PuzzlePile:count()
    return GameState:remaining_puzzle_count(PuzzleCatalog.list_by_tier())
end

-- World position the top box in the stack currently occupies -- this is
-- where a newly-spawned box's flight animation should originate from.
function PuzzlePile:top_position()
    local n = math.max(self:count(), 1)
    return {
        x = self.sprite.x,
        y = self.sprite.y - (n - 1) * C.PILE_BOX_STACK_OFFSET,
    }
end

function PuzzlePile:draw()
    local n = self:count()
    love.graphics.setColor(1, 0.75, 0.2, 1)
    local inset = (C.SLOT - C.PILE_BOX_SIZE) / 2
    for i = 1, n do
        local by = self.sprite.y - (i - 1) * C.PILE_BOX_STACK_OFFSET
        love.graphics.rectangle("fill", self.sprite.x + inset, by + inset, C.PILE_BOX_SIZE, C.PILE_BOX_SIZE)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return PuzzlePile
```
- `count()` is fully derived from `GameState` + `PuzzleCatalog` on every call — no stored/cached counter on the pile itself, so it can never drift out of sync with the pool `JigsawBox.new` actually draws from. It updates for free the instant `GameState:mark_seen` runs inside `JigsawBox.new`, whether that's from the initial `on_enter` box or a button-triggered spawn.
- Reuses the same orange (`{1, 0.75, 0.2, 1}`) `JigsawBox` uses for its own sprite (`jigsaw_box.lua:33`), so the stacked boxes read visually as "boxes," just smaller and stacked.
- `top_position()` floors `n` at 1 so it always returns a sane point even at `count() == 0` (defensive only — `_spawn_box` never actually reaches the animation-origin call when the pool is empty, since `JigsawBox.new` returns `nil` first and the function returns before using it).

### `game/constants.lua`
```lua
PILE_BOX_SIZE = 0.5 * SLOT,          -- 32px, one stacked box's edge length
PILE_BOX_STACK_OFFSET = 6,           -- px each successive box is drawn higher
```
With the current catalog (9 easy + 3 med + 2 hard = 14 max), the tallest possible pile stands `(14-1)*6 = 78px` from base to top box's origin, well within the background's headroom above the floor (`BG_OFFSET_Y = -328`).

### `game/scenes/game_scene.lua`
- `local Door = require("game/door")` → `local PuzzlePile = require("game/puzzle_pile")`
- `self.door = Door.new(WORLD_W / 2, 0)` → `self.pile = PuzzlePile.new(WORLD_W / 2, 0)`
- `_spawn_box` occupancy check: `self.door.sprite.x == cx and self.door.sprite.y == cy` → `self.pile.sprite.x == cx and self.pile.sprite.y == cy` (unchanged behavior — still blocks the pile's base cell from being chosen as a resting cell for a new box).
- `_spawn_box` flight origin:
```lua
local box = JigsawBox.new(cx, cy, self.world_w, self.world_h, self.pile:top_position())
```
  (previously `{ x = self.door.sprite.x, y = self.door.sprite.y }`, a fixed point; now the live top-of-stack point, which sits progressively lower as the pile depletes over the course of a session.)

## What stays the same
- `game/jigsaw_box.lua`'s flight animation itself (linear lerp + parabolic arc, `BOX_FLY_DURATION`, `BOX_FLY_ARC_HEIGHT`) is untouched — only the `spawn_from` point it's given changes.
- The active-puzzle cap (`GameState.MAX_ACTIVE_PUZZLES = 3`) and per-tier unlock gating (`is_tier_unlocked`) are untouched.
- The initial `on_enter` box (`game_scene.lua:69-87`) still spawns with no `spawn_from` / no flight animation — this design only changes the button-triggered spawn path (`_spawn_box`), matching the request ("when the red button is pressed..."). The pile's displayed count correctly reflects that this box already consumed one puzzle from the pool, since `count()` is derived live rather than tracked separately — no special-casing needed.
- `game/spawn_button.lua` and the player-interact dispatch in `game/player.lua` are unchanged — the pile, like the door before it, has no `interact()` and is never passed to `player:update()`.
- `GameState:can_start_puzzle()` / the 3-active-puzzle cap can leave the pile visually nonempty even while the spawn button is a silent no-op (cap reached) — same "button no-ops while something is still visually present" situation that already exists today with the door; not new to this change.

## Open questions
None outstanding — confirmed with the user:
- Pile count = unseen puzzles summed across **all** tiers, including locked ones (not just currently-unlocked tiers). One consequence: it's possible for the pile to show puzzles remaining while the button silently no-ops, if every remaining unseen image is in a still-locked tier. This mirrors an existing class of "no-op while something is visible" behavior (see cap note above) rather than introducing a new kind of surprise.
- Rendering is uncapped: one small box drawn per remaining puzzle (max realistic count is 14 given the current catalog), stacked vertically with a fixed per-box offset rather than a capped/representative stack.
