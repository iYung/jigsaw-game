local Scene      = require("lua/core/scene")
local Sprite     = require("lua/core/sprite")
local Player     = require("game/player")
local C          = require("game/constants")
local JigsawPiece = require("game/jigsaw_piece")

local GameScene = {}
GameScene.__index = GameScene

function GameScene.new()
    local self = Scene.new(1280, 720)
    setmetatable(self, GameScene)
    return self
end

function GameScene:on_enter()
    local WORLD_W = 40 * C.SLOT  -- 2560px

    self.world_w = WORLD_W

    self.player = Player.new(-16, 170)
    self.drawer:add(self.player, 10)

    self.ground = Sprite.new(0, 220, WORLD_W, 30)
    self.ground.color = { 0.25, 0.65, 0.25, 1 }
    self.drawer:add(self.ground, 1)

    self.pieces = {
        JigsawPiece.new(384,  { 1,   0.3, 0.3, 1 }),
        JigsawPiece.new(1280, { 0.3, 0.6, 1,   1 }),
        JigsawPiece.new(2112, { 0.3, 1,   0.5, 1 }),
    }

    for _, piece in ipairs(self.pieces) do
        self.drawer:add(piece, 5)
    end
end

function GameScene:update(dt)
    self.player:update(dt, self.pieces)

    self.player.sprite.x = math.max(0, math.min(self.player.sprite.x, self.world_w - 32))

    self.camera:follow(self.player:centre(), 0.85)
end

function GameScene:draw()
    Scene.draw(self)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("WASD: move   E: pick up / drop   R: rotate   ESC: quit", 16, 16)
    local c = self.player:centre()
    love.graphics.print(string.format("player (%.0f, %.0f)", c.x, c.y), 16, 36)
end

return GameScene
