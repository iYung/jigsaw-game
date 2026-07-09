local C            = require("game/constants")
local JigsawPiece  = require("game/jigsaw_piece")
local PuzzleCatalog = require("game/puzzle_catalog")
local GameState = require("game/game_state")

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

-- Player.new() sprite size matches a puzzle piece's footprint (C.SLOT x C.SLOT)

do
    local Player = require("game/player")
    local player = Player.new(100, 50)
    assert(player.sprite.width  == C.SLOT, "player sprite width should be SLOT (" .. C.SLOT .. "), got " .. tostring(player.sprite.width))
    assert(player.sprite.height == C.SLOT, "player sprite height should be SLOT (" .. C.SLOT .. "), got " .. tostring(player.sprite.height))

    local c = player:centre()
    assert(c.x == 100 + C.SLOT / 2, "player centre.x should be sprite.x + SLOT/2, got " .. tostring(c.x))
    assert(c.y == 50  + C.SLOT / 2, "player centre.y should be sprite.y + SLOT/2, got " .. tostring(c.y))
    print("PASS: player: Player.new() sprite is sized to match a puzzle piece (SLOT x SLOT)")
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
            return { x = self.sprite.x + 32, y = self.sprite.y + 32 }
        end,
    }
    local p = JigsawPiece.new(0, {1, 0, 0, 1})
    p:pick_up()
    p:update(mock_player)

    local expected_x = mock_player:centre().x - C.U   -- 332 - 32 = 300
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
            return { x = self.sprite.x + 32, y = self.sprite.y + 32 }
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

    -- centre().x - U == sprite.x (the +32 centre offset cancels the -32 U
    -- offset); set sprite.x so target_x == 384. Same for y and target_y == 192.
    player.sprite.x = 384
    player.sprite.y = 192

    local pieces = { pieceA, pieceB }
    player.input:press("interact")
    player:update(1 / 60, pieces)

    assert(pieceB.state == "held", "pieceB should still be held when target slot is occupied")
    assert(player.held_piece == pieceB, "player.held_piece should remain pieceB when drop is blocked")
    assert(pieceA.sprite.x == 384 and pieceA.sprite.y == 192, "pieceA's slot should be undisturbed")
    print("PASS: overlap check (via real Player code path): occupied slot detected, drop blocked")
end

-- Player:drop_target() snap math -------------------------------------------

do
    -- Player position already grid-aligned: the raw target itself lands on a
    -- SLOT multiple, so snap_x/snap_y should equal x/y exactly. (Note: with
    -- the 64x64 sprite, centre()'s +32 offset exactly cancels drop_target()'s
    -- -C.U (-32) offset, so target x/y now equal the sprite position itself.)
    local Player = require("game/player")
    local player = Player.new(128, 192)
    local dt = player:drop_target()
    assert(dt.x == 128, "drop_target().x should be 128, got " .. tostring(dt.x))
    assert(dt.y == 192, "drop_target().y should be 192, got " .. tostring(dt.y))
    assert(dt.snap_x == 128, "drop_target().snap_x should be 128 (already aligned), got " .. tostring(dt.snap_x))
    assert(dt.snap_y == 192, "drop_target().snap_y should be 192 (already aligned), got " .. tostring(dt.snap_y))
    print("PASS: player: drop_target() returns x/y == snap_x/snap_y when already grid-aligned")
end

do
    -- Player position not grid-aligned: snap_x/snap_y should floor to the
    -- nearest C.SLOT multiple, distinct from the raw target x/y. (centre()'s
    -- +32 offset cancels drop_target()'s -32 U offset, so target x/y equal
    -- the sprite position itself: 300, 170.)
    local Player = require("game/player")
    local player = Player.new(300, 170)
    local dt = player:drop_target()
    assert(dt.x == 300, "drop_target().x should be 300, got " .. tostring(dt.x))
    assert(dt.y == 170, "drop_target().y should be 170, got " .. tostring(dt.y))
    assert(dt.snap_x == 320, "drop_target().snap_x should snap to 320 (5*SLOT), got " .. tostring(dt.snap_x))
    assert(dt.snap_y == 192, "drop_target().snap_y should snap to 192 (3*SLOT), got " .. tostring(dt.snap_y))
    print("PASS: player: drop_target() floors an unaligned position to the nearest SLOT multiple")
end

-- interact-drop still lands the piece at Player:drop_target()'s snap values
-- (regression check that Task A's extraction didn't change drop behavior) --

do
    local Player        = require("game/player")
    local HeadlessInput = require("lua/headless/input")

    local player = Player.new(300, 170)
    player.input = HeadlessInput.new()

    local p = JigsawPiece.new(0, {1, 0, 0, 1})
    p:pick_up()
    player.held_piece = p

    local dt = player:drop_target()

    player.input:press("interact")
    player:update(1 / 60, {})

    assert(p.state == "grounded", "piece should be grounded after drop")
    assert(p.sprite.x == dt.snap_x,
        "dropped piece x should match drop_target().snap_x (" .. dt.snap_x .. "), got " .. tostring(p.sprite.x))
    assert(p.sprite.y == dt.snap_y,
        "dropped piece y should match drop_target().snap_y (" .. dt.snap_y .. "), got " .. tostring(p.sprite.y))
    print("PASS: player: interact-drop lands the piece at exactly Player:drop_target()'s snap_x/snap_y")
end

-- occupied-slot rejection is still keyed off Player:drop_target()'s values -

do
    local Player        = require("game/player")
    local HeadlessInput = require("lua/headless/input")

    local player = Player.new(300, 170)
    player.input = HeadlessInput.new()

    local pieceB = JigsawPiece.new(0, {0, 0, 1, 1})
    pieceB:pick_up()
    player.held_piece = pieceB

    local dt = player:drop_target()
    -- pieceA occupies exactly the slot drop_target() would land pieceB on.
    local pieceA = JigsawPiece.new(dt.snap_x, {1, 0, 0, 1})
    pieceA.sprite.y = dt.snap_y

    local pieces = { pieceA, pieceB }
    player.input:press("interact")
    player:update(1 / 60, pieces)

    assert(pieceB.state == "held", "pieceB should still be held when its drop_target() slot is occupied")
    assert(player.held_piece == pieceB, "player.held_piece should remain pieceB when drop is blocked")
    assert(pieceA.sprite.x == dt.snap_x and pieceA.sprite.y == dt.snap_y,
        "pieceA's slot should be undisturbed")
    print("PASS: player: occupied-slot rejection is still keyed off Player:drop_target()'s snap values")
end

-- JigsawBox ---------------------------------------------------------------
local JigsawBox = require("game/jigsaw_box")

-- Helper: constructs a JigsawBox guaranteed to resolve to a 3x3 (9-piece)
-- grid, regardless of which images PuzzleCatalog.list() happens to contain or
-- which one math.random selects, by forcing love.graphics.newImage to report
-- an easy/ path for the duration of construction (the headless stub's
-- path-aware make_stub_image then reports 192x192, so grid inference lands
-- on 3x3/9 pieces). Used below by tests that exercise ejection timing/order/
-- slot-search/slicing mechanics unrelated to catalog size, so they don't
-- depend on which image math.random happens to pick.
local function new_easy_box(...)
    local real_newImage = love.graphics.newImage
    love.graphics.newImage = function(path, ...)
        return real_newImage("assets/puzzles/easy/1.png", ...)
    end
    local box = JigsawBox.new(...)
    love.graphics.newImage = real_newImage
    return box
