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
    GameState:puzzle_solved("easy")
    GameState:puzzle_solved("easy")
    assert(GameState.active_count == 1,
        "3 started, 2 solved should leave active_count == 1, got " .. tostring(GameState.active_count))
    assert(GameState.solved_count == 2,
        "3 started, 2 solved should leave solved_count == 2, got " .. tostring(GameState.solved_count))
    assert(GameState.solved_by_tier.easy == 2,
        "2 puzzle_solved('easy') calls should leave solved_by_tier.easy == 2, got " .. tostring(GameState.solved_by_tier.easy))
    assert(GameState.solved_by_tier.med == 0 and GameState.solved_by_tier.hard == 0,
        "solved_by_tier.med/hard should remain 0 when only 'easy' puzzles were solved, got med=" ..
        tostring(GameState.solved_by_tier.med) .. " hard=" .. tostring(GameState.solved_by_tier.hard))
    print("PASS: game_state: puzzle_solved(tier) increments solved_count/solved_by_tier[tier] and decrements active_count per call")
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

    GameState:puzzle_solved("easy")
    assert(GameState:can_start_puzzle() == true,
        "can_start_puzzle() should flip back to true after one puzzle_solved() brings active_count back under the cap")
    print("PASS: game_state: can_start_puzzle() reflects the MAX_ACTIVE_PUZZLES cap and recovers after a solve")
end

-- reset() zeroes counters again after being driven non-zero ------------------

do
    GameState:reset()
    GameState:puzzle_started()
    GameState:puzzle_started()
    GameState:puzzle_solved("easy")
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

-- is_tier_unlocked("easy") is always true -------------------------------------

do
    GameState:reset()
    assert(GameState:is_tier_unlocked("easy") == true,
        "easy tier should always be unlocked, including right after reset()")
    GameState:puzzle_solved("med")
    GameState:puzzle_solved("hard")
    assert(GameState:is_tier_unlocked("easy") == true,
        "easy tier should remain unlocked regardless of med/hard solve counts")
    print("PASS: game_state: is_tier_unlocked('easy') is always true")
end

-- is_tier_unlocked("med") flips true once 3 easy puzzles are solved ----------

do
    GameState:reset()
    assert(GameState:is_tier_unlocked("med") == false,
        "med tier should be locked on a fresh reset() (0 easy puzzles solved)")
    for i = 1, GameState.UNLOCK_THRESHOLD - 1 do
        GameState:puzzle_solved("easy")
        assert(GameState:is_tier_unlocked("med") == false,
            "med tier should still be locked after " .. i .. " of " .. GameState.UNLOCK_THRESHOLD .. " easy solves")
    end
    GameState:puzzle_solved("easy")
    assert(GameState:is_tier_unlocked("med") == true,
        "med tier should unlock once solved_by_tier.easy reaches UNLOCK_THRESHOLD (" ..
        GameState.UNLOCK_THRESHOLD .. "), got solved_by_tier.easy=" .. tostring(GameState.solved_by_tier.easy))
    print("PASS: game_state: is_tier_unlocked('med') is false until 3 'easy' puzzles are solved, then true")
end

-- is_tier_unlocked("hard") flips true once 3 med puzzles are solved ----------

do
    GameState:reset()
    assert(GameState:is_tier_unlocked("hard") == false,
        "hard tier should be locked on a fresh reset() (0 med puzzles solved)")
    for i = 1, GameState.UNLOCK_THRESHOLD - 1 do
        GameState:puzzle_solved("med")
        assert(GameState:is_tier_unlocked("hard") == false,
            "hard tier should still be locked after " .. i .. " of " .. GameState.UNLOCK_THRESHOLD .. " med solves")
    end
    GameState:puzzle_solved("med")
    assert(GameState:is_tier_unlocked("hard") == true,
        "hard tier should unlock once solved_by_tier.med reaches UNLOCK_THRESHOLD (" ..
        GameState.UNLOCK_THRESHOLD .. "), got solved_by_tier.med=" .. tostring(GameState.solved_by_tier.med))
    print("PASS: game_state: is_tier_unlocked('hard') is false until 3 'med' puzzles are solved, then true")
