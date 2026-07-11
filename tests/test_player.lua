-- test_player.lua
-- Unit tests for game/player.lua's Player.build_input(device): verifies the
-- three device-descriptor cases from docs/checklists/two-player-support.md's
-- "Fixed contracts" section produce Input instances scoped exactly as
-- documented. Exercises Player.build_input (and Player.new's default-input
-- wiring) directly with faked keyboard/joystick state -- no real LÖVE window
-- needed. Mirrors the with_joysticks/fake_stick helper pattern from
-- tests/test_input_gamepad.lua.

local Player = require("game/player")

-- Builds a fake joystick. pressed_buttons: set of button-name -> true.
local function fake_stick(pressed_buttons)
    pressed_buttons = pressed_buttons or {}
    return {
        isGamepadDown  = function(_, button) return pressed_buttons[button] == true end,
        getGamepadAxis = function(_, axis) return 0 end,
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

-- Fakes love.keyboard.isDown to report only `key` as held for the duration
-- of fn(), then restores the original stub.
local function with_key_down(key, fn)
    local original = love.keyboard.isDown
    love.keyboard.isDown = function(k) return k == key end
    local ok, err = pcall(fn)
    love.keyboard.isDown = original
    if not ok then
        error(err, 0)
    end
end

-- Test 1: Player.build_input(nil) responds to both a keyboard key ('e' ->
-- interact) and a mapped button on the first-connected controller ('a' ->
-- interact) -- today's unchanged default (merged keyboard + first-two
-- gamepads).
with_key_down("e", function()
    local input = Player.build_input(nil)
    input:update()
    assert(input:pressed("interact"), "build_input(nil): keyboard 'e' should trigger interact")
end)
print("PASS: build_input(nil) responds to keyboard 'e' for interact")

with_joysticks({ fake_stick({ a = true }) }, function()
    local input = Player.build_input(nil)
    input:update()
    assert(input:pressed("interact"), "build_input(nil): controller 1's mapped 'a' should trigger interact")
end)
print("PASS: build_input(nil) responds to first-connected controller's mapped button")

-- Test 1b: Player.new(x, y) with no third arg wires up that same default
-- (self.input = input or Player.build_input()) -- verified via the
-- constructed player's own .input field rather than reimplementing
-- movement.
with_key_down("d", function()
    local player = Player.new(0, 0)
    player.input:update()
    assert(player.input:is_down("right"), "Player.new(x, y) with no input arg: keyboard 'd' should be down for right")
end)
print("PASS: Player.new(x, y) with no third arg keeps default keyboard-responsive input")

with_joysticks({ fake_stick({ dpright = true }) }, function()
    local player = Player.new(0, 0)
    player.input:update()
    assert(player.input:is_down("right"), "Player.new(x, y) with no input arg: controller 1's dpright should be down for right")
end)
print("PASS: Player.new(x, y) with no third arg keeps default gamepad-responsive input")

-- Test 2: Player.build_input({ type = "keyboard" }) responds to keyboard
-- keys but NOT to a mapped press on a connected controller.
with_joysticks({ fake_stick({ a = true }) }, function()
    local input = Player.build_input({ type = "keyboard" })

    input:update()
    assert(not input:is_down("interact"),
        "build_input({type='keyboard'}): a connected controller's mapped press must not register")

    with_key_down("e", function()
        input:update()
        assert(input:pressed("interact"),
            "build_input({type='keyboard'}): keyboard 'e' should still trigger interact")
    end)
end)
print("PASS: build_input({type='keyboard'}) responds to keyboard but ignores a connected gamepad")

-- Test 3: Player.build_input({ type = "gamepad", index = 2 }), with two
-- controllers connected, registers a mapped press on controller 2 only --
-- not controller 1, and not any keyboard key press.
with_joysticks({ fake_stick({ a = true }), fake_stick() }, function()
    local input = Player.build_input({ type = "gamepad", index = 2 })
    input:update()
    assert(not input:is_down("interact"),
        "build_input({type='gamepad', index=2}): controller 1's press must not register")
end)
print("PASS: build_input({type='gamepad', index=2}) ignores controller 1's press")

with_joysticks({ fake_stick(), fake_stick({ a = true }) }, function()
    local input = Player.build_input({ type = "gamepad", index = 2 })
    input:update()
    assert(input:is_down("interact"),
        "build_input({type='gamepad', index=2}): controller 2's mapped press should register")
end)
print("PASS: build_input({type='gamepad', index=2}) registers controller 2's press")

with_key_down("e", function()
    with_joysticks({ fake_stick(), fake_stick() }, function()
        local input = Player.build_input({ type = "gamepad", index = 2 })
        input:update()
        assert(not input:is_down("interact"),
            "build_input({type='gamepad', index=2}): a keyboard press must not register")
    end)
end)
print("PASS: build_input({type='gamepad', index=2}) ignores keyboard presses")

print("ALL TESTS PASSED")
