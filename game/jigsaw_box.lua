local Sprite = require("lua/core/sprite")
local JigsawPiece = require("game/jigsaw_piece")
local C = require("game/constants")

local JigsawBox = {}
JigsawBox.__index = JigsawBox

function JigsawBox.new(x, y)
    local self = setmetatable({}, JigsawBox)
    self.sprite = Sprite.new(x, y, C.SLOT, C.SLOT)
    self.sprite.color = {1, 0.75, 0.2, 1}
    self.state = "waiting"
    self.spawn_timer = 0
    self.pieces_to_spawn = {
        {1, 0.3, 0.3, 1},
        {0.3, 0.6, 1, 1},
        {0.3, 1, 0.5, 1},
    }
    self.spawned = {}
    return self
end

function JigsawBox:interact()
    if self.state == "waiting" then
        self.state = "ejecting"
        self.spawn_timer = 0
    end
end

function JigsawBox:update(dt, pieces)
    if self.state ~= "ejecting" then return end
    self.spawn_timer = self.spawn_timer - dt
    if self.spawn_timer <= 0 then
        self:_eject_next(pieces)
        self.spawn_timer = 0.3
    end
end

function JigsawBox:_eject_next(pieces)
    local color = table.remove(self.pieces_to_spawn, 1)
    local bx = self.sprite.x
    local by = self.sprite.y

    local cx, cy
    for d = 1, 20 do
        local candidates = {}
        for dx = -d, d do
            local ady = d - math.abs(dx)
            if ady == 0 then
                candidates[#candidates + 1] = {dx, 0}
            else
                candidates[#candidates + 1] = {dx, -ady}
                candidates[#candidates + 1] = {dx,  ady}
            end
        end
        table.sort(candidates, function(a, b)
            if a[1] ~= b[1] then return a[1] < b[1] end
            return a[2] < b[2]
        end)

        for _, pair in ipairs(candidates) do
            local tx = bx + pair[1] * C.SLOT
            local ty = by + pair[2] * C.SLOT
            local occupied = false
            for _, p in ipairs(pieces) do
                if p.state == "grounded" and p.sprite.x == tx and p.sprite.y == ty then
                    occupied = true
                    break
                end
            end
            if not occupied then
                cx, cy = tx, ty
                break
            end
        end
        if cx then break end
    end

    local piece = JigsawPiece.new(cx, color)
    piece.sprite.y = cy

    pieces[#pieces + 1] = piece
    self.spawned[#self.spawned + 1] = piece

    if #self.pieces_to_spawn == 0 then
        self.state = "done"
    end
end

function JigsawBox:centre()
    return {x = self.sprite.x + C.U, y = self.sprite.y + C.U}
end

function JigsawBox:draw()
    self.sprite:draw()
end

return JigsawBox
