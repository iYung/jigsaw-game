local StartScene = require("game/scenes/start_scene")

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

-- Test 1: StartScene.new(manager) starts with selected == 1
do
    local manager = {}
    local scene = StartScene.new(manager)
    assert(scene.selected == 1, "StartScene.new should start with selected == 1, got " .. tostring(scene.selected))
    print("PASS: start_scene: StartScene.new(manager) starts with selected == 1")
end

-- Test 2: pressing down wraps 1 -> 2 -> 1
do
    local manager = {}
    local scene = StartScene.new(manager)

    tap(scene, "s")
    assert(scene.selected == 2, "pressing down from 1 should move selected to 2, got " .. tostring(scene.selected))

    tap(scene, "s")
    assert(scene.selected == 1, "pressing down from 2 should wrap selected to 1, got " .. tostring(scene.selected))

    print("PASS: start_scene: pressing down wraps 1 -> 2 -> 1")
end

-- Test 3: pressing up from 1 wraps to 2
do
    local manager = {}
    local scene = StartScene.new(manager)

    tap(scene, "up")
    assert(scene.selected == 2, "pressing up from 1 should wrap selected to 2, got " .. tostring(scene.selected))

    print("PASS: start_scene: pressing up from 1 wraps to 2")
end

-- Test 4: confirming while selected == 1 ("New Game") calls manager:switch
-- with something GameScene-shaped (has .camera and .drawer, which Scene.new
-- always sets on any scene subclass).
do
    local switched_with = nil
    local manager = {
        switch = function(self, scene) switched_with = scene end,
    }
    local scene = StartScene.new(manager)
    assert(scene.selected == 1, "sanity: scene should start with selected == 1")

    tap(scene, "return")

    assert(switched_with ~= nil, "manager:switch should have been called when confirming New Game")
    assert(switched_with.camera ~= nil, "manager:switch should be called with a GameScene-shaped arg (missing .camera)")
    assert(switched_with.drawer ~= nil, "manager:switch should be called with a GameScene-shaped arg (missing .drawer)")

    print("PASS: start_scene: confirming New Game (selected == 1) calls manager:switch with a GameScene-shaped arg")
end

-- Test 5: confirming while selected == 2 ("Exit Game") calls love.event.quit.
-- love.event is the real LOVE module under --headless (conf.lua only
-- disables window/graphics/audio/sound/joystick/touch/video), and
-- lua/headless/stubs.lua does not stub love.event at all. Rather than
-- actually invoking the real quit (which enqueues a real LOVE "quit" event),
-- spy on it locally: save the original, swap in a recording stub, restore
-- it afterward.
do
    local manager = {}
    local scene = StartScene.new(manager)

    tap(scene, "s")
    assert(scene.selected == 2, "sanity: scene should be on Exit Game (selected == 2) before confirming")

    local quit_called = false
    local original_quit = love.event.quit
    love.event.quit = function(...) quit_called = true end

    tap(scene, "return")

    love.event.quit = original_quit

    assert(quit_called, "love.event.quit should have been called when confirming Exit Game")

    print("PASS: start_scene: confirming Exit Game (selected == 2) calls love.event.quit")
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
    local manager = {}
    local scene = StartScene.new(manager)

    -- Center of item 2's ("Exit Game") rect: x = (1280-300)/2 + 150 = 640,
    -- y = 340 + (2-1)*(60+20) + 30 = 450.
    scene:mousemoved(640, 450)

    assert(scene.selected == 2, "hovering item 2's rect should set selected to 2, got " .. tostring(scene.selected))

    print("PASS: start_scene: mousemoved over an item's rect updates selected")
end

-- Test 7: mousepressed(button 1) over an item confirms it.
do
    local switched_with = nil
    local manager = {
        switch = function(self, scene) switched_with = scene end,
    }
    local scene = StartScene.new(manager)

    -- Center of item 1's ("New Game") rect: x = 640, y = 340 + 30 = 370.
    scene:mousepressed(640, 370, 1)

    assert(switched_with ~= nil, "mousepressed(button 1) over New Game should call manager:switch")
    assert(switched_with.camera ~= nil, "manager:switch should be called with a GameScene-shaped arg (missing .camera)")

    print("PASS: start_scene: mousepressed(button 1) over an item confirms it")
end

print("ALL TESTS PASSED")
