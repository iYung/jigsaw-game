local Sprite = require("lua/core/sprite")
local C = require("game/constants")

-- World-space interactable, modeled on game/puzzle_pile.lua, that toggles
-- the camera into a zoomed-out view framing the completed-puzzles wall (see
-- docs/design/wall-view-tile.md). Purely the interactable object here -- no
-- camera/zoom logic lives in this file; GameScene owns wiring on_press to
-- the actual view-toggle behavior.
local WallViewTile = {}
WallViewTile.__index = WallViewTile

function WallViewTile.new(x, y, on_press)
    local self = setmetatable({}, WallViewTile)
    -- Base footprint sprite: same role as PuzzlePile's -- used for grid-cell
    -- occupancy checks (e.g. _spawn_box excluding this cell). Invisible --
    -- the tile itself is drawn in :draw(), not via Sprite:draw().
    self.sprite = Sprite.new(x, y, C.SLOT, C.SLOT)
    self.sprite.visible = false
    self.on_press = on_press
    return self
end

function WallViewTile:interact()
    if self.on_press then
        self.on_press()
    end
end

function WallViewTile:centre()
    return {x = self.sprite.x + C.U, y = self.sprite.y + C.U}
end

function WallViewTile:draw()
    -- Cool blue/teal, distinct from PuzzlePile's orange (1, 0.75, 0.2, 1),
    -- so this reads as a different kind of object in the world.
    love.graphics.setColor(0.2, 0.6, 0.9, 1)
    local inset = (C.SLOT - C.PILE_BOX_SIZE) / 2
    love.graphics.rectangle("fill", self.sprite.x + inset, self.sprite.y + inset, C.PILE_BOX_SIZE, C.PILE_BOX_SIZE)
    love.graphics.setColor(1, 1, 1, 1)
end

return WallViewTile
