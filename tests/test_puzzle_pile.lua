local GameState     = require("game/game_state")
local PuzzleCatalog  = require("game/puzzle_catalog")
local PuzzlePile     = require("game/puzzle_pile")
local C              = require("game/constants")

-- GameState:remaining_puzzle_count(by_tier) ---------------------------------

-- Sums unseen paths across all tiers in a synthetic by_tier table; a tier
-- with nothing marked seen contributes its full count, a tier fully marked
-- seen contributes 0.

do
    GameState:reset()
    local by_tier = {
        easy = {"synthetic/easy/a.png", "synthetic/easy/b.png"},
        med  = {"synthetic/med/c.png"},
    }
    assert(GameState:remaining_puzzle_count(by_tier) == 3,
        "with nothing marked seen, remaining_puzzle_count should equal the total path count (3), got " ..
        tostring(GameState:remaining_puzzle_count(by_tier)))

    GameState:mark_seen("easy", "synthetic/easy/a.png")
    GameState:mark_seen("easy", "synthetic/easy/b.png")
    -- easy tier now fully seen (contributes 0); med tier untouched (contributes its full count, 1)
    assert(GameState:remaining_puzzle_count(by_tier) == 1,
        "with easy tier fully seen and med tier untouched, remaining_puzzle_count should be 0 + 1 = 1, got " ..
        tostring(GameState:remaining_puzzle_count(by_tier)))
    print("PASS: puzzle_pile: remaining_puzzle_count(by_tier) sums unseen paths across tiers -- fully-seen tier contributes 0, untouched tier contributes its full count")
end

-- Sums across three tiers at once, with a partial mix per tier.

do
    GameState:reset()
    local by_tier = {
        easy = {"synthetic/easy/1.png", "synthetic/easy/2.png", "synthetic/easy/3.png"},
        med  = {"synthetic/med/1.png", "synthetic/med/2.png"},
        hard = {"synthetic/hard/1.png"},
    }
    GameState:mark_seen("easy", "synthetic/easy/1.png")
    GameState:mark_seen("med", "synthetic/med/1.png")
    GameState:mark_seen("med", "synthetic/med/2.png")
    -- easy: 2 unseen, med: 0 unseen, hard: 1 unseen -> total 3
    assert(GameState:remaining_puzzle_count(by_tier) == 3,
        "expected 2 (easy) + 0 (med) + 1 (hard) = 3, got " .. tostring(GameState:remaining_puzzle_count(by_tier)))
    print("PASS: puzzle_pile: remaining_puzzle_count(by_tier) sums unseen paths across all three tiers simultaneously")
end

-- Does NOT check is_tier_unlocked: a locked tier's (e.g. "hard", locked by
-- default since nothing has been solved) unseen paths are still counted.

do
    GameState:reset()
    assert(GameState:is_tier_unlocked("hard") == false,
        "sanity check: hard tier should be locked on a fresh reset() (0 med solves)")

    local by_tier = {hard = {"synthetic/hard/x.png", "synthetic/hard/y.png"}}
    assert(GameState:remaining_puzzle_count(by_tier) == 2,
        "remaining_puzzle_count should count a locked tier's unseen paths just like any other tier " ..
        "(it deliberately does not consult is_tier_unlocked), got " ..
        tostring(GameState:remaining_puzzle_count(by_tier)))
    print("PASS: puzzle_pile: remaining_puzzle_count(by_tier) counts a locked tier's unseen paths, ignoring is_tier_unlocked")
end

-- PuzzlePile:count() ----------------------------------------------------------

-- Matches GameState:remaining_puzzle_count(PuzzleCatalog.list_by_tier()) for
-- the real on-disk catalog after a fresh reset() -- i.e. the full catalog
-- size, computed from the catalog itself rather than a hardcoded number so
-- this doesn't break if images are added/removed later.

