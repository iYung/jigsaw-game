local Sprite = require("lua/core/sprite")
local C = require("game/constants")
local GameState = require("game/game_state")
local PuzzleCatalog = require("game/puzzle_catalog")

-- Same role game/door.lua used to play as a grid-aligned world object
-- marking where new boxes fly in from, but drawn as a stack of small boxes
-- (one per puzzle still left to see this session) instead of one flat tile.
-- Also the player's spawn-a-box interact target (see :interact()), taking
-- over that role from the now-retired game/spawn_button.lua.
local PuzzlePile = {}
PuzzlePile.__index = PuzzlePile

function PuzzlePile.new(x, y, on_press)
    local self = setmetatable({}, PuzzlePile)
    -- Base footprint sprite: same role the door's sprite played for
    -- occupancy checks in game_scene.lua's _spawn_box (blocks this grid
    -- cell from being picked as a new box's resting cell). Invisible --
    -- the stack itself is drawn in :draw(), not via Sprite:draw().
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

-- Fully derived from GameState + PuzzleCatalog on every call -- no
-- stored/cached count on the pile itself, so it can never drift out of
-- sync with the pool JigsawBox.new actually draws from. Updates for free
-- the instant GameState:mark_seen runs inside JigsawBox.new, whether
-- that's from the initial on_enter box or a button-triggered spawn.
function PuzzlePile:count()
    return GameState:remaining_puzzle_count(PuzzleCatalog.list_by_tier())
end

-- World position the top box in the stack currently occupies -- this is
-- where a newly-spawned box's flight animation should originate from.
-- Floors n at 1 so this always returns a sane point even at count() == 0
-- (defensive only -- _spawn_box never actually reaches the animation-origin
-- call when the pool is empty, since JigsawBox.new returns nil first).
function PuzzlePile:top_position()
    local n = math.max(self:count(), 1)
    return {
        x = self.sprite.x,
        y = self.sprite.y - (n - 1) * C.PILE_BOX_STACK_OFFSET,
    }
end

function PuzzlePile:draw()
    local n = self:count()
    -- Same orange JigsawBox uses for its own sprite (jigsaw_box.lua:33), so
    -- the stacked boxes read visually as "boxes," just smaller and stacked.
    love.graphics.setColor(1, 0.75, 0.2, 1)
    local inset = (C.SLOT - C.PILE_BOX_SIZE) / 2
    for i = 1, n do
        local by = self.sprite.y - (i - 1) * C.PILE_BOX_STACK_OFFSET
        love.graphics.rectangle("fill", self.sprite.x + inset, by + inset, C.PILE_BOX_SIZE, C.PILE_BOX_SIZE)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return PuzzlePile
