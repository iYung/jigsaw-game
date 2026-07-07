local Sprite = require("lua/core/sprite")
local C = require("game/constants")

local SpawnButton = {}
SpawnButton.__index = SpawnButton

function SpawnButton.new(x, y, on_press)
    local self = setmetatable({}, SpawnButton)
    self.sprite = Sprite.new(x, y, C.SLOT, C.SLOT)
    self.sprite.color = {0.9, 0.2, 0.2, 1}
    self.on_press = on_press
    return self
end

function SpawnButton:interact()
    if self.on_press then
        self.on_press()
    end
end

function SpawnButton:centre()
    return {x = self.sprite.x + C.U, y = self.sprite.y + C.U}
end

function SpawnButton:draw()
    self.sprite:draw()
end

return SpawnButton
