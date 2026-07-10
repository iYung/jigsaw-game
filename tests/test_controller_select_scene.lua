-- test_controller_select_scene.lua
-- Unit tests for game/scenes/controller_select_scene.lua: device source
-- discovery (keyboard always, controller N only when connected), per-frame
-- left/right claim logic (including overlap rejection), confirm gating
-- (both players must be claimed before manager:switch fires), and the
-- escape_to_menu contract. Exercises the real lua/core/input.lua via faked
-- love.keyboard.isDown/love.joystick.getJoysticks state -- no real LOVE
-- window needed, matching tests/test_start_scene.lua and
-- tests/test_input_gamepad.lua's conventions.

local ControllerSelectScene = require("game/scenes/controller_select_scene")

-- Builds a fake joystick. pressed_buttons: set of button-name -> true.
-- axes: table of axis-name -> number (defaults to 0 for unset axes).
-- Mirrors tests/test_input_gamepad.lua's fake_stick, duplicated locally per
-- this repo's convention of not sharing test helper modules between files.
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

-- Simulates one full keyboard key tap against the scene: a press frame
-- (love.keyboard.isDown faked true for `key`) followed by a release frame,
-- so Input's internal _down state resets and a later tap on the same action
-- can register a fresh rising edge. Mirrors tests/test_start_scene.lua's
-- tap() helper.
local function tap_key(scene, key)
    local original_isDown = love.keyboard.isDown
    love.keyboard.isDown = function(k) return k == key end
    scene:update(1 / 60)
    love.keyboard.isDown = original_isDown
    scene:update(1 / 60)
end

-- Simulates one full gamepad button tap on `stick_buttons` (the mutable
-- pressed_buttons table backing a fake_stick): sets `button` true, updates
-- the scene once (rising edge), then sets it false and updates again so the
-- rising edge resets for a later tap. Must be called from within a
-- with_joysticks(...) block that includes this stick.
local function tap_button(scene, stick_buttons, button)
    stick_buttons[button] = true
    scene:update(1 / 60)
    stick_buttons[button] = false
    scene:update(1 / 60)
end

