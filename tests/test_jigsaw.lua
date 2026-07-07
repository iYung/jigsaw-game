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
    assert(#box.pieces_to_spawn == 9,    "new box should have 9 items in pieces_to_spawn (3x3 grid)")
    print("PASS: jigsaw_box: new() creates box in state 'waiting' with 9 pieces queued")
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
    assert(box.state == "ejecting",   "state should still be 'ejecting' with 8 pieces remaining")
    print("PASS: jigsaw_box: update() ejects one piece per large-dt call, state stays 'ejecting'")
end

-- update() x9 ejects all pieces, state becomes done ----------------------

do
    local box = JigsawBox.new(128, 128)
    local pieces = {}
    box:interact()
    for i = 1, 8 do
        box:update(1.0, pieces)
        assert(box.state == "ejecting",
            "state should still be 'ejecting' after " .. i .. " of 9 updates")
    end
    box:update(1.0, pieces)
    assert(#pieces == 9,        "nine pieces should be ejected after nine updates")
    assert(box.state == "done", "state should be 'done' only once all 9 pieces are ejected")
    print("PASS: jigsaw_box: after 9 updates all pieces ejected and state is 'done' (not before)")
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

-- pieces_to_spawn slices the image into 9 distinct cells (shuffle) --------

do
    -- The headless stub's love.graphics.newQuad (lua/headless/stubs.lua)
    -- falls through the catch-all new*-handler and returns a bare table with
    -- no getViewport()/coordinate info, so a quad object alone can't tell us
    -- which grid cell it represents. To still verify the slicing/shuffle is
    -- correct, spy on love.graphics.newQuad for the duration of JigsawBox.new
    -- and record which (col, row) each *returned quad table* corresponds to,
    -- keyed by table identity. This only touches the test's local view of
    -- love.graphics, not the stub file itself.
    local real_newQuad = love.graphics.newQuad
    local cell_of = {}  -- quad (table identity) -> "col,row"
    love.graphics.newQuad = function(qx, qy, qw, qh, imgW, imgH)
        local quad = real_newQuad(qx, qy, qw, qh, imgW, imgH)
        local col = math.floor(qx / qw + 0.5)
        local row = math.floor(qy / qh + 0.5)
        cell_of[quad] = col .. "," .. row
        return quad
    end

    local box = JigsawBox.new(0, 0)
    love.graphics.newQuad = real_newQuad

    assert(#box.pieces_to_spawn == 9, "pieces_to_spawn should have 9 entries")

    local seen = {}
    for _, spec in ipairs(box.pieces_to_spawn) do
        assert(spec.image ~= nil, "each pieces_to_spawn entry should carry a non-nil image")
        assert(spec.quad  ~= nil, "each pieces_to_spawn entry should carry a non-nil quad")
        local cell = cell_of[spec.quad]
        assert(cell ~= nil, "spec.quad should be one of the quads created by JigsawBox.new")
        assert(not seen[cell], "cell " .. cell .. " appears more than once in pieces_to_spawn")
        seen[cell] = true
    end
    for row = 0, 2 do
        for col = 0, 2 do
            local cell = col .. "," .. row
            assert(seen[cell], "pieces_to_spawn is missing expected cell " .. cell)
        end
    end
    print("PASS: jigsaw_box: pieces_to_spawn covers all 9 grid cells exactly once")
end

do
    -- Probabilistic check that the 9 entries are actually shuffled (not left
    -- in row-major construction order) across several fresh boxes. As with
    -- other probabilistic assertions in this file, a false failure is
    -- astronomically unlikely (would require 9! order to repeat unshuffled
    -- every single trial) rather than impossible.
    local real_newQuad = love.graphics.newQuad
    local unshuffled_order = "0,0|1,0|2,0|0,1|1,1|2,1|0,2|1,2|2,2"
    local orders = {}
    for trial = 1, 8 do
        local cell_of = {}
        love.graphics.newQuad = function(qx, qy, qw, qh, imgW, imgH)
            local quad = real_newQuad(qx, qy, qw, qh, imgW, imgH)
            local col = math.floor(qx / qw + 0.5)
            local row = math.floor(qy / qh + 0.5)
            cell_of[quad] = col .. "," .. row
            return quad
        end
        local box = JigsawBox.new(0, 0)
        love.graphics.newQuad = real_newQuad

        local order = {}
        for i, spec in ipairs(box.pieces_to_spawn) do
            order[i] = cell_of[spec.quad]
        end
        local key = table.concat(order, "|")
        orders[#orders + 1] = key
    end

    local all_row_major = true
    for _, key in ipairs(orders) do
        if key ~= unshuffled_order then all_row_major = false break end
    end
    assert(not all_row_major,
        "pieces_to_spawn order matched unshuffled row-major order in every trial -- shuffle may be missing")
    print("PASS: jigsaw_box: pieces_to_spawn ejection order is shuffled (not row-major every time)")
end

-- ejected piece gets a random initial rotation_step ------------------------

do
    local rotation_steps = {}
    for trial = 1, 12 do
        local box = JigsawBox.new(128, 128)
        box:interact()
        local pieces = {}
        box:update(1.0, pieces)
        local piece = pieces[1]
        local step = piece.rotation_step
        assert(step == 0 or step == 1 or step == 2 or step == 3,
            "ejected piece rotation_step should be one of 0,1,2,3, got " .. tostring(step))
        rotation_steps[#rotation_steps + 1] = step
    end

    local all_same = true
    for i = 2, #rotation_steps do
        if rotation_steps[i] ~= rotation_steps[1] then all_same = false break end
    end
    assert(not all_same,
        "rotation_step was " .. tostring(rotation_steps[1]) .. " in every one of " ..
        #rotation_steps .. " trials -- expected some variety from the random initial rotation")
    print("PASS: jigsaw_box: ejected pieces get a random initial rotation_step in {0,1,2,3}, with variety across ejections")
end

-- ejected piece carries non-nil image + quad (visual wiring) --------------

do
    local box = JigsawBox.new(128, 128)
    box:interact()
    local pieces = {}
    box:update(1.0, pieces)
    local piece = pieces[1]
    assert(piece.sprite.image ~= nil, "ejected piece's sprite.image should be non-nil")
    assert(piece.sprite.quad  ~= nil, "ejected piece's sprite.quad should be non-nil")
    print("PASS: jigsaw_box: ejected piece's sprite carries non-nil image and quad (visual wiring)")
end

-- Drawer:remove ------------------------------------------------------------

do
    local Drawer = require("lua/core/drawer")
    local Sprite = require("lua/core/sprite")

    local drawer = Drawer.new()
    local sA = Sprite.new(0, 0, 10, 10)
    local sB = Sprite.new(0, 0, 10, 10)
    local sC = Sprite.new(0, 0, 10, 10)
    drawer:add(sA, 1)
    drawer:add(sB, 2)
    drawer:add(sC, 3)

    drawer:remove(sB)

    assert(#drawer.layers == 2,
        "layers should have 2 entries after removing one of 3, got " .. #drawer.layers)
    for _, entry in ipairs(drawer.layers) do
        assert(entry.sprite ~= sB, "removed sprite should not appear in layers")
    end
    local found_a, found_c = false, false
    for _, entry in ipairs(drawer.layers) do
        if entry.sprite == sA then found_a = true end
        if entry.sprite == sC then found_c = true end
    end
    assert(found_a and found_c, "remaining sprites should still be present in layers")
    print("PASS: drawer: remove() removes the matching entry and leaves others intact")
end

do
    local Drawer = require("lua/core/drawer")
    local Sprite = require("lua/core/sprite")

    local drawer = Drawer.new()
    local sA = Sprite.new(0, 0, 10, 10)
    local sOther = Sprite.new(0, 0, 10, 10)  -- never added to drawer
    drawer:add(sA, 1)

    drawer:remove(sOther)

    assert(#drawer.layers == 1,
        "layers should be unchanged when removing a sprite that was never added, got " .. #drawer.layers)
    assert(drawer.layers[1].sprite == sA, "the only entry should still be sA")
    print("PASS: drawer: remove() no-ops when sprite is not present")
end

-- pick-up removes the piece from both pieces[] and the Drawer --------------

do
    local Player        = require("game/player")
    local HeadlessInput = require("lua/headless/input")
    local Drawer        = require("lua/core/drawer")

    local drawer = Drawer.new()
    -- Grounded at (0, 192) -> centre (32, 224).
    local piece = JigsawPiece.new(0, {1, 0, 0, 1})
    drawer:add(piece, C.PRIORITY_PIECE)
    local pieces = { piece }

    -- Player centre (32, 224) exactly matches the piece's centre, well
    -- within the 1.5*U pick-up range.
    local player = Player.new(16, 200)
    player.input = HeadlessInput.new()

    player.input:press("interact")
    player:update(1 / 60, pieces, nil, drawer)

    assert(#pieces == 0, "pieces array should be empty after pick-up, got " .. #pieces)
    local found_in_drawer = false
    for _, entry in ipairs(drawer.layers) do
        if entry.sprite == piece then found_in_drawer = true end
    end
    assert(not found_in_drawer, "picked-up piece should be removed from drawer.layers")
    assert(player.held_piece == piece, "player.held_piece should be the picked-up piece")
    print("PASS: player: pick-up removes piece from both the pieces array and the Drawer")
end

-- drop re-inserts the piece into pieces[] and the Drawer at C.PRIORITY_PIECE

do
    local Player        = require("game/player")
    local HeadlessInput = require("lua/headless/input")
    local Drawer        = require("lua/core/drawer")

    local piece = JigsawPiece.new(0, {1, 0, 0, 1})
    piece:pick_up()

    local player = Player.new(16, 200)
    player.input = HeadlessInput.new()
    player.held_piece = piece

    local pieces = {}
    local drawer = Drawer.new()

    player.input:press("interact")
    player:update(1 / 60, pieces, nil, drawer)

    local found_in_pieces = false
    for _, p in ipairs(pieces) do
        if p == piece then found_in_pieces = true end
    end
    assert(found_in_pieces, "dropped piece should be re-inserted into the pieces array")

    local found_in_drawer, drawer_priority = false, nil
    for _, entry in ipairs(drawer.layers) do
        if entry.sprite == piece then
            found_in_drawer = true
            drawer_priority = entry.priority
        end
    end
    assert(found_in_drawer, "dropped piece should be re-added to the Drawer")
    assert(drawer_priority == C.PRIORITY_PIECE,
        "dropped piece's drawer priority should be C.PRIORITY_PIECE (" .. C.PRIORITY_PIECE ..
        "), got " .. tostring(drawer_priority))
    assert(player.held_piece == nil, "player.held_piece should be nil after drop")
    print("PASS: player: drop re-inserts piece into pieces and re-adds it to the Drawer at C.PRIORITY_PIECE")
end

-- Player:draw() draws the held piece after the player's own sprite --------

do
    local Player = require("game/player")

    local player = Player.new(0, 0)
    local piece = JigsawPiece.new(0, {1, 0, 0, 1})
    player.held_piece = piece

    local call_order = {}
    local orig_player_draw = player.sprite.draw
    local orig_piece_draw  = piece.sprite.draw

    player.sprite.draw = function(self)
        call_order[#call_order + 1] = "player"
        return orig_player_draw(self)
    end
    piece.sprite.draw = function(self)
        call_order[#call_order + 1] = "piece"
        return orig_piece_draw(self)
    end

    player:draw()

    player.sprite.draw = orig_player_draw
    piece.sprite.draw  = orig_piece_draw

    assert(#call_order == 2,
        "both player and held piece sprites should draw, got " .. #call_order .. " calls")
    assert(call_order[1] == "player",
        "player's own sprite should draw first, got " .. tostring(call_order[1]))
    assert(call_order[2] == "piece",
        "held piece's sprite should draw second, got " .. tostring(call_order[2]))
    print("PASS: player: draw() draws the held piece's sprite after the player's own sprite")
end

do
    local Player = require("game/player")

    local player = Player.new(0, 0)
    player.held_piece = nil

    local call_order = {}
    local orig_player_draw = player.sprite.draw
    player.sprite.draw = function(self)
        call_order[#call_order + 1] = "player"
        return orig_player_draw(self)
    end

    local ok, err = pcall(function() player:draw() end)

    player.sprite.draw = orig_player_draw

    assert(ok, "draw() should not error when no piece is held: " .. tostring(err))
    assert(#call_order == 1,
        "only the player's own sprite should draw when no piece is held, got " .. #call_order)
    assert(call_order[1] == "player", "the single draw call should be the player's sprite")
    print("PASS: player: draw() with no held piece only draws the player's own sprite, without error")
end

-- pieces_to_spawn row/col fields match each quad's actual source cell -----

do
    -- Same love.graphics.newQuad spy technique as the "pieces_to_spawn
    -- slices the image into 9 distinct cells" block above, but this time
    -- checking that spec.row/spec.col (which JigsawPiece/JigsawSolver rely
    -- on) actually agree with the quad's real (col, row) source cell rather
    -- than just checking the cells are distinct.
    local real_newQuad = love.graphics.newQuad
    local cell_of = {}  -- quad (table identity) -> {col=, row=}
    love.graphics.newQuad = function(qx, qy, qw, qh, imgW, imgH)
        local quad = real_newQuad(qx, qy, qw, qh, imgW, imgH)
        local col = math.floor(qx / qw + 0.5)
        local row = math.floor(qy / qh + 0.5)
        cell_of[quad] = { col = col, row = row }
        return quad
    end

    local box = JigsawBox.new(0, 0)
    love.graphics.newQuad = real_newQuad

    local seen = {}
    for _, spec in ipairs(box.pieces_to_spawn) do
        local actual = cell_of[spec.quad]
        assert(actual ~= nil, "spec.quad should be one of the quads created by JigsawBox.new")
        assert(spec.row == actual.row,
            "spec.row (" .. tostring(spec.row) .. ") should match quad's actual row (" .. actual.row .. ")")
        assert(spec.col == actual.col,
            "spec.col (" .. tostring(spec.col) .. ") should match quad's actual col (" .. actual.col .. ")")
        local cell = spec.col .. "," .. spec.row
        assert(not seen[cell], "(row,col) combination " .. cell .. " appears more than once in pieces_to_spawn")
        seen[cell] = true
    end
    for row = 0, 2 do
        for col = 0, 2 do
            local cell = col .. "," .. row
            assert(seen[cell], "pieces_to_spawn is missing expected (col,row) combination " .. cell)
        end
    end
    print("PASS: jigsaw_box: pieces_to_spawn entries' row/col fields match their quad's actual source cell (all 9 combinations)")
end

-- JigsawPiece.new copies visual.row/visual.col onto the piece -------------

do
    local visual = { image = {}, quad = {}, row = 1, col = 2 }
    local p = JigsawPiece.new(0, {1, 1, 1, 1}, visual)
    assert(p.row == 1, "piece.row should be copied from visual.row, got " .. tostring(p.row))
    assert(p.col == 2, "piece.col should be copied from visual.col, got " .. tostring(p.col))
    print("PASS: jigsaw_piece: new() copies visual.row/visual.col onto the piece")
end

-- start_vanish() ------------------------------------------------------------

do
    local p = JigsawPiece.new(0, {1, 0, 0, 1})
    p:start_vanish()
    assert(p.state == "vanishing", "state should be 'vanishing' after start_vanish()")
    assert(p.fade_timer == C.PIECE_FADE_DURATION,
        "fade_timer should be C.PIECE_FADE_DURATION (" .. C.PIECE_FADE_DURATION .. "), got " .. tostring(p.fade_timer))
    assert(p.fade_timer > 0, "fade_timer should be a positive number")
    print("PASS: jigsaw_piece: start_vanish() sets state to 'vanishing' with a full fade_timer")
end

-- update_fade() -------------------------------------------------------------

do
    local p = JigsawPiece.new(0, {1, 1, 1, 1})
    p:start_vanish()
    local step = C.PIECE_FADE_DURATION / 4

    local prev_alpha = p.sprite.color[4]
    local finished
    for i = 1, 3 do
        finished = p:update_fade(step)
        assert(not finished, "update_fade() should not report finished while time remains (step " .. i .. ")")
        assert(p.sprite.color[4] < prev_alpha,
            "sprite.color[4] should decrease each update_fade() call, step " .. i)
        prev_alpha = p.sprite.color[4]
    end

    finished = p:update_fade(C.PIECE_FADE_DURATION)
    assert(finished, "update_fade() should return true once fade_timer is exhausted")
    assert(p.sprite.color[4] == 0,
        "sprite.color[4] should be clamped to 0 once fully faded, got " .. tostring(p.sprite.color[4]))
    print("PASS: jigsaw_piece: update_fade() fades alpha to 0 over time and reports completion")
end

-- JigsawSolver.is_assembled -------------------------------------------------
local JigsawSolver = require("game/jigsaw_solver")

-- Builds an array of 9 fake piece tables (same minimal shape as fake_piece
-- above) arranged correctly relative to each other, with the whole grid
-- offset by (ox, oy) slots from the world origin.
local function build_assembled_pieces(ox, oy)
    local pieces = {}
    for row = 0, 2 do
        for col = 0, 2 do
            pieces[#pieces + 1] = {
                rotation_step = 0,
                row = row,
                col = col,
                sprite = { x = (col + ox) * C.SLOT, y = (row + oy) * C.SLOT },
            }
        end
    end
    return pieces
end

do
    local pieces = build_assembled_pieces(0, 0)
    table.remove(pieces)  -- drop to 8 well-formed pieces
    assert(JigsawSolver.is_assembled(pieces) == false,
        "is_assembled should be false for fewer than C.PUZZLE_PIECE_COUNT pieces")
    print("PASS: jigsaw_solver: is_assembled() is false with fewer than 9 pieces")
end

do
    local pieces = build_assembled_pieces(0, 0)
    pieces[1].rotation_step = 1
    assert(JigsawSolver.is_assembled(pieces) == false,
        "is_assembled should be false when any piece has a non-zero rotation_step")
    print("PASS: jigsaw_solver: is_assembled() is false when a piece is rotated")
end

do
    -- Swap two pieces' sprite positions so their (row, col) identities no
    -- longer match their placement, while rotation stays correct and the
    -- count stays at 9 -- the relative arrangement is now wrong.
    local pieces = build_assembled_pieces(0, 0)
    local ax, ay = pieces[1].sprite.x, pieces[1].sprite.y
    pieces[1].sprite.x, pieces[1].sprite.y = pieces[2].sprite.x, pieces[2].sprite.y
    pieces[2].sprite.x, pieces[2].sprite.y = ax, ay
    assert(JigsawSolver.is_assembled(pieces) == false,
        "is_assembled should be false when the relative arrangement is wrong")
    print("PASS: jigsaw_solver: is_assembled() is false when two pieces' positions are swapped")
end

do
    local pieces_origin  = build_assembled_pieces(0, 0)
    local pieces_shifted = build_assembled_pieces(3, 3)
    assert(JigsawSolver.is_assembled(pieces_origin) == true,
        "is_assembled should be true for a correctly arranged puzzle at the world origin")
    assert(JigsawSolver.is_assembled(pieces_shifted) == true,
        "is_assembled should be true for a correctly arranged puzzle shifted by a constant offset")
    print("PASS: jigsaw_solver: is_assembled() is true regardless of the puzzle's absolute world position")
end

-- integration: assembling the puzzle vanishes pieces, then removes them ---
-- from both gs.pieces and the Drawer once their fade completes (GameScene) -

do
    local GameScene = require("game/scenes/game_scene")

    local gs = GameScene.new()
    gs:on_enter()

    -- Replace whatever the box set up in on_enter() with 9 correctly
    -- arranged, unrotated pieces so JigsawSolver.is_assembled(gs.pieces) is
    -- true as soon as gs:update()'s solved-check runs.
    gs.pieces = {}
    gs.pieces_in_drawer = {}
    local spawned = {}
    for row = 0, 2 do
        for col = 0, 2 do
            local p = JigsawPiece.new(col * C.SLOT, {1, 1, 1, 1},
                { image = {}, quad = {}, row = row, col = col })
            p.sprite.y = row * C.SLOT
            gs.pieces[#gs.pieces + 1] = p
            spawned[#spawned + 1] = p
            gs.drawer:add(p, C.PRIORITY_PIECE)
            gs.pieces_in_drawer[p] = true
        end
    end
    assert(#gs.pieces == C.PUZZLE_PIECE_COUNT, "test setup should have 9 pieces before update()")

    -- First update(): the one-shot solved check fires (assembled == true),
    -- start_vanish() runs on every piece, and the same call already drives
    -- one small update_fade() tick on each piece since it's now "vanishing".
    gs:update(1 / 60)

    assert(gs.puzzle_solved == true, "puzzle_solved should be set true once the arrangement is detected")
    for _, p in ipairs(spawned) do
        assert(p.state == "vanishing", "every piece should be in the 'vanishing' state after the solved check fires")
    end
    assert(#gs.pieces == C.PUZZLE_PIECE_COUNT,
        "pieces should not be removed yet after only one small fade tick")

    -- Drive enough more time for the fade to fully complete.
    gs:update(C.PIECE_FADE_DURATION)

    assert(#gs.pieces == 0,
        "all pieces should be removed from gs.pieces once their fade completes, got " .. #gs.pieces)
    for _, p in ipairs(spawned) do
        assert(gs.pieces_in_drawer[p] == nil, "vanished piece should be cleared from pieces_in_drawer")
        local found_in_drawer = false
        for _, entry in ipairs(gs.drawer.layers) do
            if entry.sprite == p then found_in_drawer = true end
        end
        assert(not found_in_drawer, "vanished piece should no longer appear in the Drawer's layers")
    end
    print("PASS: game_scene: assembling the puzzle fades out and removes all pieces from gs.pieces and the Drawer")
end

print("ALL TESTS PASSED")
