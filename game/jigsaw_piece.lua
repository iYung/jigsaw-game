local Sprite = require("lua/core/sprite")
local C = require("game/constants")

local JigsawPiece = {}
JigsawPiece.__index = JigsawPiece

-- Loaded lazily on first celebrating draw; nil in headless mode (never loaded).
local _shine_shader = nil

local GROUND_Y = 3 * C.SLOT  -- 192 (ground sits at 4*SLOT=256, pieces rest on top)

function JigsawPiece.new(x, color, visual)
    local self = setmetatable({}, JigsawPiece)
    self.sprite = Sprite.new(x, GROUND_Y, C.SLOT, C.SLOT)
    self.sprite.color = color
    self.sprite.rotation = 0
    if visual then
        self.sprite.image = visual.image
        self.sprite.quad = visual.quad
        self.row = visual.row
        self.col = visual.col
        self.path = visual.path
    end
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

function JigsawPiece:drop(x, y)
    self.sprite.x = math.floor(x / C.SLOT + 0.5) * C.SLOT
    self.sprite.y = math.floor(y / C.SLOT + 0.5) * C.SLOT
    self.state = "grounded"
end

function JigsawPiece:start_celebrate(total_cols)
    self.state = "celebrating"
    self.celebrate_timer = C.PIECE_CELEBRATE_DURATION
    self._celebrate_cols = total_cols or 1
end

function JigsawPiece:update_celebrate(dt)
    self.celebrate_timer = self.celebrate_timer - dt
    if self.celebrate_timer <= 0 then
        self:start_vanish()
        return true
    end
    return false
end

function JigsawPiece:start_vanish()
    self.state = "vanishing"
    self.fade_timer = C.PIECE_FADE_DURATION
end

function JigsawPiece:update_fade(dt)
    self.fade_timer = self.fade_timer - dt
    self.sprite.color[4] = math.max(0, self.fade_timer / C.PIECE_FADE_DURATION)
    return self.fade_timer <= 0
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
    if self.state == "celebrating" then
        -- Load shader once (skipped in headless mode where newShader is absent).
        if not _shine_shader and love.graphics and love.graphics.newShader then
            _shine_shader = love.graphics.newShader("assets/shaders/shine.frag")
        end
        if _shine_shader then
            local t = self.celebrate_timer / C.PIECE_CELEBRATE_DURATION
            local global_progress = 1 - t  -- 0=left edge of puzzle, 1=right edge
            local total = self._celebrate_cols or 1
            -- Band travels from 0.3 cols before the left edge to 0.3 cols past the
            -- right edge, so it fades in and out rather than appearing/disappearing
            -- abruptly at piece boundaries.
            local band = global_progress * (total + 0.6) - 0.3
            -- local_progress: where the band center sits in this piece's own UV space
            -- (0 = piece left, 1 = piece right; outside that range = band off-screen
            -- for this piece, which the shader's distance test handles gracefully).
            local local_progress = band - (self.col or 0)
            self.sprite.shader = _shine_shader
            _shine_shader:send("local_progress", local_progress)
        end
    else
        self.sprite.shader = nil
    end
    self.sprite:draw()
end

function JigsawPiece:draw_ghost(x, y, alpha)
    alpha = alpha or 0.35
    local orig_x = self.sprite.x
    local orig_y = self.sprite.y
    local orig_a = self.sprite.color[4]
    self.sprite.x = x
    self.sprite.y = y
    self.sprite.color[4] = alpha
    self.sprite:draw()
    self.sprite.x = orig_x
    self.sprite.y = orig_y
    self.sprite.color[4] = orig_a
end

function JigsawPiece:to_save()
    return {
        path = self.path,
        row = self.row,
        col = self.col,
        rotation_step = self.rotation_step,
        x = self.sprite.x,
        y = self.sprite.y,
    }
end

function JigsawPiece.from_save(data)
    local image = love.graphics.newImage(data.path)
    local imgW, imgH = image:getDimensions()
    local quad = love.graphics.newQuad(data.col * C.SLOT, data.row * C.SLOT, C.SLOT, C.SLOT, imgW, imgH)
    local piece = JigsawPiece.new(data.x, {1, 1, 1, 1}, { image = image, quad = quad, row = data.row, col = data.col, path = data.path })
    piece.sprite.x = data.x
    piece.sprite.y = data.y
    for _ = 1, data.rotation_step do
        piece:rotate()
    end
    return piece
end

return JigsawPiece
