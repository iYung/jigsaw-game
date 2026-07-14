local C              = require("game/constants")
local WallViewTile   = require("game/wall_view_tile")
local Player         = require("game/player")
local HeadlessInput  = require("lua/headless/input")

-- WallViewTile:centre() ---------------------------------------------------

-- Mirrors puzzle_pile's "centre() returns sprite center" test.

do
    local tile = WallViewTile.new(320, 640, function() end)
    local c = tile:centre()
    assert(c.x == 320 + C.U, "centre.x should be x + U = " .. (320 + C.U) .. ", got " .. tostring(c.x))
    assert(c.y == 640 + C.U, "centre.y should be y + U = " .. (640 + C.U) .. ", got " .. tostring(c.y))
    print("PASS: wall_view_tile: centre() returns sprite center")
end

-- WallViewTile:draw() ------------------------------------------------------

-- Smoke test, mirroring tests/test_settings_scene.lua's Test 25 and
-- puzzle_pile's equivalent: :draw() must not error under the headless
-- love.graphics stub now that it calls love.graphics.draw with an Image
-- (TILE_IMAGE, loaded via love.graphics.newImage) instead of only
-- love.graphics.rectangle.

do
    local tile = WallViewTile.new(0, 0, function() end)
    local ok, err = pcall(function() tile:draw() end)
    assert(ok, "WallViewTile:draw() should not error, got: " .. tostring(err))
    print("PASS: wall_view_tile: :draw() does not error (image-backed tile)")
end

-- WallViewTile:interact() -------------------------------------------------

-- Mirrors puzzle_pile's "interact() invokes on_press exactly once per call".

do
    local calls = 0
    local tile = WallViewTile.new(0, 0, function() calls = calls + 1 end)

    tile:interact()
    assert(calls == 1, "on_press should be invoked once after first interact(), got " .. calls)

    tile:interact()
    assert(calls == 2, "on_press should be invoked once more after second interact(), got " .. calls)
    print("PASS: wall_view_tile: interact() invokes on_press exactly once per call")
end

-- interact() with no on_press set is a silent no-op (mirrors PuzzlePile).

do
    local tile = WallViewTile.new(0, 0)
    tile:interact()
    print("PASS: wall_view_tile: interact() with no on_press set does not error")
end

-- Player:update() calls wall_tile:interact() when in range and no piece held --

do
    local player = Player.new(0, 0)
    player.input = HeadlessInput.new()
    -- player:centre() == (32, 32)

    local presses = 0
    local tile = WallViewTile.new(0, 0, function() presses = presses + 1 end)  -- centre (32, 32)

    player.input:press("interact")
    player:update(1 / 60, {}, {}, nil, nil, tile, false)

    assert(presses == 1,
        "wall_tile:interact() should fire when in range, no piece held, and not frozen, got " .. presses .. " presses")
    print("PASS: wall_view_tile: Player:update() calls wall_tile:interact() when in range and unfrozen")
end

-- Player:update() does NOT call wall_tile:interact() while holding a piece --

do
    local JigsawPiece = require("game/jigsaw_piece")

    local player = Player.new(0, 0)
    player.input = HeadlessInput.new()
    player.held_piece = JigsawPiece.new(0, {1, 0, 0, 1})

    local presses = 0
    local tile = WallViewTile.new(0, 0, function() presses = presses + 1 end)

    player.input:press("interact")
    player:update(1 / 60, {}, {}, nil, nil, tile, false)

    assert(presses == 0,
        "wall_tile:interact() should NOT fire while the player is holding a piece, got " .. presses .. " presses")
    print("PASS: wall_view_tile: Player:update() does not call wall_tile:interact() while a piece is held")
end

-- Player:update() with frozen == true: movement stays blocked, but the
-- wall tile itself must still be interactable -- frozen is driven by
-- already being in wall view, so if the tile stopped working the instant
-- the player froze, there would be no way to ever toggle back out.