end

-- puzzle_solved(tier) only increments that tier's counter --------------------

do
    GameState:reset()
    GameState:puzzle_solved("easy")
    GameState:puzzle_solved("easy")
    GameState:puzzle_solved("med")
    assert(GameState.solved_by_tier.easy == 2,
        "solved_by_tier.easy should be 2 after two puzzle_solved('easy') calls, got " ..
        tostring(GameState.solved_by_tier.easy))
    assert(GameState.solved_by_tier.med == 1,
        "solved_by_tier.med should be 1 after one puzzle_solved('med') call, got " ..
        tostring(GameState.solved_by_tier.med))
    assert(GameState.solved_by_tier.hard == 0,
        "solved_by_tier.hard should remain 0 -- no puzzle_solved('hard') calls were made, got " ..
        tostring(GameState.solved_by_tier.hard))
    assert(GameState.solved_count == 3,
        "flat solved_count should still be the sum of all puzzle_solved() calls regardless of tier, got " ..
        tostring(GameState.solved_count))
    print("PASS: game_state: puzzle_solved(tier) increments solved_by_tier[tier] only, leaving other tiers' counts untouched")
end

-- reset() clears solved_by_tier back to {easy=0, med=0, hard=0} --------------

do
    GameState:reset()
    GameState:puzzle_solved("easy")
    GameState:puzzle_solved("med")
    GameState:puzzle_solved("hard")
    assert(GameState.solved_by_tier.easy == 1 and GameState.solved_by_tier.med == 1 and GameState.solved_by_tier.hard == 1,
        "test setup should have driven all three solved_by_tier counters to 1 before reset()")

    GameState:reset()
    assert(GameState.solved_by_tier.easy == 0,
        "solved_by_tier.easy should be 0 after reset(), got " .. tostring(GameState.solved_by_tier.easy))
    assert(GameState.solved_by_tier.med == 0,
        "solved_by_tier.med should be 0 after reset(), got " .. tostring(GameState.solved_by_tier.med))
    assert(GameState.solved_by_tier.hard == 0,
        "solved_by_tier.hard should be 0 after reset(), got " .. tostring(GameState.solved_by_tier.hard))
    print("PASS: game_state: reset() clears solved_by_tier back to {easy=0, med=0, hard=0}")
end

-- to_save() reports version == 1 and mirrors the live singleton's fields ----

do
    GameState:reset()
    GameState:mark_seen("easy", "assets/puzzles/easy/1.png")
    GameState:puzzle_started()
    GameState:puzzle_started()
    GameState:puzzle_solved("easy")

    local saved = GameState:to_save()
    assert(saved.version == 1,
        "to_save() should report version == 1, got " .. tostring(saved.version))
    assert(saved.solved_count == GameState.solved_count,
        "to_save().solved_count should match the live singleton's solved_count, got " ..
        tostring(saved.solved_count) .. " vs " .. tostring(GameState.solved_count))
    assert(saved.active_count == GameState.active_count,
        "to_save().active_count should match the live singleton's active_count, got " ..
        tostring(saved.active_count) .. " vs " .. tostring(GameState.active_count))
    assert(saved.solved_by_tier.easy == GameState.solved_by_tier.easy
        and saved.solved_by_tier.med == GameState.solved_by_tier.med
        and saved.solved_by_tier.hard == GameState.solved_by_tier.hard,
        "to_save().solved_by_tier should match the live singleton's solved_by_tier per tier")
    assert(saved.seen.easy["assets/puzzles/easy/1.png"] == true,
        "to_save().seen should reflect paths already marked seen on the live singleton")
    print("PASS: game_state: to_save() returns version == 1 and matches the live singleton's current fields")
end

-- to_save() is a shallow snapshot: seen/solved_by_tier are the SAME tables --

