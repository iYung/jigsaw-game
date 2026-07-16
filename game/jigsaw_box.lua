local Sprite = require("lua/core/sprite")
local JigsawPiece = require("game/jigsaw_piece")
local Sound = require("lua/core/sound")
local C = require("game/constants")
local PuzzleCatalog = require("game/puzzle_catalog")
local GameState = require("game/game_state")

local JigsawBox = {}
JigsawBox.__index = JigsawBox

function JigsawBox.new(x, y, world_w, world_h, spawn_from)
    local by_tier = PuzzleCatalog.list_by_tier()
    local pool = {}
    for tier, paths in pairs(by_tier) do
        if GameState:is_tier_unlocked(tier, by_tier) then
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
    self.path = path
    self.tier = chosen.tier
    self.sprite = Sprite.new(x, y, C.SLOT, C.SLOT)
    self.sprite.color = {1, 0.75, 0.2, 1}
    self.state = "waiting"
    self.spawn_timer = 0
    self.world_w = world_w
    self.world_h = world_h

    self.target_x, self.target_y = x, y
    if spawn_from then
        self.state = "flying"
        self.spawn_x, self.spawn_y = spawn_from.x, spawn_from.y
        self.sprite.x, self.sprite.y = self.spawn_x, self.spawn_y
        self.fly_timer = C.BOX_FLY_DURATION
    end

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
            self.pieces_to_spawn[#self.pieces_to_spawn + 1] = { image = puzzle_image, quad = quad, row = row, col = col, path = path }
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
    if self.state == "flying" then
        self.fly_timer = self.fly_timer - dt
        local t = 1 - math.max(0, self.fly_timer) / C.BOX_FLY_DURATION
        -- Ground and arc share the same linear progress t so the hop's peak
        -- lines up with the midpoint of the ground track (classic constant-
        -- velocity-plus-parabola projectile motion). Easing the ground alone
        -- while the arc stayed on raw t used to desync them -- the ground
        -- would race ~88% of the way there by t=0.5, so the box looked like
        -- it snapped near the target and then wobbled in place instead of
        -- tracing a single upward arc.
        local arc = 4 * t * (1 - t) * C.BOX_FLY_ARC_HEIGHT  -- 0 at t=0/1, peaks at t=0.5
        self.sprite.x = self.spawn_x + (self.target_x - self.spawn_x) * t
        self.sprite.y = self.spawn_y + (self.target_y - self.spawn_y) * t - arc
        if self.fly_timer <= 0 then
            self.sprite.x, self.sprite.y = self.target_x, self.target_y
            self.state = "waiting"
        end
        return
    end
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
    Sound.play("poof")

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

function JigsawBox:to_save()
    local pieces_to_spawn = {}
    for i, spec in ipairs(self.pieces_to_spawn) do
        pieces_to_spawn[i] = {row = spec.row, col = spec.col}
    end
    return {
        path = self.path,
        tier = self.tier,
        state = (self.state == "flying" and "waiting" or self.state),
        target_x = self.target_x,
        target_y = self.target_y,
        pieces_to_spawn = pieces_to_spawn,
    }
end

function JigsawBox.from_save(data, world_w, world_h)
    local self = setmetatable({}, JigsawBox)
    self.path = data.path
    self.tier = data.tier
    self.world_w = world_w
    self.world_h = world_h
    self.target_x, self.target_y = data.target_x, data.target_y

    self.sprite = Sprite.new(data.target_x, data.target_y, C.SLOT, C.SLOT)
    self.sprite.color = {1, 0.75, 0.2, 1}
    self.sprite.visible = true

    local puzzle_image = love.graphics.newImage(data.path)
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
    for _, entry in ipairs(data.pieces_to_spawn) do
        local quad = love.graphics.newQuad(entry.col * C.SLOT, entry.row * C.SLOT, C.SLOT, C.SLOT, imgW, imgH)
        self.pieces_to_spawn[#self.pieces_to_spawn + 1] =
            { image = puzzle_image, quad = quad, row = entry.row, col = entry.col, path = data.path }
    end

    self.spawned = {}

    if data.state == "ejecting" then
        self.state = "ejecting"
        self.spawn_timer = 0.3
        self.sprite.visible = false
    else
        self.state = "waiting"
        self.spawn_timer = 0
    end

    return self
end

return JigsawBox
