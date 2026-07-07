local Scene      = require("lua/core/scene")
local Sprite     = require("lua/core/sprite")
local Player     = require("game/player")
local C          = require("game/constants")
local JigsawBox  = require("game/jigsaw_box")
local JigsawSolver = require("game/jigsaw_solver")
local SpawnButton = require("game/spawn_button")

local GameScene = {}
GameScene.__index = GameScene

function GameScene.new()
    local self = Scene.new(1280, 720)
    setmetatable(self, GameScene)
    return self
end

function GameScene:on_enter()
    local WORLD_W = 40 * C.SLOT  -- 2560px
    local WORLD_H = WORLD_W

    self.world_w = WORLD_W
    self.world_h = WORLD_H

    local GROUND_Y = 4 * C.SLOT  -- 256, grid-aligned so pieces rest at 3*SLOT=192

    self.player = Player.new(0, GROUND_Y - 48)
    self.drawer:add(self.player, 10)

    self.ground = Sprite.new(0, GROUND_Y, WORLD_W, 30)
    self.ground.color = { 0.25, 0.65, 0.25, 1 }
    self.drawer:add(self.ground, 1)

    self.pieces = {}
    self.pieces_in_drawer = {}
    self.puzzle_solved = false

    self.boxes = { JigsawBox.new(5 * C.SLOT, 3 * C.SLOT) }
    self.drawer:add(self.boxes[1], C.PRIORITY_PIECE)

    self.spawn_button = SpawnButton.new(WORLD_W / 2, 0, function() self:_spawn_box() end)
    self.drawer:add(self.spawn_button, C.PRIORITY_PIECE)
end

function GameScene:_spawn_box()
    local cols = self.world_w / C.SLOT
    local rows = self.world_h / C.SLOT

    for _ = 1, 50 do
        local cx = math.random(0, cols - 1) * C.SLOT
        local cy = math.random(0, rows - 1) * C.SLOT

        local occupied = false
        for _, box in ipairs(self.boxes) do
            if box.sprite.x == cx and box.sprite.y == cy then
                occupied = true
                break
            end
        end
        if not occupied and self.spawn_button.sprite.x == cx and self.spawn_button.sprite.y == cy then
            occupied = true
        end

        if not occupied then
            local box = JigsawBox.new(cx, cy)
            self.boxes[#self.boxes + 1] = box
            self.drawer:add(box, C.PRIORITY_PIECE)
            return
        end
    end
end

function GameScene:update(dt)
    for _, box in ipairs(self.boxes) do
        box:update(dt, self.pieces)
    end

    for _, piece in ipairs(self.pieces) do
        if not self.pieces_in_drawer[piece] then
            self.drawer:add(piece, C.PRIORITY_PIECE)
            self.pieces_in_drawer[piece] = true
        end
    end

    for i = #self.boxes, 1, -1 do
        local box = self.boxes[i]
        if box.state == "done" then
            box.sprite.visible = false
            table.remove(self.boxes, i)
        end
    end

    self.player:update(dt, self.pieces, self.boxes, self.spawn_button, self.drawer)

    if not self.puzzle_solved and JigsawSolver.is_assembled(self.pieces) then
        self.puzzle_solved = true
        for _, piece in ipairs(self.pieces) do
            piece:start_vanish()
        end
    end

    for i = #self.pieces, 1, -1 do
        local piece = self.pieces[i]
        if piece.state == "vanishing" then
            local finished = piece:update_fade(dt)
            if finished then
                table.remove(self.pieces, i)
                self.drawer:remove(piece)
                self.pieces_in_drawer[piece] = nil
            end
        end
    end

    self.player.sprite.x = math.max(0, math.min(self.player.sprite.x, self.world_w - 32))
    self.player.sprite.y = math.max(0, math.min(self.player.sprite.y, self.world_h - 48))

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
