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

-- Test 4: Player:update() plays the "rotate" sound (game/player.lua's
-- rotate_piece handling) exactly when a piece is held, and never when one
-- isn't. Spies on Sound.play by monkey-patching the shared lua/core/sound
-- module singleton -- require() caches modules, so this is the same table
-- player.lua's own `local Sound = require(...)` holds a reference to.
-- Mirrors the spy-and-restore pattern used for love.* stubs elsewhere (e.g.
-- with_joysticks above, love.graphics.newQuad spies in test_jigsaw.lua).
local Sound = require("lua/core/sound")

local function with_sound_play_spy(fn)
    local original = Sound.play
    local played = {}
    Sound.play = function(name) played[#played + 1] = name end
    local ok, err = pcall(fn, played)
    Sound.play = original
    if not ok then
        error(err, 0)
    end
end

local function fake_held_piece()
    return {
        rotate = function() end,
        update = function() end,
    }
end

local function played_contains(played, name)
    for _, n in ipairs(played) do
        if n == name then return true end
    end
    return false
end

with_key_down("r", function()
    with_sound_play_spy(function(played)
        local player = Player.new(0, 0)
        player.held_piece = fake_held_piece()
        player:update(0)
        assert(played_contains(played, "rotate"),
            "Player:update(): pressing rotate_piece while holding a piece should call Sound.play('rotate')")
    end)
end)
print("PASS: Player:update() plays 'rotate' sound when rotate_piece is pressed while holding a piece")

with_key_down("r", function()
    with_sound_play_spy(function(played)
        local player = Player.new(0, 0)
        player.held_piece = nil
        player:update(0)
        assert(not played_contains(played, "rotate"),
            "Player:update(): pressing rotate_piece with no piece held should not call Sound.play('rotate')")
    end)
end)
print("PASS: Player:update() does not play 'rotate' sound when rotate_piece is pressed with no piece held")

-- Facing direction and animation state tests

-- Helper: simulate a player update with a key held for one frame.
local function update_with_key(player, key)
    local original = love.keyboard.isDown
    love.keyboard.isDown = function(k) return k == key end
    player.input:update()
    player:update(0.016)
    love.keyboard.isDown = original
end

-- Helper: simulate a player update with no keys held.
local function update_idle(player)
    local original = love.keyboard.isDown
    love.keyboard.isDown = function(_) return false end
    player.input:update()
    player:update(0.016)
    love.keyboard.isDown = original
end

-- Test: facing defaults to "right" on a freshly constructed player.
do
    local player = Player.new(0, 0)
    assert(player.facing == "right", "facing should default to 'right'")
end
print("PASS: facing defaults to 'right'")

-- Test: pressing left sets facing to "left".
do
    local player = Player.new(0, 0)
    update_with_key(player, "a")
    assert(player.facing == "left", "facing should be 'left' after pressing left")
end
print("PASS: facing is 'left' after pressing left")

-- Test: pressing right sets facing to "right".
do
    local player = Player.new(0, 0)
    update_with_key(player, "a")  -- go left first
    update_with_key(player, "d")  -- then right
    assert(player.facing == "right", "facing should flip back to 'right' after pressing right")
end
print("PASS: facing flips back to 'right' after pressing right")

-- Test: facing stays "left" after the left key is released (no input frame).
do
    local player = Player.new(0, 0)
    update_with_key(player, "a")
    update_idle(player)
    assert(player.facing == "left", "facing should remain 'left' after releasing left key")
end
print("PASS: facing stays 'left' after releasing the left key")

-- Test: pressing up or down does not change facing.
do
    local player = Player.new(0, 0)
    update_with_key(player, "a")  -- set facing to left
    update_with_key(player, "w")  -- press up
    assert(player.facing == "left", "pressing up must not change facing")
    update_with_key(player, "s")  -- press down
    assert(player.facing == "left", "pressing down must not change facing")
end
print("PASS: up/down keys do not change facing")

-- Test: is_moving is true while a directional key is held.
do
    local player = Player.new(0, 0)
    update_with_key(player, "d")
    assert(player.is_moving == true, "is_moving should be true while moving")
end
print("PASS: is_moving is true while a directional key is held")

-- Test: is_moving is false when no keys are held.
do
    local player = Player.new(0, 0)
    update_with_key(player, "d")
    update_idle(player)
    assert(player.is_moving == false, "is_moving should be false when no keys held")
end
print("PASS: is_moving is false when no keys are held")

-- Test: sprite switches to sprite_walk while moving.
do
    local player = Player.new(0, 0)
    update_with_key(player, "d")
    assert(player.sprite == player.sprite_walk, "sprite should be sprite_walk while moving")
end
print("PASS: sprite is sprite_walk while moving")

-- Test: sprite switches back to sprite_idle when stopped.
do
    local player = Player.new(0, 0)
    update_with_key(player, "d")
    update_idle(player)
    assert(player.sprite == player.sprite_idle, "sprite should return to sprite_idle when stopped")
end
print("PASS: sprite returns to sprite_idle when stopped")

print("ALL TESTS PASSED")
