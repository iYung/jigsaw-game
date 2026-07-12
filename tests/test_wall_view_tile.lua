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

-- Player:update() with frozen == true: no movement, no interactions -------

do
    local player = Player.new(0, 0)
    player.input = HeadlessInput.new()
    player.input:hold("right")
    player.input:press("interact")

    local presses = 0
    local tile = WallViewTile.new(0, 0, function() presses = presses + 1 end)

    local start_x, start_y = player.sprite.x, player.sprite.y
    player:update(1 / 60, {}, {}, nil, nil, tile, true)

    assert(player.sprite.x == start_x and player.sprite.y == start_y,
        "player position should be unchanged when frozen, even with a movement key held, got (" ..
        tostring(player.sprite.x) .. ", " .. tostring(player.sprite.y) .. ")")
    assert(presses == 0, "wall_tile:interact() should NOT fire while frozen, got " .. presses .. " presses")
    print("PASS: wall_view_tile: Player:update() applies no movement or interaction while frozen")
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
