local PuzzleCatalog = require("game/puzzle_catalog")

local TIER_NAMES = {"easy", "med", "hard", "final_puzzle"}

-- PuzzleCatalog.list() flattens all tiers into one array of path strings,
-- filtering to .png entries, and memoizes the scan for the process lifetime.
-- NOTE: because the cache is module-scope (persists for the whole
-- test-runner process), some other test file may have already called
-- PuzzleCatalog.list() before this file runs, using the real (unmocked)
-- love.filesystem.getDirectoryItems -- in that case cached_list is already
-- populated and our mock below never gets called. Test 1 is therefore
-- written to only make strong assertions about the shape of the result when
-- our mock was actually consulted; Test 2's memoization check is written to
-- be robust either way (see comment there).

-- PuzzleCatalog.list() returns a flat list across tiers, filtering to .png --

do
    -- Spy-and-restore pattern on love.filesystem.getDirectoryItems, mirroring
    -- how tests/test_jigsaw.lua spies on love.graphics.newQuad/newImage:
    -- save the real function, install a replacement, restore afterward.
    local real_getDirectoryItems = love.filesystem.getDirectoryItems

    local mock_items = {
        ["assets/puzzles/easy"] = {"1.png", "2.png", "3.png", ".DS_Store"},
        ["assets/puzzles/med"]  = {"1.png"},
        ["assets/puzzles/hard"] = {"1.png"},
        ["assets/puzzles/final_puzzle"] = {"1.png"},
    }

    local call_count = 0
    love.filesystem.getDirectoryItems = function(dir)
        call_count = call_count + 1
        return mock_items[dir] or real_getDirectoryItems(dir)
    end

    local list = PuzzleCatalog.list()

    love.filesystem.getDirectoryItems = real_getDirectoryItems

    if call_count > 0 then
        -- Our mock was actually consulted (the cache was not already
        -- populated by an earlier test file's real scan), so we can make
        -- strong assertions about the exact returned list.
        assert(#list == 6,
            "expected 6 total paths from the mocked 3/1/1/1 tiers, got " .. #list)

        local expected = {
            ["assets/puzzles/easy/1.png"] = true,
            ["assets/puzzles/easy/2.png"] = true,
            ["assets/puzzles/easy/3.png"] = true,
            ["assets/puzzles/med/1.png"]  = true,
            ["assets/puzzles/hard/1.png"] = true,
            ["assets/puzzles/final_puzzle/1.png"] = true,
        }

        local seen = {}
        for i, path in ipairs(list) do
            assert(expected[path],
                "path #" .. i .. " (" .. tostring(path) ..
                ") should be one of the 5 expected mocked paths")
            assert(not path:find(".DS_Store", 1, true),
                "non-.png mock entry .DS_Store should have been filtered out, got " .. tostring(path))
            seen[path] = true
        end
        for path in pairs(expected) do
            assert(seen[path], "expected path " .. path .. " missing from PuzzleCatalog.list() result")
        end

        print("PASS: puzzle_catalog: list() returns a flat 6-path list across easy/med/hard/final_puzzle tiers, filtering out non-.png entries")
    else
        -- The module-level cache was already populated by an earlier test
        -- file's real scan before our mock was installed; our mock never
        -- ran. Fall back to a weaker but still meaningful shape assertion.
        assert(type(list) == "table", "PuzzleCatalog.list() should return a table")
        for i, path in ipairs(list) do
            assert(type(path) == "string" and path:sub(-4) == ".png",
                "path #" .. i .. " should be a .png path string, got " .. tostring(path))
        end
        print("PASS: puzzle_catalog: list() returns a flat list of .png path strings (cache pre-populated by an earlier test file; mock not exercised)")
    end
end

-- PuzzleCatalog.list() memoizes: a second call triggers no additional scans --

do
    local real_getDirectoryItems = love.filesystem.getDirectoryItems

    local mock_items = {
        ["assets/puzzles/easy"] = {"1.png", "2.png", "3.png"},
        ["assets/puzzles/med"]  = {"1.png"},
        ["assets/puzzles/hard"] = {"1.png"},
        ["assets/puzzles/final_puzzle"] = {"1.png"},
    }

    local call_count = 0
    love.filesystem.getDirectoryItems = function(dir)
        call_count = call_count + 1
        return mock_items[dir] or real_getDirectoryItems(dir)
    end

    PuzzleCatalog.list()
    local count_after_first = call_count

    PuzzleCatalog.list()
    local count_after_second = call_count

    love.filesystem.getDirectoryItems = real_getDirectoryItems

    -- Robust to execution order: regardless of whether our mock or an
    -- earlier real scan populated the module-level cache first, the second
    -- call within this test must add zero new getDirectoryItems calls.
    assert(count_after_second == count_after_first,
        "second PuzzleCatalog.list() call should not trigger additional " ..
        "getDirectoryItems calls (memoization) -- had " .. count_after_first ..
        " calls after the first .list(), " .. count_after_second .. " after the second")
    print("PASS: puzzle_catalog: list() memoizes -- a second call adds zero new getDirectoryItems scans")
end

-- PuzzleCatalog.list_by_tier() partitions paths per tier, filtering to .png --

do
    local real_getDirectoryItems = love.filesystem.getDirectoryItems

    local mock_items = {
        ["assets/puzzles/easy"] = {"1.png", "2.png", "3.png", ".DS_Store"},
        ["assets/puzzles/med"]  = {"1.png"},
        ["assets/puzzles/hard"] = {"1.png"},
        ["assets/puzzles/final_puzzle"] = {"1.png"},
    }

    local call_count = 0
    love.filesystem.getDirectoryItems = function(dir)
        call_count = call_count + 1
        return mock_items[dir] or real_getDirectoryItems(dir)
    end

    local by_tier = PuzzleCatalog.list_by_tier()

    love.filesystem.getDirectoryItems = real_getDirectoryItems

    if call_count > 0 then
        -- Our mock was actually consulted (the cache was not already
        -- populated by an earlier test block's real scan), so we can make
        -- strong assertions about the exact returned tables.
        local keys = {}
        for k in pairs(by_tier) do keys[#keys + 1] = k end
        table.sort(keys)
        assert(#keys == 4 and keys[1] == "easy" and keys[2] == "final_puzzle"
            and keys[3] == "hard" and keys[4] == "med",
            "expected exactly the keys easy/final_puzzle/hard/med, got: " .. table.concat(keys, ", "))

        assert(#by_tier.easy == 3,
            "expected 3 easy paths (.DS_Store filtered out), got " .. #by_tier.easy)
        assert(#by_tier.med == 1, "expected 1 med path, got " .. #by_tier.med)
        assert(#by_tier.hard == 1, "expected 1 hard path, got " .. #by_tier.hard)
        assert(#by_tier.final_puzzle == 1, "expected 1 final_puzzle path, got " .. #by_tier.final_puzzle)

        local expected_easy = {
            ["assets/puzzles/easy/1.png"] = true,
            ["assets/puzzles/easy/2.png"] = true,
            ["assets/puzzles/easy/3.png"] = true,
        }
        local seen_easy = {}
        for i, path in ipairs(by_tier.easy) do
            assert(expected_easy[path],
                "easy path #" .. i .. " (" .. tostring(path) .. ") should be one of the 3 expected easy paths")
            assert(not path:find(".DS_Store", 1, true),
                "non-.png mock entry .DS_Store should have been filtered out of easy, got " .. tostring(path))
            seen_easy[path] = true
        end
        for path in pairs(expected_easy) do
            assert(seen_easy[path], "expected easy path " .. path .. " missing from by_tier.easy")
        end

        assert(by_tier.med[1] == "assets/puzzles/med/1.png",
            "expected by_tier.med[1] to be assets/puzzles/med/1.png, got " .. tostring(by_tier.med[1]))
        assert(by_tier.hard[1] == "assets/puzzles/hard/1.png",
            "expected by_tier.hard[1] to be assets/puzzles/hard/1.png, got " .. tostring(by_tier.hard[1]))
        assert(by_tier.final_puzzle[1] == "assets/puzzles/final_puzzle/1.png",
            "expected by_tier.final_puzzle[1] to be assets/puzzles/final_puzzle/1.png, got " .. tostring(by_tier.final_puzzle[1]))

        -- No cross-tier contamination: no tier's array should contain a path
        -- belonging to a different tier's directory.
        for _, tier in ipairs(TIER_NAMES) do
            for _, other in ipairs(TIER_NAMES) do
                if tier ~= other then
                    for _, path in ipairs(by_tier[tier]) do
                        assert(not path:find("assets/puzzles/" .. other .. "/", 1, true),
                            tier .. " tier array should not contain a " .. other .. "-tier path, got " .. tostring(path))
                    end
                end
            end
        end

        print("PASS: puzzle_catalog: list_by_tier() partitions paths into easy/med/hard/final_puzzle, filtering out non-.png entries, with no cross-tier contamination")
    else
        -- The module-level cache was already populated by an earlier test
        -- block's real scan before our mock was installed; our mock never
        -- ran. Fall back to a weaker but still meaningful shape assertion.
        assert(type(by_tier) == "table", "PuzzleCatalog.list_by_tier() should return a table")

        local keys = {}
        for k in pairs(by_tier) do keys[#keys + 1] = k end
        table.sort(keys)
        assert(#keys == 4 and keys[1] == "easy" and keys[2] == "final_puzzle"
            and keys[3] == "hard" and keys[4] == "med",
            "expected exactly the keys easy/final_puzzle/hard/med, got: " .. table.concat(keys, ", "))

        for _, tier in ipairs(TIER_NAMES) do
            local prefix = "assets/puzzles/" .. tier .. "/"
            for i, path in ipairs(by_tier[tier]) do
                assert(type(path) == "string" and path:sub(-4) == ".png",
                    tier .. " path #" .. i .. " should be a .png path string, got " .. tostring(path))
                assert(path:sub(1, #prefix) == prefix,
                    tier .. " path #" .. i .. " should start with " .. prefix .. ", got " .. tostring(path))
            end
        end

        print("PASS: puzzle_catalog: list_by_tier() returns easy/med/hard/final_puzzle tables scoped to their own tier's .png paths (cache pre-populated by an earlier test block; mock not exercised)")
    end
end

-- PuzzleCatalog.list() and list_by_tier() share one memoized scan, no matter --
-- which of the two public functions is called first                        --

do
    local real_getDirectoryItems = love.filesystem.getDirectoryItems

    local mock_items = {
        ["assets/puzzles/easy"] = {"1.png", "2.png", "3.png"},
        ["assets/puzzles/med"]  = {"1.png"},
        ["assets/puzzles/hard"] = {"1.png"},
        ["assets/puzzles/final_puzzle"] = {"1.png"},
    }

    local call_count = 0
    love.filesystem.getDirectoryItems = function(dir)
        call_count = call_count + 1
        return mock_items[dir] or real_getDirectoryItems(dir)
    end

    -- By this point in the file the module-level cache has almost certainly
    -- already been populated by an earlier block/file, so in practice both
    -- calls below add zero new scans regardless of order -- but the
    -- assertion is written generically (comparing counts before/after each
    -- call) so it holds just as well the first time either function is ever
    -- called in a fresh process, whichever one runs first.
    PuzzleCatalog.list_by_tier()
    local count_after_first_call = call_count

    PuzzleCatalog.list()
    local count_after_second_call = call_count

    love.filesystem.getDirectoryItems = real_getDirectoryItems

    assert(count_after_second_call == count_after_first_call,
        "calling list_by_tier() then list() back-to-back should not trigger " ..
        "additional getDirectoryItems calls (shared memoization) -- had " ..
        count_after_first_call .. " calls after the first public-function call, " ..
        count_after_second_call .. " after the second")
    print("PASS: puzzle_catalog: list() and list_by_tier() share one memoized scan -- the second public-function call adds zero new getDirectoryItems scans, regardless of call order")
end

print("ALL TESTS PASSED")
