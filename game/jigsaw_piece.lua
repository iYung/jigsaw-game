local Sprite = require("lua/core/sprite")
local C = require("game/constants")

local JigsawPiece = {}
JigsawPiece.__index = JigsawPiece

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

return JigsawPiece
