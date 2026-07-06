local Sprite = require("lua/core/sprite")
local Input  = require("lua/core/input")
local C      = require("game/constants")

local SPEED = 200

local Player = {}
Player.__index = Player

function Player.new(x, y)
    local self        = setmetatable({}, Player)
    self.sprite       = Sprite.new(x, y, 32, 48)
    self.sprite.image = love.graphics.newImage("assets/player.png")
    self.input        = Input.new({
        up           = { "w", "up" },
        down         = { "s", "down" },
        left         = { "a", "left" },
        right        = { "d", "right" },
        interact     = { "e" },
        rotate_piece = { "r" },
    })
    self.held_piece = nil
    return self
end

function Player:update(dt, pieces)
    self.input:update()
    local s = self.sprite
    if self.input:is_down("left")  then s.x = s.x - SPEED * dt end
    if self.input:is_down("right") then s.x = s.x + SPEED * dt end
    if self.input:is_down("up")    then s.y = s.y - SPEED * dt end
    if self.input:is_down("down")  then s.y = s.y + SPEED * dt end

    if self.input:pressed("interact") then
        if self.held_piece ~= nil then
            self.held_piece:drop()
            self.held_piece = nil
        else
            local centre = self:centre()
            local nearest, nearest_dist = nil, math.huge
            if pieces then
                for _, piece in ipairs(pieces) do
                    if piece.state == "grounded" then
                        local pc = piece:centre()
                        local dx = pc.x - centre.x
                        local dy = pc.y - centre.y
                        local dist = math.sqrt(dx * dx + dy * dy)
                        if dist < nearest_dist then
                            nearest_dist = dist
                            nearest = piece
                        end
                    end
                end
            end
            if nearest and nearest_dist <= 1.5 * C.U then
                nearest:pick_up()
                self.held_piece = nearest
            end
        end
    end

    if self.input:pressed("rotate_piece") then
        if self.held_piece ~= nil then
            self.held_piece:rotate()
        end
    end

    if self.held_piece ~= nil then
        self.held_piece:update(self)
    end
end

-- Centre point used for camera tracking
function Player:centre()
    return { x = self.sprite.x + 16, y = self.sprite.y + 24 }
end

function Player:draw()
    self.sprite:draw()
end

return Player
