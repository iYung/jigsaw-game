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

-- Test 5: Player.hud_hints is populated by update() based on context.
-- Helpers --
local C = require("game/constants")

local function make_piece(x, y)
    return {
        state  = "grounded",
        sprite = { x = x, y = y },
        centre = function(self) return { x = self.sprite.x + C.U, y = self.sprite.y + C.U } end,
    }
end

local function make_interactive(x, y)
    return {
        centre = function(self) return { x = x + C.U, y = y + C.U } end,
    }
end

-- 5a: no pieces nearby -> hud_hints is empty and _hover_pos is nil
do
    local player = Player.new(0, 0)
    player:update(0, {}, {}, nil, nil, nil, false, nil)
    assert(#player.hud_hints == 0,
        "hud_hints should be empty when nothing is nearby and player holds nothing")
    assert(player._hover_pos == nil,
        "_hover_pos should be nil when nothing is nearby")
    print("PASS: hud_hints is empty and _hover_pos is nil when nothing is nearby")
end

-- 5b: piece within range -> hud_hints contains a pick-up hint and _hover_pos
-- points at the piece's grid cell
do
    local player = Player.new(0, 0)
    -- Place piece at same cell (distance 0 < 1.5*C.U)
    local pieces = { make_piece(0, 0) }
    player:update(0, pieces, {}, nil, nil, nil, false, nil)
    assert(#player.hud_hints == 1 and player.hud_hints[1]:find("Pick up"),
        "hud_hints should contain a pick-up hint when a piece is nearby")
    assert(player._hover_pos ~= nil,
        "_hover_pos should be set when a piece is within range")
    assert(player._hover_pos.x == 0 and player._hover_pos.y == 0,
        "_hover_pos should match the piece's sprite position")
    print("PASS: hud_hints shows pick-up hint and _hover_pos targets piece when within range")
end

-- 5c: holding a piece with a free drop target -> two hints: Drop + Rotate
do
    local player = Player.new(0, 0)
    local drop_target = player:drop_target()
    player.held_piece = {
        sprite  = { x = 0, y = 0, width = C.SLOT, height = C.SLOT, color = {1,1,1,1}, visible = true },
        state   = "held",
        update  = function() end,
        draw    = function() end,
        draw_ghost = function() end,
    }
    player:update(0, {}, {}, nil, nil, nil, false, nil)
    assert(#player.hud_hints == 2,
        "hud_hints should have 2 entries (Drop + Rotate) when holding a piece with a free drop target")
    assert(player.hud_hints[1]:find("Drop"),    "first hint should be Drop")
    assert(player.hud_hints[2]:find("Rotate"),  "second hint should be Rotate")
    print("PASS: hud_hints shows Drop + Rotate when holding a piece with a free drop target")
end

-- 5d: holding a piece but drop target is blocked -> only Rotate hint
do
    local player = Player.new(0, 0)
    local drop_target = player:drop_target()
    player.held_piece = {
        sprite  = { x = 0, y = 0, width = C.SLOT, height = C.SLOT, color = {1,1,1,1}, visible = true },
        state   = "held",
        update  = function() end,
        draw    = function() end,
        draw_ghost = function() end,
    }
    -- Blocker piece snapped to the same cell as the drop target
    local blocker = {
        state  = "grounded",
        sprite = { x = drop_target.snap_x, y = drop_target.snap_y },
        centre = function(self) return { x = self.sprite.x + C.U, y = self.sprite.y + C.U } end,
    }
    player:update(0, { blocker }, {}, nil, nil, nil, false, nil)
    assert(#player.hud_hints == 1 and player.hud_hints[1]:find("Rotate"),
        "hud_hints should show only Rotate when the drop target is blocked")
    print("PASS: hud_hints shows only Rotate when drop target is blocked")
end

-- 5e: frozen (wall view) -> hud_hints is empty regardless of proximity
do
    local player = Player.new(0, 0)
    local pieces = { make_piece(0, 0) }
    local wall_tile = make_interactive(0, 0)
    player:update(0, pieces, {}, nil, nil, wall_tile, true, nil)
    assert(#player.hud_hints == 0,
        "hud_hints should be empty when player is frozen (wall view)")
    print("PASS: hud_hints is empty when frozen")
end

-- 5f: gamepad device -> button labels use [A] and [X] instead of [E] and [R]
do
    with_joysticks({ fake_stick({ a = true }) }, function()
        -- Trigger a gamepad press to flip last_device to "gamepad"
        local gp_input = Player.build_input(nil)
        gp_input:update()

        local player = Player.new(0, 0)
        player.input = gp_input
        local pieces = { make_piece(0, 0) }
        player:update(0, pieces, {}, nil, nil, nil, false, nil)
        assert(#player.hud_hints == 1 and player.hud_hints[1]:find("%[A%]"),
            "hud_hints pick-up hint should use [A] when last device is gamepad")
    end)
    print("PASS: hud_hints uses [A] label when last input device is gamepad")
end

print("ALL TESTS PASSED")
