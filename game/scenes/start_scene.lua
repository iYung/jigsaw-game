local Scene     = require("lua/core/scene")
local Input     = require("lua/core/input")
local GameScene = require("game/scenes/game_scene")
local ControllerSelectScene = require("game/scenes/controller_select_scene")
local Save      = require("lua/core/save")
local GameState = require("game/game_state")
local Sound     = require("lua/core/sound")

local StartScene = {}
StartScene.__index = StartScene

local LOGICAL_W, LOGICAL_H = 1280, 720

local ITEM_W = 300
local ITEM_H = 54
local ITEM_GAP = 20
local ITEMS_TOP = 300

function StartScene.new(manager, on_settings)
    local self = Scene.new(LOGICAL_W, LOGICAL_H)
    setmetatable(self, StartScene)
    self.manager  = manager
    self.on_settings = on_settings
    self.player_count = 1
    self._has_controller = #love.joystick.getJoysticks() > 0
    self.items    = { "New Game", "Continue", "Players: 1", "Settings", "Exit Game" }
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
-- `n`, but skipping index 2 ("Continue") whenever `has_save` is false.
local function _next_selectable(current, delta, has_save, n)
    local s = current
    for _ = 1, n do
        s = ((s - 1 + delta) % n) + 1
        if s ~= 2 or has_save then return s end
    end
    return current
end

function StartScene:on_enter()
    self._img_bg      = love.graphics.newImage("assets/backgrounds/start_bg.png")
    self._img_logo    = love.graphics.newImage("assets/ui/start_logo.png")
    self._img_btn     = love.graphics.newImage("assets/ui/menu_btn.png")
    self._img_btn_sel = love.graphics.newImage("assets/ui/menu_btn_selected.png")
    self._font_btn    = love.graphics.newFont(13)
    self._has_save = Save.exists()
    if not Sound.is_music_playing("menu") then
        Sound.play_music("menu")
    end
end

function StartScene:on_exit() end

-- Clamps `player_count` to 1 if no controller is currently connected.
local function _clamp_player_count(player_count)
    if player_count == 2 and #love.joystick.getJoysticks() == 0 then
        return 1
    end
    return player_count
end

function StartScene:_confirm()
    if self.selected == 1 then
        Sound.play("menu_confirm")
        GameState:reset()
        GameState.player_count = _clamp_player_count(self.player_count)
        if GameState.player_count == 2 then
            self.manager:switch(ControllerSelectScene.new(self.manager))
        else
            Sound.fade_music("menu", 0, 2)
            self.manager:switch(GameScene.new())
        end
    elseif self.selected == 2 then
        if not self._has_save then
            Sound.play("fail")
            return
        end
        local data = Save.read()
        if not data then return end
        GameState:apply_save(data.game_state)
        GameState.player_count = _clamp_player_count(self.player_count)
        if GameState.player_count == 2 then
            self.manager:switch(ControllerSelectScene.new(self.manager, data.scene))
        else
            Sound.fade_music("menu", 0, 2)
            self.manager:switch(GameScene.new(data.scene))
        end
    elseif self.selected == 4 then
        Sound.play("menu_confirm")
        if self.on_settings then
            self.on_settings()
        end
    elseif self.selected == 5 then
        Sound.play("menu_confirm")
        love.event.quit()
    end
end

-- Flips self.player_count between 1 and 2 and keeps the "Players: N" label in sync.
function StartScene:_toggle_player_count()
    self.player_count = (self.player_count == 1) and 2 or 1
    self.items[3] = "Players: " .. self.player_count
end

function StartScene:update(dt)
    self.input:update()

    self._has_controller = #love.joystick.getJoysticks() > 0

    if self.input:pressed("down") then
        local prev_selected = self.selected
        self.selected = _next_selectable(self.selected, 1, self._has_save, #self.items)
        if self.selected ~= prev_selected then
            Sound.play("menu_navigate")
        end
    end
    if self.input:pressed("up") then
        local prev_selected = self.selected
        self.selected = _next_selectable(self.selected, -1, self._has_save, #self.items)
        if self.selected ~= prev_selected then
            Sound.play("menu_navigate")
        end
    end

    if self.selected == 3 then
        if self.input:pressed("left") or self.input:pressed("right") or self.input:pressed("confirm") then
            if self._has_controller then
                self:_toggle_player_count()
                Sound.play("menu_navigate")
            else
                Sound.play("fail")
            end
        end
        return
    end

    if self.input:pressed("confirm") then
        self:_confirm()
    end
end

function StartScene:draw()
    local prev_font = love.graphics.getFont()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self._img_bg, 0, 0)

    local iw = self._img_logo:getWidth()
    love.graphics.draw(self._img_logo, (LOGICAL_W - iw) / 2, 140)

    love.graphics.setFont(self._font_btn)
    for i, label in ipairs(self.items) do
        local x, y, w, h = self:_item_rect(i)
        if i == 3 and i == self.selected then
            label = "< " .. label .. " >"
            if not self._has_controller then
                label = label .. " (connect a controller for 2P)"
            end
        end
        if i == 2 and not self._has_save then
            love.graphics.setColor(1, 1, 1, 0.4)
            love.graphics.draw(self._img_btn, x, y)
            love.graphics.printf(label, x, y + (h - self._font_btn:getHeight()) / 2, w, "center")
        else
            local img = (i == self.selected) and self._img_btn_sel or self._img_btn
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(img, x, y)
            love.graphics.printf(label, x, y + (h - self._font_btn:getHeight()) / 2, w, "center")
        end
    end

    love.graphics.setFont(prev_font)
    love.graphics.setColor(1, 1, 1, 1)
end

return StartScene
