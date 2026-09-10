local Sprite = require("lua/core/sprite")
local C = require("game/constants")

local HelpTile = {}
HelpTile.__index = HelpTile

function HelpTile.new(x, y, on_press)
    local self = setmetatable({}, HelpTile)
    self.sprite = Sprite.new(x, y, C.SLOT, C.SLOT)
    self.sprite.visible = false
    self.on_press = on_press
    self.active = false
    return self
end

function HelpTile:interact()
    if self.on_press then
        self.on_press()
    end
end

function HelpTile:centre()
    return { x = self.sprite.x + C.U, y = self.sprite.y + C.U }
end

function HelpTile:draw()
    if self.active then
        love.graphics.setColor(1, 0.5, 1, 1)
    else
        love.graphics.setColor(0.9, 0.2, 0.9, 1)
    end
    local inset = (C.SLOT - C.PILE_BOX_SIZE) / 2
    love.graphics.rectangle("fill", self.sprite.x + inset, self.sprite.y + inset, C.PILE_BOX_SIZE, C.PILE_BOX_SIZE)
    love.graphics.setColor(1, 1, 1, 1)
end

return HelpTile
