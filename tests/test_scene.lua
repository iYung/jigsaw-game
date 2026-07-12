local Scene    = require("lua/core/scene")
local GameScene = require("game/scenes/game_scene")
local GameState = require("game/game_state")
local C        = require("game/constants")
local HeadlessInput = require("lua/headless/input")

-- Test 1: Scene.new(w, h) passes dimensions to its camera
do
    local s = Scene.new(800, 600)
    assert(s.camera ~= nil,    "Scene.new should create a camera")
    assert(s.camera._w == 800, "camera._w should be 800, got " .. tostring(s.camera._w))
    assert(s.camera._h == 600, "camera._h should be 600, got " .. tostring(s.camera._h))
    print("PASS: scene: Scene.new(w, h) threads dimensions to camera")
end

-- Test 2: Scene.new creates a drawer
do
    local s = Scene.new(1280, 720)
    assert(s.drawer ~= nil, "Scene.new should create a drawer")
    print("PASS: scene: Scene.new creates a drawer")
end

-- Test 3: GameScene inherits drawer and camera from Scene
do
    local gs = GameScene.new()
    assert(gs.drawer ~= nil,        "GameScene should have a drawer from Scene")
    assert(gs.camera ~= nil,        "GameScene should have a camera from Scene")
    assert(gs.camera._w == 1280,    "GameScene camera._w should be 1280")
    assert(gs.camera._h == 720,     "GameScene camera._h should be 720")
    print("PASS: scene: GameScene inherits drawer and camera from Scene")
end

