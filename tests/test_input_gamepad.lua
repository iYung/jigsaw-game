-- test_input_gamepad.lua
-- Unit tests for lua/core/input.lua's gamepad support: mapped button
-- presses, left-stick deadzone crossing, joystick_scope filtering, the
-- no-regression guarantee when opts is omitted, and rising-edge pressed()
-- semantics. Exercises lua/core/input.lua directly with fake joystick
-- tables — no real LÖVE window needed.

local Input = require("lua/core/input")

-- Builds a fake joystick. pressed_buttons: set of button-name -> true.
-- axes: table of axis-name -> number (defaults to 0 for unset axes).
local function fake_stick(pressed_buttons, axes)
    pressed_buttons = pressed_buttons or {}
    axes = axes or {}
    return {
        isGamepadDown = function(_, button) return pressed_buttons[button] == true end,
        getGamepadAxis = function(_, axis) return axes[axis] or 0 end,
    }
end

-- Monkey-patches love.joystick.getJoysticks to return `sticks` for the
-- duration of fn(), then restores the original stub.
local function with_joysticks(sticks, fn)
    local original = love.joystick.getJoysticks
    love.joystick.getJoysticks = function() return sticks end
    local ok, err = pcall(fn)
    love.joystick.getJoysticks = original
    if not ok then
        error(err, 0)
    end
end

-- Test 1: a mapped gamepad button press makes is_down/pressed true
-- (joystick_scope defaults to "first").
with_joysticks({ fake_stick({ a = true }) }, function()
    local input = Input.new({ interact = { "z" } }, {
        gamepad_buttons = { interact = { "a" } },
    })
    input:update()
    assert(input:is_down("interact"), "mapped button press on controller 1 should set is_down")
    assert(input:pressed("interact"), "mapped button press on controller 1 should set pressed on rising edge")
    print("PASS: mapped gamepad button press sets is_down/pressed (default scope 'first')")
end)

-- Test 2: left-stick axis crossing the deadzone drives up/down/left/right
-- when use_left_stick = true; a value within the deadzone does not.
do
    local function check_direction(action, axis, sign)
        local axes = {}
        axes[axis] = sign * 0.9 -- well past C.GAMEPAD_DEADZONE (0.35)
        with_joysticks({ fake_stick(nil, axes) }, function()
            local input = Input.new({ [action] = {} }, { use_left_stick = true })
            input:update()
            assert(input:is_down(action),
                action .. " should be down when " .. axis .. " = " .. tostring(axes[axis]))
        end)
    end

    check_direction("left", "leftx", -1)
    check_direction("right", "leftx", 1)
    check_direction("up", "lefty", -1)
    check_direction("down", "lefty", 1)
    print("PASS: left-stick axis past deadzone drives up/down/left/right")

    -- Within the deadzone (0.35) should NOT register as down.
    with_joysticks({ fake_stick(nil, { leftx = 0.2, lefty = -0.2 }) }, function()
        local input = Input.new({ left = {}, right = {}, up = {}, down = {} }, { use_left_stick = true })
        input:update()
        assert(not input:is_down("left"), "leftx = 0.2 is within the deadzone, left should not be down")
        assert(not input:is_down("right"), "leftx = 0.2 is within the deadzone, right should not be down")
        assert(not input:is_down("up"), "lefty = -0.2 is within the deadzone, up should not be down")
        assert(not input:is_down("down"), "lefty = -0.2 is within the deadzone, down should not be down")
    end)
    print("PASS: left-stick axis within deadzone does not register as down")
end

-- Test 3: joystick_scope = "first" ignores a press on the 2nd controller.
with_joysticks({ fake_stick(), fake_stick({ a = true }) }, function()
    local input = Input.new({ interact = {} }, {
        gamepad_buttons = { interact = { "a" } },
        joystick_scope = "first",
    })
    input:update()
    assert(not input:is_down("interact"), "'first' scope should ignore a press on controller 2")
    print("PASS: joystick_scope 'first' ignores controller 2")
end)

-- Test 4: joystick_scope = "first_two" registers a press on controller 2 but
-- not controller 3.
with_joysticks({ fake_stick(), fake_stick({ a = true }), fake_stick() }, function()
    local input = Input.new({ interact = {} }, {
        gamepad_buttons = { interact = { "a" } },
        joystick_scope = "first_two",
    })
    input:update()
    assert(input:is_down("interact"), "'first_two' scope should register a press on controller 2")
    print("PASS: joystick_scope 'first_two' registers controller 2")
end)

with_joysticks({ fake_stick(), fake_stick(), fake_stick({ a = true }) }, function()
    local input = Input.new({ interact = {} }, {
        gamepad_buttons = { interact = { "a" } },
        joystick_scope = "first_two",
    })
    input:update()
    assert(not input:is_down("interact"), "'first_two' scope should ignore a press on controller 3")
    print("PASS: joystick_scope 'first_two' ignores controller 3")
end)

-- Test 5: joystick_scope = "any" registers a press on a 3rd (or any)
-- controller.
with_joysticks({ fake_stick(), fake_stick(), fake_stick({ a = true }) }, function()
    local input = Input.new({ interact = {} }, {
        gamepad_buttons = { interact = { "a" } },
        joystick_scope = "any",
    })
    input:update()
    assert(input:is_down("interact"), "'any' scope should register a press on controller 3")
    print("PASS: joystick_scope 'any' registers controller 3")
end)

-- Test 6: opts omitted (nil) preserves keyboard-only behavior exactly, even
-- if love.joystick.getJoysticks() is patched to return a "pressed" fake
-- stick — gamepad state must be entirely ignored when opts is nil.
with_joysticks({ fake_stick({ a = true }, { leftx = 1, lefty = 1 }) }, function()
    local input = Input.new({ interact = { "z" }, left = {}, right = {}, up = {}, down = {} })
    input:update()
    assert(not input:is_down("interact"), "opts omitted: gamepad button press must be ignored")
    assert(not input:is_down("left"), "opts omitted: gamepad axis must be ignored")
    assert(not input:is_down("right"), "opts omitted: gamepad axis must be ignored")
    assert(not input:is_down("up"), "opts omitted: gamepad axis must be ignored")
    assert(not input:is_down("down"), "opts omitted: gamepad axis must be ignored")
    print("PASS: opts omitted preserves keyboard-only behavior (gamepad state ignored)")
end)

-- Test 7: pressed() fires only on the rising-edge frame — held gamepad
-- input across two update() calls should be pressed() on the first call
-- only.
with_joysticks({ fake_stick({ a = true }) }, function()
    local input = Input.new({ interact = {} }, {
        gamepad_buttons = { interact = { "a" } },
    })
    input:update()
    assert(input:is_down("interact"), "held button: is_down should be true on frame 1")
    assert(input:pressed("interact"), "held button: pressed should be true on frame 1 (rising edge)")

    input:update()
    assert(input:is_down("interact"), "held button: is_down should still be true on frame 2")
    assert(not input:pressed("interact"), "held button: pressed should be false on frame 2 (not a new edge)")
    print("PASS: pressed() fires only on the rising-edge frame")
end)

print("ALL TESTS PASSED")
