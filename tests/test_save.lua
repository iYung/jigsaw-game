local Save      = require("lua/core/save")
local GameState  = require("game/game_state")

-- Stub love.filesystem with an in-memory store so tests don't touch disk.
local _fs = {}
love.filesystem.write   = function(path, content) _fs[path] = content end
love.filesystem.read    = function(path) return _fs[path], _fs[path] and #_fs[path] or 0 end
love.filesystem.getInfo = function(path) return _fs[path] and { type = "file" } or nil end

local function reset_fs() _fs = {} end

-- Test 1: exists() returns false when no file
do
    reset_fs()
    assert(Save.exists() == false, "exists() should be false with no save file")
    print("PASS: save: exists() false with no file")
end

-- Test 2: write() + exists() returns true
do
    reset_fs()
    Save.write({ x = 1 })
    assert(Save.exists() == true, "exists() should be true after write()")
    print("PASS: save: exists() true after write()")
end

-- Test 3: read() returns nil with no file
do
    reset_fs()
    assert(Save.read() == nil, "read() should return nil with no file")
    print("PASS: save: read() nil with no file")
end

-- Test 4: read() returns nil on corrupt data
do
    reset_fs()
    love.filesystem.write("save.dat", "NOT VALID LUA }{{{")
    assert(Save.read() == nil, "read() should return nil on corrupt data")
    print("PASS: save: read() nil on corrupt data")
end

-- Test 5: round-trip preserves this game's actual save shape (scalars,
-- nested string-keyed "seen" table, and empty arrays included)
do
    reset_fs()
    local data_in = {
        game_state = {
            version = 1,
            seen = {
                easy = { ["assets/puzzles/easy/1.png"] = true },
                med  = {},
                hard = {},
            },
            solved_count   = 2,
            active_count   = 1,
            solved_by_tier = { easy = 2, med = 0, hard = 0 },
        },
        scene = {
            player = { x = 320, y = 192, held_piece = nil },
            pieces = {},
            boxes  = {},
            completed_puzzles   = {},
            shelf_row_x         = 0,
            shelf_row_bottom    = -64,
            shelf_row_max_height = 0,
        },
    }
    Save.write(data_in)
    local data_out = Save.read()
    assert(data_out ~= nil, "read() should return a table after write()")

    local gs_out = data_out.game_state
    assert(gs_out.version == 1, "game_state.version round-trip, got " .. tostring(gs_out.version))
    assert(gs_out.seen.easy["assets/puzzles/easy/1.png"] == true,
        "game_state.seen.easy[path] round-trip")
    assert(next(gs_out.seen.med) == nil, "game_state.seen.med should round-trip as an empty table")
    assert(next(gs_out.seen.hard) == nil, "game_state.seen.hard should round-trip as an empty table")
    assert(gs_out.solved_count == 2, "game_state.solved_count round-trip, got " .. tostring(gs_out.solved_count))
    assert(gs_out.active_count == 1, "game_state.active_count round-trip, got " .. tostring(gs_out.active_count))
    assert(gs_out.solved_by_tier.easy == 2, "game_state.solved_by_tier.easy round-trip")
    assert(gs_out.solved_by_tier.med == 0,  "game_state.solved_by_tier.med round-trip")
    assert(gs_out.solved_by_tier.hard == 0, "game_state.solved_by_tier.hard round-trip")

    local scene_out = data_out.scene
    assert(scene_out.player.x == 320, "scene.player.x round-trip, got " .. tostring(scene_out.player.x))
    assert(scene_out.player.y == 192, "scene.player.y round-trip, got " .. tostring(scene_out.player.y))
    assert(scene_out.player.held_piece == nil, "scene.player.held_piece should round-trip as nil")
    assert(next(scene_out.pieces) == nil, "scene.pieces should round-trip as an empty table")
    assert(next(scene_out.boxes) == nil, "scene.boxes should round-trip as an empty table")
    assert(next(scene_out.completed_puzzles) == nil, "scene.completed_puzzles should round-trip as an empty table")
    assert(scene_out.shelf_row_x == 0, "scene.shelf_row_x round-trip, got " .. tostring(scene_out.shelf_row_x))
    assert(scene_out.shelf_row_bottom == -64, "scene.shelf_row_bottom round-trip, got " .. tostring(scene_out.shelf_row_bottom))
    assert(scene_out.shelf_row_max_height == 0, "scene.shelf_row_max_height round-trip, got " .. tostring(scene_out.shelf_row_max_height))
    print("PASS: save: round-trip preserves the game's actual save shape (nested seen table included)")