end

-- JigsawBox.new -----------------------------------------------------------

do
    GameState:reset()
    local box = new_easy_box(128, 128)
    assert(box.state == "waiting",       "new box should be in state 'waiting'")
    assert(#box.pieces_to_spawn == 9,    "new box should have 9 items in pieces_to_spawn (3x3 grid)")
    assert(box.rows == 3,         "box.rows should be inferred as 3 for a 192px-tall image, got " .. tostring(box.rows))
    assert(box.cols == 3,         "box.cols should be inferred as 3 for a 192px-wide image, got " .. tostring(box.cols))
    assert(box.piece_count == 9,  "box.piece_count should be rows*cols == 9, got " .. tostring(box.piece_count))
    print("PASS: jigsaw_box: new() creates box in state 'waiting' with 9 pieces queued")
end

-- JigsawBox.new stores the loaded puzzle image ----------------------------

do
    GameState:reset()
    local box = new_easy_box(128, 128)
    assert(box.image ~= nil, "box.image should be set to the loaded puzzle image after JigsawBox.new()")
    print("PASS: jigsaw_box: new() stores the loaded puzzle image on self.image")
end

-- interact() --------------------------------------------------------------

do
    GameState:reset()
    local box = JigsawBox.new(128, 128)
    box:interact()
    assert(box.state == "ejecting", "state should be 'ejecting' after interact()")
    assert(box.spawn_timer <= 0,    "spawn_timer should be <= 0 after interact()")
    print("PASS: jigsaw_box: interact() transitions to 'ejecting' and sets spawn_timer <= 0")
end

-- update() ejects one piece per call -------------------------------------

do
    GameState:reset()
    local box = JigsawBox.new(128, 128, 2000, 2000)
    local pieces = {}
    box:interact()
    box:update(1.0, pieces)
    assert(#pieces == 1,              "one piece should be ejected after first update")
    assert(box.state == "ejecting",   "state should still be 'ejecting' with 8 pieces remaining")
    print("PASS: jigsaw_box: update() ejects one piece per large-dt call, state stays 'ejecting'")
end

-- update() x9 ejects all pieces, state becomes done ----------------------

do
    GameState:reset()
    local box = new_easy_box(128, 128, 2000, 2000)
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
    GameState:reset()
    local box = JigsawBox.new(128, 192, 2000, 2000)
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

-- interact() hides the box sprite immediately ------------------------------

do
    GameState:reset()
    local box = JigsawBox.new(128, 128, 2000, 2000)
    assert(box.sprite.visible == true, "box sprite should be visible before interact()")
    box:interact()
    assert(box.sprite.visible == false, "box sprite should be hidden immediately after interact()")
    assert(box.state == "ejecting", "state should be 'ejecting' (not 'done') right after interact()")
    print("PASS: jigsaw_box: interact() hides the box sprite immediately, before ejection finishes")
end

-- background ejection is unaffected by the box's early disappearance ------

do
    GameState:reset()
    local box = new_easy_box(128, 128, 2000, 2000)
    local pieces = {}
    box:interact()
    for i = 1, 9 do
        box:update(1.0, pieces)
        assert(box.sprite.visible == false,
            "box sprite should stay hidden through update " .. i .. " of 9")
    end
    assert(#pieces == 9,        "nine pieces should be ejected after nine updates")
    assert(box.state == "done", "state should be 'done' only once all 9 pieces are ejected")
    print("PASS: jigsaw_box: box stays hidden while background ejection proceeds exactly as before")
end

-- _eject_next respects world bounds near an edge ---------------------------

do
    GameState:reset()
    local world_w, world_h = 4 * C.SLOT, 4 * C.SLOT
    local box = new_easy_box(0, 0, world_w, world_h)
    local pieces = {}
    box:interact()
    for i = 1, 9 do
        box:update(1.0, pieces)
    end
    assert(box.state == "done", "state should be 'done' after nine updates even near a world edge")
    for i, p in ipairs(pieces) do
        assert(p.sprite.x >= 0 and p.sprite.x < world_w,
            "piece " .. i .. " sprite.x=" .. tostring(p.sprite.x) .. " should be within [0, world_w)")
        assert(p.sprite.y >= 0 and p.sprite.y < world_h,
            "piece " .. i .. " sprite.y=" .. tostring(p.sprite.y) .. " should be within [0, world_h)")
    end
    print("PASS: jigsaw_box: _eject_next keeps ejected pieces within world bounds near an edge")
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

    GameState:reset()
    local box = new_easy_box(0, 0)
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
        -- Reset before every trial (not just once before the loop): each
        -- trial performs a real JigsawBox.new() construction that consumes
        -- one entry from the unseen pool, and the on-disk catalog only has
        -- 5 images total, so without a per-trial reset the pool would be
        -- exhausted well before all 8 trials complete and JigsawBox.new
        -- would start returning nil.
        GameState:reset()
        local cell_of = {}
        love.graphics.newQuad = function(qx, qy, qw, qh, imgW, imgH)
            local quad = real_newQuad(qx, qy, qw, qh, imgW, imgH)
            local col = math.floor(qx / qw + 0.5)
            local row = math.floor(qy / qh + 0.5)
            cell_of[quad] = col .. "," .. row
            return quad
        end
        local box = new_easy_box(0, 0)
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
        -- Reset before every trial: this test only cares about sampling
        -- rotation variety, not image selection, and the on-disk catalog
        -- has just 5 images, so a full pool must be guaranteed for all 12
        -- trials or JigsawBox.new would return nil partway through.
        GameState:reset()
        local box = JigsawBox.new(128, 128, 2000, 2000)
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
    GameState:reset()
    local box = JigsawBox.new(128, 128, 2000, 2000)
    box:interact()
    local pieces = {}
    box:update(1.0, pieces)
    local piece = pieces[1]
    assert(piece.sprite.image ~= nil, "ejected piece's sprite.image should be non-nil")
    assert(piece.sprite.quad  ~= nil, "ejected piece's sprite.quad should be non-nil")
    print("PASS: jigsaw_box: ejected piece's sprite carries non-nil image and quad (visual wiring)")
end

-- JigsawBox.new randomly selects one of the catalog's puzzle images --------

do
    -- Spy on love.graphics.newImage for the duration of several JigsawBox.new()
    -- calls, following the same spy-and-restore pattern used above for
    -- love.graphics.newQuad, to capture which path each construction loads.
    local expected_paths = {}
    for _, path in ipairs(PuzzleCatalog.list()) do
        expected_paths[path] = true
    end

    -- Under the no-repeat contract, a full unseen-pool cycle can only
    -- produce #PuzzleCatalog.list() distinct successful constructions
    -- (currently 5) before JigsawBox.new starts returning nil, so the trial
    -- count is derived from the catalog size rather than a fixed literal.
    GameState:reset()
    local trial_count = #PuzzleCatalog.list()

    local real_newImage = love.graphics.newImage
    local captured_paths = {}
    love.graphics.newImage = function(path, ...)
        captured_paths[#captured_paths + 1] = path
        return real_newImage(path, ...)
    end

    for trial = 1, trial_count do
        JigsawBox.new(128, 128)
    end

    love.graphics.newImage = real_newImage

    assert(#captured_paths == trial_count,
        "expected " .. trial_count .. " captured love.graphics.newImage calls, got " .. #captured_paths)
    for i, path in ipairs(captured_paths) do
        assert(expected_paths[path],
            "captured path #" .. i .. " (" .. tostring(path) ..
            ") should be one of the catalog's expected puzzle images")
    end
    print("PASS: jigsaw_box: new() always loads one of the catalog's expected puzzle images")

    -- No-repeat check: under the new seen-tracking contract, duplicates
    -- across a single unseen-pool cycle are structurally impossible (not
    -- just statistically unlikely), so this replaces the old "variety
    -- across trials" probabilistic check.
    local seen_paths = {}
    for i, path in ipairs(captured_paths) do
        assert(not seen_paths[path],
            "path " .. tostring(path) .. " (captured trial #" .. i .. ") repeated across trials -- " ..
            "the no-repeat contract requires each unseen path to be picked at most once per cycle")
        seen_paths[path] = true
    end
    print("PASS: jigsaw_box: new() never repeats a puzzle image within a single unseen-pool cycle")

    -- Pool is now fully exhausted (every catalog path has been seen): the
    -- next construction attempt must signal exhaustion by returning nil.
    local exhausted_box = JigsawBox.new(128, 128)
    assert(exhausted_box == nil,
        "JigsawBox.new() should return nil once every catalog image has been seen")
    print("PASS: jigsaw_box: new() returns nil once the unseen pool across all tiers is exhausted")
end

-- JigsawBox.new selects flat-uniformly across the whole catalog, not -------
-- weighted by tier (today's catalog is 3 easy + 1 med + 1 hard == 5 images;
-- a broken per-tier-then-per-image scheme would give the med and hard images
-- each ~33% per trial instead of the correct flat ~20%) --------------------

do
    -- Under the no-repeat contract, both a per-tier-proportional scheme and
    -- a naive per-tier-first scheme reach full catalog coverage once repeats
    -- are disallowed, so a pure "was every image hit" coverage check can no
    -- longer distinguish flat-uniform weighting from per-tier weighting on
    -- its own. This test now primarily guards the no-repeat/exhaustion-
    -- after-N-calls contract: exactly #PuzzleCatalog.list() constructions
    -- succeed, each catalog path appears exactly once, and the call after
    -- that returns nil.
    GameState:reset()

    local real_newImage = love.graphics.newImage
    local captured_paths = {}
    love.graphics.newImage = function(path, ...)
        captured_paths[#captured_paths + 1] = path
        return real_newImage(path, ...)
    end

    repeat
        local box = JigsawBox.new(128, 128)
    until box == nil

    love.graphics.newImage = real_newImage

    local catalog_paths = PuzzleCatalog.list()
    assert(#captured_paths == #catalog_paths,
        "expected number of successful constructions to equal catalog size (" ..
        #catalog_paths .. "), got " .. #captured_paths)

    local count_of = {}
    for _, path in ipairs(captured_paths) do
        count_of[path] = (count_of[path] or 0) + 1
    end
    for _, path in ipairs(catalog_paths) do
        assert(count_of[path] == 1,
            "expected catalog path " .. path .. " to appear exactly once across captured paths, got " ..
            tostring(count_of[path] or 0))
    end
    print("PASS: jigsaw_box: new() covers the whole catalog exactly once each, then returns nil (no-repeat/exhaustion contract)")
end

-- grid inference for non-3x3 catalog images (med/hard) ---------------------
-- Uses a bounded-retry loop (mirroring the bounded slot search in
-- game/jigsaw_box.lua's _eject_next) to reliably land on a med/ image, since
-- math.random selection alone can't guarantee which tier's image a single
-- JigsawBox.new() call will pick.

do
    GameState:reset()
    local real_newImage = love.graphics.newImage
    local last_path = nil
    love.graphics.newImage = function(path, ...)
        last_path = path
        return real_newImage(path, ...)
    end

    local box, found = nil, false
    for _ = 1, 200 do
        box = JigsawBox.new(0, 0)
        if not box then break end
        if last_path:find("/med/", 1, true) then
            found = true
            break
        end
    end

    love.graphics.newImage = real_newImage

    assert(found, "expected at least one of 200 JigsawBox.new() trials to pick a med/ image")
    assert(box.cols == 4, "box.cols should be inferred as 4 for a 256px-wide med image, got " .. tostring(box.cols))
    assert(box.rows == 4, "box.rows should be inferred as 4 for a 256px-tall med image, got " .. tostring(box.rows))
    assert(box.piece_count == 16, "box.piece_count should be rows*cols == 16, got " .. tostring(box.piece_count))
    print("PASS: jigsaw_box: grid inference for a med/ (256x256) image yields cols=4, rows=4, piece_count=16")
end

do
    GameState:reset()
    local real_newImage = love.graphics.newImage
    local last_path = nil
    love.graphics.newImage = function(path, ...)
        last_path = path
        return real_newImage(path, ...)
    end

    local box, found = nil, false
    for _ = 1, 200 do
        box = JigsawBox.new(0, 0)
        if not box then break end
        if last_path:find("/hard/", 1, true) then
            found = true
            break
        end
    end

    love.graphics.newImage = real_newImage

    assert(found, "expected at least one of 200 JigsawBox.new() trials to pick a hard/ image")
    assert(box.cols == 5, "box.cols should be inferred as 5 for a 320px-wide hard image, got " .. tostring(box.cols))
    assert(box.rows == 5, "box.rows should be inferred as 5 for a 320px-tall hard image, got " .. tostring(box.rows))
    assert(box.piece_count == 25, "box.piece_count should be rows*cols == 25, got " .. tostring(box.piece_count))
    print("PASS: jigsaw_box: grid inference for a hard/ (320x320) image yields cols=5, rows=5, piece_count=25")
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
    local player = Player.new(0, 192)
    player.input = HeadlessInput.new()

    player.input:press("interact")
    player:update(1 / 60, pieces, nil, nil, drawer)

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
    player:update(1 / 60, pieces, nil, nil, drawer)

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

-- Player:draw() draws the ghost preview behind the player, held piece on top --

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

    assert(#call_order == 3,
        "ghost preview, player sprite, and held piece sprite should all draw, got " .. #call_order .. " calls")
    assert(call_order[1] == "piece",
        "ghost preview (piece sprite) should draw first, behind the player, got " .. tostring(call_order[1]))
    assert(call_order[2] == "player",
        "player's own sprite should draw second, on top of the ghost, got " .. tostring(call_order[2]))
    assert(call_order[3] == "piece",
        "held piece's sprite should draw third, on top of the player, got " .. tostring(call_order[3]))
    print("PASS: player: draw() draws the ghost preview behind the player, then the held piece's sprite on top")
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

-- draw_ghost() draws at the given position/alpha then restores real state --

do
    local p = JigsawPiece.new(384, {1, 0, 0, 1})
    p:pick_up()
    p:rotate()  -- rotation_step = 1, to prove ghost draw doesn't disturb rotation state either

    local before_x     = p.sprite.x
    local before_y      = p.sprite.y
    local before_alpha  = p.sprite.color[4]
    local before_state  = p.state
    local before_rot    = p.rotation_step

    local captured = nil
    local orig_draw = p.sprite.draw
    p.sprite.draw = function(self)
        captured = { x = self.x, y = self.y, alpha = self.color[4] }
        return orig_draw(self)
    end

    p:draw_ghost(500, 700, 0.2)

    p.sprite.draw = orig_draw

    assert(captured ~= nil, "draw_ghost() should draw the sprite")
    assert(captured.x == 500, "ghost draw should use given x, got " .. tostring(captured.x))
    assert(captured.y == 700, "ghost draw should use given y, got " .. tostring(captured.y))
    assert(captured.alpha == 0.2, "ghost draw should use given alpha, got " .. tostring(captured.alpha))

    assert(p.sprite.x == before_x, "sprite.x should be restored after draw_ghost()")
    assert(p.sprite.y == before_y, "sprite.y should be restored after draw_ghost()")
    assert(p.sprite.color[4] == before_alpha, "sprite.color[4] should be restored after draw_ghost()")
    assert(p.state == before_state, "state should be unchanged by draw_ghost()")
    assert(p.rotation_step == before_rot, "rotation_step should be unchanged by draw_ghost()")
    print("PASS: jigsaw_piece: draw_ghost() draws at given position/alpha then restores real state")
end

-- draw_ghost() defaults alpha to 0.35 when omitted -------------------------

do
    local p = JigsawPiece.new(0, {1, 0, 0, 1})
    local captured_alpha = nil
    local orig_draw = p.sprite.draw
    p.sprite.draw = function(self)
        captured_alpha = self.color[4]
        return orig_draw(self)
    end

    p:draw_ghost(100, 100)

    p.sprite.draw = orig_draw

    assert(captured_alpha == 0.35, "draw_ghost() with no alpha arg should default to 0.35, got " .. tostring(captured_alpha))
    print("PASS: jigsaw_piece: draw_ghost() defaults alpha to 0.35 when omitted")
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

    GameState:reset()
    local box = new_easy_box(0, 0)
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

-- Builds an array of 9 fake piece tables uniformly rotated by k steps
-- (k in 1..3), arranged correctly relative to each other under that
-- rotation's grid mapping (JigsawSolver.rotate_cell), offset by (ox, oy)
-- slots from the world origin.
local function build_rotated_assembled_pieces(k, ox, oy)
    local pieces = {}
    for row = 0, 2 do
        for col = 0, 2 do
            local gx, gy = JigsawSolver.rotate_cell(row, col, k)
            pieces[#pieces + 1] = {
                rotation_step = k,
                row = row,
                col = col,
                sprite = { x = (gx + ox) * C.SLOT, y = (gy + oy) * C.SLOT },
            }
        end
    end
    return pieces
end

do
    local pieces = build_assembled_pieces(0, 0)
    table.remove(pieces)  -- drop to 8 well-formed pieces
    assert(JigsawSolver.is_assembled(pieces, 9) == false,
        "is_assembled should be false for fewer than the expected piece count")
    print("PASS: jigsaw_solver: is_assembled() is false with fewer than 9 pieces")
end

do
    -- Piece 1 disagrees with the rest of the grid on rotation_step (1 vs 0).
    -- A puzzle where all pieces share one non-zero rotation_step is now a
    -- valid solve (see rotated cases below) -- what must still fail is
    -- pieces *disagreeing* on rotation.
    local pieces = build_assembled_pieces(0, 0)
    pieces[1].rotation_step = 1
    assert(JigsawSolver.is_assembled(pieces, 9) == false,
        "is_assembled should be false when pieces disagree on rotation_step")
    print("PASS: jigsaw_solver: is_assembled() is false when pieces disagree on rotation_step")
end

do
    for k = 1, 3 do
        local pieces = build_rotated_assembled_pieces(k, 0, 0)
        assert(JigsawSolver.is_assembled(pieces, 9) == true,
            "is_assembled should be true for a puzzle uniformly rotated to rotation_step=" .. k ..
            " and arranged per that rotation's grid mapping")
    end
    print("PASS: jigsaw_solver: is_assembled() is true when the whole puzzle is solved rotated as a rigid unit (k=1,2,3)")
end

do
    for k = 1, 3 do
        -- Every piece shares rotation_step=k, but positions are laid out
        -- with the *unrotated* (k=0) mapping -- rotation and layout disagree.
        local pieces = build_assembled_pieces(0, 0)
        for _, piece in ipairs(pieces) do
            piece.rotation_step = k
        end
        assert(JigsawSolver.is_assembled(pieces, 9) == false,
            "is_assembled should be false when rotation_step=" .. k ..
            " but the layout still uses the unrotated grid mapping")
    end
    print("PASS: jigsaw_solver: is_assembled() is false when a shared rotation_step and the layout mapping disagree")
end

do
    -- Swap two pieces' sprite positions so their (row, col) identities no
    -- longer match their placement, while rotation stays correct and the
    -- count stays at 9 -- the relative arrangement is now wrong.
    local pieces = build_assembled_pieces(0, 0)
    local ax, ay = pieces[1].sprite.x, pieces[1].sprite.y
    pieces[1].sprite.x, pieces[1].sprite.y = pieces[2].sprite.x, pieces[2].sprite.y
    pieces[2].sprite.x, pieces[2].sprite.y = ax, ay
    assert(JigsawSolver.is_assembled(pieces, 9) == false,
        "is_assembled should be false when the relative arrangement is wrong")
    print("PASS: jigsaw_solver: is_assembled() is false when two pieces' positions are swapped")
end

do
    -- Same swap check, but at a shared non-zero rotation_step -- rotation-
    -- aware position comparison must still catch swapped pieces.
    local pieces = build_rotated_assembled_pieces(1, 0, 0)
    local ax, ay = pieces[1].sprite.x, pieces[1].sprite.y
    pieces[1].sprite.x, pieces[1].sprite.y = pieces[2].sprite.x, pieces[2].sprite.y
    pieces[2].sprite.x, pieces[2].sprite.y = ax, ay
    assert(JigsawSolver.is_assembled(pieces, 9) == false,
        "is_assembled should be false when two pieces' positions are swapped, even under a shared rotation_step")
    print("PASS: jigsaw_solver: is_assembled() is false when two pieces' positions are swapped under rotation_step=1")
end

do
    local pieces_origin  = build_assembled_pieces(0, 0)
    local pieces_shifted = build_assembled_pieces(3, 3)
    assert(JigsawSolver.is_assembled(pieces_origin, 9) == true,
        "is_assembled should be true for a correctly arranged puzzle at the world origin")
    assert(JigsawSolver.is_assembled(pieces_shifted, 9) == true,
        "is_assembled should be true for a correctly arranged puzzle shifted by a constant offset")
    print("PASS: jigsaw_solver: is_assembled() is true regardless of the puzzle's absolute world position")
end

do
    -- Same offset-invariance check, but at a shared non-zero rotation_step --
    -- the puzzle's absolute world position must still be irrelevant once
    -- rotated as a rigid unit.
    local pieces_origin  = build_rotated_assembled_pieces(1, 0, 0)
    local pieces_shifted = build_rotated_assembled_pieces(1, 3, 3)
    assert(JigsawSolver.is_assembled(pieces_origin, 9) == true,
        "is_assembled should be true for a rotated puzzle at the world origin")
    assert(JigsawSolver.is_assembled(pieces_shifted, 9) == true,
        "is_assembled should be true for a rotated puzzle shifted by a constant offset")
    print("PASS: jigsaw_solver: is_assembled() is true regardless of world position for a rotated (rotation_step=1) puzzle")
end

-- integration: assembling the puzzle vanishes pieces, then removes them ---
-- from both gs.pieces and the Drawer once their fade completes (GameScene) -
-- Note: solving-while-rotated (a uniform rotation_step of 1/2/3) is covered
-- at the unit level above; the integration tests below stay at
-- rotation_step = 0 throughout and are not duplicated per rotation step.

do
    GameState:reset()
    local GameScene = require("game/scenes/game_scene")

    local gs = GameScene.new()
    gs:on_enter()

    -- Replace whatever the box set up in on_enter() with 9 correctly
    -- arranged, unrotated pieces so JigsawSolver.is_assembled(entry.pieces,
    -- entry.piece_count) is true as soon as gs:update()'s solved-check runs.
    -- Since this bypasses a real JigsawBox/_spawn_box, also seed a matching
    -- active_puzzles entry so the per-entry loop in GameScene:update has
    -- something to evaluate.
    gs.pieces = {}
    gs.pieces_in_drawer = {}
    gs.active_puzzles = {}
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
    assert(#gs.pieces == 9, "test setup should have 9 pieces before update()")

    local entry = { pieces = spawned, piece_count = 9, solved = false }
    gs.active_puzzles[#gs.active_puzzles + 1] = entry

    -- First update(): the one-shot solved check fires (assembled == true),
    -- start_vanish() runs on every piece, and the same call already drives
    -- one small update_fade() tick on each piece since it's now "vanishing".
    gs:update(1 / 60)

    assert(entry.solved == true, "active_puzzles entry.solved should be set true once the arrangement is detected")
    assert(GameState.solved_count == 1,
        "GameState.solved_count should increase by 1 the instant entry.solved flips to true, got " .. GameState.solved_count)
    for _, p in ipairs(spawned) do
        assert(p.state == "vanishing", "every piece should be in the 'vanishing' state after the solved check fires")
    end
    assert(#gs.pieces == 9,
        "pieces should not be removed yet after only one small fade tick")
    local found_entry = false
    for _, e in ipairs(gs.active_puzzles) do
        if e == entry then found_entry = true end
    end
    assert(found_entry, "active_puzzles entry should not be pruned yet, before pieces finish fading")

    -- Drive enough more time for the fade to fully complete.
    gs:update(C.PIECE_FADE_DURATION)

    assert(GameState.solved_count == 1,
        "GameState.solved_count should not increase again on later fade-out frames, got " .. GameState.solved_count)
    assert(#gs.pieces == 0,
        "all pieces should be removed from gs.pieces once their fade completes, got " .. #gs.pieces)
    for _, p in ipairs(spawned) do
        assert(gs.pieces_in_drawer[p] == nil, "vanished piece should be cleared from pieces_in_drawer")
        local found_in_drawer = false
        for _, entry2 in ipairs(gs.drawer.layers) do
            if entry2.sprite == p then found_in_drawer = true end
        end
        assert(not found_in_drawer, "vanished piece should no longer appear in the Drawer's layers")
    end
    local still_present = false
    for _, e in ipairs(gs.active_puzzles) do
        if e == entry then still_present = true end
    end
    assert(not still_present,
        "active_puzzles entry should be pruned once solved and all its pieces have fully faded")
    print("PASS: game_scene: assembling the puzzle fades out and removes all pieces from gs.pieces and the Drawer, and prunes the active_puzzles entry")
end

-- integration: two differently-sized puzzles solve/vanish independently ----
-- via separate active_puzzles entries (the scenario per-box completion -----
-- tracking exists for -- see docs/design/infer-puzzle-size.md) -------------

do
    GameState:reset()
    local GameScene = require("game/scenes/game_scene")

    local gs = GameScene.new()
    gs:on_enter()

    gs.pieces = {}
    gs.pieces_in_drawer = {}
    gs.active_puzzles = {}

    -- Puzzle A: a correctly-arranged 3x3 (9-piece) puzzle at the world origin.
    local spawned_a = {}
    for row = 0, 2 do
        for col = 0, 2 do
            local p = JigsawPiece.new(col * C.SLOT, {1, 1, 1, 1},
                { image = {}, quad = {}, row = row, col = col })
            p.sprite.y = row * C.SLOT
            gs.pieces[#gs.pieces + 1] = p
            spawned_a[#spawned_a + 1] = p
            gs.drawer:add(p, C.PRIORITY_PIECE)
            gs.pieces_in_drawer[p] = true
        end
    end
    local entry_a = { pieces = spawned_a, piece_count = 9, solved = false }
    gs.active_puzzles[#gs.active_puzzles + 1] = entry_a

    -- Puzzle B: a 2x2 (4-piece) puzzle, offset well clear of puzzle A, but
    -- deliberately NOT correctly arranged yet (one piece is rotated), so it
    -- should stay unsolved while puzzle A completes.
    local OX, OY = 10, 10  -- slot offset, clear of puzzle A's 0..2 range
    local spawned_b = {}
    for row = 0, 1 do
        for col = 0, 1 do
            local p = JigsawPiece.new((col + OX) * C.SLOT, {0, 1, 1, 1},
                { image = {}, quad = {}, row = row, col = col })
            p.sprite.y = (row + OY) * C.SLOT
            gs.pieces[#gs.pieces + 1] = p
            spawned_b[#spawned_b + 1] = p
            gs.drawer:add(p, C.PRIORITY_PIECE)
            gs.pieces_in_drawer[p] = true
        end
    end
    spawned_b[4].rotation_step = 1  -- misarranged: not assembled yet
    local entry_b = { pieces = spawned_b, piece_count = 4, solved = false }
    gs.active_puzzles[#gs.active_puzzles + 1] = entry_b

    -- First update(): puzzle A (correctly arranged, 9 pieces) should solve
    -- and start vanishing even though puzzle B's 4 pieces are also on the
    -- field (gs.pieces totals 13) -- neither a stale global count nor
    -- puzzle B's presence should block puzzle A's own per-entry check.
    gs:update(1 / 60)

    assert(entry_a.solved == true, "puzzle A should solve independently of puzzle B's pieces being present")
    assert(entry_b.solved == false, "puzzle B should remain unsolved since it isn't correctly arranged")
    assert(GameState.solved_count == 1,
        "GameState.solved_count should increase by 1 the instant puzzle A's entry.solved flips to true, got " .. GameState.solved_count)
    for _, p in ipairs(spawned_a) do
        assert(p.state == "vanishing", "puzzle A's pieces should start vanishing once solved")
    end
    for _, p in ipairs(spawned_b) do
        assert(p.state == "grounded", "puzzle B's pieces should be untouched while unsolved")
    end

    -- Drive time forward so puzzle A's pieces fully fade and its
    -- active_puzzles entry gets pruned -- puzzle B must be unaffected.
    gs:update(C.PIECE_FADE_DURATION)

    assert(GameState.solved_count == 1,
        "GameState.solved_count should not increase again while puzzle A's pieces are only fading, got " .. GameState.solved_count)

    local a_present = false
    for _, e in ipairs(gs.active_puzzles) do
        if e == entry_a then a_present = true end
    end
    assert(not a_present, "puzzle A's active_puzzles entry should be pruned once fully faded")

    local b_present = false
    for _, e in ipairs(gs.active_puzzles) do
        if e == entry_b then b_present = true end
    end
    assert(b_present, "puzzle B's active_puzzles entry should still be present and untouched")
    assert(entry_b.solved == false, "puzzle B should still be unsolved after puzzle A's cleanup")

    -- Now fix puzzle B's arrangement (undo the rotation) and confirm it
    -- registers as solved on its own, on a later frame, with puzzle A's
    -- pieces already gone from the field -- proves puzzle A's absence
    -- doesn't block puzzle B either.
    spawned_b[4].rotation_step = 0

    gs:update(1 / 60)

    assert(entry_b.solved == true,
        "puzzle B should solve independently once correctly arranged, after puzzle A already vanished")
    assert(GameState.solved_count == 2,
        "GameState.solved_count should increase by 1 again the instant puzzle B's entry.solved flips to true, got " .. GameState.solved_count)
    for _, p in ipairs(spawned_b) do
        assert(p.state == "vanishing", "puzzle B's pieces should start vanishing once solved")
    end
    print("PASS: game_scene: two differently-sized puzzles solve and vanish independently via active_puzzles")
end

-- integration: active_puzzles entries carry image/cols/rows from the box ---
-- that spawned them (on_enter() and _spawn_box() both build these entries) -

do
    GameState:reset()
    local GameScene = require("game/scenes/game_scene")

    local gs = GameScene.new()
    gs:on_enter()

    assert(#gs.boxes == 1, "on_enter() should spawn one box when under the active-puzzle cap")
    local box = gs.boxes[1]
    local entry = gs.active_puzzles[1]
    assert(entry ~= nil, "on_enter() should record an active_puzzles entry for the spawned box")
    assert(entry.image ~= nil, "active_puzzles entry.image should be non-nil")
    assert(entry.image == box.image, "active_puzzles entry.image should match the spawned box's image")
    assert(entry.cols == box.cols,
        "active_puzzles entry.cols should match box.cols, got " .. tostring(entry.cols) .. " vs " .. tostring(box.cols))
    assert(entry.rows == box.rows,
        "active_puzzles entry.rows should match box.rows, got " .. tostring(entry.rows) .. " vs " .. tostring(box.rows))

    -- _spawn_box() builds its active_puzzles entry the same way -- confirm
    -- a second, manually-triggered spawn also carries image/cols/rows.
    gs:_spawn_box()
    local entry2 = gs.active_puzzles[2]
    if entry2 then
        local box2 = gs.boxes[2]
        assert(entry2.image ~= nil, "_spawn_box()'s active_puzzles entry.image should be non-nil")
        assert(entry2.image == box2.image, "_spawn_box()'s active_puzzles entry.image should match its box's image")
        assert(entry2.cols == box2.cols, "_spawn_box()'s active_puzzles entry.cols should match its box's cols")
        assert(entry2.rows == box2.rows, "_spawn_box()'s active_puzzles entry.rows should match its box's rows")
    end
    print("PASS: game_scene: active_puzzles entries from on_enter() and _spawn_box() carry image/cols/rows matching their box")
end

-- integration: a fully-faded solved puzzle is shelved onto completed_puzzles
-- at the deterministic left-to-right slot position (trophy shelf) ----------

do
    GameState:reset()
    local GameScene = require("game/scenes/game_scene")

    local gs = GameScene.new()
    gs:on_enter()

    -- Bypass the real box/spawn path, same technique as the earlier
    -- "assembling the puzzle" integration tests, but this time seed the
    -- active_puzzles entry with image/cols/rows so the shelving logic in
    -- update()'s fade-prune loop has something to work with.
    gs.pieces = {}
    gs.pieces_in_drawer = {}
    gs.active_puzzles = {}
    gs.completed_puzzles = {}

    local puzzle_image = {}  -- stand-in for a love.graphics.Image; only its identity matters here
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

    local entry = {
        pieces = spawned,
        piece_count = 9,
        solved = false,
        image = puzzle_image,
        cols = 3,
        rows = 3,
    }
    gs.active_puzzles[#gs.active_puzzles + 1] = entry

    gs:update(1 / 60)
    assert(entry.solved == true, "entry should be solved once the correctly-arranged pieces are detected")

    gs:update(C.PIECE_FADE_DURATION)

    assert(#gs.completed_puzzles == 1,
        "one puzzle should be shelved onto completed_puzzles after fully fading, got " .. #gs.completed_puzzles)
    local shelved = gs.completed_puzzles[1]
    assert(shelved.image == puzzle_image, "shelved entry.image should be the solved puzzle's image")
    assert(shelved.cols == 3 and shelved.rows == 3, "shelved entry should carry the puzzle's cols/rows")
    assert(shelved.y == -(C.SLOT + 3 * C.SLOT),
        "shelved entry.y should be -(SLOT + rows*SLOT), got " .. tostring(shelved.y))
    assert(shelved.x == 0, "the first-ever shelved puzzle should be placed at x = 0, got " .. tostring(shelved.x))

    local found_in_drawer = false
    for _, layer_entry in ipairs(gs.drawer.layers) do
        if layer_entry.sprite == shelved then found_in_drawer = true end
    end
    assert(found_in_drawer, "shelved entry should be added to the drawer so it renders on the trophy shelf")

    -- Solve and fade a second, differently-sized puzzle; it should land to
    -- the right of the first one, offset by the first puzzle's pixel width
    -- plus a fixed C.SLOT gap.
    local spawned_b = {}
    for row = 0, 1 do
        for col = 0, 1 do
            local p = JigsawPiece.new((col + 10) * C.SLOT, {0, 1, 1, 1},
                { image = {}, quad = {}, row = row, col = col })
            p.sprite.y = (row + 10) * C.SLOT
            gs.pieces[#gs.pieces + 1] = p
            spawned_b[#spawned_b + 1] = p
            gs.drawer:add(p, C.PRIORITY_PIECE)
            gs.pieces_in_drawer[p] = true
        end
    end
    local puzzle_image_b = {}
    local entry_b = {
        pieces = spawned_b,
        piece_count = 4,
        solved = false,
        image = puzzle_image_b,
        cols = 2,
        rows = 2,
    }
    gs.active_puzzles[#gs.active_puzzles + 1] = entry_b

    gs:update(1 / 60)
    assert(entry_b.solved == true, "second entry should solve once its pieces are correctly arranged")
    gs:update(C.PIECE_FADE_DURATION)

    assert(#gs.completed_puzzles == 2,
        "a second puzzle should be shelved after fading, got " .. #gs.completed_puzzles)
    local shelved_b = gs.completed_puzzles[2]
    assert(shelved_b.x == shelved.cols * C.SLOT + C.SLOT,
        "second shelved puzzle's x should sit one C.SLOT gap after the first, got " .. tostring(shelved_b.x))
    assert(shelved_b.y == -(C.SLOT + 2 * C.SLOT),
        "second shelved entry.y should be -(SLOT + rows*SLOT) for its own rows, got " .. tostring(shelved_b.y))

    print("PASS: game_scene: fully-faded solved puzzles are shelved onto completed_puzzles at the deterministic left-to-right slot position")
end

-- integration: the trophy shelf wraps to a new row once a row's cumulative
-- width would exceed the world width ----------------------------------------

do
    GameState:reset()
    local GameScene = require("game/scenes/game_scene")

    local gs = GameScene.new()
    gs:on_enter()

    gs.pieces = {}
    gs.pieces_in_drawer = {}
    gs.active_puzzles = {}
    gs.completed_puzzles = {}

    -- Helper: solve and fully fade a synthetic 5x5 (hard-tier-sized) puzzle,
    -- bypassing the real box/spawn path, same technique as the earlier shelf
    -- test. `offset` keeps each puzzle's pieces spatially distinct so the
    -- solver doesn't confuse one puzzle's pieces for another's.
    local function solve_and_fade_5x5(offset)
        local puzzle_image = {}
        local spawned = {}
        for row = 0, 4 do
            for col = 0, 4 do
                local p = JigsawPiece.new((col + offset) * C.SLOT, {1, 1, 1, 1},
                    { image = {}, quad = {}, row = row, col = col })
                p.sprite.y = (row + offset) * C.SLOT
                gs.pieces[#gs.pieces + 1] = p
                spawned[#spawned + 1] = p
                gs.drawer:add(p, C.PRIORITY_PIECE)
                gs.pieces_in_drawer[p] = true
            end
        end
        local entry = {
            pieces = spawned,
            piece_count = 25,
            solved = false,
            image = puzzle_image,
            cols = 5,
            rows = 5,
        }
        gs.active_puzzles[#gs.active_puzzles + 1] = entry
        gs:update(1 / 60)
        assert(entry.solved == true, "synthetic 5x5 entry should solve once correctly arranged")
        gs:update(C.PIECE_FADE_DURATION)
    end

    -- world_w is 1280px; each 5x5 puzzle is 320px wide plus a 64px gap
    -- (384px per slot), so a 4th puzzle in the same row would push
    -- cumulative width to 4*384 = 1536 > 1280 -- it must wrap to a new row.
    for i = 1, 4 do
        solve_and_fade_5x5(i * 20)
    end

    assert(#gs.completed_puzzles == 4, "all four solved puzzles should be shelved, got " .. #gs.completed_puzzles)

    local row0_y = gs.completed_puzzles[1].y
    assert(gs.completed_puzzles[1].x == 0, "1st puzzle should start row 0 at x = 0")
    assert(gs.completed_puzzles[2].x == 5 * C.SLOT + C.SLOT, "2nd puzzle should sit right after the 1st in row 0")
    assert(gs.completed_puzzles[3].x == 2 * (5 * C.SLOT + C.SLOT), "3rd puzzle should sit right after the 2nd in row 0")
    assert(gs.completed_puzzles[2].y == row0_y and gs.completed_puzzles[3].y == row0_y,
        "puzzles sharing a row should share the same y")

    local fourth = gs.completed_puzzles[4]
    assert(fourth.x == 0, "the 4th puzzle should wrap to a new row and reset to x = 0, got " .. tostring(fourth.x))
    assert(fourth.y == row0_y - 5 * C.SLOT - C.SLOT,
        "the wrapped row's y should sit one C.SLOT above the tallest puzzle in the previous row, got " .. tostring(fourth.y))
    assert(fourth.y ~= row0_y, "the wrapped puzzle should not share row 0's y")

    print("PASS: game_scene: trophy shelf wraps to a new row once a row's cumulative width would exceed the world width")
end

-- SpawnButton ---------------------------------------------------------------
local SpawnButton = require("game/spawn_button")

-- interact() invokes on_press exactly once per call --------------------------

do
    local calls = 0
    local button = SpawnButton.new(0, 0, function() calls = calls + 1 end)

    button:interact()
    assert(calls == 1, "on_press should be invoked once after first interact(), got " .. calls)

    button:interact()
    assert(calls == 2, "on_press should be invoked once more after second interact(), got " .. calls)
    print("PASS: spawn_button: interact() invokes on_press exactly once per call")
end

-- centre() --------------------------------------------------------------------

do
    local button = SpawnButton.new(320, 640, function() end)
    local c = button:centre()
    assert(c.x == 320 + C.U, "centre.x should be x + U = " .. (320 + C.U) .. ", got " .. tostring(c.x))
    assert(c.y == 640 + C.U, "centre.y should be y + U = " .. (640 + C.U) .. ", got " .. tostring(c.y))
    print("PASS: spawn_button: centre() returns sprite center")
end

-- GameScene:_spawn_box() ------------------------------------------------------
-- picks grid-aligned, in-bounds, non-colliding cells for new boxes -----------

do
    GameState:reset()
    local GameScene = require("game/scenes/game_scene")

    local gs = GameScene.new()
    gs:on_enter()

    local boxes_before = #gs.boxes
    for _ = 1, 20 do
        gs:_spawn_box()
    end
    -- on_enter() already created 1 box, so only 2 more of these 20 attempts
    -- can succeed before GameState.MAX_ACTIVE_PUZZLES is hit -- once the cap
    -- is reached, _spawn_box()'s "if not GameState:can_start_puzzle() then
    -- return end" guard makes every remaining attempt a silent no-op
    -- regardless of catalog state (5 images is more than enough headroom).
    -- This assertion only requires at least one new box, which still holds.
    assert(#gs.boxes > boxes_before,
        "expected at least one new box to be added across 20 spawn attempts in a mostly-empty world")
    assert(#gs.boxes <= GameState.MAX_ACTIVE_PUZZLES,
        "number of boxes should never exceed GameState.MAX_ACTIVE_PUZZLES, got " .. #gs.boxes)

    local seen = {}
    for _, box in ipairs(gs.boxes) do
        local bx, by = box.sprite.x, box.sprite.y

        assert(bx >= 0 and bx <= gs.world_w - C.SLOT,
            "box x should be within [0, world_w - SLOT], got " .. tostring(bx))
        assert(by >= 0 and by <= gs.world_h - C.SLOT,
            "box y should be within [0, world_h - SLOT], got " .. tostring(by))
        assert(bx % C.SLOT == 0, "box x should be a multiple of C.SLOT, got " .. tostring(bx))
        assert(by % C.SLOT == 0, "box y should be a multiple of C.SLOT, got " .. tostring(by))

        local key = bx .. "," .. by
        assert(seen[key] == nil, "two boxes should not share the same (x, y) position: " .. key)
        seen[key] = true

        assert(not (bx == gs.spawn_button.sprite.x and by == gs.spawn_button.sprite.y),
            "box position should not collide with the spawn button's position")
    end
    print("PASS: game_scene: _spawn_box() places boxes on grid-aligned, in-bounds, non-colliding cells")
end

-- GameScene:_spawn_box() / GameState -----------------------------------------
-- enforces the 3-active-puzzle cap, and a solved puzzle frees a slot --------

do
    GameState:reset()
    local GameScene = require("game/scenes/game_scene")

    local gs = GameScene.new()
    gs:on_enter()  -- 1 active puzzle from the initial box

    local attempts = 0
    while #gs.boxes < GameState.MAX_ACTIVE_PUZZLES and attempts < 20 do
        gs:_spawn_box()
        attempts = attempts + 1
    end

    assert(#gs.boxes == GameState.MAX_ACTIVE_PUZZLES,
        "expected to reach the cap of " .. GameState.MAX_ACTIVE_PUZZLES .. " boxes, got " .. #gs.boxes)
    assert(GameState.active_count == GameState.MAX_ACTIVE_PUZZLES,
        "active_count should equal the cap once " .. GameState.MAX_ACTIVE_PUZZLES .. " boxes are active, got " .. GameState.active_count)
    assert(GameState:can_start_puzzle() == false,
        "can_start_puzzle() should be false once active_count has reached the cap")

    -- One more spawn attempt at the cap should be a silent no-op: no new
    -- box, and GameState.active_count untouched.
    local boxes_at_cap = #gs.boxes
    local active_count_at_cap = GameState.active_count
    gs:_spawn_box()
    assert(#gs.boxes == boxes_at_cap,
        "_spawn_box() at the cap should not add a new box, got " .. #gs.boxes)
    assert(GameState.active_count == active_count_at_cap,
        "_spawn_box() at the cap should not change active_count, got " .. GameState.active_count)

    -- Simulate solving one of the active puzzles, using the same technique
    -- as the "assembling the puzzle" integration test above: replace one
    -- active_puzzles entry's pieces with a correctly-arranged, unrotated set
    -- so JigsawSolver.is_assembled(entry.pieces, entry.piece_count) is true
    -- as soon as gs:update()'s solved-check runs.
    local entry = gs.active_puzzles[1]
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
    entry.pieces = spawned
    entry.piece_count = 9

    gs:update(1 / 60)

    assert(GameState.active_count == GameState.MAX_ACTIVE_PUZZLES - 1,
        "active_count should drop by 1 once a puzzle is detected solved, got " .. GameState.active_count)
    assert(GameState.solved_count == 1,
        "solved_count should increase by 1 once a puzzle is detected solved, got " .. GameState.solved_count)
    assert(GameState:can_start_puzzle() == true,
        "can_start_puzzle() should be true again once a slot has freed up")

    -- A slot is now free, so the next spawn attempt should succeed.
    local boxes_before_new = #gs.boxes
    gs:_spawn_box()
    assert(#gs.boxes == boxes_before_new + 1,
        "a new box should be allowed in once a slot has freed up, got " .. #gs.boxes)
    print("PASS: game_scene: enforces the 3-active-puzzle cap")
end

-- checkerboard floor -----------------------------------------------------
-- GameScene:on_enter() halves the world size and replaces self.ground with
-- self.floor, a plain-table drawable registered in the drawer at priority 0
-- (docs/design/checkerboard-floor.md, docs/checklists/checkerboard-floor.md)

do
    GameState:reset()
    local GameScene = require("game/scenes/game_scene")

    local gs = GameScene.new()
    gs:on_enter()

    assert(gs.world_w == 20 * C.SLOT,
        "world_w should be halved to 20*C.SLOT (1280), got " .. tostring(gs.world_w))
    assert(gs.world_h == 20 * C.SLOT,
        "world_h should be halved to 20*C.SLOT (1280), got " .. tostring(gs.world_h))
    assert(gs.ground == nil, "gs.ground should no longer exist")
    assert(type(gs.floor) == "table", "gs.floor should exist as a table")
    assert(type(gs.floor.draw) == "function", "gs.floor should have a draw function")

    local found_entry = nil
    for _, entry in ipairs(gs.drawer.layers) do
        if entry.sprite == gs.floor then found_entry = entry end
    end
    assert(found_entry ~= nil, "gs.floor should be registered in the drawer's layers")
    assert(found_entry.priority == 0,
        "gs.floor should be registered at priority 0, got " .. tostring(found_entry.priority))

    local ok, err = pcall(function() gs.floor.draw() end)
    assert(ok, "gs.floor.draw() should not error under the headless love.graphics stub: " .. tostring(err))
    print("PASS: game_scene: on_enter() halves world size and replaces self.ground with self.floor (checkerboard, priority 0)")
end

-- Player:update interacts with the nearest of several waiting boxes ---------

do
    local Player        = require("game/player")
    local HeadlessInput = require("lua/headless/input")
    local JigsawBoxMod  = require("game/jigsaw_box")

    local player = Player.new(0, 0)
    player.input = HeadlessInput.new()
    -- player:centre() == (32, 32)

    GameState:reset()
    -- All three boxes' centres sit within 1.5*C.U (48px) of the player's
    -- centre, with boxNear strictly the closest of the three.
    local boxNear = JigsawBoxMod.new(0, 0)    -- centre (32, 32), dist 0
    local boxMid  = JigsawBoxMod.new(16, 16)  -- centre (48, 48), dist ~22.6
    local boxFar  = JigsawBoxMod.new(0, 32)   -- centre (32, 64), dist 32

    -- Deliberately not in nearest-first array order, to prove the scan
    -- actually compares distances rather than just picking boxes[1].
    local boxes = { boxFar, boxNear, boxMid }

    player.input:press("interact")
    player:update(1 / 60, {}, boxes, nil, nil)

    assert(boxNear.state == "ejecting", "the nearest waiting box should have been interacted with")
    assert(boxMid.state  == "waiting",  "a farther waiting box should be untouched")
    assert(boxFar.state  == "waiting",  "the farthest waiting box should be untouched")
    print("PASS: player: update() interacts with the nearest of several waiting boxes in range")
end

-- Player:update calls button:interact() when no piece/box is in range -------
-- but the button is --------------------------------------------------------

do
    local Player         = require("game/player")
    local HeadlessInput  = require("lua/headless/input")
    local SpawnButtonMod = require("game/spawn_button")

    local player = Player.new(0, 0)
    player.input = HeadlessInput.new()
    -- player:centre() == (32, 32)

    local presses = 0
    local button = SpawnButtonMod.new(0, 0, function() presses = presses + 1 end)
    -- button:centre() == (32, 32), dist 0, well within 1.5*C.U

    player.input:press("interact")
    player:update(1 / 60, {}, {}, button, nil)

    assert(presses == 1,
        "button:interact() should fire when no piece/box is in range but the button is, got " .. presses .. " presses")
    print("PASS: player: update() calls button:interact() when no piece/box is in range but the button is")
end

-- ...and does NOT call button:interact() when a box interaction already ----
-- happened on the same press (box takes priority over the button) ----------

do
    local Player         = require("game/player")
    local HeadlessInput  = require("lua/headless/input")
    local SpawnButtonMod = require("game/spawn_button")
    local JigsawBoxMod   = require("game/jigsaw_box")

    local player = Player.new(0, 0)
    player.input = HeadlessInput.new()
    -- player:centre() == (32, 32)

    local presses = 0
    local button = SpawnButtonMod.new(0, 0, function() presses = presses + 1 end)  -- centre (32, 32)
    GameState:reset()
    local box    = JigsawBoxMod.new(0, 0)                                          -- centre (32, 32)

    player.input:press("interact")
    player:update(1 / 60, {}, { box }, button, nil)

    assert(box.state == "ejecting", "box should be interacted with when both box and button are in range")
    assert(presses == 0,
        "button:interact() should NOT fire when a box interaction already happened this press, got " .. presses .. " presses")
    print("PASS: player: update() prioritizes box interaction over button interaction when both are in range")
end

print("ALL TESTS PASSED")
