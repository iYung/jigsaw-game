local Scene    = require("lua/core/scene")
local GameScene = require("game/scenes/game_scene")
local GameState = require("game/game_state")
local C        = require("game/constants")

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

print("ALL TESTS PASSED")
