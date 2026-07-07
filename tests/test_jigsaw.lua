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
    p:drop(555, 200)
    assert(p.state    == "grounded", "state should be grounded after drop()")
    assert(p.sprite.x == 576,        "x should snap to 576 (9*SLOT), got " .. tostring(p.sprite.x))
    assert(p.sprite.y == 192,        "y should snap to 192 (3*SLOT), got " .. tostring(p.sprite.y))
    print("PASS: jigsaw_piece: drop() snaps both x and y to nearest SLOT")
end

do
    -- Drop at exact slot boundary on both axes
    local p = JigsawPiece.new(0, {1, 0, 0, 1})
    p:pick_up()
    p:drop(384, 128)  -- exactly 6*64, 2*64
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

-- drop() lands at the player's current position ---------------------------

do
    local Player        = require("game/player")
    local HeadlessInput = require("lua/headless/input")

    local player = Player.new(300, 170)
    player.input = HeadlessInput.new()

    local p = JigsawPiece.new(0, {1, 0, 0, 1})
    p:pick_up()
    player.held_piece = p

    -- Move the player after pickup, before dropping, to prove the drop
    -- target is derived from the player's *current* position at the moment
    -- of interact, not a stale position captured earlier (or the piece's
    -- own floating carry position, which is still at its pre-pickup spot
    -- here since we never called p:update(player)).
    player.sprite.x = 500
    player.sprite.y = 260

    player.input:press("interact")
    player:update(1 / 60, {})

    local centre     = player:centre()
    local expected_x = math.floor((centre.x - C.U) / C.SLOT + 0.5) * C.SLOT
    local expected_y = math.floor((centre.y - C.U) / C.SLOT + 0.5) * C.SLOT

    assert(p.state == "grounded", "piece should be grounded after drop via player:update()")
    assert(player.held_piece == nil, "player.held_piece should be nil after drop")
    assert(p.sprite.x == expected_x,
        "dropped piece x should match player's current position (" .. expected_x .. "), got " .. tostring(p.sprite.x))
    assert(p.sprite.y == expected_y,
        "dropped piece y should match player's current position (" .. expected_y .. "), got " .. tostring(p.sprite.y))
    print("PASS: player: interact drop lands piece at player's current position, not a stale one")
end

-- overlap check (via player logic) ---------------------------------------

do
    -- pieceA is grounded at slot (384, 192). pieceB is held by the player,
    -- whose position is chosen so its drop-target slot is exactly pieceA's
    -- slot. The drop must be blocked and pieceA left undisturbed. This goes
    -- through the real Player:update()/JigsawPiece:drop() code path (rather
    -- than duplicating the occupied-slot check inline) so the test tracks
    -- however player.lua actually computes the target.
    local Player        = require("game/player")
    local HeadlessInput = require("lua/headless/input")

    local pieceA = JigsawPiece.new(384, {1, 0, 0, 1})  -- grounded at (384, 192)
    local pieceB = JigsawPiece.new(0,   {0, 0, 1, 1})
    pieceB:pick_up()

    local player = Player.new(0, 0)
    player.input = HeadlessInput.new()
    player.held_piece = pieceB

    -- centre().x - U == sprite.x - 16; set sprite.x so target_x == 384.
    -- centre().y - U == sprite.y -  8; set sprite.y so target_y == 192.
    player.sprite.x = 400
    player.sprite.y = 200

    local pieces = { pieceA, pieceB }
    player.input:press("interact")
    player:update(1 / 60, pieces)

    assert(pieceB.state == "held", "pieceB should still be held when target slot is occupied")
    assert(player.held_piece == pieceB, "player.held_piece should remain pieceB when drop is blocked")
    assert(pieceA.sprite.x == 384 and pieceA.sprite.y == 192, "pieceA's slot should be undisturbed")
    print("PASS: overlap check (via real Player code path): occupied slot detected, drop blocked")
end

-- JigsawBox ---------------------------------------------------------------
local JigsawBox = require("game/jigsaw_box")

-- JigsawBox.new -----------------------------------------------------------

do
    local box = JigsawBox.new(128, 128)
    assert(box.state == "waiting",       "new box should be in state 'waiting'")
    assert(#box.pieces_to_spawn == 3,    "new box should have 3 items in pieces_to_spawn")
    print("PASS: jigsaw_box: new() creates box in state 'waiting' with 3 pieces queued")
end

-- interact() --------------------------------------------------------------

do
    local box = JigsawBox.new(128, 128)
    box:interact()
    assert(box.state == "ejecting", "state should be 'ejecting' after interact()")
    assert(box.spawn_timer <= 0,    "spawn_timer should be <= 0 after interact()")
    print("PASS: jigsaw_box: interact() transitions to 'ejecting' and sets spawn_timer <= 0")
end

-- update() ejects one piece per call -------------------------------------

do
    local box = JigsawBox.new(128, 128)
    local pieces = {}
    box:interact()
    box:update(1.0, pieces)
    assert(#pieces == 1,              "one piece should be ejected after first update")
    assert(box.state == "ejecting",   "state should still be 'ejecting' with 2 pieces remaining")
    print("PASS: jigsaw_box: update() ejects one piece per large-dt call, state stays 'ejecting'")
end

-- update() x3 ejects all pieces, state becomes done ---------------------

do
    local box = JigsawBox.new(128, 128)
    local pieces = {}
    box:interact()
    box:update(1.0, pieces)
    box:update(1.0, pieces)
    box:update(1.0, pieces)
    assert(#pieces == 3,        "three pieces should be ejected after three updates")
    assert(box.state == "done", "state should be 'done' after all pieces ejected")
    print("PASS: jigsaw_box: after 3 updates all pieces ejected and state is 'done'")
end

-- slot search skips occupied slots ----------------------------------------

do
    local box = JigsawBox.new(128, 192)
    local bx = box.sprite.x  -- 128
    local by = box.sprite.y  -- 192
    -- The first d=1 candidate (sorted by dx then dy) is {-1,0} -> (bx-SLOT, by).
    -- Block it with a fake grounded piece so the eject must choose something else.
    local blocked_x = bx - C.SLOT
    local blocked_y = by
    local fake_piece = { state = "grounded", sprite = { x = blocked_x, y = blocked_y } }
    local pieces = { fake_piece }
    box:interact()
    box:update(1.0, pieces)
    -- pieces[2] is the newly ejected piece (pieces[1] is our fake blocker)
    local new_piece = pieces[2]
    assert(new_piece ~= nil, "an ejected piece should be appended to pieces")
    assert(not (new_piece.sprite.x == blocked_x and new_piece.sprite.y == blocked_y),
        "ejected piece must not land on the occupied slot")
    print("PASS: jigsaw_box: slot search skips grounded-piece-occupied slots")
end

print("ALL TESTS PASSED")
