local Scene     = require("lua/core/scene")
local Input     = require("lua/core/input")
local GameScene = require("game/scenes/game_scene")
local ControllerSelectScene = require("game/scenes/controller_select_scene")
local Save      = require("lua/core/save")
local GameState = require("game/game_state")

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
    self.player_count = 1
    self._has_controller = #love.joystick.getJoysticks() > 0
    self.items    = { "New Game", "Continue", "Players: 1", "Exit Game" }
    self.selected = 1
    self.input    = Input.new({
        up      = { "w", "up" },
        down    = { "s", "down" },
        left    = { "a", "left" },
        right   = { "d", "right" },
        confirm = { "e", "return" },
    }, {
        gamepad_buttons = {
            up      = { "dpup" },
            down    = { "dpdown" },
            left    = { "dpleft" },
            right   = { "dpright" },
            confirm = { "a" },
        },
        joystick_scope = "first_two",
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

-- Advances `current` by `delta` (+1 for down, -1 for up), wrapping modulo
-- `n`, but skipping index 2 ("Continue") whenever `has_save` is false --
-- mirrors /root/wip/lua/game/scenes/start_scene.lua's _next_selectable.
local function _next_selectable(current, delta, has_save, n)
    local s = current
    for _ = 1, n do
        s = ((s - 1 + delta) % n) + 1
        if s ~= 2 or has_save then return s end
    end
    return current
end

function StartScene:on_enter()
    self._has_save = Save.exists()
end

function StartScene:on_exit() end

-- Clamps `player_count` to 1 if no controller is currently connected --
-- 2P has nothing to hand Player 2 in the controller-select scene without
-- one. Checked fresh at the exact moment New Game/Continue is confirmed,
-- rather than continuously every frame, so a one-frame joystick-enumeration
-- hiccup while merely navigating the menu can't silently discard a
-- deliberate 2P selection before the player ever reaches confirm.
local function _clamp_player_count(player_count)
    if player_count == 2 and #love.joystick.getJoysticks() == 0 then
        return 1
    end
    return player_count
end

function StartScene:_confirm()
    if self.selected == 1 then
        GameState:reset()
        GameState.player_count = _clamp_player_count(self.player_count)
        if GameState.player_count == 2 then
            self.manager:switch(ControllerSelectScene.new(self.manager))
        else
            self.manager:switch(GameScene.new())
        end
    elseif self.selected == 2 then
        if not self._has_save then return end
        local data = Save.read()
        if not data then return end
        GameState:apply_save(data.game_state)
        GameState.player_count = _clamp_player_count(GameState.player_count)
        if GameState.player_count == 2 then
            self.manager:switch(ControllerSelectScene.new(self.manager, data.scene))
        else
            self.manager:switch(GameScene.new(data.scene))
        end
    elseif self.selected == 4 then
        love.event.quit()
    end
end

-- Flips self.player_count between 1 and 2 and keeps the "Players: N" menu
-- label (item index 3) in sync with the new value.
function StartScene:_toggle_player_count()
    self.player_count = (self.player_count == 1) and 2 or 1
    self.items[3] = "Players: " .. self.player_count
end

function StartScene:update(dt)
    self.input:update()

    -- 2P requires a second physical input device -- with only a keyboard
    -- detected, there's nothing distinct to hand Player 2 in the upcoming
    -- controller-select scene. Recomputed every frame purely as a read (for
    -- the toggle gate below and the draw() hint) -- deliberately does NOT
    -- write self.player_count back to 1 here; that would silently discard a
    -- deliberate 2P selection on any single-frame joystick-enumeration
    -- hiccup while just navigating the menu. The only places player_count
    -- actually changes are the explicit toggle keypress below and the
    -- confirm-time clamp in _confirm().
    self._has_controller = #love.joystick.getJoysticks() > 0

    if self.input:pressed("down") then
        self.selected = _next_selectable(self.selected, 1, self._has_save, #self.items)
    end
    if self.input:pressed("up") then
        self.selected = _next_selectable(self.selected, -1, self._has_save, #self.items)
    end

    if self.selected == 3 then
        if self.input:pressed("left") or self.input:pressed("right") or self.input:pressed("confirm") then
            if self._has_controller then
                self:_toggle_player_count()
            end
        end
        return
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
        if i == 3 and i == self.selected then
            label = "< " .. label .. " >"
            if not self._has_controller then
                label = label .. " (connect a controller for 2P)"
            end
        end
        if i == 2 and not self._has_save then
            local r, g, b = NORMAL_COLOR[1], NORMAL_COLOR[2], NORMAL_COLOR[3]
            love.graphics.setColor(r, g, b, 0.4)
            love.graphics.rectangle("fill", x, y, w, h)

            love.graphics.setColor(1, 1, 1, 0.4)
            love.graphics.printf(label, x, y + h / 2 - 8, w, "center")
        else
            if i == self.selected then
                love.graphics.setColor(SELECTED_COLOR)
            else
                love.graphics.setColor(NORMAL_COLOR)
            end
            love.graphics.rectangle("fill", x, y, w, h)

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(label, x, y + h / 2 - 8, w, "center")
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return StartScene
