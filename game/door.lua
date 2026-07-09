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
