local StartScene = require("game/scenes/start_scene")
local Save       = require("lua/core/save")
local GameState  = require("game/game_state")

-- Stub love.filesystem with an in-memory store so tests don't touch disk,
-- exactly matching tests/test_save.lua's pattern -- Save.exists()/Save.read()
-- must never touch the real disk in this file either.
local _fs = {}
love.filesystem.write   = function(path, content) _fs[path] = content end
love.filesystem.read    = function(path) return _fs[path], _fs[path] and #_fs[path] or 0 end
love.filesystem.getInfo = function(path) return _fs[path] and { type = "file" } or nil end

local function reset_fs() _fs = {} end

-- StartScene owns a *real* lua/core/input.lua instance (not HeadlessInput —
-- HeadlessInput only gets wired in via lua/headless/runner.lua's
-- runner.setup(scene_factory), which injects (input, sm) into the factory,
-- but StartScene.new(manager) doesn't accept an injected input; same
-- limitation tests/test_basics.lua documents for game/player.lua). Under
-- --headless, love.keyboard.isDown is stubbed to always return false, so we
-- locally fake it around scene:update(dt) calls to drive real rising-edge
-- key presses through the actual Input class.
--
-- tap() simulates one full key tap: a press frame (isDown faked true for
-- `key`) followed by a release frame (isDown restored), so Input's internal
-- _down state resets and a later tap() on the same action can register a
-- fresh rising edge.
local function tap(scene, key)
    local original_isDown = love.keyboard.isDown
    love.keyboard.isDown = function(k) return k == key end
    scene:update(1 / 60)
    love.keyboard.isDown = original_isDown
    scene:update(1 / 60)
end

