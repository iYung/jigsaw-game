local StartScene = require("game/scenes/start_scene")
local Save       = require("lua/core/save")
local GameState  = require("game/game_state")

-- Stub love.filesystem with an in-memory store so tests don't touch disk,
-- exactly matching tests/test_save.lua's pattern -- Save.exists()/Save.read()
-- must never touch the real disk in this file either.
local _fs = {}
love.filesystem.write   = function(path, content) _fs[path] = content end
love.filesystem.read    = function(path) return _fs[path], _fs[path] and #_fs[path] or 0 end
love.filesystem.getInfo = function(path) return _fs[path] and { type = "file" } or nil end

local function reset_fs() _fs = {} end

-- Builds a fake joystick, matching tests/test_input_gamepad.lua's helper --
-- duplicated locally per this repo's no-shared-test-helpers convention.
local function fake_stick()
    return {
        isGamepadDown = function() return false end,
        getGamepadAxis = function() return 0 end,
    }
end

-- Monkey-patches love.joystick.getJoysticks to return `sticks` for the
-- duration of fn(), then restores the original stub (mirrors
-- tests/test_input_gamepad.lua's with_joysticks).
local function with_joysticks(sticks, fn)
    local original = love.joystick.getJoysticks
    love.joystick.getJoysticks = function() return sticks end
    local ok, err = pcall(fn)
    love.joystick.getJoysticks = original
    if not ok then
        error(err, 0)
    end
end

-- StartScene owns a *real* lua/core/input.lua instance (not HeadlessInput —
-- HeadlessInput only gets wired in via lua/headless/runner.lua's
-- runner.setup(scene_factory), which injects (input, sm) into the factory,
-- but StartScene.new(manager) doesn't accept an injected input; same
-- limitation tests/test_basics.lua documents for game/player.lua). Under
-- --headless, love.keyboard.isDown is stubbed to always return false, so we
-- locally fake it around scene:update(dt) calls to drive real rising-edge
-- key presses through the actual Input class.
--
-- tap() simulates one full key tap: a press frame (isDown faked true for
-- `key`) followed by a release frame (isDown restored), so Input's internal
-- _down state resets and a later tap() on the same action can register a
-- fresh rising edge.
local function tap(scene, key)
    local original_isDown = love.keyboard.isDown
    love.keyboard.isDown = function(k) return k == key end
    scene:update(1 / 60)
    love.keyboard.isDown = original_isDown
    scene:update(1 / 60)
end

-- Builds a realistic save-shaped table (matching the {game_state=, scene=}
-- shape GameScene:to_save()/GameState:to_save() produce -- see
-- tests/test_save.lua's Test 5/6) with solved_count == 2 so restoration can
-- be asserted on distinctly from a freshly-reset GameState.
local function make_save()
    return {
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
            completed_puzzles    = {},
            shelf_row_x          = 0,
            shelf_row_bottom     = -64,
            shelf_row_max_height = 0,
        },
    }
end

-- Test 1: StartScene.new(manager) starts with selected == 1
do
    reset_fs()
    local manager = {}
    local scene = StartScene.new(manager)
    scene:on_enter()
    assert(scene.selected == 1, "StartScene.new should start with selected == 1, got " .. tostring(scene.selected))
    print("PASS: start_scene: StartScene.new(manager) starts with selected == 1")
end

-- Test 2: pressing down cycles 1 -> 3 -> 4 -> 5 -> 1 with no save present
-- (index 2, "Continue", is disabled and must be skipped by the
-- down-navigation). Players (3), Settings (4), and Exit Game (5) are all
-- selectable, so with 5 items the full cycle now takes 4 taps instead of 3.
do
    reset_fs()
    local manager = {}
    local scene = StartScene.new(manager)
    scene:on_enter()
    assert(scene._has_save == false, "sanity: _has_save should be false with no save file")

    tap(scene, "s")
    assert(scene.selected == 3,
        "pressing down from 1 with no save should skip Continue (2) and land on Players (3), got " .. tostring(scene.selected))

    tap(scene, "s")
    assert(scene.selected == 4,
        "pressing down from Players (3) should land on Settings (4), got " .. tostring(scene.selected))

    tap(scene, "s")
    assert(scene.selected == 5,
        "pressing down from Settings (4) should land on Exit Game (5), got " .. tostring(scene.selected))

    tap(scene, "s")
    assert(scene.selected == 1, "pressing down from Exit Game (5) should wrap selected to 1, got " .. tostring(scene.selected))

    print("PASS: start_scene: pressing down cycles 1 -> 3 -> 4 -> 5 -> 1, skipping disabled Continue")
end

-- Test 3: pressing up from 1 wraps directly to 5 (Exit Game) with no save
-- present -- going backward from 1 wraps straight past Continue (2),
-- Players (3), and Settings (4) to the last item.
do
    reset_fs()
    local manager = {}
    local scene = StartScene.new(manager)
    scene:on_enter()
    assert(scene._has_save == false, "sanity: _has_save should be false with no save file")

    tap(scene, "up")
    assert(scene.selected == 5,
        "pressing up from 1 with no save should wrap selected to Exit Game (5), got " .. tostring(scene.selected))

    print("PASS: start_scene: pressing up from 1 wraps to Exit Game (5)")
end

-- Test 4: confirming while selected == 1 ("New Game") calls manager:switch
-- with something GameScene-shaped (has .camera and .drawer, which Scene.new
-- always sets on any scene subclass).
do
    reset_fs()
    local switched_with = nil
    local manager = {
        switch = function(self, scene) switched_with = scene end,
    }
    local scene = StartScene.new(manager)
    scene:on_enter()
    assert(scene.selected == 1, "sanity: scene should start with selected == 1")

    tap(scene, "return")

    assert(switched_with ~= nil, "manager:switch should have been called when confirming New Game")
    assert(switched_with.camera ~= nil, "manager:switch should be called with a GameScene-shaped arg (missing .camera)")
    assert(switched_with.drawer ~= nil, "manager:switch should be called with a GameScene-shaped arg (missing .drawer)")

    print("PASS: start_scene: confirming New Game (selected == 1) calls manager:switch with a GameScene-shaped arg")
end

-- Test 5: confirming while selected == 5 ("Exit Game") calls love.event.quit.
-- love.event is the real LOVE module under --headless (conf.lua only
-- disables window/graphics/audio/sound/joystick/touch/video), and
-- lua/headless/stubs.lua does not stub love.event at all. Rather than
-- actually invoking the real quit (which enqueues a real LOVE "quit" event),
-- spy on it locally: save the original, swap in a recording stub, restore
-- it afterward.
do
    reset_fs()
    local manager = {}
    local scene = StartScene.new(manager)
    scene:on_enter()

    -- No save present, so pressing up from 1 wraps straight past Continue
    -- (2), Players (3), and Settings (4) and lands directly on Exit Game (5).
    tap(scene, "up")
    assert(scene.selected == 5, "sanity: scene should be on Exit Game (selected == 5) before confirming")

    local quit_called = false
    local original_quit = love.event.quit
    love.event.quit = function(...) quit_called = true end

    tap(scene, "return")

    love.event.quit = original_quit

    assert(quit_called, "love.event.quit should have been called when confirming Exit Game")

    print("PASS: start_scene: confirming Exit Game (selected == 5) calls love.event.quit")
end

-- Test 8: with no save present, confirming while selected == 2 ("Continue")
-- is a no-op -- manager:switch should never be called.
do
    reset_fs()
    local switched_with = nil
    local manager = {
        switch = function(self, scene) switched_with = scene end,
    }
    local scene = StartScene.new(manager)
    scene:on_enter()
    assert(scene._has_save == false, "sanity: _has_save should be false with no save file")

    scene.selected = 2
    tap(scene, "return")

    assert(switched_with == nil,
        "confirming Continue with no save present should be a no-op; manager:switch should never be called")

    print("PASS: start_scene: confirming Continue with no save present is a no-op")
end

-- Test 9: with a save file present, on_enter() sets _has_save == true.
do
    reset_fs()
    Save.write(make_save())

    local manager = {}
    local scene = StartScene.new(manager)
    scene:on_enter()

    assert(scene._has_save == true, "on_enter() should set _has_save == true when a save file is present")

    print("PASS: start_scene: on_enter() sets _has_save == true when a save file is present")
end

-- Test 10: with a save file present, confirming while selected == 2
-- ("Continue") calls manager:switch with a GameScene-shaped arg and restores
-- GameState's fields from the save.
do
    reset_fs()
    Save.write(make_save())
    GameState:reset()
    assert(GameState.solved_count == 0, "sanity: reset() should zero solved_count before continuing")

    local switched_with = nil
    local manager = {
        switch = function(self, scene) switched_with = scene end,
    }
    local scene = StartScene.new(manager)
    scene:on_enter()
    assert(scene._has_save == true, "sanity: _has_save should be true with a save file present")

    scene.selected = 2
    tap(scene, "return")

    assert(switched_with ~= nil, "manager:switch should have been called when confirming Continue with a save present")
    assert(switched_with.camera ~= nil, "manager:switch should be called with a GameScene-shaped arg (missing .camera)")
    assert(switched_with.drawer ~= nil, "manager:switch should be called with a GameScene-shaped arg (missing .drawer)")

    assert(GameState.solved_count == 2,
        "confirming Continue should restore GameState.solved_count from the save, got " .. tostring(GameState.solved_count))
    assert(GameState.active_count == 1,
        "confirming Continue should restore GameState.active_count from the save, got " .. tostring(GameState.active_count))
    assert(GameState.solved_by_tier.easy == 2,
        "confirming Continue should restore GameState.solved_by_tier.easy from the save, got " .. tostring(GameState.solved_by_tier.easy))
    assert(GameState:is_seen("easy", "assets/puzzles/easy/1.png") == true,
        "confirming Continue should restore GameState's seen table from the save")

    print("PASS: start_scene: confirming Continue with a save present calls manager:switch and restores GameState")
end

-- Test 11: down/up skip-logic depends on whether a save is present -- with a
-- save, Continue (2) is no longer skipped; without one, navigation still
-- skips straight to Players (3).
do
    reset_fs()
    Save.write(make_save())
    local manager = {}
    local scene_with_save = StartScene.new(manager)
    scene_with_save:on_enter()
    assert(scene_with_save._has_save == true, "sanity: _has_save should be true with a save file present")

    tap(scene_with_save, "s")
    assert(scene_with_save.selected == 2,
        "pressing down from 1 with a save present should land on Continue (2), got " .. tostring(scene_with_save.selected))

    reset_fs()
    local scene_without_save = StartScene.new(manager)
    scene_without_save:on_enter()
    assert(scene_without_save._has_save == false, "sanity: _has_save should be false with no save file")

    tap(scene_without_save, "s")
    assert(scene_without_save.selected == 3,
        "pressing down from 1 with no save should skip Continue and land on Players (3), got " .. tostring(scene_without_save.selected))

    print("PASS: start_scene: down-navigation skip-logic depends on whether a save is present")
end

-- Test 12: confirming New Game resets GameState. GameState is a
-- process-lifetime singleton, and New Game can now run more than once per
-- process (via ESC returning to the start menu -- see game/scenes/game_scene.lua's
-- on_exit -- and choosing New Game again), so a dirty GameState left over
-- from a prior, abandoned game must not leak into the next one: leftover
-- active_count would wrongly count against GameState.MAX_ACTIVE_PUZZLES,
-- and leftover `seen` entries would wrongly suppress puzzle images that
-- should be selectable again in a genuinely fresh game.
do
    reset_fs()
    GameState:reset()
    GameState:mark_seen("easy", "assets/puzzles/easy/1.png")
    GameState:puzzle_started()
    GameState:puzzle_started()
    GameState:puzzle_started()
    assert(GameState.active_count == 3, "sanity: active_count should be 3 before New Game")

    local manager = {
        switch = function(self, scene) end,
    }
    local scene = StartScene.new(manager)
    scene:on_enter()
    scene.selected = 1
    scene:_confirm()

    assert(GameState.active_count == 0,
        "confirming New Game should reset GameState.active_count, got " .. tostring(GameState.active_count))
    assert(GameState:is_seen("easy", "assets/puzzles/easy/1.png") == false,
        "confirming New Game should reset GameState's seen table")

    print("PASS: start_scene: confirming New Game resets GameState")
end

-- Test 13: the start menu's item list includes a "Players: 1" row (index 3)
-- by default, reflecting self.player_count == 1.
do
    reset_fs()
    local manager = {}
    local scene = StartScene.new(manager)
    scene:on_enter()

    assert(scene.player_count == 1,
        "StartScene.new should start with player_count == 1, got " .. tostring(scene.player_count))
    assert(scene.items[3] == "Players: 1",
        "items[3] should read 'Players: 1' by default, got " .. tostring(scene.items[3]))

    print("PASS: start_scene: default Players row reads 'Players: 1'")
end

-- Test 14: navigating to the Players row (index 3) and pressing right
-- toggles player_count from 1 -> 2; pressing left toggles it back to 1. The
-- "Players: N" label (items[3]) stays in sync with the toggled value.
-- Requires a connected controller (see Test 14b) -- wrapped in
-- with_joysticks so the toggle is actually allowed to reach 2.
do
    reset_fs()
    with_joysticks({ fake_stick() }, function()
        local manager = {}
        local scene = StartScene.new(manager)
        scene:on_enter()

        tap(scene, "s")
        assert(scene.selected == 3,
            "sanity: down from 1 with no save should land on Players (3), got " .. tostring(scene.selected))

        tap(scene, "d")
        assert(scene.player_count == 2,
            "pressing right on Players row should toggle player_count to 2, got " .. tostring(scene.player_count))
        assert(scene.items[3] == "Players: 2",
            "items[3] should read 'Players: 2' after toggling, got " .. tostring(scene.items[3]))

        tap(scene, "a")
        assert(scene.player_count == 1,
            "pressing left on Players row should toggle player_count back to 1, got " .. tostring(scene.player_count))
        assert(scene.items[3] == "Players: 1",
            "items[3] should read 'Players: 1' after toggling back, got " .. tostring(scene.items[3]))
    end)

    print("PASS: start_scene: left/right on Players row toggles player_count between 1 and 2")
end

-- Test 14b: with no controller connected (the default in this test file's
-- headless environment), pressing left/right/confirm on the Players row
-- does not toggle player_count past 1 -- 2P requires a second physical
-- input device, so the toggle is disabled without one.
do
    reset_fs()
    local manager = {}
    local scene = StartScene.new(manager)
    scene:on_enter()
    assert(scene._has_controller == false, "sanity: no controller should be detected in this test's headless environment")

    tap(scene, "s")
    assert(scene.selected == 3,
        "sanity: down from 1 with no save should land on Players (3), got " .. tostring(scene.selected))

    tap(scene, "d")
    assert(scene.player_count == 1,
        "pressing right on Players row with no controller connected should not toggle player_count, got " .. tostring(scene.player_count))
    assert(scene.items[3] == "Players: 1",
        "items[3] should stay 'Players: 1' with no controller connected, got " .. tostring(scene.items[3]))

    tap(scene, "return")
    assert(scene.player_count == 1,
        "confirming on Players row with no controller connected should not toggle player_count, got " .. tostring(scene.player_count))

    print("PASS: start_scene: Players row toggle is disabled with no controller connected")
end

-- Test 14c: navigating away from the Players row after toggling to 2 must
-- NOT silently revert player_count back to 1 just because a later update()
-- tick happens to see no controller (e.g. a one-frame joystick-enumeration
-- hiccup while merely moving the selection cursor) -- only an explicit
-- toggle keypress or the confirm-time clamp (Test 14d) may change
-- player_count. This guards against the exact bug class this test replaced:
-- a continuous per-frame recheck used to zero out a deliberate 2P
-- selection before the player ever reached confirm.
do
    reset_fs()
    local manager = {}
    local scene = StartScene.new(manager)
    scene:on_enter()

    with_joysticks({ fake_stick() }, function()
        tap(scene, "s")
        tap(scene, "d")
        assert(scene.player_count == 2, "sanity: toggling right with a controller connected should set player_count to 2")
    end)

    -- with_joysticks above has restored this test file's default,
    -- always-empty headless stub. Navigate away from the Players row (as a
    -- real player would while heading to New Game) -- several plain
    -- update() ticks with no controller present must not touch
    -- player_count.
    tap(scene, "up")
    scene:update(1 / 60)
    scene:update(1 / 60)
    assert(scene.player_count == 2,
        "player_count must not be silently reverted by later update() ticks with no controller present, got " .. tostring(scene.player_count))
    assert(scene.items[3] == "Players: 2",
        "items[3] must stay 'Players: 2' -- only an explicit toggle or confirm-time clamp may change it, got " .. tostring(scene.items[3]))

    print("PASS: start_scene: player_count is not silently reverted by later update() ticks after navigating away from the Players row")
end

-- Test 14d: confirming New Game with player_count toggled to 2 but no
-- controller connected at confirm time falls back to 1P (GameState.player_count
-- == 1, switches to GameScene) instead of routing to a ControllerSelectScene
-- with nothing to claim a second device.
do
    reset_fs()
    GameState:reset()

    local switched_with = nil
    local manager = {
        switch = function(self, scene) switched_with = scene end,
    }
    local scene = StartScene.new(manager)

    with_joysticks({ fake_stick() }, function()
        scene:on_enter()
        tap(scene, "s")
        tap(scene, "d")
        assert(scene.player_count == 2, "sanity: toggling right with a controller connected should set player_count to 2")
        tap(scene, "up")
    end)

    -- Controller gone by the time New Game is confirmed.
    tap(scene, "return")

    assert(switched_with ~= nil, "confirming New Game should have called manager:switch")
    assert(GameState.player_count == 1,
        "confirming New Game with no controller connected should clamp GameState.player_count to 1, got " .. tostring(GameState.player_count))
    assert(switched_with.escape_to_menu == nil,
        "confirming New Game with no controller connected should switch to a GameScene, not a ControllerSelectScene")

    GameState:reset()
    print("PASS: start_scene: confirming New Game with player_count == 2 but no controller connected falls back to 1P")
end

-- Test 15: confirming while the Players row (3) is selected toggles
-- player_count instead of running _confirm()'s normal per-index branch --
-- manager:switch and love.event.quit must never fire from this row.
-- Requires a connected controller, since confirm-toggling to 2 is subject
-- to the same no-controller gating as left/right (Test 14b).
do
    reset_fs()
    local switched_with = nil
    local manager = {
        switch = function(self, scene) switched_with = scene end,
    }
    local scene = StartScene.new(manager)

    with_joysticks({ fake_stick() }, function()
        scene:on_enter()

        tap(scene, "s")
        assert(scene.selected == 3,
            "sanity: down from 1 with no save should land on Players (3), got " .. tostring(scene.selected))

        local quit_called = false
        local original_quit = love.event.quit
        love.event.quit = function(...) quit_called = true end

        tap(scene, "return")

        love.event.quit = original_quit

        assert(scene.player_count == 2,
            "confirming on Players row should toggle player_count to 2, got " .. tostring(scene.player_count))
        assert(switched_with == nil, "confirming on Players row should never call manager:switch")
        assert(not quit_called, "confirming on Players row should never call love.event.quit")
    end)

    print("PASS: start_scene: confirming on Players row toggles player_count instead of switching or quitting")
end

-- Test 16: toggling Players to 2 then confirming New Game carries the value
-- onto GameState.player_count -- start_scene.lua's _confirm branch for
-- selected == 1 runs GameState:reset() first and then assigns
-- GameState.player_count = self.player_count, so the toggled value survives
-- the reset. Wrapped in with_joysticks so the initial toggle to 2 is allowed
-- (Test 14b) and doesn't snap back before New Game is confirmed (Test 14c).
do
    reset_fs()
    GameState:reset()

    local switched_with = nil
    local manager = {
        switch = function(self, scene) switched_with = scene end,
    }
    local scene = StartScene.new(manager)

    with_joysticks({ fake_stick() }, function()
        scene:on_enter()

        tap(scene, "s")
        assert(scene.selected == 3,
            "sanity: down from 1 with no save should land on Players (3), got " .. tostring(scene.selected))

        tap(scene, "d")
        assert(scene.player_count == 2,
            "sanity: toggling right should set player_count to 2, got " .. tostring(scene.player_count))

        tap(scene, "up")
        assert(scene.selected == 1,
            "sanity: up from Players (3) with no save should skip Continue and land back on New Game (1), got " .. tostring(scene.selected))

        tap(scene, "return")
    end)

    assert(switched_with ~= nil, "confirming New Game should have called manager:switch")
    assert(GameState.player_count == 2,
        "confirming New Game with player_count toggled to 2 should set GameState.player_count == 2, got " .. tostring(GameState.player_count))

    GameState:reset()
    print("PASS: start_scene: confirming New Game with Players toggled to 2 sets GameState.player_count == 2")
end

-- Test 17: pressing up repeatedly cycles through all 5 items, still skipping
-- Continue (2) whenever there's no save -- reverse-direction complement to
-- Test 2's forward-direction cycle, now that the menu has grown to 5 items.
do
    reset_fs()
    local manager = {}
    local scene = StartScene.new(manager)
    scene:on_enter()
    assert(scene._has_save == false, "sanity: _has_save should be false with no save file")

    tap(scene, "up")
    assert(scene.selected == 5,
        "pressing up from 1 with no save should wrap to Exit Game (5), got " .. tostring(scene.selected))

    tap(scene, "up")
    assert(scene.selected == 4,
        "pressing up from Exit Game (5) with no save should land on Settings (4), got " .. tostring(scene.selected))

    tap(scene, "up")
    assert(scene.selected == 3,
        "pressing up from Settings (4) with no save should land on Players (3), got " .. tostring(scene.selected))

    tap(scene, "up")
    assert(scene.selected == 1,
        "pressing up from Players (3) with no save should skip Continue and wrap to New Game (1), got " .. tostring(scene.selected))

    print("PASS: start_scene: up-navigation cycles 1 -> 5 -> 4 -> 3 -> 1, skipping disabled Continue")
end

-- Test 18: confirming New Game with the Players toggle left at 1 still
-- switches manager.current to a GameScene-shaped scene (regression check
-- against Task D's ControllerSelectScene routing change) -- specifically,
-- the switched-to scene must NOT carry ControllerSelectScene's
-- `escape_to_menu` marker, since GameScene never sets that field.
do
    reset_fs()
    local switched_with = nil
    local manager = {
        switch = function(self, scene) switched_with = scene end,
    }
    local scene = StartScene.new(manager)
    scene:on_enter()
    assert(scene.player_count == 1, "sanity: player_count should start at 1")
    assert(scene.selected == 1, "sanity: scene should start with selected == 1")

    tap(scene, "return")

    assert(switched_with ~= nil, "manager:switch should have been called when confirming New Game")
    assert(switched_with.camera ~= nil, "manager:switch should be called with a GameScene-shaped arg (missing .camera)")
    assert(switched_with.drawer ~= nil, "manager:switch should be called with a GameScene-shaped arg (missing .drawer)")
    assert(switched_with.escape_to_menu == nil,
        "New Game with player_count == 1 should switch to a GameScene, not ControllerSelectScene (unexpected escape_to_menu marker)")

    GameState:reset()
    print("PASS: start_scene: confirming New Game with player_count == 1 switches to a GameScene")
end

-- Test 19: confirming New Game with the Players toggle cycled to 2 switches
-- manager.current to a ControllerSelectScene instead of a GameScene --
-- verified via the `escape_to_menu == true` marker ControllerSelectScene.new
-- sets (per docs/checklists/two-player-support.md's fixed contract), since
-- GameScene never sets that field. Wrapped in with_joysticks so the toggle
-- to 2 is allowed and doesn't snap back before confirming (Tests 14b/14c).
do
    reset_fs()
    local switched_with = nil
    local manager = {
        switch = function(self, scene) switched_with = scene end,
    }
    local scene = StartScene.new(manager)

    with_joysticks({ fake_stick() }, function()
        scene:on_enter()

        tap(scene, "s")
        assert(scene.selected == 3,
            "sanity: down from 1 with no save should land on Players (3), got " .. tostring(scene.selected))

        tap(scene, "d")
        assert(scene.player_count == 2,
            "sanity: toggling right should set player_count to 2, got " .. tostring(scene.player_count))

        tap(scene, "up")
        assert(scene.selected == 1,
            "sanity: up from Players (3) with no save should skip Continue and land back on New Game (1), got " .. tostring(scene.selected))

        tap(scene, "return")
    end)

    assert(switched_with ~= nil, "manager:switch should have been called when confirming New Game")
    assert(switched_with.escape_to_menu == true,
        "New Game with player_count == 2 should switch to a ControllerSelectScene (missing escape_to_menu == true marker)")

    GameState:reset()
    print("PASS: start_scene: confirming New Game with player_count == 2 switches to a ControllerSelectScene")
end

-- Test 20: confirming Continue where the loaded save's game_state.player_count
-- is 1 (the default make_save() produces, since GameState:apply_save defaults
-- a missing player_count to 1) still switches to a GameScene with the save's
-- scene data threaded through -- regression check mirroring Test 10's
-- existing GameScene-shaped assertions, plus an explicit check (as Test 10
-- does not) that the save's scene table reached the new scene via
-- `_save_data`.
do
    reset_fs()
    local save = make_save()
    Save.write(save)
    GameState:reset()

    local switched_with = nil
    local manager = {
        switch = function(self, scene) switched_with = scene end,
    }
    local scene = StartScene.new(manager)
    scene:on_enter()
    assert(scene._has_save == true, "sanity: _has_save should be true with a save file present")

    scene.selected = 2
    tap(scene, "return")

    assert(switched_with ~= nil, "manager:switch should have been called when confirming Continue")
    assert(switched_with.camera ~= nil, "manager:switch should be called with a GameScene-shaped arg (missing .camera)")
    assert(switched_with.drawer ~= nil, "manager:switch should be called with a GameScene-shaped arg (missing .drawer)")
    assert(switched_with.escape_to_menu == nil,
        "Continue restoring player_count == 1 should switch to a GameScene, not ControllerSelectScene (unexpected escape_to_menu marker)")
    -- Save.write()/Save.read() round-trip through Lua chunk (de)serialization
    -- (see lua/core/save.lua), so switched_with._save_data is never the same
    -- table object as save.scene -- compare field values instead, matching
    -- how tests/test_save.lua's round-trip assertions already do this
    -- against make_save()'s literal x=320/y=192.
    assert(switched_with._save_data ~= nil, "Continue should thread the save's scene data through to GameScene.new via _save_data")
    assert(switched_with._save_data.player.x == 320,
        "Continue's threaded scene data should preserve player.x from the save, got " .. tostring(switched_with._save_data.player.x))
    assert(switched_with._save_data.player.y == 192,
        "Continue's threaded scene data should preserve player.y from the save, got " .. tostring(switched_with._save_data.player.y))

    GameState:reset()
    print("PASS: start_scene: confirming Continue restoring player_count == 1 switches to a GameScene with scene data threaded through")
end

-- Test 21: confirming Continue with the start-screen "Players" toggle cycled
-- to 2 switches to a ControllerSelectScene instead of a GameScene, with the
-- save's scene data threaded through to it (per
-- ControllerSelectScene.new(manager, save_data)'s contract, mirrored the same
-- way Test 20 verifies scene-data threading for GameScene). The live toggle
-- -- not the save's own game_state.player_count -- is what governs this
-- routing decision (mirrors Test 19's New Game pattern), since StartScene is
-- freshly constructed on every visit to the menu and self.player_count
-- always reflects the player's current, explicit choice rather than
-- whatever was true when the save was written. Requires a connected
-- controller at confirm time -- a live 2P toggle is subject to the same
-- confirm-time clamp (Test 14d) as a restored one.
do
    reset_fs()
    local save = make_save()
    Save.write(save)
    GameState:reset()

    local switched_with = nil
    local manager = {
        switch = function(self, scene) switched_with = scene end,
    }
    local scene = StartScene.new(manager)

    with_joysticks({ fake_stick() }, function()
        scene:on_enter()
        assert(scene._has_save == true, "sanity: _has_save should be true with a save file present")

        scene.selected = 3
        tap(scene, "d")
        assert(scene.player_count == 2,
            "sanity: toggling right should set player_count to 2, got " .. tostring(scene.player_count))

        scene.selected = 2
        tap(scene, "return")
    end)

    assert(switched_with ~= nil, "manager:switch should have been called when confirming Continue")
    assert(GameState.player_count == 2,
        "confirming Continue with the Players toggle at 2 and a controller connected should set GameState.player_count to 2, got " .. tostring(GameState.player_count))
    assert(switched_with.escape_to_menu == true,
        "Continue with the Players toggle at 2 should switch to a ControllerSelectScene (missing escape_to_menu == true marker)")
    -- Same round-trip caveat as Test 20: compare field values, not table
    -- identity, since Save.write()/Save.read() serialize through a Lua chunk.
    assert(switched_with._save_data ~= nil, "Continue should thread the save's scene data through to ControllerSelectScene.new via _save_data")
    assert(switched_with._save_data.player.x == 320,
        "Continue's threaded scene data should preserve player.x from the save, got " .. tostring(switched_with._save_data.player.x))
    assert(switched_with._save_data.player.y == 192,
        "Continue's threaded scene data should preserve player.y from the save, got " .. tostring(switched_with._save_data.player.y))

    GameState:reset()
    print("PASS: start_scene: confirming Continue with the Players toggle at 2 switches to a ControllerSelectScene with scene data threaded through")
end

-- Test 21c: confirming Continue where the loaded save's own
-- game_state.player_count is 2 but the start-screen Players toggle was left
-- at its default of 1 goes straight to a GameScene (1P), not
-- ControllerSelectScene -- proving the live toggle governs this routing
-- decision, not whatever player_count happened to be persisted in the save.
do
    reset_fs()
    local save = make_save()
    save.game_state.player_count = 2
    Save.write(save)
    GameState:reset()

    local switched_with = nil
    local manager = {
        switch = function(self, scene) switched_with = scene end,
    }
    local scene = StartScene.new(manager)
    scene:on_enter()
    assert(scene._has_save == true, "sanity: _has_save should be true with a save file present")
    assert(scene.player_count == 1, "sanity: player_count toggle should default to 1")

    scene.selected = 2
    with_joysticks({ fake_stick() }, function()
        tap(scene, "return")
    end)

    assert(switched_with ~= nil, "manager:switch should have been called when confirming Continue")
    assert(GameState.player_count == 1,
        "confirming Continue with the Players toggle left at 1 should not adopt the save's player_count == 2, got " .. tostring(GameState.player_count))
    assert(switched_with.escape_to_menu == nil,
        "Continue with the Players toggle left at 1 should switch to a GameScene, not a ControllerSelectScene, even though the save's player_count == 2")

    GameState:reset()
    print("PASS: start_scene: confirming Continue with the Players toggle left at 1 ignores the save's player_count == 2 and switches to a GameScene")
end

-- Test 21b: confirming Continue where the loaded save's game_state.player_count
-- is 2 but no controller is connected at confirm time clamps back to 1P
-- (GameState.player_count == 1, switches to GameScene) instead of routing to
-- a ControllerSelectScene with nothing to claim a second device.
do
    reset_fs()
    local save = make_save()
    save.game_state.player_count = 2
    Save.write(save)
    GameState:reset()

    local switched_with = nil
    local manager = {
        switch = function(self, scene) switched_with = scene end,
    }
    local scene = StartScene.new(manager)
    scene:on_enter()

    scene.selected = 2
    tap(scene, "return")

    assert(switched_with ~= nil, "manager:switch should have been called when confirming Continue")
    assert(GameState.player_count == 1,
        "confirming Continue with no controller connected should clamp GameState.player_count to 1, got " .. tostring(GameState.player_count))
    assert(switched_with.escape_to_menu == nil,
        "Continue with no controller connected should switch to a GameScene, not a ControllerSelectScene")

    GameState:reset()
    print("PASS: start_scene: confirming Continue restoring player_count == 2 but no controller connected falls back to 1P")
end

-- Test 22: the start menu's item list includes a "Settings" row at index 4
-- (inserted immediately before "Exit Game"), and confirming while selected
-- == 4 invokes the on_settings callback passed to
-- StartScene.new(manager, on_settings) -- neither manager:switch nor
-- love.event.quit should fire from this row.
do
    reset_fs()
    local switched_with = nil
    local manager = {
        switch = function(self, scene) switched_with = scene end,
    }
    local on_settings_called = false
    local scene = StartScene.new(manager, function() on_settings_called = true end)
    scene:on_enter()

    assert(scene.items[4] == "Settings",
        "items[4] should read 'Settings', got " .. tostring(scene.items[4]))

    local quit_called = false
    local original_quit = love.event.quit
    love.event.quit = function(...) quit_called = true end

    scene.selected = 4
    tap(scene, "return")

    love.event.quit = original_quit

    assert(on_settings_called, "confirming Settings (selected == 4) should invoke the on_settings callback")
    assert(switched_with == nil, "confirming Settings should never call manager:switch")
    assert(not quit_called, "confirming Settings should never call love.event.quit")

    print("PASS: start_scene: confirming Settings (selected == 4) invokes the on_settings callback")
end

-- Test 23: StartScene.new(manager) with on_settings omitted -- the common
-- case for every other call site in this file -- must not error when
-- Settings is selected and confirmed; selecting it with no callback present
-- is a silent no-op.
do
    reset_fs()
    local manager = {}
    local scene = StartScene.new(manager)
    scene:on_enter()

    assert(scene.on_settings == nil, "sanity: on_settings should be nil when omitted from StartScene.new")

    scene.selected = 4
    local ok, err = pcall(function() tap(scene, "return") end)

    assert(ok, "confirming Settings with on_settings omitted should not error, got: " .. tostring(err))

    print("PASS: start_scene: confirming Settings with on_settings omitted is a silent no-op and does not error")
end

-- Test 24: :draw() doesn't error, including the disabled-Continue branch
-- (no save present) and the normal/selected branch -- regression coverage
-- for the panel_normal.png/panel_selected.png image-draw swap (see
-- docs/design/menu-ui-pngs.md): :draw() now calls love.graphics.draw with
-- an Image instead of only love.graphics.rectangle, and this must still be
-- safe under the headless love.graphics stub (lua/headless/stubs.lua stubs
-- newImage/draw so no real GPU/window is needed).
do
    reset_fs()
    local manager = {}
    local scene = StartScene.new(manager)
    scene:on_enter()
    assert(scene._has_save == false, "sanity: no save present, so the Continue row is disabled")

    local ok, err = pcall(function() scene:draw() end)
    assert(ok, "StartScene:draw() should not error with the disabled Continue row present, got: " .. tostring(err))

    scene.selected = 3
    ok, err = pcall(function() scene:draw() end)
    assert(ok, "StartScene:draw() should not error with a non-default row selected, got: " .. tostring(err))

    print("PASS: start_scene: :draw() does not error, including the disabled Continue row, image-backed rows included")
end

print("ALL TESTS PASSED")

-- Leave the process-lifetime GameState singleton clean for whichever test
-- file the headless runner executes next.
GameState:reset()
