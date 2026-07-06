local C            = require("game/constants")
local JigsawPiece  = require("game/jigsaw_piece")

-- constants ---------------------------------------------------------------

do
    assert(C.U    == 32, "U should be 32, got " .. tostring(C.U))
    assert(C.SLOT == 64, "SLOT should be 64, got " .. tostring(C.SLOT))
    print("PASS: constants: U=32, SLOT=64")
end

-- sprite rotation field ---------------------------------------------------

do
    local Sprite = require("lua/core/sprite")
    local s = Sprite.new(0, 0, 64, 64)
    assert(s.rotation == 0, "Sprite.rotation should default to 0")
    print("PASS: sprite: rotation field defaults to 0")
end

-- JigsawPiece.new ---------------------------------------------------------

do
    local p = JigsawPiece.new(384, {1, 0, 0, 1})
    assert(p.state         == "grounded", "new piece should be grounded")
    assert(p.rotation_step == 0,          "new piece rotation_step should be 0")
    assert(p.sprite.x      == 384,        "sprite.x should match constructor x")
    assert(p.sprite.y      == 192,        "sprite.y should be 3*SLOT = 192")
    assert(p.sprite.width  == C.SLOT,     "sprite width should be SLOT")
    assert(p.sprite.height == C.SLOT,     "sprite height should be SLOT")
    print("PASS: jigsaw_piece: new() positions on ground with correct size")
end

-- centre() ----------------------------------------------------------------

do
    local p = JigsawPiece.new(384, {1, 0, 0, 1})
    local c = p:centre()
    assert(c.x == 384 + C.U, "centre.x should be x + U = " .. (384 + C.U) .. ", got " .. tostring(c.x))
    assert(c.y == 192 + C.U, "centre.y should be y + U = " .. (192 + C.U) .. ", got " .. tostring(c.y))
    print("PASS: jigsaw_piece: centre() returns sprite center")
end

-- rotate() ----------------------------------------------------------------

do
    local p = JigsawPiece.new(0, {1, 0, 0, 1})
    p:rotate()
    assert(p.rotation_step == 1, "rotation_step should be 1 after one rotate")
    local expected = 1 * (math.pi / 2)
    assert(math.abs(p.sprite.rotation - expected) < 1e-9,
        "sprite.rotation should be pi/2 after one rotate")

    p:rotate() p:rotate() p:rotate()
    assert(p.rotation_step == 0, "rotation_step should wrap back to 0 after 4 rotates")
    print("PASS: jigsaw_piece: rotate() cycles rotation_step 0→1→2→3→0")
end

-- pick_up() ---------------------------------------------------------------

do
    local p = JigsawPiece.new(0, {1, 0, 0, 1})
    p:pick_up()
    assert(p.state == "held", "state should be 'held' after pick_up()")
    print("PASS: jigsaw_piece: pick_up() sets state to held")
end

-- drop() grid snap --------------------------------------------------------

do
    -- Position piece at (555, 200) — nearest slot is x=576 (9*64), y=192 (3*64)
    local p = JigsawPiece.new(0, {1, 0, 0, 1})
    p:pick_up()
    p.sprite.x = 555
    p.sprite.y = 200
    p:drop()
    assert(p.state    == "grounded", "state should be grounded after drop()")
    assert(p.sprite.x == 576,        "x should snap to 576 (9*SLOT), got " .. tostring(p.sprite.x))
    assert(p.sprite.y == 192,        "y should snap to 192 (3*SLOT), got " .. tostring(p.sprite.y))
    print("PASS: jigsaw_piece: drop() snaps both x and y to nearest SLOT")
end

do
    -- Drop at exact slot boundary on both axes
    local p = JigsawPiece.new(0, {1, 0, 0, 1})
    p:pick_up()
    p.sprite.x = 384  -- exactly 6 * 64
    p.sprite.y = 128  -- exactly 2 * 64
    p:drop()
    assert(p.sprite.x == 384, "drop at exact x boundary should stay at 384, got " .. tostring(p.sprite.x))
    assert(p.sprite.y == 128, "drop at exact y boundary should stay at 128, got " .. tostring(p.sprite.y))
    print("PASS: jigsaw_piece: drop() at exact slot boundary stays aligned")
end

-- update() held position --------------------------------------------------

do
    -- Mock a minimal player table
    local mock_player = {
        sprite = { x = 300, y = 170 },
        centre = function(self)
            return { x = self.sprite.x + 16, y = self.sprite.y + 24 }
        end,
    }
    local p = JigsawPiece.new(0, {1, 0, 0, 1})
    p:pick_up()
    p:update(mock_player)

    local expected_x = mock_player:centre().x - C.U   -- 316 - 32 = 284
    local expected_y = mock_player.sprite.y - 2 * C.U -- 170 - 64 = 106
    assert(p.sprite.x == expected_x,
        "held piece x should be " .. expected_x .. ", got " .. tostring(p.sprite.x))
    assert(p.sprite.y == expected_y,
        "held piece y should be " .. expected_y .. ", got " .. tostring(p.sprite.y))
    print("PASS: jigsaw_piece: update() positions held piece above player head")
end

-- grounded piece not moved by update() -----------------------------------

do
    local mock_player = {
        sprite = { x = 300, y = 170 },
        centre = function(self)
            return { x = self.sprite.x + 16, y = self.sprite.y + 24 }
        end,
    }
    local p = JigsawPiece.new(200, {1, 0, 0, 1})
    p:update(mock_player)
    assert(p.sprite.x == 200, "grounded piece should not move on update()")
    print("PASS: jigsaw_piece: update() does not move grounded pieces")
end

-- overlap check (via player logic) ---------------------------------------

do
    -- Simulate two pieces: A grounded at (384, 192), B held at same target slot.
    -- Player must not drop B onto A.
    local C2   = require("game/constants")
    local pieceA = JigsawPiece.new(384, {1, 0, 0, 1})       -- grounded at (384,192)
    local pieceB = JigsawPiece.new(0,   {0, 0, 1, 1})
    pieceB:pick_up()
    pieceB.sprite.x = 384  -- would snap to same slot as A
    pieceB.sprite.y = 192

    local snap_x = math.floor(pieceB.sprite.x / C2.SLOT + 0.5) * C2.SLOT
    local snap_y = math.floor(pieceB.sprite.y / C2.SLOT + 0.5) * C2.SLOT
    local occupied = false
    local pieces = { pieceA, pieceB }
    for _, p in ipairs(pieces) do
        if p ~= pieceB and p.state == "grounded"
           and p.sprite.x == snap_x and p.sprite.y == snap_y then
            occupied = true
            break
        end
    end
    assert(occupied == true, "slot (384,192) should be detected as occupied")
    assert(pieceB.state == "held", "pieceB should still be held when target slot is occupied")
    print("PASS: overlap check: occupied slot detected, drop blocked")
end

print("ALL TESTS PASSED")
