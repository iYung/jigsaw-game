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

function Player:update(dt, pieces, box, drawer)
    self.input:update()
    local s = self.sprite
    if self.input:is_down("left")  then s.x = s.x - SPEED * dt end
    if self.input:is_down("right") then s.x = s.x + SPEED * dt end
    if self.input:is_down("up")    then s.y = s.y - SPEED * dt end
    if self.input:is_down("down")  then s.y = s.y + SPEED * dt end

    if self.input:pressed("interact") then
        if self.held_piece ~= nil then
            local drop_target = self:drop_target()
            local occupied = false
            if pieces then
                for _, p in ipairs(pieces) do
                    if p ~= self.held_piece and p.state == "grounded"
                       and p.sprite.x == drop_target.snap_x and p.sprite.y == drop_target.snap_y then
                        occupied = true
                        break
                    end
                end
            end
            if not occupied then
                self.held_piece:drop(drop_target.x, drop_target.y)
                pieces[#pieces + 1] = self.held_piece
                if drawer then
                    drawer:add(self.held_piece, C.PRIORITY_PIECE)
                end
                self.held_piece = nil
            end
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
                for i, piece in ipairs(pieces) do
                    if piece == nearest then
                        table.remove(pieces, i)
                        break
                    end
                end
                if drawer then
                    drawer:remove(nearest)
                end
                self.held_piece = nearest
            end
            if self.held_piece == nil and box ~= nil and box.state == "waiting" then
                local bc = box:centre()
                local dx = bc.x - centre.x
                local dy = bc.y - centre.y
                if math.sqrt(dx * dx + dy * dy) <= 1.5 * C.U then
                    box:interact()
                end
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

-- Where a held piece would land (grid-snapped) if dropped right now
function Player:drop_target()
    local centre = self:centre()
    local target_x = centre.x - C.U
    local target_y = centre.y - C.U
    local snap_x = math.floor(target_x / C.SLOT + 0.5) * C.SLOT
    local snap_y = math.floor(target_y / C.SLOT + 0.5) * C.SLOT
    return { x = target_x, y = target_y, snap_x = snap_x, snap_y = snap_y }
end

function Player:draw()
    if self.held_piece ~= nil then
        local drop_target = self:drop_target()
        self.held_piece:draw_ghost(drop_target.snap_x, drop_target.snap_y)
    end
    self.sprite:draw()
    if self.held_piece ~= nil then
        self.held_piece:draw()
    end
end

return Player