do
    GameState:reset()
    GameState:mark_seen("easy", "assets/puzzles/easy/1.png")
    GameState:puzzle_solved("easy")

    local saved = GameState:to_save()
    assert(saved.seen == GameState.seen,
        "to_save().seen should be the same table reference as GameState.seen (shallow snapshot), got a different table")
    assert(saved.solved_by_tier == GameState.solved_by_tier,
        "to_save().solved_by_tier should be the same table reference as GameState.solved_by_tier (shallow snapshot), got a different table")
    print("PASS: game_state: to_save() returns the same seen/solved_by_tier table references as the live singleton (shallow, not a deep copy)")
end

-- apply_save() mutates the existing singleton in place, never replaces it --

do
    GameState:reset()
    local ref = GameState
    GameState:apply_save({
        version = 1,
        seen = {easy = {}, med = {}, hard = {}},
        solved_count = 0,
        active_count = 0,
        solved_by_tier = {easy = 0, med = 0, hard = 0},
    })
    assert(GameState == ref,
        "apply_save() should mutate the existing GameState singleton in place, not replace it, got a different table identity")
    print("PASS: game_state: apply_save() mutates the existing singleton table in place rather than replacing it")
end

-- apply_save(data) restores solved_count/active_count/solved_by_tier/seen --

do
    GameState:reset()
    local data = {
        version = 1,
        seen = {easy = {["assets/puzzles/easy/2.png"] = true}, med = {}, hard = {}},
        solved_count = 5,
        active_count = 2,
        solved_by_tier = {easy = 3, med = 2, hard = 0},
    }

    GameState:apply_save(data)
    assert(GameState.solved_count == 5,
        "apply_save() should restore solved_count == 5, got " .. tostring(GameState.solved_count))
    assert(GameState.active_count == 2,
        "apply_save() should restore active_count == 2, got " .. tostring(GameState.active_count))
    assert(GameState.solved_by_tier.easy == 3 and GameState.solved_by_tier.med == 2 and GameState.solved_by_tier.hard == 0,
        "apply_save() should restore solved_by_tier per tier, got easy=" .. tostring(GameState.solved_by_tier.easy) ..
        " med=" .. tostring(GameState.solved_by_tier.med) .. " hard=" .. tostring(GameState.solved_by_tier.hard))
    assert(GameState:is_seen("easy", "assets/puzzles/easy/2.png") == true,
        "apply_save() should restore seen such that is_seen() reflects the restored data, got false")
    assert(GameState:is_seen("easy", "assets/puzzles/easy/1.png") == false,
        "apply_save() should not report a path as seen unless the restored seen table actually marks it, got true")
    print("PASS: game_state: apply_save(data) restores solved_count/active_count/solved_by_tier/seen, reflected by is_seen()")
end

-- apply_save(nil) and apply_save({version mismatch}) fall back to reset() --

