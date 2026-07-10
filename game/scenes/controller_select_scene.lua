local Scene     = require("lua/core/scene")
local Input     = require("lua/core/input")
local GameScene = require("game/scenes/game_scene")
local Player    = require("game/player")

local ControllerSelectScene = {}
ControllerSelectScene.__index = ControllerSelectScene

local LOGICAL_W, LOGICAL_H = 1280, 720

local NORMAL_COLOR   = { 0.35, 0.35, 0.35, 1 }
local SELECTED_COLOR = { 0.55, 0.55, 0.55, 1 }

local COLUMN_W = 360
local COLUMN_TOP = 260
local COLUMN_H = 200

-- True when two device descriptors (or nil) refer to the same device,
-- compared by value rather than table identity.
local function devices_equal(a, b)
    if a == nil or b == nil then
        return a == b
    end
    if a.type ~= b.type then
        return false
    end
    if a.type == "gamepad" then
        return a.index == b.index
    end
    return true
end

function ControllerSelectScene.new(manager, save_data)
    local self = Scene.new(LOGICAL_W, LOGICAL_H)
    setmetatable(self, ControllerSelectScene)
    self.manager   = manager
    self._save_data = save_data
    self.escape_to_menu = true
    self.p1_device = nil
    self.p2_device = nil
    return self
end

function ControllerSelectScene:on_enter()
    self._sources = {}

    self._sources[#self._sources + 1] = {
        device = { type = "keyboard" },
        label  = "Keyboard",
        input  = Input.new({
            left    = { "a", "left" },
            right   = { "d", "right" },
            confirm = { "e", "return" },
        }, nil),
    }

    local sticks = love.joystick.getJoysticks()
    for i = 1, 2 do
        if sticks[i] then
            self._sources[#self._sources + 1] = {
                device = { type = "gamepad", index = i },
                label  = "Controller " .. i,
                input  = Input.new({
                    left    = {},
                    right   = {},
                    confirm = {},
                }, {
                    gamepad_buttons = {
                        left    = { "dpleft" },
                        right   = { "dpright" },
                        confirm = { "a" },
                    },
                    use_left_stick = true,
                    joystick_scope = i,
                }),
            }
        end
    end
end

function ControllerSelectScene:_confirm()
    local p1_input = Player.build_input(self.p1_device)
    local p2_input = Player.build_input(self.p2_device)
    self.manager:switch(GameScene.new(self._save_data, { p1 = p1_input, p2 = p2_input }))
end

function ControllerSelectScene:update(dt)
    for _, source in ipairs(self._sources) do
        source.input:update()
    end

    for _, source in ipairs(self._sources) do
        if source.input:pressed("left") and not devices_equal(source.device, self.p2_device) then
            self.p1_device = source.device
        end
        if source.input:pressed("right") and not devices_equal(source.device, self.p1_device) then
            self.p2_device = source.device
        end
    end

    for _, source in ipairs(self._sources) do
        if source.input:pressed("confirm") and self.p1_device and self.p2_device then
            self:_confirm()
            break
        end
    end
end

local function _label_for(device, sources)
    if not device then
        return "-"
    end
    for _, source in ipairs(sources) do
        if devices_equal(source.device, device) then
            return source.label
        end
    end
    return "-"
end

function ControllerSelectScene:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Choose Your Controller", 0, 140, LOGICAL_W, "center")

    local left_x = (LOGICAL_W / 2) - COLUMN_W - 40
    local right_x = (LOGICAL_W / 2) + 40
    local mid_x = (LOGICAL_W / 2) - COLUMN_W / 2

    -- Player 1 column
    love.graphics.setColor(NORMAL_COLOR)
    love.graphics.rectangle("fill", left_x, COLUMN_TOP, COLUMN_W, COLUMN_H)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Player 1", left_x, COLUMN_TOP + 20, COLUMN_W, "center")
    love.graphics.printf(_label_for(self.p1_device, self._sources), left_x, COLUMN_TOP + 60, COLUMN_W, "center")

    -- Middle legend column
    love.graphics.setColor(SELECTED_COLOR)
    love.graphics.rectangle("fill", mid_x, COLUMN_TOP, COLUMN_W, COLUMN_H)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Devices", mid_x, COLUMN_TOP + 20, COLUMN_W, "center")
    for i, source in ipairs(self._sources) do
        love.graphics.printf(source.label, mid_x, COLUMN_TOP + 20 + i * 30, COLUMN_W, "center")
    end

    -- Player 2 column
    love.graphics.setColor(NORMAL_COLOR)
    love.graphics.rectangle("fill", right_x, COLUMN_TOP, COLUMN_W, COLUMN_H)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Player 2", right_x, COLUMN_TOP + 20, COLUMN_W, "center")
    love.graphics.printf(_label_for(self.p2_device, self._sources), right_x, COLUMN_TOP + 60, COLUMN_W, "center")

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(
        "P1: press Left to claim   P2: press Right to claim   Confirm to start",
        0, COLUMN_TOP + COLUMN_H + 40, LOGICAL_W, "center"
    )
end

-- Forwards to Scene:on_exit() (clears self.drawer), matching how
-- game_scene.lua forwards its own on_exit override.
function ControllerSelectScene:on_exit()
    Scene.on_exit(self)
end

return ControllerSelectScene
