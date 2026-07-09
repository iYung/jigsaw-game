local Sprite = require("lua/core/sprite")
local JigsawPiece = require("game/jigsaw_piece")
local C = require("game/constants")
local PuzzleCatalog = require("game/puzzle_catalog")
local GameState = require("game/game_state")

local JigsawBox = {}
JigsawBox.__index = JigsawBox

function JigsawBox.new(x, y, world_w, world_h)
    local by_tier = PuzzleCatalog.list_by_tier()
    local pool = {}
    for tier, paths in pairs(by_tier) do
        if GameState:is_tier_unlocked(tier) then
            local unseen = GameState:unseen_paths(tier, paths)
            for _, path in ipairs(unseen) do
                pool[#pool + 1] = {path = path, tier = tier}
            end
        end
    end

    if #pool == 0 then
        return nil
    end

    local chosen = pool[math.random(#pool)]
    local path = chosen.path
    GameState:mark_seen(chosen.tier, path)

    local self = setmetatable({}, JigsawBox)
    self.tier = chosen.tier
    self.sprite = Sprite.new(x, y, C.SLOT, C.SLOT)
    self.sprite.color = {1, 0.75, 0.2, 1}
    self.state = "waiting"
    self.spawn_timer = 0
    self.world_w = world_w
    self.world_h = world_h

    local puzzle_image = love.graphics.newImage(path)
    self.image = puzzle_image
    local imgW, imgH = puzzle_image:getDimensions()
    local cols = imgW / C.SLOT
    local rows = imgH / C.SLOT
    assert(cols == math.floor(cols) and cols > 0,
        "puzzle image width must be a positive multiple of C.SLOT, got " .. tostring(imgW))
    assert(rows == math.floor(rows) and rows > 0,
        "puzzle image height must be a positive multiple of C.SLOT, got " .. tostring(imgH))
    self.rows = rows
    self.cols = cols
    self.piece_count = rows * cols

    self.pieces_to_spawn = {}
    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            local quad = love.graphics.newQuad(col * C.SLOT, row * C.SLOT, C.SLOT, C.SLOT, imgW, imgH)
            self.pieces_to_spawn[#self.pieces_to_spawn + 1] = { image = puzzle_image, quad = quad, row = row, col = col }
        end
    end

    for i = #self.pieces_to_spawn, 2, -1 do
        local j = math.random(i)
        self.pieces_to_spawn[i], self.pieces_to_spawn[j] = self.pieces_to_spawn[j], self.pieces_to_spawn[i]
    end

    self.spawned = {}
    return self
end

function JigsawBox:interact()
    if self.state == "waiting" then
        self.state = "ejecting"
        self.spawn_timer = 0
        self.sprite.visible = false
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
    local spec = table.remove(self.pieces_to_spawn, 1)
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
            local out_of_bounds = tx < 0 or tx >= self.world_w or ty < 0 or ty >= self.world_h
            local occupied = false
            for _, p in ipairs(pieces) do
                if p.state == "grounded" and p.sprite.x == tx and p.sprite.y == ty then
                    occupied = true
                    break
                end
            end
            if not occupied and not out_of_bounds then
                cx, cy = tx, ty
                break
            end
        end
        if cx then break end
    end

    local piece = JigsawPiece.new(cx, {1, 1, 1, 1}, spec)
    piece.sprite.y = cy

    local rotations = math.random(0, 3)
    for _ = 1, rotations do
        piece:rotate()
    end

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
