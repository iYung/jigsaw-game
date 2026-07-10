local Scene     = require("lua/core/scene")
local Input     = require("lua/core/input")
local GameScene = require("game/scenes/game_scene")

local StartScene = {}
StartScene.__index = StartScene

local LOGICAL_W, LOGICAL_H = 1280, 720

local ITEM_W = 300
local ITEM_H = 60
local ITEM_GAP = 20
local ITEMS_TOP = 340

local NORMAL_COLOR   = { 0.35, 0.35, 0.35, 1 }
local SELECTED_COLOR = { 0.55, 0.55, 0.55, 1 }

function StartScene.new(manager)
    local self = Scene.new(LOGICAL_W, LOGICAL_H)
    setmetatable(self, StartScene)
    self.manager  = manager
    self.items    = { "New Game", "Exit Game" }
    self.selected = 1
    self.input    = Input.new({
        up      = { "w", "up" },
        down    = { "s", "down" },
        confirm = { "e", "return" },
    })
    return self
end

-- Logical (1280x720) bounding rect for menu item `i`, matching main.lua's
-- letterboxing convention so mouse hit-testing lines up with what's drawn.
function StartScene:_item_rect(i)
    local x = (LOGICAL_W - ITEM_W) / 2
    local y = ITEMS_TOP + (i - 1) * (ITEM_H + ITEM_GAP)
    return x, y, ITEM_W, ITEM_H
end

function StartScene:_point_in_rect(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

-- Convert raw window coordinates into the 1280x720 logical canvas space,
-- using the same scale/offset math as main.lua's love.draw letterboxing.
function StartScene:_to_logical(x, y)
    local scale = math.min(love.graphics.getWidth() / LOGICAL_W, love.graphics.getHeight() / LOGICAL_H)
    local ox = (love.graphics.getWidth() - LOGICAL_W * scale) / 2
    local oy = (love.graphics.getHeight() - LOGICAL_H * scale) / 2
    return (x - ox) / scale, (y - oy) / scale
end

function StartScene:on_enter() end

function StartScene:on_exit() end

function StartScene:_confirm()
    if self.selected == 1 then
        self.manager:switch(GameScene.new())
    elseif self.selected == 2 then
        love.event.quit()
    end
end

function StartScene:update(dt)
    self.input:update()

    if self.input:pressed("down") then
        self.selected = (self.selected % #self.items) + 1
    end
    if self.input:pressed("up") then
        self.selected = ((self.selected - 2) % #self.items) + 1
    end
    if self.input:pressed("confirm") then
        self:_confirm()
    end
end

function StartScene:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Jigsaw", 0, 160, LOGICAL_W, "center")

    for i, label in ipairs(self.items) do
        local x, y, w, h = self:_item_rect(i)
        if i == self.selected then
            love.graphics.setColor(SELECTED_COLOR)
        else
            love.graphics.setColor(NORMAL_COLOR)
        end
        love.graphics.rectangle("fill", x, y, w, h)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(label, x, y + h / 2 - 8, w, "center")
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function StartScene:mousemoved(x, y)
    local lx, ly = self:_to_logical(x, y)
    for i = 1, #self.items do
        local rx, ry, rw, rh = self:_item_rect(i)
        if self:_point_in_rect(lx, ly, rx, ry, rw, rh) then
            self.selected = i
            return
        end
    end
end

function StartScene:mousepressed(x, y, button)
    if button ~= 1 then return end
    local lx, ly = self:_to_logical(x, y)
    for i = 1, #self.items do
        local rx, ry, rw, rh = self:_item_rect(i)
        if self:_point_in_rect(lx, ly, rx, ry, rw, rh) then
            self.selected = i
            self:_confirm()
            return
        end
    end
end

return StartScene