do
    GameState:reset()
    local pile = PuzzlePile.new(0, 0)

    local by_tier = PuzzleCatalog.list_by_tier()
    local expected_total = 0
    for _, paths in pairs(by_tier) do
        expected_total = expected_total + #paths
    end

    assert(pile:count() == expected_total,
        "PuzzlePile:count() should equal the full real catalog size (" .. expected_total ..
        ") right after GameState:reset(), got " .. tostring(pile:count()))
    assert(pile:count() == GameState:remaining_puzzle_count(PuzzleCatalog.list_by_tier()),
        "PuzzlePile:count() should exactly match GameState:remaining_puzzle_count(PuzzleCatalog.list_by_tier())")
    print("PASS: puzzle_pile: PuzzlePile:count() matches GameState:remaining_puzzle_count(PuzzleCatalog.list_by_tier()) for the real catalog, i.e. the full catalog size after reset()")
end

-- PuzzlePile:top_position() ---------------------------------------------------

-- Helper: flattens PuzzleCatalog.list_by_tier() into an ordered array of
-- {tier=..., path=...} entries so tests can drive GameState into a state
-- where exactly N real catalog paths are unseen (by marking every entry
-- after index N as seen), giving PuzzlePile:count() an exact, controlled
-- value without needing a GameState API to "unmark" a path.
local function flatten_catalog_entries()
    local entries = {}
    for tier, paths in pairs(PuzzleCatalog.list_by_tier()) do
        for _, path in ipairs(paths) do
            entries[#entries + 1] = {tier = tier, path = path}
        end
    end
    return entries
end

-- Helper: resets GameState, then marks every catalog entry beyond the first
-- n as seen, leaving PuzzlePile:count() == n (assuming n <= #entries).
local function set_unseen_count(entries, n)
    GameState:reset()
    for i = n + 1, #entries do
        GameState:mark_seen(entries[i].tier, entries[i].path)
    end
end

do
    local entries = flatten_catalog_entries()
    assert(#entries >= 4,
        "test setup requires at least 4 real catalog images to exercise count()==1..4, found " .. #entries)

    local base_x, base_y = 123, 456
    local pile = PuzzlePile.new(base_x, base_y)

    -- count() == 1: top_position() should return the base sprite.y unchanged.
    set_unseen_count(entries, 1)
    assert(pile:count() == 1, "test setup: pile:count() should be 1, got " .. tostring(pile:count()))
    local pos1 = pile:top_position()
    assert(pos1.x == base_x, "top_position().x should equal the base sprite.x (" .. base_x .. "), got " .. tostring(pos1.x))
    assert(pos1.y == base_y,
        "top_position().y should equal the base sprite.y (" .. base_y .. ") unchanged when count() == 1, got " .. tostring(pos1.y))

    -- count() == 2: y should be exactly one PILE_BOX_STACK_OFFSET higher (smaller).
    set_unseen_count(entries, 2)
    assert(pile:count() == 2, "test setup: pile:count() should be 2, got " .. tostring(pile:count()))
    local pos2 = pile:top_position()
    assert(pos2.y == base_y - C.PILE_BOX_STACK_OFFSET,
        "top_position().y at count()==2 should be base_y - PILE_BOX_STACK_OFFSET (" ..
        (base_y - C.PILE_BOX_STACK_OFFSET) .. "), got " .. tostring(pos2.y))

    -- count() == 3: y should be exactly two PILE_BOX_STACK_OFFSETs higher.
    set_unseen_count(entries, 3)
    assert(pile:count() == 3, "test setup: pile:count() should be 3, got " .. tostring(pile:count()))
    local pos3 = pile:top_position()
    assert(pos3.y == base_y - 2 * C.PILE_BOX_STACK_OFFSET,
        "top_position().y at count()==3 should be base_y - 2*PILE_BOX_STACK_OFFSET (" ..
        (base_y - 2 * C.PILE_BOX_STACK_OFFSET) .. "), got " .. tostring(pos3.y))

    print("PASS: puzzle_pile: top_position().y equals sprite.y at count()==1, and decreases by exactly PILE_BOX_STACK_OFFSET per additional unit of count above 1")
end

-- count() == 0 (every real catalog image marked seen) returns the exact same
-- position as count() == 1 would -- verifies the math.max(n, 1) floor.

do
    local entries = flatten_catalog_entries()
    local base_x, base_y = 77, 88
    local pile = PuzzlePile.new(base_x, base_y)

    set_unseen_count(entries, 1)
    local pos_at_1 = pile:top_position()

    set_unseen_count(entries, 0)
    assert(pile:count() == 0, "test setup: pile:count() should be 0 with every catalog image marked seen, got " .. tostring(pile:count()))
    local pos_at_0 = pile:top_position()

    assert(pos_at_0.x == pos_at_1.x and pos_at_0.y == pos_at_1.y,
        "top_position() at count()==0 should equal top_position() at count()==1 (the math.max(n, 1) floor), got (" ..
        tostring(pos_at_0.x) .. ", " .. tostring(pos_at_0.y) .. ") vs (" ..
        tostring(pos_at_1.x) .. ", " .. tostring(pos_at_1.y) .. ")")
    -- Also pin it against the analytically expected y at n=1 (base_y unchanged).
    assert(pos_at_0.y == base_y,
        "top_position() at count()==0 should analytically equal base_y (" .. base_y .. ") via the n=1 floor, got " ..
        tostring(pos_at_0.y))
    print("PASS: puzzle_pile: top_position() at count()==0 returns the same position as count()==1 (math.max(n, 1) floor)")
end

-- PuzzlePile:interact() --------------------------------------------------------

-- interact() invokes on_press exactly once per call, mirroring the old
-- spawn_button "interact() invokes on_press exactly once per call" test, now
-- driven through PuzzlePile.new(x, y, on_press)'s third arg.

do
    local calls = 0
    local pile = PuzzlePile.new(0, 0, function() calls = calls + 1 end)

    pile:interact()
    assert(calls == 1, "on_press should be invoked once after first interact(), got " .. calls)

    pile:interact()
    assert(calls == 2, "on_press should be invoked once more after second interact(), got " .. calls)
    print("PASS: puzzle_pile: interact() invokes on_press exactly once per call")
end

-- PuzzlePile:centre() ----------------------------------------------------------

-- Mirrors the old spawn_button "centre() returns sprite center" test.

do
    local pile = PuzzlePile.new(320, 640, function() end)
    local c = pile:centre()
    assert(c.x == 320 + C.U, "centre.x should be x + U = " .. (320 + C.U) .. ", got " .. tostring(c.x))
    assert(c.y == 640 + C.U, "centre.y should be y + U = " .. (640 + C.U) .. ", got " .. tostring(c.y))
    print("PASS: puzzle_pile: centre() returns sprite center")
end

-- Player:update() prioritizes box interaction over pile interaction ----------

-- Mirrors the box-vs-button priority test previously in test_jigsaw.lua: a
-- nearby waiting box still wins over the pile when both are in interact
-- range on the same press.

do
    local Player       = require("game/player")
    local HeadlessInput = require("lua/headless/input")
    local JigsawBoxMod = require("game/jigsaw_box")

    local player = Player.new(0, 0)
    player.input = HeadlessInput.new()
    -- player:centre() == (32, 32)

    local presses = 0
    local pile = PuzzlePile.new(0, 0, function() presses = presses + 1 end)  -- centre (32, 32)
    GameState:reset()
    local box = JigsawBoxMod.new(0, 0)                                      -- centre (32, 32)

    player.input:press("interact")
    player:update(1 / 60, {}, { box }, pile, nil)

    assert(box.state == "ejecting", "box should be interacted with when both box and pile are in range")
    assert(presses == 0,
        "pile:interact() should NOT fire when a box interaction already happened this press, got " .. presses .. " presses")
    print("PASS: player: update() prioritizes box interaction over pile interaction when both are in range")
end

-- ...and pile:interact() still fires when no piece/box is in range but the --
-- pile is (mirrors the old spawn_button "no piece/box in range" test) -------

do
    local Player       = require("game/player")
    local HeadlessInput = require("lua/headless/input")

    local player = Player.new(0, 0)
    player.input = HeadlessInput.new()
    -- player:centre() == (32, 32)

    local presses = 0
    local pile = PuzzlePile.new(0, 0, function() presses = presses + 1 end)
    -- pile:centre() == (32, 32), dist 0, well within 1.5*C.U

    player.input:press("interact")
    player:update(1 / 60, {}, {}, pile, nil)

    assert(presses == 1,
        "pile:interact() should fire when no piece/box is in range but the pile is, got " .. presses .. " presses")
    print("PASS: player: update() calls pile:interact() when no piece/box is in range but the pile is")
end
