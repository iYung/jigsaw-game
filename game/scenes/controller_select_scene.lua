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
    self.p1_confirmed = false
    self.p2_confirmed = false
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
        if source.input:pressed("left") then
            if devices_equal(source.device, self.p2_device) then
                -- Already holds the OTHER slot -- left is P2's release
                -- button (the opposite of the "right" that claimed it), so a
                -- claimed device can back out without a different device
                -- having to steal the slot out from under it.
                self.p2_device = nil
                self.p2_confirmed = false
            elseif not devices_equal(source.device, self.p1_device) then
                self.p1_device = source.device
                self.p1_confirmed = false
            end
            -- Already holding p1_device and pressing left again (its own
            -- claiming button) is a no-op -- release is always the other
            -- button, never a second press of the same one.
        end
        if source.input:pressed("right") then
            if devices_equal(source.device, self.p1_device) then
                self.p1_device = nil
                self.p1_confirmed = false
            elseif not devices_equal(source.device, self.p2_device) then
                self.p2_device = source.device
                self.p2_confirmed = false
            end
        end
    end

    -- Each player readies up independently -- only the device actually
    -- claiming a slot can toggle that slot's confirmed flag, so one player
    -- mashing confirm can never start the game before the other player has
    -- also confirmed. Confirm toggles rather than only ever setting true, so
    -- a player can un-ready themselves (e.g. to swap devices) without
    -- having to release and re-claim their slot.
    for _, source in ipairs(self._sources) do
        if source.input:pressed("confirm") then
            if devices_equal(source.device, self.p1_device) then
                self.p1_confirmed = not self.p1_confirmed
            end
            if devices_equal(source.device, self.p2_device) then
                self.p2_confirmed = not self.p2_confirmed
            end
        end
    end

    if self.p1_device and self.p2_device and self.p1_confirmed and self.p2_confirmed then
        self:_confirm()
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

-- Returns a new array of self._sources entries whose device isn't currently
-- claimed by either player -- used by draw() to drop a claimed device out
-- of the middle legend column, and reinsert it the instant it's released.
function ControllerSelectScene:_unclaimed_sources()
    local result = {}
    for _, source in ipairs(self._sources) do
        if not devices_equal(source.device, self.p1_device) and not devices_equal(source.device, self.p2_device) then
            result[#result + 1] = source
        end
    end
    return result
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
    if self.p1_device then
        love.graphics.printf(self.p1_confirmed and "Ready!" or "press Confirm", left_x, COLUMN_TOP + 100, COLUMN_W, "center")
    end

    -- Middle legend column
    love.graphics.setColor(SELECTED_COLOR)
    love.graphics.rectangle("fill", mid_x, COLUMN_TOP, COLUMN_W, COLUMN_H)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Devices", mid_x, COLUMN_TOP + 20, COLUMN_W, "center")
    for i, source in ipairs(self:_unclaimed_sources()) do
        love.graphics.printf(source.label, mid_x, COLUMN_TOP + 20 + i * 30, COLUMN_W, "center")
    end

    -- Player 2 column
    love.graphics.setColor(NORMAL_COLOR)
    love.graphics.rectangle("fill", right_x, COLUMN_TOP, COLUMN_W, COLUMN_H)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Player 2", right_x, COLUMN_TOP + 20, COLUMN_W, "center")
    love.graphics.printf(_label_for(self.p2_device, self._sources), right_x, COLUMN_TOP + 60, COLUMN_W, "center")
    if self.p2_device then
        love.graphics.printf(self.p2_confirmed and "Ready!" or "press Confirm", right_x, COLUMN_TOP + 100, COLUMN_W, "center")
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(
        "P1: Left to claim, Right to release   P2: Right to claim, Left to release   Confirm to toggle ready (both required to start)",
        0, COLUMN_TOP + COLUMN_H + 40, LOGICAL_W, "center"
    )
end

-- Forwards to Scene:on_exit() (clears self.drawer), matching how
-- game_scene.lua forwards its own on_exit override.
function ControllerSelectScene:on_exit()
    Scene.on_exit(self)
end

return ControllerSelectScene
