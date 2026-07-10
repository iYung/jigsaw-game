local C = require("game/constants")

local Input = {}
Input.__index = Input

function Input.new(key_map, opts)
    local self    = setmetatable({}, Input)
    self._map     = key_map
    self._opts    = opts
    self._down    = {}
    self._pressed = {}
    return self
end

-- Resolve the list of in-scope joysticks for this frame, per opts.joystick_scope.
local function scoped_joysticks(scope)
    local sticks = love.joystick.getJoysticks()
    local result = {}
    if scope == "any" then
        for _, stick in ipairs(sticks) do
            result[#result + 1] = stick
        end
    elseif scope == "first_two" then
        if sticks[1] then result[#result + 1] = sticks[1] end
        if sticks[2] then result[#result + 1] = sticks[2] end
    else -- "first" or nil/default
        if sticks[1] then result[#result + 1] = sticks[1] end
    end
    return result
end

local AXIS_DIRECTIONS = {
    left  = { axis = "leftx", sign = -1 },
    right = { axis = "leftx", sign = 1 },
    up    = { axis = "lefty", sign = -1 },
    down  = { axis = "lefty", sign = 1 },
}

function Input:_gamepad_down(action, joysticks)
    local opts = self._opts
    if not opts then
        return false
    end

    local buttons = opts.gamepad_buttons and opts.gamepad_buttons[action]
    local axis_dir = opts.use_left_stick and AXIS_DIRECTIONS[action]

    if not buttons and not axis_dir then
        return false
    end

    for _, stick in ipairs(joysticks) do
        if buttons then
            for _, button in ipairs(buttons) do
                if stick:isGamepadDown(button) then
                    return true
                end
            end
        end
        if axis_dir then
            local value = stick:getGamepadAxis(axis_dir.axis)
            if value * axis_dir.sign > C.GAMEPAD_DEADZONE then
                return true
            end
        end
    end

    return false
end

function Input:update()
    local new_pressed = {}
    -- Resolved unconditionally (even when opts is nil/gamepad-less) so a
    -- missing/empty joystick list is always a silent no-op rather than a
    -- special case.
    local joysticks = scoped_joysticks(self._opts and self._opts.joystick_scope)

    for action, keys in pairs(self._map) do
        local down = false
        for _, key in ipairs(keys) do
            if love.keyboard.isDown(key) then
                down = true
                break
            end
        end
        if not down then
            down = self:_gamepad_down(action, joysticks)
        end
        if down and not self._down[action] then
            new_pressed[action] = true
        end
        self._down[action] = down
    end
    self._pressed = new_pressed
end

function Input:is_down(action)
    return self._down[action] == true
end

function Input:pressed(action)
    return self._pressed[action] == true
end

return Input