do
    GameState:reset()
    GameState:mark_seen("easy", "assets/puzzles/easy/1.png")
    GameState:puzzle_started()
    GameState:puzzle_solved("easy")
    assert(GameState.solved_count ~= 0 or GameState.active_count ~= 0,
        "test setup should have driven at least one counter non-zero before apply_save(nil)")

    GameState:apply_save(nil)
    assert(GameState.solved_count == 0,
        "apply_save(nil) should fall back to a freshly-reset state, got solved_count=" .. tostring(GameState.solved_count))
    assert(GameState.active_count == 0,
        "apply_save(nil) should fall back to a freshly-reset state, got active_count=" .. tostring(GameState.active_count))
    assert(GameState.solved_by_tier.easy == 0 and GameState.solved_by_tier.med == 0 and GameState.solved_by_tier.hard == 0,
        "apply_save(nil) should zero out solved_by_tier, got easy=" .. tostring(GameState.solved_by_tier.easy) ..
        " med=" .. tostring(GameState.solved_by_tier.med) .. " hard=" .. tostring(GameState.solved_by_tier.hard))
    assert(GameState:is_seen("easy", "assets/puzzles/easy/1.png") == false,
        "apply_save(nil) should clear previously-marked seen paths, got is_seen() == true")

    GameState:mark_seen("easy", "assets/puzzles/easy/1.png")
    GameState:puzzle_started()
    GameState:puzzle_solved("easy")
    assert(GameState.solved_count ~= 0 or GameState.active_count ~= 0,
        "test setup should have driven at least one counter non-zero before apply_save({version mismatch})")

    GameState:apply_save({
        version = 2,
        seen = {easy = {["should-not-apply.png"] = true}, med = {}, hard = {}},
        solved_count = 99,
        active_count = 99,
        solved_by_tier = {easy = 99, med = 99, hard = 99},
    })
    assert(GameState.solved_count == 0,
        "apply_save() with a mismatched version should fall back to reset(), not partially apply fields, got solved_count=" ..
        tostring(GameState.solved_count))
    assert(GameState.active_count == 0,
        "apply_save() with a mismatched version should fall back to reset(), got active_count=" .. tostring(GameState.active_count))
    assert(GameState.solved_by_tier.easy == 0 and GameState.solved_by_tier.med == 0 and GameState.solved_by_tier.hard == 0,
        "apply_save() with a mismatched version should zero out solved_by_tier rather than applying the mismatched data's values")
    assert(GameState:is_seen("easy", "should-not-apply.png") == false,
        "apply_save() with a mismatched version should not apply the mismatched data's seen table, got is_seen() == true")
    print("PASS: game_state: apply_save(nil) and apply_save({version mismatch}) both fall back to a freshly-reset state instead of erroring or partially applying fields")
end

-- player_count defaults to 1 after reset() -----------------------------------

do
    GameState:reset()
    assert(GameState.player_count == 1,
        "player_count should default to 1 after reset(), got " .. tostring(GameState.player_count))
    print("PASS: game_state: player_count defaults to 1 after reset()")
end

-- to_save() reflects a mutated player_count -----------------------------------

do
    GameState:reset()
    GameState.player_count = 2

    local saved = GameState:to_save()
    assert(saved.player_count == 2,
        "to_save().player_count should reflect the live singleton's player_count == 2, got " .. tostring(saved.player_count))
    print("PASS: game_state: to_save() includes the current player_count")
end

-- apply_save(data) restores player_count --------------------------------------

do
    GameState:reset()
    local data = {
        version = 1,
        seen = {easy = {}, med = {}, hard = {}},
        solved_count = 0,
        active_count = 0,
        solved_by_tier = {easy = 0, med = 0, hard = 0},
        player_count = 2,
    }

    GameState:apply_save(data)
    assert(GameState.player_count == 2,
        "apply_save() should restore player_count == 2, got " .. tostring(GameState.player_count))
    print("PASS: game_state: apply_save(data) restores player_count")
end

-- apply_save(data) defaults player_count to 1 when the save predates it -------

do
    GameState:reset()
    GameState.player_count = 2
    local data = {
        version = 1,
        seen = {easy = {}, med = {}, hard = {}},
        solved_count = 0,
        active_count = 0,
        solved_by_tier = {easy = 0, med = 0, hard = 0},
        -- player_count intentionally omitted: simulates a save written
        -- before this field existed.
    }

    GameState:apply_save(data)
    assert(GameState.player_count == 1,
        "apply_save() should default player_count to 1 when the save data omits it, got " .. tostring(GameState.player_count))
    print("PASS: game_state: apply_save(data) defaults player_count to 1 for a version-1 save missing that field")
end

-- reset() restores player_count to 1 after it was changed ---------------------

do
    GameState:reset()
    GameState.player_count = 2
    assert(GameState.player_count == 2,
        "test setup should have driven player_count to 2 before reset()")

    GameState:reset()
    assert(GameState.player_count == 1,
        "reset() should restore player_count to 1, got " .. tostring(GameState.player_count))
    print("PASS: game_state: reset() restores player_count to 1 after being changed to 2")
end