end

-- Test 6: GameState:to_save()/GameState:apply_save() round-trip through
-- Save.write/Save.read, driven via the real public API
do
    reset_fs()
    GameState:reset()
    GameState:mark_seen("easy", "assets/puzzles/easy/1.png")
    GameState:puzzle_started()
    GameState:puzzle_solved("easy")

    local saved = GameState:to_save()
    Save.write({ game_state = saved })
    local loaded = Save.read()
    assert(loaded ~= nil, "Save.read() should return a table after Save.write()")

    -- Prove apply_save (not stale in-process state) is what restores things.
    GameState:reset()
    assert(GameState.solved_count == 0, "sanity: reset() should zero solved_count before apply_save")

    GameState:apply_save(loaded.game_state)

    assert(GameState.solved_count == 1,
        "apply_save should restore solved_count == 1, got " .. tostring(GameState.solved_count))
    assert(GameState.active_count == 0,
        "apply_save should restore active_count == 0 (1 started, 1 solved), got " .. tostring(GameState.active_count))
    assert(GameState.solved_by_tier.easy == 1,
        "apply_save should restore solved_by_tier.easy == 1, got " .. tostring(GameState.solved_by_tier.easy))
    assert(GameState:is_seen("easy", "assets/puzzles/easy/1.png") == true,
        "apply_save should restore the seen table so is_seen() reflects the saved mark_seen() call")
    print("PASS: save: GameState:to_save()/apply_save() round-trip through Save.write()/Save.read()")
end

-- Test 7: GameState:apply_save(nil) and a version-mismatched table both
-- fall back to a freshly-reset state
do
    reset_fs()
    GameState:reset()
    GameState:mark_seen("easy", "assets/puzzles/easy/1.png")
    GameState:puzzle_started()
    GameState:puzzle_solved("easy")
    assert(GameState.solved_count ~= 0, "test setup should have driven solved_count non-zero before apply_save(nil)")

    GameState:apply_save(nil)
    assert(GameState.solved_count == 0, "apply_save(nil) should reset solved_count to 0, got " .. tostring(GameState.solved_count))
    assert(GameState.active_count == 0, "apply_save(nil) should reset active_count to 0, got " .. tostring(GameState.active_count))
    assert(GameState.solved_by_tier.easy == 0, "apply_save(nil) should reset solved_by_tier.easy to 0, got " .. tostring(GameState.solved_by_tier.easy))
    assert(GameState.solved_by_tier.med == 0, "apply_save(nil) should reset solved_by_tier.med to 0, got " .. tostring(GameState.solved_by_tier.med))
    assert(GameState.solved_by_tier.hard == 0, "apply_save(nil) should reset solved_by_tier.hard to 0, got " .. tostring(GameState.solved_by_tier.hard))
    assert(GameState:is_seen("easy", "assets/puzzles/easy/1.png") == false,
        "apply_save(nil) should reset the seen table so is_seen() is false again")
    print("PASS: save: apply_save(nil) falls back to a freshly-reset state")

    GameState:reset()
    GameState:mark_seen("easy", "assets/puzzles/easy/1.png")
    GameState:puzzle_started()
    GameState:puzzle_solved("easy")
    assert(GameState.solved_count ~= 0, "test setup should have driven solved_count non-zero before apply_save(version mismatch)")

    GameState:apply_save({ version = 2, solved_count = 99, active_count = 99,
        solved_by_tier = { easy = 99, med = 99, hard = 99 }, seen = { easy = {}, med = {}, hard = {} } })
    assert(GameState.solved_count == 0,
        "apply_save with mismatched version should reset solved_count to 0, got " .. tostring(GameState.solved_count))
    assert(GameState.active_count == 0,
        "apply_save with mismatched version should reset active_count to 0, got " .. tostring(GameState.active_count))
    assert(GameState.solved_by_tier.easy == 0,
        "apply_save with mismatched version should reset solved_by_tier.easy to 0, got " .. tostring(GameState.solved_by_tier.easy))
    print("PASS: save: apply_save() with a mismatched version falls back to a freshly-reset state")
end

print("ALL TESTS PASSED")

-- Leave the process-lifetime GameState singleton clean for whichever test
-- file the headless runner executes next.
GameState:reset()
