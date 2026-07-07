local Scene      = require("lua/core/scene")
local Sprite     = require("lua/core/sprite")
local Player     = require("game/player")
local C          = require("game/constants")
local JigsawBox  = require("game/jigsaw_box")

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

    local GROUND_Y = 4 * C.SLOT  -- 256, grid-aligned so pieces rest at 3*SLOT=192

    self.player = Player.new(0, GROUND_Y - 48)
    self.drawer:add(self.player, 10)

    self.ground = Sprite.new(0, GROUND_Y, WORLD_W, 30)
    self.ground.color = { 0.25, 0.65, 0.25, 1 }
    self.drawer:add(self.ground, 1)

    self.pieces = {}
    self.pieces_in_drawer = {}

    self.box = JigsawBox.new(5 * C.SLOT, 3 * C.SLOT)
    self.drawer:add(self.box, C.PRIORITY_PIECE)
end

function GameScene:update(dt)
    if self.box then self.box:update(dt, self.pieces) end

    for _, piece in ipairs(self.pieces) do
        if not self.pieces_in_drawer[piece] then
            self.drawer:add(piece, C.PRIORITY_PIECE)
            self.pieces_in_drawer[piece] = true
        end
    end

    if self.box and self.box.state == "done" then
        self.box.sprite.visible = false
        self.box = nil
    end

    self.player:update(dt, self.pieces, self.box, self.drawer)

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