-- Builds a realistic save-shaped table (matching the {game_state=, scene=}
-- shape GameScene:to_save()/GameState:to_save() produce -- see
-- tests/test_save.lua's Test 5/6) with solved_count == 2 so restoration can
-- be asserted on distinctly from a freshly-reset GameState.
local function make_save()
    return {
        game_state = {
            version = 1,
            seen = {
                easy = { ["assets/puzzles/easy/1.png"] = true },
                med  = {},
                hard = {},
            },
            solved_count   = 2,
            active_count   = 1,
            solved_by_tier = { easy = 2, med = 0, hard = 0 },
        },
        scene = {
            player = { x = 320, y = 192, held_piece = nil },
            pieces = {},
            boxes  = {},
            completed_puzzles    = {},
            shelf_row_x          = 0,
            shelf_row_bottom     = -64,
            shelf_row_max_height = 0,
        },
    }
end

-- Test 1: StartScene.new(manager) starts with selected == 1
do
    reset_fs()
    local manager = {}
    local scene = StartScene.new(manager)
    scene:on_enter()
    assert(scene.selected == 1, "StartScene.new should start with selected == 1, got " .. tostring(scene.selected))
    print("PASS: start_scene: StartScene.new(manager) starts with selected == 1")
end

-- Test 2: pressing down wraps 1 -> 3 -> 1 with no save present (index 2,
-- "Continue", is disabled and must be skipped by the down-navigation).
do
    reset_fs()
    local manager = {}
    local scene = StartScene.new(manager)
    scene:on_enter()
    assert(scene._has_save == false, "sanity: _has_save should be false with no save file")

    tap(scene, "s")
    assert(scene.selected == 3,
        "pressing down from 1 with no save should skip Continue (2) and land on 3, got " .. tostring(scene.selected))

    tap(scene, "s")
    assert(scene.selected == 1, "pressing down from 3 should wrap selected to 1, got " .. tostring(scene.selected))

    print("PASS: start_scene: pressing down wraps 1 -> 3 -> 1, skipping disabled Continue")
end

-- Test 3: pressing up from 1 wraps to 3, skipping Continue, with no save
-- present.
do
    reset_fs()
    local manager = {}
    local scene = StartScene.new(manager)
    scene:on_enter()
    assert(scene._has_save == false, "sanity: _has_save should be false with no save file")

    tap(scene, "up")
    assert(scene.selected == 3,
        "pressing up from 1 with no save should wrap selected to 3, skipping Continue, got " .. tostring(scene.selected))

    print("PASS: start_scene: pressing up from 1 wraps to 3, skipping disabled Continue")
end

-- Test 4: confirming while selected == 1 ("New Game") calls manager:switch
-- with something GameScene-shaped (has .camera and .drawer, which Scene.new
-- always sets on any scene subclass).
do
    reset_fs()
    local switched_with = nil
    local manager = {
        switch = function(self, scene) switched_with = scene end,
    }
    local scene = StartScene.new(manager)
    scene:on_enter()
    assert(scene.selected == 1, "sanity: scene should start with selected == 1")

    tap(scene, "return")

    assert(switched_with ~= nil, "manager:switch should have been called when confirming New Game")
    assert(switched_with.camera ~= nil, "manager:switch should be called with a GameScene-shaped arg (missing .camera)")
    assert(switched_with.drawer ~= nil, "manager:switch should be called with a GameScene-shaped arg (missing .drawer)")

    print("PASS: start_scene: confirming New Game (selected == 1) calls manager:switch with a GameScene-shaped arg")
end

-- Test 5: confirming while selected == 3 ("Exit Game") calls love.event.quit.
-- love.event is the real LOVE module under --headless (conf.lua only
-- disables window/graphics/audio/sound/joystick/touch/video), and
-- lua/headless/stubs.lua does not stub love.event at all. Rather than
-- actually invoking the real quit (which enqueues a real LOVE "quit" event),
-- spy on it locally: save the original, swap in a recording stub, restore
-- it afterward.
do
    reset_fs()
    local manager = {}
    local scene = StartScene.new(manager)
    scene:on_enter()

    -- No save present, so a single down-tap skips Continue (2) and lands
    -- directly on Exit Game (3).
    tap(scene, "s")
    assert(scene.selected == 3, "sanity: scene should be on Exit Game (selected == 3) before confirming")

    local quit_called = false
    local original_quit = love.event.quit
    love.event.quit = function(...) quit_called = true end

    tap(scene, "return")

    love.event.quit = original_quit

    assert(quit_called, "love.event.quit should have been called when confirming Exit Game")

    print("PASS: start_scene: confirming Exit Game (selected == 3) calls love.event.quit")
end

-- Test 6: mousemoved over an item's rect updates selected to hover it.
-- Exercises StartScene:_to_logical, which calls love.graphics.getWidth()/
-- getHeight() directly -- lua/headless/stubs.lua previously only stubbed
-- getDimensions(), leaving getWidth/getHeight to fall through the graphics
-- stub's catch-all __index to a no-op (returning nil), which would break
-- division in _to_logical. Stubs now also provide getWidth()/getHeight()
-- matching getDimensions()'s 1280x720, so scale == 1 and offset == 0 here,
-- meaning window coordinates equal logical coordinates directly.
do
    reset_fs()
    local manager = {}
    local scene = StartScene.new(manager)
    scene:on_enter()

    -- Center of item 2's ("Continue") rect: x = (1280-300)/2 + 150 = 640,
    -- y = 340 + (2-1)*(60+20) + 30 = 450. mousemoved's hit-testing doesn't
    -- consult _has_save (only the keyboard skip-logic does), so hovering
    -- Continue's rect still sets selected == 2 even with no save present.
    scene:mousemoved(640, 450)
    assert(scene.selected == 2, "hovering item 2's rect should set selected to 2, got " .. tostring(scene.selected))

    -- Center of item 3's ("Exit Game") rect: x = 640,
    -- y = 340 + (3-1)*(60+20) + 30 = 530.
    scene:mousemoved(640, 530)
    assert(scene.selected == 3, "hovering item 3's rect should set selected to 3, got " .. tostring(scene.selected))

    print("PASS: start_scene: mousemoved over an item's rect updates selected")
end

-- Test 7: mousepressed(button 1) over an item confirms it.
do
    reset_fs()
    local switched_with = nil
    local manager = {
        switch = function(self, scene) switched_with = scene end,
    }
    local scene = StartScene.new(manager)
    scene:on_enter()

    -- Center of item 1's ("New Game") rect: x = 640, y = 340 + 30 = 370.
    scene:mousepressed(640, 370, 1)

    assert(switched_with ~= nil, "mousepressed(button 1) over New Game should call manager:switch")
    assert(switched_with.camera ~= nil, "manager:switch should be called with a GameScene-shaped arg (missing .camera)")

    print("PASS: start_scene: mousepressed(button 1) over an item confirms it")
end

-- Test 8: with no save present, confirming while selected == 2 ("Continue")
-- is a no-op -- manager:switch should never be called.
do
    reset_fs()
    local switched_with = nil
    local manager = {
        switch = function(self, scene) switched_with = scene end,
    }
    local scene = StartScene.new(manager)
    scene:on_enter()
    assert(scene._has_save == false, "sanity: _has_save should be false with no save file")

    scene.selected = 2
    tap(scene, "return")

    assert(switched_with == nil,
        "confirming Continue with no save present should be a no-op; manager:switch should never be called")

    print("PASS: start_scene: confirming Continue with no save present is a no-op")
end

-- Test 9: with a save file present, on_enter() sets _has_save == true.
do
    reset_fs()
    Save.write(make_save())

    local manager = {}
    local scene = StartScene.new(manager)
    scene:on_enter()

    assert(scene._has_save == true, "on_enter() should set _has_save == true when a save file is present")

    print("PASS: start_scene: on_enter() sets _has_save == true when a save file is present")
end

-- Test 10: with a save file present, confirming while selected == 2
-- ("Continue") calls manager:switch with a GameScene-shaped arg and restores
-- GameState's fields from the save.
do
    reset_fs()
    Save.write(make_save())
    GameState:reset()
    assert(GameState.solved_count == 0, "sanity: reset() should zero solved_count before continuing")

    local switched_with = nil
    local manager = {
        switch = function(self, scene) switched_with = scene end,
    }
    local scene = StartScene.new(manager)
    scene:on_enter()
    assert(scene._has_save == true, "sanity: _has_save should be true with a save file present")

    scene.selected = 2
    tap(scene, "return")

    assert(switched_with ~= nil, "manager:switch should have been called when confirming Continue with a save present")
    assert(switched_with.camera ~= nil, "manager:switch should be called with a GameScene-shaped arg (missing .camera)")
    assert(switched_with.drawer ~= nil, "manager:switch should be called with a GameScene-shaped arg (missing .drawer)")

    assert(GameState.solved_count == 2,
        "confirming Continue should restore GameState.solved_count from the save, got " .. tostring(GameState.solved_count))
    assert(GameState.active_count == 1,
        "confirming Continue should restore GameState.active_count from the save, got " .. tostring(GameState.active_count))
    assert(GameState.solved_by_tier.easy == 2,
        "confirming Continue should restore GameState.solved_by_tier.easy from the save, got " .. tostring(GameState.solved_by_tier.easy))
    assert(GameState:is_seen("easy", "assets/puzzles/easy/1.png") == true,
        "confirming Continue should restore GameState's seen table from the save")

    print("PASS: start_scene: confirming Continue with a save present calls manager:switch and restores GameState")
end

-- Test 11: down/up skip-logic depends on whether a save is present -- with a
-- save, Continue (2) is no longer skipped; without one, navigation still
-- skips straight to Exit Game (3).
do
    reset_fs()
    Save.write(make_save())
    local manager = {}
    local scene_with_save = StartScene.new(manager)
    scene_with_save:on_enter()
    assert(scene_with_save._has_save == true, "sanity: _has_save should be true with a save file present")

    tap(scene_with_save, "s")
    assert(scene_with_save.selected == 2,
        "pressing down from 1 with a save present should land on Continue (2), got " .. tostring(scene_with_save.selected))

    reset_fs()
    local scene_without_save = StartScene.new(manager)
    scene_without_save:on_enter()
    assert(scene_without_save._has_save == false, "sanity: _has_save should be false with no save file")

    tap(scene_without_save, "s")
    assert(scene_without_save.selected == 3,
        "pressing down from 1 with no save should skip Continue and land on Exit Game (3), got " .. tostring(scene_without_save.selected))

    print("PASS: start_scene: down-navigation skip-logic depends on whether a save is present")
end

print("ALL TESTS PASSED")

-- Leave the process-lifetime GameState singleton clean for whichever test
-- file the headless runner executes next.
GameState:reset()
