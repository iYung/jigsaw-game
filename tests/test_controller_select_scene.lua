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

-- Test 3: releasing via the opposite button -- a device holding P1 pressing
-- "right" (P2's claim button, and P1's release button) releases its own P1
-- claim rather than claiming P2 or being a rejected no-op; p2_device stays
-- nil since the press was consumed as a release, not a claim. This is also
-- the invariant that used to be called "overlap rejection": a device can
-- never end up holding both slots at once, since pressing the other slot's
-- button always releases your own claim first rather than advancing to
-- claim the other one.
do
    local c1_buttons = {}
    with_joysticks({ fake_stick(c1_buttons) }, function()
        local scene = ControllerSelectScene.new({})
        scene:on_enter()

        tap_key(scene, "a") -- keyboard claims p1 via "left"
        assert(scene.p1_device ~= nil and scene.p1_device.type == "keyboard",
            "sanity: keyboard should have claimed p1_device")

        tap_key(scene, "d") -- keyboard presses "right" -- its own release button
        assert(scene.p1_device == nil,
            "keyboard (holding p1) pressing right should release its own p1 claim")
        assert(scene.p2_device == nil,
            "releasing p1 via the opposite button should not also claim p2")

        print("PASS: controller_select_scene: a device holding P1 releases it by pressing the opposite (right) button")
    end)
end

-- Test 3b: releasing via the opposite button, mirrored for P2 -- a device
-- holding P2 pressing "left" (P1's claim button, and P2's release button)
-- releases its own P2 claim; the freed slot can then be claimed normally by
-- a different device.
do
    local c1_buttons = {}
    with_joysticks({ fake_stick(c1_buttons) }, function()
        local scene = ControllerSelectScene.new({})
        scene:on_enter()

        tap_button(scene, c1_buttons, "dpright") -- controller 1 claims p2 via "right"
        assert(scene.p2_device ~= nil and scene.p2_device.type == "gamepad" and scene.p2_device.index == 1,
            "sanity: controller 1 should have claimed p2_device")

        tap_button(scene, c1_buttons, "dpleft") -- controller 1 presses "left" -- its own release button
        assert(scene.p2_device == nil,
            "controller 1 (holding p2) pressing left should release its own p2 claim")
        assert(scene.p1_device == nil,
            "releasing p2 via the opposite button should not also claim p1")

        -- The slot is free again -- a different device (keyboard) can claim it.
        tap_key(scene, "a")
        assert(scene.p1_device ~= nil and scene.p1_device.type == "keyboard",
            "after controller 1 releases p2, keyboard pressing left should claim p1 normally")

        print("PASS: controller_select_scene: a device holding P2 releases it by pressing the opposite (left) button")
    end)
end

-- Test 4: confirm gating -- manager:switch is never called while either
-- p1_device or p2_device is nil, or while either player hasn't individually
-- confirmed; only once BOTH devices are claimed AND both have pressed
-- confirm does manager:switch fire, with a GameScene-shaped argument
-- (duck-typed via .camera/.drawer, matching tests/test_start_scene.lua's
-- convention). One player mashing confirm alone must never be enough.
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
        assert(scene.p1_confirmed == true, "keyboard confirming should set p1_confirmed, since keyboard is p1_device")

        -- Claim p2 with a *different* device (controller 1, right) -- a
        -- device already claimed by one player is rejected for the other
        -- player's direction (see the overlap test above), so p2 must be
        -- claimed by something other than the keyboard p1 already holds.
        tap_button(scene, c1_buttons, "dpright")
        assert(scene.p2_device ~= nil, "sanity: p2_device should now be claimed")

        -- Both devices claimed, but only P1 has confirmed so far -- must
        -- still be a no-op even though a naive "both claimed" check would
        -- pass; P2's device has not confirmed yet.
        assert(switched_with == nil, "both claimed but only P1 confirmed should not call manager:switch")

        -- P1 (keyboard) confirming again should not fake out P2's requirement.
        tap_key(scene, "return")
        assert(switched_with == nil, "P1 alone re-confirming must not substitute for P2's own confirm")

        -- Now P2 (controller 1) confirms -- both have now individually
        -- confirmed, so the game should start.
        tap_button(scene, c1_buttons, "a")
        assert(switched_with ~= nil, "confirm from both devices individually should call manager:switch")
        assert(switched_with.camera ~= nil, "manager:switch should be called with a GameScene-shaped arg (missing .camera)")
        assert(switched_with.drawer ~= nil, "manager:switch should be called with a GameScene-shaped arg (missing .drawer)")

        print("PASS: controller_select_scene: manager:switch fires only once both devices are claimed AND both have individually confirmed")
    end)
end

-- Test 4b: claiming a slot (or losing it to another device, or releasing it
-- yourself) resets that slot's confirmed flag -- a stale "ready" from a
-- previous device/claim must never carry over.
do
    local switched_with = nil
    local manager = {
        switch = function(self, scene) switched_with = scene end,
    }
    local c1_buttons = {}

    with_joysticks({ fake_stick(c1_buttons) }, function()
        local scene = ControllerSelectScene.new(manager)
        scene:on_enter()

        tap_key(scene, "a") -- keyboard claims p1
        tap_button(scene, c1_buttons, "dpright") -- controller 1 claims p2
        tap_key(scene, "return") -- keyboard (p1) confirms
        assert(scene.p1_confirmed == true, "sanity: p1 should be confirmed")
        assert(switched_with == nil, "sanity: should not have switched yet (p2 hasn't confirmed)")

        -- Controller 1 releases its own p2 claim via the opposite button
        -- ("left") -- p2_device goes back to nil.
        tap_button(scene, c1_buttons, "dpleft")
        assert(scene.p2_device == nil, "controller 1 pressing left (its release button) while p2 should release its claim")

        -- Keyboard now releases its own p1 claim via the opposite button
        -- ("right").
        tap_key(scene, "d")
        assert(scene.p1_device == nil, "keyboard pressing right (its release button) while p1 should release its claim")
        assert(scene.p1_confirmed == false, "releasing p1's claim should reset p1_confirmed")

        -- Re-claim p1 with keyboard -- must start unconfirmed again, not
        -- inherit the earlier confirmed state.
        tap_key(scene, "a")
        assert(scene.p1_device ~= nil, "sanity: keyboard should have re-claimed p1")
        assert(scene.p1_confirmed == false, "re-claiming p1 should not inherit a stale confirmed flag")

        assert(switched_with == nil, "manager:switch should never have fired during this claim/release/reclaim sequence")

        print("PASS: controller_select_scene: releasing or re-claiming a slot resets that slot's confirmed flag")
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