do
    local player = Player.new(0, 0)
    player.input = HeadlessInput.new()
    player.input:hold("right")
    player.input:press("interact")

    local presses = 0
    local tile = WallViewTile.new(0, 0, function() presses = presses + 1 end)  -- centre (32, 32)

    local start_x, start_y = player.sprite.x, player.sprite.y
    player:update(1 / 60, {}, {}, nil, nil, tile, true)

    assert(player.sprite.x == start_x and player.sprite.y == start_y,
        "player position should be unchanged when frozen, even with a movement key held, got (" ..
        tostring(player.sprite.x) .. ", " .. tostring(player.sprite.y) .. ")")
    assert(presses == 1,
        "wall_tile:interact() SHOULD fire while frozen and in range -- this is the only way to exit " ..
        "wall view once the player is frozen there -- got " .. presses .. " presses")
    print("PASS: wall_view_tile: Player:update() blocks movement but still allows the wall tile while frozen")
end

-- ...and the frozen wall_tile check is still gated the same way the
-- not-frozen one is: out of range, or holding a piece, doesn't fire.

do
    local player = Player.new(0, 0)
    player.input = HeadlessInput.new()
    player.input:press("interact")

    local presses = 0
    local far_tile = WallViewTile.new(1000, 1000, function() presses = presses + 1 end)

    player:update(1 / 60, {}, {}, nil, nil, far_tile, true)

    assert(presses == 0, "an out-of-range wall_tile should not fire even while frozen, got " .. presses .. " presses")
    print("PASS: wall_view_tile: frozen wall_tile check respects the proximity gate")
end

do
    local JigsawPiece = require("game/jigsaw_piece")

    local player = Player.new(0, 0)
    player.input = HeadlessInput.new()
    player.held_piece = JigsawPiece.new(0, {1, 0, 0, 1})
    player.input:press("interact")

    local presses = 0
    local tile = WallViewTile.new(0, 0, function() presses = presses + 1 end)

    player:update(1 / 60, {}, {}, nil, nil, tile, true)

    assert(presses == 0, "wall_tile should not fire while frozen and holding a piece, got " .. presses .. " presses")
    print("PASS: wall_view_tile: frozen wall_tile check respects the held-piece gate")
end

-- Full round trip: entering wall view (unfrozen call) and then exiting it
-- (frozen call, same tile, second interact press) both invoke on_press --
-- this is the actual toggle mechanic GameScene:_toggle_wall_view relies on.

do
    local player = Player.new(0, 0)
    player.input = HeadlessInput.new()

    local presses = 0
    local tile = WallViewTile.new(0, 0, function() presses = presses + 1 end)

    -- Enter: not frozen yet (view was "play" this frame).
    player.input:press("interact")
    player:update(1 / 60, {}, {}, nil, nil, tile, false)
    assert(presses == 1, "entering wall view should fire on_press once, got " .. presses .. " presses")

    -- Exit: now frozen (view became "wall" after the toggle above), same
    -- tile, second press.
    player.input:press("interact")
    player:update(1 / 60, {}, {}, nil, nil, tile, true)
    assert(presses == 2, "exiting wall view while frozen should fire on_press a second time, got " ..
        presses .. " presses")
    print("PASS: wall_view_tile: entering (unfrozen) and exiting (frozen) both reach wall_tile:interact()")
end

-- Player:update() still advances input edge-state while frozen -- self.input
-- :update() must run every frozen frame (not just be skipped), or a
-- single-frame queued press() sitting in HeadlessInput's internal _queued
-- table never gets consumed/cleared, and falsely re-fires as a fresh press
-- once unfrozen. Regression guard for the edge-detection note in
-- docs/design/wall-view-tile.md.

do
    local player = Player.new(0, 0)
    player.input = HeadlessInput.new()
    player.input:press("interact")  -- single-frame queued press

    -- Frame 1: frozen. If input:update() runs (as required), this queued
    -- press is consumed and cleared this frame.
    player:update(1 / 60, {}, {}, nil, nil, nil, true)

    -- Frame 2: unfrozen, nothing newly pressed. If frame 1 had skipped
    -- input:update(), the stale queued press would still be sitting in
    -- _queued and would incorrectly fire here against the tile instead of
    -- having been long consumed.
    local presses = 0
    local tile = WallViewTile.new(0, 0, function() presses = presses + 1 end)
    player:update(1 / 60, {}, {}, nil, nil, tile, false)

    assert(presses == 0,
        "a single-frame press() queued during a frozen frame should be consumed that frame (via the " ..
        "unconditional input:update() call), not leak into the next unfrozen frame as a fresh press, got " ..
        presses .. " presses")
    print("PASS: wall_view_tile: a queued press during a frozen frame is consumed, not leaked to the next frame")
end
