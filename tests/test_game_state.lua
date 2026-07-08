local GameState = require("game/game_state")

-- singleton identity --------------------------------------------------------

do
    local a = require("game/game_state")
    local b = require("game/game_state")
    assert(a == GameState, "require(\"game/game_state\") should return the same singleton as the top-level require")
    assert(a == b, "multiple require(\"game/game_state\") calls should return the same singleton instance")
    print("PASS: game_state: require() returns the same singleton across multiple calls")
end

-- reset() zeroes solved_count/active_count -----------------------------------

do
    GameState:reset()
    assert(GameState.solved_count == 0, "solved_count should be 0 after reset(), got " .. tostring(GameState.solved_count))
    assert(GameState.active_count == 0, "active_count should be 0 after reset(), got " .. tostring(GameState.active_count))
    print("PASS: game_state: reset() starts solved_count and active_count at 0")
end

-- puzzle_started() increments active_count only ------------------------------

do
    GameState:reset()
    local n = 4
    for _ = 1, n do
        GameState:puzzle_started()
    end
    assert(GameState.active_count == n,
        "active_count should be " .. n .. " after " .. n .. " puzzle_started() calls, got " .. tostring(GameState.active_count))
    assert(GameState.solved_count == 0,
        "solved_count should remain 0 after only puzzle_started() calls, got " .. tostring(GameState.solved_count))
    print("PASS: game_state: puzzle_started() increments active_count by N and leaves solved_count unchanged")
end

-- puzzle_started()/puzzle_solved() interplay ---------------------------------

do
    GameState:reset()
    GameState:puzzle_started()
    GameState:puzzle_started()
    GameState:puzzle_started()
    GameState:puzzle_solved()
    GameState:puzzle_solved()
    assert(GameState.active_count == 1,
        "3 started, 2 solved should leave active_count == 1, got " .. tostring(GameState.active_count))
    assert(GameState.solved_count == 2,
        "3 started, 2 solved should leave solved_count == 2, got " .. tostring(GameState.solved_count))
    print("PASS: game_state: puzzle_solved() increments solved_count and decrements active_count per call")
end

-- can_start_puzzle() cap behavior --------------------------------------------

do
    GameState:reset()
    for i = 1, GameState.MAX_ACTIVE_PUZZLES - 1 do
        assert(GameState:can_start_puzzle() == true,
            "can_start_puzzle() should be true before reaching the cap (iteration " .. i .. ")")
        GameState:puzzle_started()
    end
    assert(GameState:can_start_puzzle() == true,
        "can_start_puzzle() should still be true one call short of the cap")
    GameState:puzzle_started()  -- active_count now == MAX_ACTIVE_PUZZLES
    assert(GameState.active_count == GameState.MAX_ACTIVE_PUZZLES,
        "active_count should equal MAX_ACTIVE_PUZZLES after driving it up via puzzle_started()")
    assert(GameState:can_start_puzzle() == false,
        "can_start_puzzle() should be false once active_count == MAX_ACTIVE_PUZZLES")

    GameState:puzzle_solved()
    assert(GameState:can_start_puzzle() == true,
        "can_start_puzzle() should flip back to true after one puzzle_solved() brings active_count back under the cap")
    print("PASS: game_state: can_start_puzzle() reflects the MAX_ACTIVE_PUZZLES cap and recovers after a solve")
end

-- reset() zeroes counters again after being driven non-zero ------------------

do
    GameState:reset()
    GameState:puzzle_started()
    GameState:puzzle_started()
    GameState:puzzle_solved()
    assert(GameState.active_count ~= 0 or GameState.solved_count ~= 0,
        "test setup should have driven at least one counter non-zero before reset()")

    GameState:reset()
    assert(GameState.solved_count == 0,
        "solved_count should be zeroed by reset() even after being driven non-zero, got " .. tostring(GameState.solved_count))
    assert(GameState.active_count == 0,
        "active_count should be zeroed by reset() even after being driven non-zero, got " .. tostring(GameState.active_count))
    print("PASS: game_state: reset() zeroes solved_count and active_count again after they've been driven non-zero")
end

-- seen-tracking smoke check (untouched by this feature) ----------------------

do
    GameState:reset()
    assert(GameState:is_seen("easy", "assets/puzzles/easy/1.png") == false,
        "a path should not be seen right after reset()")
    GameState:mark_seen("easy", "assets/puzzles/easy/1.png")
    assert(GameState:is_seen("easy", "assets/puzzles/easy/1.png") == true,
        "mark_seen() should make is_seen() true for that path/tier")
    print("PASS: game_state: mark_seen()/is_seen() still work post-reset (unaffected by the new counters)")
end
