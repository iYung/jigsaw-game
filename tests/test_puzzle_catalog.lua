local PuzzleCatalog = require("game/puzzle_catalog")

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
        assert(#list == 5,
            "expected 5 total paths from the mocked 3/1/1 tiers, got " .. #list)

        local expected = {
            ["assets/puzzles/easy/1.png"] = true,
            ["assets/puzzles/easy/2.png"] = true,
            ["assets/puzzles/easy/3.png"] = true,
            ["assets/puzzles/med/1.png"]  = true,
            ["assets/puzzles/hard/1.png"] = true,
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

        print("PASS: puzzle_catalog: list() returns a flat 5-path list across easy/med/hard tiers, filtering out non-.png entries")
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

print("ALL TESTS PASSED")
