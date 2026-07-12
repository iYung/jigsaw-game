local Camera = require("lua/core/camera")

-- Test 1: default dimensions are 1280x720
do
    local c = Camera.new()
    assert(c._w == 1280, "default _w should be 1280, got " .. tostring(c._w))
    assert(c._h == 720,  "default _h should be 720, got "  .. tostring(c._h))
    print("PASS: camera: default dimensions are 1280x720")
end

-- Test 2: custom dimensions are stored
do
    local c = Camera.new(0, 0, 800, 600)
    assert(c._w == 800, "custom _w should be 800, got " .. tostring(c._w))
    assert(c._h == 600, "custom _h should be 600, got " .. tostring(c._h))
    print("PASS: camera: custom dimensions stored correctly")
end

-- Test 3: position and dimensions are independent
do
    local c = Camera.new(100, 200, 1920, 1080)
    assert(c.x   == 100,  "x should be 100")
    assert(c.y   == 200,  "y should be 200")
    assert(c._w  == 1920, "_w should be 1920")
    assert(c._h  == 1080, "_h should be 1080")
    print("PASS: camera: position and dimensions stored independently")
end

-- Test 4: default screen_x/screen_y are 0 when omitted
do
    local c = Camera.new(0, 0, 1280, 720)
    assert(c.screen_x == 0, "default screen_x should be 0, got " .. tostring(c.screen_x))
    assert(c.screen_y == 0, "default screen_y should be 0, got " .. tostring(c.screen_y))
    print("PASS: camera: default screen_x/screen_y are 0")
end

-- Test 5: custom screen_x/screen_y are stored (screen_x, screen_y = 640, 0)
do
    local c = Camera.new(0, 0, 640, 720, 640, 0)
    assert(c.screen_x == 640, "screen_x should be 640, got " .. tostring(c.screen_x))
    assert(c.screen_y == 0,   "screen_y should be 0, got "   .. tostring(c.screen_y))
    print("PASS: camera: custom screen_x stored correctly")
end

-- Test 6: screen_x/screen_y are stored independently (screen_x, screen_y = 0, 360)
do
    local c = Camera.new(0, 0, 640, 720, 0, 360)
    assert(c.screen_x == 0,   "screen_x should be 0, got "   .. tostring(c.screen_x))
    assert(c.screen_y == 360, "screen_y should be 360, got " .. tostring(c.screen_y))
    print("PASS: camera: screen_x/screen_y stored independently")
end

-- Test 7: follow() lerps zoom toward target.zoom when provided
do
    local c = Camera.new(0, 0, 1280, 720)
    c.zoom = 1.0
    c:follow({x = 0, y = 0, zoom = 0.5}, 0.5)
    assert(math.abs(c.zoom - 0.75) < 1e-9,
        "zoom should lerp halfway from 1.0 toward 0.5 (expected 0.75), got " .. tostring(c.zoom))
    print("PASS: camera: follow() lerps zoom toward target.zoom when provided")
end

-- Test 8: follow() with lerp=0 (instant) snaps zoom to target.zoom exactly
do
    local c = Camera.new(0, 0, 1280, 720)
    c.zoom = 1.0
    c:follow({x = 0, y = 0, zoom = 0.4}, 0)
    assert(c.zoom == 0.4, "zoom should snap exactly to target.zoom with lerp=0, got " .. tostring(c.zoom))
    print("PASS: camera: follow() with lerp=0 snaps zoom exactly to target.zoom")
end

-- Test 9: follow() leaves zoom untouched when target.zoom is nil -- this is
-- the existing player-follow call shape (game_scene.lua's pre-wall-view
-- self.camera:follow(self.player:centre(), 0.85) never set a zoom field),
-- so it must not regress once follow() knows how to lerp zoom.
do
    local c = Camera.new(0, 0, 1280, 720)
    c.zoom = 0.6
    c:follow({x = 10, y = 20}, 0.85)
    assert(c.zoom == 0.6, "zoom should be left untouched when target.zoom is nil, got " .. tostring(c.zoom))
    print("PASS: camera: follow() leaves zoom untouched when target.zoom is nil")
end

-- Test 10: follow() x/y lerp behavior is unchanged by the zoom addition
do
    local c = Camera.new(0, 0, 1280, 720)
    c.x, c.y = 0, 0
    c:follow({x = 100, y = 200}, 0.5)
    assert(math.abs(c.x - 50) < 1e-9, "x should lerp halfway to 100 (expected 50), got " .. tostring(c.x))
    assert(math.abs(c.y - 100) < 1e-9, "y should lerp halfway to 200 (expected 100), got " .. tostring(c.y))
    print("PASS: camera: follow() x/y lerp behavior unchanged by the zoom addition")
end

print("ALL TESTS PASSED")