-- Test 4: _spawn_box() sources spawn_from from the live pile:top_position(),
-- not a fixed constant like the old door's (WORLD_W/2, 0)
do
    GameState:reset()

    local gs = GameScene.new()
    gs:on_enter()

    local count_before = #gs.boxes
    local expected = gs.pile:top_position()

    gs:_spawn_box()

    assert(#gs.boxes == count_before + 1,
        "_spawn_box() should have appended exactly one box to gs.boxes (had " .. count_before ..
        ", expected " .. (count_before + 1) .. ", got " .. #gs.boxes .. ") -- if this fails, " ..
        "_spawn_box() silently no-op'd (cap reached, catalog exhausted, or exhausted its 50 " ..
        "occupancy retries), which shouldn't happen right after a fresh GameState:reset()")

    local new_box = gs.boxes[#gs.boxes]
    assert(new_box.spawn_x == expected.x,
        "newly-spawned box's spawn_x should equal pile:top_position().x (" .. tostring(expected.x) ..
        ") captured immediately before _spawn_box(), got " .. tostring(new_box.spawn_x))
    assert(new_box.spawn_y == expected.y,
        "newly-spawned box's spawn_y should equal pile:top_position().y (" .. tostring(expected.y) ..
        ") captured immediately before _spawn_box(), got " .. tostring(new_box.spawn_y))
    print("PASS: scene: _spawn_box() sources spawn_from from the live pile:top_position(), not a fixed constant")
end

-- Test 5: when GameState.player_count == 2, GameScene:on_enter() spawns a
-- second Player one grid cell to the right of Player 1, tinted a distinct
-- color so the two are visually distinguishable in the world.
do
    GameState:reset()
    GameState.player_count = 2

    local gs = GameScene.new()
    gs:on_enter()

    assert(gs.player2 ~= nil, "GameScene:on_enter() should construct player2 when GameState.player_count == 2")
    assert(gs.player2.sprite.x == gs.player.sprite.x + C.SLOT,
        "player2 should spawn one grid cell (C.SLOT) to the right of player1, got dx=" ..
        tostring(gs.player2.sprite.x - gs.player.sprite.x))
    assert(gs.player2.sprite.y == gs.player.sprite.y, "player2 should spawn at the same y as player1")

    local c1, c2 = gs.player.sprite.color, gs.player2.sprite.color
    assert(c1[1] ~= c2[1] or c1[2] ~= c2[2] or c1[3] ~= c2[3],
        "player2's sprite color should differ from player1's so the two are visually distinguishable")

    assert(gs.camera2 ~= nil, "GameScene:on_enter() should construct camera2 when GameState.player_count == 2")
    assert(gs.camera2._w == 640, "camera2._w should be 640, got " .. tostring(gs.camera2._w))
    assert(gs.camera2.screen_x == 640, "camera2.screen_x should be 640, got " .. tostring(gs.camera2.screen_x))
    assert(gs.camera._w == 640, "camera._w should be shrunk to 640 in 2-player mode, got " .. tostring(gs.camera._w))

    GameState:reset()
    print("PASS: scene: GameScene spawns a distinctly colored player2 one grid cell right of player1 when player_count == 2")
end

-- Test 6: in 1-player mode (the default), GameScene:on_enter() should not
-- set up a second camera, and the main camera should retain the full
-- 1280-wide canvas -- unchanged from today.
do
    GameState:reset()

    local gs = GameScene.new()
    gs:on_enter()

    assert(gs.camera2 == nil, "GameScene:on_enter() should not construct camera2 in 1-player mode")
    assert(gs.camera._w == 1280, "camera._w should remain 1280 in 1-player mode, got " .. tostring(gs.camera._w))

    GameState:reset()
    print("PASS: scene: GameScene keeps a single full-width camera in 1-player mode")
end

-- Test 7: on_enter() wires up a wall_tile and starts view1 == "play"
do
    GameState:reset()

    local gs = GameScene.new()
    gs:on_enter()

    assert(gs.wall_tile ~= nil, "GameScene:on_enter() should construct wall_tile")
    assert(gs.wall_tile.sprite.x == gs.world_w - C.SLOT,
        "wall_tile should sit at the floor's top-right cell, x = world_w - SLOT, got " ..
        tostring(gs.wall_tile.sprite.x))
    assert(gs.wall_tile.sprite.y == 0, "wall_tile should sit at y = 0 (floor's top edge), got " ..
        tostring(gs.wall_tile.sprite.y))
    assert(gs.view1 == "play", "view1 should start as 'play', got " .. tostring(gs.view1))
    assert(gs.wall_tile2 == nil, "wall_tile2 should not exist in 1-player mode")
    print("PASS: scene: on_enter() wires up wall_tile at the floor's top-right cell, view1 starts 'play'")
end

-- Test 8: _toggle_wall_view() is a no-op when completed_puzzles is empty
do
    GameState:reset()

    local gs = GameScene.new()
    gs:on_enter()
    gs.completed_puzzles = {}

    gs:_toggle_wall_view("p1")

    assert(gs.view1 == "play",
        "_toggle_wall_view() should stay on 'play' when completed_puzzles is empty (nothing to fit), got " ..
        tostring(gs.view1))
    assert(gs.wall_target1 == nil, "wall_target1 should remain nil when the toggle no-ops")
    print("PASS: scene: _toggle_wall_view() no-ops when completed_puzzles is empty")
end

-- Test 9: _toggle_wall_view() computes bounding-box center/zoom from a
-- synthetic completed_puzzles set, and toggling again returns to "play"
do
    GameState:reset()

    local gs = GameScene.new()
    gs:on_enter()
    -- Two synthetic shelved entries: a 2x1 at (0, -64) and a 1x1 at (128, -128).
    -- Bounding box: x in [0, 192], y in [-128, 0] -> width 192, height 128.
    gs.completed_puzzles = {
        {x = 0,   y = -64,  cols = 2, rows = 1},
        {x = 128, y = -128, cols = 1, rows = 1},
    }

    gs:_toggle_wall_view("p1")

    assert(gs.view1 == "wall", "view1 should become 'wall' after toggling with a non-empty wall, got " ..
        tostring(gs.view1))
    assert(gs.wall_target1 ~= nil, "wall_target1 should be set after entering wall view")
    assert(math.abs(gs.wall_target1.x - 96) < 1e-9,
        "wall_target1.x should be the bbox center x = (0+192)/2 = 96, got " .. tostring(gs.wall_target1.x))
    assert(math.abs(gs.wall_target1.y - (-64)) < 1e-9,
        "wall_target1.y should be the bbox center y = (-128+0)/2 = -64, got " .. tostring(gs.wall_target1.y))
    -- expected zoom = min(1.0, 0.9 * min(1280/192, 720/128)) = min(1.0, 0.9 * min(6.667, 5.625)) = min(1.0, 5.0625) = 1.0
    assert(gs.wall_target1.zoom == 1.0,
        "wall_target1.zoom should clamp to 1.0 when the fit-zoom would exceed normal scale, got " ..
        tostring(gs.wall_target1.zoom))

    gs:_toggle_wall_view("p1")
    assert(gs.view1 == "play", "toggling a second time should return view1 to 'play', got " .. tostring(gs.view1))
    print("PASS: scene: _toggle_wall_view() computes bbox center/zoom and toggles back to 'play'")
end

-- Test 10: a large wall (bigger than the logical screen) clamps zoom below
-- 1.0 to fit -- exercises the actual "zoom out" case, not just the clamp.
do
    GameState:reset()

    local gs = GameScene.new()
    gs:on_enter()
    -- A single entry 30 cols wide, 20 rows tall: width = 1920, height = 1280,
    -- both larger than the 1280x720 logical screen.
    gs.completed_puzzles = {
        {x = 0, y = -1280, cols = 30, rows = 20},
    }

    gs:_toggle_wall_view("p1")

    -- expected zoom = min(1.0, 0.9 * min(1280/1920, 720/1280)) = min(1.0, 0.9*min(0.6667,0.5625)) = 0.9*0.5625 = 0.50625
    local expected_zoom = 0.9 * math.min(1280 / 1920, 720 / 1280)
    assert(math.abs(gs.wall_target1.zoom - expected_zoom) < 1e-9,
        "wall_target1.zoom should fit the oversized wall with a 10% margin (expected " ..
        tostring(expected_zoom) .. "), got " .. tostring(gs.wall_target1.zoom))
    print("PASS: scene: _toggle_wall_view() zooms out (zoom < 1.0) to fit a wall larger than the screen")
end

-- Test 11: in 2-player mode, each player's view/wall_target toggles
-- independently -- toggling p1 does not affect p2's view.
do
    GameState:reset()
    GameState.player_count = 2

    local gs = GameScene.new()
    gs:on_enter()
    gs.completed_puzzles = {
        {x = 0, y = -64, cols = 1, rows = 1},
    }

    assert(gs.wall_tile2 ~= nil, "wall_tile2 should exist in 2-player mode")

    gs:_toggle_wall_view("p1")
    assert(gs.view1 == "wall", "view1 should become 'wall' after p1 toggles")
    assert(gs.view2 == "play", "view2 should remain 'play' -- p1 toggling should not affect p2")

    gs:_toggle_wall_view("p2")
    assert(gs.view2 == "wall", "view2 should become 'wall' after p2 toggles")
    assert(gs.view1 == "wall", "view1 should remain 'wall' -- p2 toggling should not affect p1")

    GameState:reset()
    print("PASS: scene: 2-player mode tracks view1/view2 and wall_target1/wall_target2 independently")
end

-- Test 12: full end-to-end round trip through real gs:update() ticks --
-- entering wall view (player not yet frozen that frame) and then exiting it
-- again (player now frozen, since view1 == "wall") both actually work.
-- Regression test: Player:update()'s frozen early-return used to skip the
-- wall_tile proximity check entirely, so once frozen there was no way back
-- to "play" -- this reproduces that exact scenario through the same
-- gs:update() call site the live game uses every frame.
do
    GameState:reset()

    local gs = GameScene.new()
    gs:on_enter()
    gs.completed_puzzles = {
        {x = 0, y = -64, cols = 1, rows = 1},
    }

    -- Stand the player exactly on the wall tile so proximity always holds.
    gs.player.sprite.x, gs.player.sprite.y = gs.wall_tile.sprite.x, gs.wall_tile.sprite.y

    gs.player.input = HeadlessInput.new()

    -- Frame 1: not frozen yet (view1 starts "play") -- interact should
    -- toggle into wall view.
    gs.player.input:press("interact")
    gs:update(1 / 60)
    assert(gs.view1 == "wall", "first interact press should toggle view1 to 'wall', got " .. tostring(gs.view1))

    -- Frame 2: now frozen (view1 == "wall"), same interact press again --
    -- this is exactly the step that was broken.
    gs.player.input:press("interact")
    gs:update(1 / 60)
    assert(gs.view1 == "play",
        "second interact press while frozen should toggle view1 back to 'play' -- if this fails, " ..
        "Player:update()'s frozen early-return is once again skipping the wall_tile check, got " ..
        tostring(gs.view1))

    print("PASS: scene: pressing interact again while frozen in wall view correctly returns to 'play'")
end

print("ALL TESTS PASSED")