-- Test 1: source discovery -- zero connected controllers means only the
-- Keyboard source exists; one/two connected controllers add the
-- corresponding Controller N source(s).
with_joysticks({}, function()
    local scene = ControllerSelectScene.new({})
    scene:on_enter()
    assert(#scene._sources == 1, "zero controllers: expected exactly 1 source, got " .. #scene._sources)
    assert(scene._sources[1].label == "Keyboard", "zero controllers: only source should be Keyboard")
    assert(scene._sources[1].device.type == "keyboard", "Keyboard source's device should be { type = 'keyboard' }")
    print("PASS: controller_select_scene: zero controllers connected yields only a Keyboard source")
end)

with_joysticks({ fake_stick() }, function()
    local scene = ControllerSelectScene.new({})
    scene:on_enter()
    assert(#scene._sources == 2, "one controller: expected exactly 2 sources, got " .. #scene._sources)
    assert(scene._sources[2].label == "Controller 1", "one controller: 2nd source should be labeled Controller 1")
    assert(scene._sources[2].device.type == "gamepad" and scene._sources[2].device.index == 1,
        "one controller: 2nd source's device should be { type = 'gamepad', index = 1 }")
    print("PASS: controller_select_scene: one controller connected adds a Controller 1 source")
end)

with_joysticks({ fake_stick(), fake_stick() }, function()
    local scene = ControllerSelectScene.new({})
    scene:on_enter()
    assert(#scene._sources == 3, "two controllers: expected exactly 3 sources, got " .. #scene._sources)
    assert(scene._sources[2].label == "Controller 1", "two controllers: 2nd source should be labeled Controller 1")
    assert(scene._sources[3].label == "Controller 2", "two controllers: 3rd source should be labeled Controller 2")
    assert(scene._sources[3].device.type == "gamepad" and scene._sources[3].device.index == 2,
        "two controllers: 3rd source's device should be { type = 'gamepad', index = 2 }")
    print("PASS: controller_select_scene: two controllers connected add Controller 1 and Controller 2 sources")
end)

-- Test 2: a keyboard "left" tap claims p1_device as { type = "keyboard" };
-- a controller-1 "right" tap (dpright) claims p2_device as
-- { type = "gamepad", index = 1 }.
do
    local c1_buttons = {}
    with_joysticks({ fake_stick(c1_buttons) }, function()
        local scene = ControllerSelectScene.new({})
        scene:on_enter()

        assert(scene.p1_device == nil, "sanity: p1_device should start nil")
        assert(scene.p2_device == nil, "sanity: p2_device should start nil")

        tap_key(scene, "a") -- "left"
        assert(scene.p1_device ~= nil, "keyboard left press should claim p1_device")
        assert(scene.p1_device.type == "keyboard", "keyboard left press should set p1_device to { type = 'keyboard' }")

        tap_button(scene, c1_buttons, "dpright")
        assert(scene.p2_device ~= nil, "controller-1 dpright press should claim p2_device")
        assert(scene.p2_device.type == "gamepad" and scene.p2_device.index == 1,
            "controller-1 dpright press should set p2_device to { type = 'gamepad', index = 1 }")

        print("PASS: controller_select_scene: keyboard left claims p1_device, controller-1 right claims p2_device")
    end)
end

-- Test 3: overlap rejection -- once a device is claimed by one player, that
-- same device pressing the other player's direction does not steal it; a
-- different, unclaimed device pressing that direction still works.
do
    local c1_buttons = {}
    with_joysticks({ fake_stick(c1_buttons) }, function()
        local scene = ControllerSelectScene.new({})
        scene:on_enter()

        -- Controller 1 claims p2 via "right".
        tap_button(scene, c1_buttons, "dpright")
        assert(scene.p2_device ~= nil and scene.p2_device.type == "gamepad" and scene.p2_device.index == 1,
            "sanity: controller 1 should have claimed p2_device")

        -- Controller 1 (already P2's device) pressing "left" must NOT steal p1 --
        -- overlap rejected, p1_device stays nil.
        tap_button(scene, c1_buttons, "dpleft")
        assert(scene.p1_device == nil,
            "controller 1 pressing left should be rejected (already claimed by p2), p1_device should remain nil")

        -- A different, unclaimed device (keyboard) pressing "left" still claims
        -- p1 normally.
        tap_key(scene, "a") -- "left"
        assert(scene.p1_device ~= nil and scene.p1_device.type == "keyboard",
            "a different, unclaimed device (keyboard) pressing left should still claim p1_device")

        print("PASS: controller_select_scene: overlap rejected for the claiming device, but a different device still claims normally")
    end)
end

-- Test 4: confirm gating -- manager:switch is never called while either
-- p1_device or p2_device is nil; once both are set, confirm calls
-- manager:switch with a GameScene-shaped argument (duck-typed via
-- .camera/.drawer, matching tests/test_start_scene.lua's convention).
do
    local switched_with = nil
    local manager = {
        switch = function(self, scene) switched_with = scene end,
    }
    local c1_buttons = {}

    with_joysticks({ fake_stick(c1_buttons) }, function()
        local scene = ControllerSelectScene.new(manager)
        scene:on_enter()

        -- Confirm with neither device claimed: no-op.
        tap_key(scene, "return")
        assert(switched_with == nil, "confirm with no devices claimed should not call manager:switch")

        -- Claim only p1 (keyboard left), confirm again: still a no-op.
        tap_key(scene, "a") -- "left"
        assert(scene.p1_device ~= nil, "sanity: p1_device should now be claimed")
        assert(scene.p2_device == nil, "sanity: p2_device should still be nil")

        tap_key(scene, "return")
        assert(switched_with == nil, "confirm with only p1_device claimed should not call manager:switch")

        -- Claim p2 with a *different* device (controller 1, right) -- a
        -- device already claimed by one player is rejected for the other
        -- player's direction (see the overlap test above), so p2 must be
        -- claimed by something other than the keyboard p1 already holds.
        tap_button(scene, c1_buttons, "dpright")
        assert(scene.p2_device ~= nil, "sanity: p2_device should now be claimed")

        tap_key(scene, "return")
        assert(switched_with ~= nil, "confirm with both devices claimed should call manager:switch")
        assert(switched_with.camera ~= nil, "manager:switch should be called with a GameScene-shaped arg (missing .camera)")
        assert(switched_with.drawer ~= nil, "manager:switch should be called with a GameScene-shaped arg (missing .drawer)")

        print("PASS: controller_select_scene: manager:switch fires only once both devices are claimed, with a GameScene-shaped arg")
    end)
end

-- Test 5: a fresh ControllerSelectScene.new(manager) has escape_to_menu == true.
do
    local scene = ControllerSelectScene.new({})
    assert(scene.escape_to_menu == true,
        "ControllerSelectScene.new should set escape_to_menu == true, got " .. tostring(scene.escape_to_menu))
    print("PASS: controller_select_scene: fresh scene has escape_to_menu == true")
end

print("ALL TESTS PASSED")
