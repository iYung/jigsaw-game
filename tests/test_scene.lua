local Scene    = require("lua/core/scene")
local GameScene = require("game/scenes/game_scene")
local GameState = require("game/game_state")

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

print("ALL TESTS PASSED")
