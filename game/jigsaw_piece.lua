local Sprite = require("lua/core/sprite")
local C = require("game/constants")

local JigsawPiece = {}
JigsawPiece.__index = JigsawPiece

local GROUND_Y = 220 - C.SLOT  -- 156

function JigsawPiece.new(x, color)
    local self = setmetatable({}, JigsawPiece)
    self.sprite = Sprite.new(x, GROUND_Y, C.SLOT, C.SLOT)
    self.sprite.color = color
    self.sprite.rotation = 0
    self.state = "grounded"
    self.rotation_step = 0
    return self
end

function JigsawPiece:rotate()
    self.rotation_step = (self.rotation_step + 1) % 4
    self.sprite.rotation = self.rotation_step * (math.pi / 2)
end

function JigsawPiece:pick_up()
    self.state = "held"
end

function JigsawPiece:drop(wx)
    self.sprite.x = math.floor(wx / C.SLOT + 0.5) * C.SLOT
    self.sprite.y = GROUND_Y
    self.state = "grounded"
end

function JigsawPiece:update(player)
    if self.state == "held" then
        self.sprite.x = player:centre().x - C.U
        self.sprite.y = player.sprite.y - 2 * C.U
    end
end

function JigsawPiece:centre()
    return { x = self.sprite.x + C.U, y = self.sprite.y + C.U }
end

function JigsawPiece:draw()
    self.sprite:draw()
end

return JigsawPiece
