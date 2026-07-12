-- test_settings_scene.lua
-- Unit tests for game/scenes/settings_scene.lua: row navigation (wrap
-- semantics), opaque-vs-overlay top-level item set + confirm behavior, the
-- Fullscreen toggle + persistence, the Keybinds subscreen (entry/exit, row
-- order, rebind-capture including duplicate-key rejection), the "all bound"
-- gate, :gamepadpressed(button) nav/confirm/start, and the
-- _keyboard_rebindable propagation to live scene.player/scene.player2
-- Input instances. Matches tests/test_start_scene.lua's tap()/with_joysticks()
-- helper style (duplicated locally per this repo's no-shared-test-helpers
-- convention) and tests/test_save.lua's in-memory love.filesystem stub
-- pattern.

local SettingsScene = require("game/scenes/settings_scene")
local SettingsState = require("game/settings_state")
local Save          = require("lua/core/save")

-- Stub love.filesystem with an in-memory store so tests don't touch disk,
-- exactly matching tests/test_save.lua's / tests/test_start_scene.lua's
-- pattern -- Save.write_settings()/Save.read_settings() (and the plain
-- save.dat trio, exercised via the overlay Main Menu row) must never touch
-- real disk in this file.
local _fs = {}
love.filesystem.write   = function(path, content) _fs[path] = content end
love.filesystem.read    = function(path) return _fs[path], _fs[path] and #_fs[path] or 0 end
love.filesystem.getInfo = function(path) return _fs[path] and { type = "file" } or nil end

local function reset_fs() _fs = {} end

-- Builds a fake joystick. pressed_buttons: set of button-name -> true.
-- axes: table of axis-name -> number (defaults to 0 for unset axes).
-- Matches tests/test_input_gamepad.lua's fake_stick shape (a superset of
-- tests/test_start_scene.lua's always-false fake_stick) -- duplicated
-- locally per this repo's no-shared-test-helpers convention, since this
-- file needs to actually drive a mapped button press through
-- self.input:update()'s own gamepad polling, not just always report "not
-- pressed".
local function fake_stick(pressed_buttons, axes)
    pressed_buttons = pressed_buttons or {}
    axes = axes or {}
    return {
        isGamepadDown  = function(_, button) return pressed_buttons[button] == true end,
        getGamepadAxis = function(_, axis) return axes[axis] or 0 end,
    }
end

-- Monkey-patches love.joystick.getJoysticks to return `sticks` for the
-- duration of fn(), then restores the original stub (mirrors
-- tests/test_start_scene.lua's with_joysticks).
local function with_joysticks(sticks, fn)
    local original = love.joystick.getJoysticks
    love.joystick.getJoysticks = function() return sticks end
    local ok, err = pcall(fn)
    love.joystick.getJoysticks = original
    if not ok then
        error(err, 0)
    end
end

-- SettingsScene owns a *real* lua/core/input.lua instance for its own
-- up/down/confirm menu-nav, exactly like StartScene. Under --headless,
-- love.keyboard.isDown is stubbed to always return false, so we locally
-- fake it around scene:update(dt) calls to drive real rising-edge key
-- presses through the actual Input class -- identical to
-- tests/test_start_scene.lua's tap() helper.
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

-- Test 1: top-level row navigation (3 rows: Fullscreen/Keybinds/Back-or-
-- Main-Menu) wraps in both directions, per SettingsScene:_nav's modulo
-- wraparound (settings_scene.lua:146-151) -- same wrap behavior StartScene
-- uses, just confirmed here against the real implementation rather than
-- assumed.
do
    reset_fs()
    SettingsState:reset()
    local scene = SettingsScene.new()
    scene:open(false, nil, nil)
    assert(scene.selected == 1, "opening the settings scene should start with selected == 1, got " .. tostring(scene.selected))

    tap(scene, "s")
    assert(scene.selected == 2, "pressing down from row 1 should land on row 2, got " .. tostring(scene.selected))

    tap(scene, "s")
    assert(scene.selected == 3, "pressing down from row 2 should land on row 3, got " .. tostring(scene.selected))

    tap(scene, "s")
    assert(scene.selected == 1, "pressing down from row 3 (the last top-level row) should wrap to row 1, got " .. tostring(scene.selected))

    tap(scene, "w")
    assert(scene.selected == 3, "pressing up from row 1 should wrap to row 3 (the last top-level row), got " .. tostring(scene.selected))

    print("PASS: settings_scene: top-level row navigation wraps in both directions across the 3 rows")
end

-- Test 2: opaque mode shows "Back" as row 3; overlay mode shows "Main Menu"
-- instead -- SettingsScene:_top_item_label(3), settings_scene.lua:153-161.
do
    reset_fs()
    SettingsState:reset()
    local scene = SettingsScene.new()

    scene:open(true, nil, nil)
    assert(scene._opaque == true, "opening with opaque == true should set self._opaque == true")
    assert(scene:_top_item_label(3) == "Back",
        "opaque mode should show 'Back' as row 3, got " .. tostring(scene:_top_item_label(3)))

    scene:open(false, nil, nil)
    assert(scene._opaque == false, "opening with opaque == false should set self._opaque == false")
    assert(scene:_top_item_label(3) == "Main Menu",
        "overlay mode should show 'Main Menu' as row 3, got " .. tostring(scene:_top_item_label(3)))

    print("PASS: settings_scene: opaque mode shows 'Back' as row 3; overlay mode shows 'Main Menu' instead")
end

-- Test 3: opaque mode's "Back" row (row 3) closes the overlay via :close(),
-- and requires no live scene/manager to do so.
do
    reset_fs()
    SettingsState:reset()
    local scene = SettingsScene.new()
    scene:open(true, nil, nil)
    scene.selected = 3
    assert(scene.is_open == true, "sanity: scene should be open before confirming Back")

    tap(scene, "return")

    assert(scene.is_open == false, "confirming 'Back' in opaque mode should close the settings scene")
    print("PASS: settings_scene: confirming opaque-mode 'Back' (row 3) calls :close()")
end

-- Test 4: overlay mode's "Main Menu" row (row 3) writes a save (via
-- Save.write, the same {game_state=, scene=} shape main.lua's own save path
-- writes) using the live `scene`'s :to_save(), switches away via the
-- `manager` passed to :open() (manager:switch called with a StartScene
-- instance), and then closes the overlay -- settings_scene.lua:163-191.
do
    reset_fs()
    SettingsState:reset()

    local fake_scene = { to_save = function(self) return { marker = "from-fake-scene" } end }
    local switched_with = nil
    local manager = { switch = function(self, s) switched_with = s end }

    local scene = SettingsScene.new()
    scene:open(false, fake_scene, manager)
    scene.selected = 3
    assert(scene:_top_item_label(3) == "Main Menu", "sanity: row 3 should read 'Main Menu' in overlay mode")

    tap(scene, "return")

    assert(switched_with ~= nil, "confirming Main Menu should call manager:switch")
    assert(switched_with.items ~= nil and switched_with.items[1] == "New Game",
        "manager:switch should be called with a StartScene-shaped instance (missing/mismatched .items)")
    assert(scene.is_open == false, "confirming Main Menu should close the settings overlay")

    assert(Save.exists() == true, "confirming Main Menu should write a save via Save.write")
    local saved = Save.read()
    assert(saved.game_state ~= nil, "the Main Menu save should include a game_state snapshot")
    assert(saved.scene ~= nil and saved.scene.marker == "from-fake-scene",
        "the Main Menu save should thread the live scene's :to_save() through as the scene= field")

    print("PASS: settings_scene: overlay-mode 'Main Menu' (row 3) saves, switches to StartScene via manager, and closes")
end

-- Test 5: the Fullscreen row (row 1) toggles SettingsState.fullscreen (flips
-- the flag, flips the label "Fullscreen" <-> "Window") and persists via
-- Save.write_settings(SettingsState:to_save()) -- settings_scene.lua:177-180.
do
    reset_fs()
    SettingsState:reset()
    local scene = SettingsScene.new()
    scene:open(false, nil, nil)

    assert(scene:_top_item_label(1) == "Fullscreen", "sanity: row 1 should read 'Fullscreen' before toggling")
    assert(SettingsState.fullscreen == false, "sanity: fullscreen should default to false")
    assert(Save.settings_exists() == false, "sanity: no settings.dat should exist before any toggle")

    tap(scene, "return") -- selected starts at row 1

    assert(SettingsState.fullscreen == true,
        "confirming the Fullscreen row should call SettingsState:toggle_fullscreen(), flipping .fullscreen to true")
    assert(scene:_top_item_label(1) == "Window", "row 1's label should flip to 'Window' once fullscreen is on")
    assert(Save.settings_exists() == true,
        "toggling fullscreen should persist via Save.write_settings (settings.dat should now exist)")

    local saved = Save.read_settings()
    assert(saved ~= nil, "Save.read_settings() should return the persisted settings after toggling fullscreen")
    assert(saved.fullscreen == true, "the persisted settings.dat should reflect fullscreen == true")

    print("PASS: settings_scene: confirming the Fullscreen row toggles SettingsState.fullscreen and persists via Save.write_settings")
end

-- Test 6: entering the Keybinds subscreen (row 2) resets selected to row 1
-- of the subscreen's row list, and its row navigation wraps across all 6
-- rows (SettingsScene:_row_count returns #KEYBIND_ACTIONS == 6 while
-- self._subscreen == "keybinds", settings_scene.lua:139-144).
do
    reset_fs()
    SettingsState:reset()
    local scene = SettingsScene.new()
    scene:open(false, nil, nil)
    scene.selected = 2
    tap(scene, "return")

    assert(scene._subscreen == "keybinds", "confirming the Keybinds row should enter the Keybinds subscreen")
    assert(scene.selected == 1, "entering the Keybinds subscreen should reset selected to row 1")

    for i = 2, 6 do
        tap(scene, "s")
        assert(scene.selected == i, "pressing down should advance to Keybinds row " .. i .. ", got " .. tostring(scene.selected))
    end
    tap(scene, "s")
    assert(scene.selected == 1, "pressing down from Keybinds row 6 should wrap to row 1, got " .. tostring(scene.selected))

    tap(scene, "w")
    assert(scene.selected == 6, "pressing up from Keybinds row 1 should wrap to row 6, got " .. tostring(scene.selected))

    SettingsState:reset()
    print("PASS: settings_scene: Keybinds subscreen row navigation wraps across all 6 rows")
end

-- Test 7: the Keybinds subscreen's 6 rows are Up/Down/Left/Right/Interact/
-- Rotate Piece, in that order (KEYBIND_ACTIONS/KEYBIND_LABELS,
-- settings_scene.lua:49-50) -- verified indirectly via the rebind-capture
-- flow itself, since KEYBIND_ACTIONS is a module-local not exposed on the
-- instance: selecting row i and completing a capture must rebind exactly
-- the expected action. Also exercises the successful rebind-capture path
-- (select a row, confirm to start capturing, :keypressed(key) rebinds) and
-- its Save.write_settings persistence for each of the 6 rows.
do
    local expected_actions = { "up", "down", "left", "right", "interact", "rotate_piece" }
    for i, action in ipairs(expected_actions) do
        reset_fs()
        SettingsState:reset()
        local scene = SettingsScene.new()
        scene:open(false, nil, nil)
        scene.selected = 2
        tap(scene, "return") -- enter the Keybinds subscreen
        assert(scene._subscreen == "keybinds", "sanity: should be in the Keybinds subscreen")

        scene.selected = i
        tap(scene, "return") -- begin capturing this row's action
        assert(scene._capturing == action,
            "Keybinds row " .. i .. " should begin capturing action '" .. action .. "', got " .. tostring(scene._capturing))

        local consumed = scene:keypressed("z") -- "z" is unbound by default on every row
        assert(consumed == true, "a successful capture keypress should be consumed (return true)")
        assert(SettingsState.keybinds[action] == "z",
            "capturing row " .. i .. " and pressing 'z' should rebind SettingsState.keybinds." .. action ..
            ", got " .. tostring(SettingsState.keybinds[action]))
        assert(scene._capturing == nil, "a successful rebind should clear self._capturing")

        assert(Save.settings_exists() == true, "a successful rebind should persist via Save.write_settings")
        local saved = Save.read_settings()
        assert(saved.keybinds[action] == "z",
            "persisted settings.dat should reflect the new binding for '" .. action .. "'")
    end
    SettingsState:reset()
    print("PASS: settings_scene: the 6 Keybinds rows are Up/Down/Left/Right/Interact/Rotate Piece in order, and each rebinds + persists correctly")
end

-- Test 8: duplicate-key rejection. Capturing "down" (default "s") and
-- pressing "w" (already bound to "up") is rejected: SettingsState.keybinds
-- is left unchanged, self._shake_row is set to the index of the
-- already-bound action ("up" == KEYBIND_ACTIONS[1]), self._shake_timer ==
-- SHAKE_DURATION, and -- per settings_scene.lua:266-270's doc comment --
-- self._capturing deliberately STAYS active (the reject branch never clears
-- it), so the player can immediately retry with a different key. A
-- subsequent unused key then succeeds. Also covers: a bare modifier key
-- (e.g. "lshift") is not consumed and does not disturb capturing state, and
-- "escape" during capture cancels the capture (clears self._capturing)
-- without rebinding.
do
    reset_fs()
    SettingsState:reset()
    local scene = SettingsScene.new()
    scene:open(false, nil, nil)
    scene.selected = 2
    tap(scene, "return") -- enter Keybinds subscreen
    scene.selected = 2   -- "down" row (default key "s")
    tap(scene, "return") -- begin capturing "down"
    assert(scene._capturing == "down", "sanity: should be capturing 'down'")

    local consumed = scene:keypressed("w") -- "w" is already bound to "up"
    assert(consumed == true, "a rejected duplicate-key capture should still be consumed (return true)")
    assert(SettingsState.keybinds.down == "s",
        "a rejected duplicate-key capture must NOT rebind the action, got " .. tostring(SettingsState.keybinds.down))
    assert(scene._shake_row == 1,
        "rejecting a key already bound to 'up' (KEYBIND_ACTIONS[1]) should set self._shake_row == 1, got " .. tostring(scene._shake_row))
    assert(scene._shake_timer == 0.5,
        "a duplicate-key rejection should set self._shake_timer to SHAKE_DURATION (0.5), got " .. tostring(scene._shake_timer))
    assert(scene._capturing == "down",
        "a duplicate-key rejection must leave self._capturing active (still 'down'), not cancel it, got " .. tostring(scene._capturing))

    -- A bare modifier key is not a completed capture attempt: not consumed,
    -- capturing state undisturbed.
    local mod_consumed = scene:keypressed("lshift")
    assert(mod_consumed == false, "a bare modifier keypress during capture should not be consumed")
    assert(scene._capturing == "down", "a bare modifier keypress must not disturb an active capture")
    assert(SettingsState.keybinds.down == "s", "a bare modifier keypress must not rebind anything")

    -- Retry with an unused key succeeds even though a reject just happened.
    local retry_consumed = scene:keypressed("z")
    assert(retry_consumed == true, "retrying capture with an unused key after a reject should be consumed")
    assert(SettingsState.keybinds.down == "z",
        "retrying capture with an unused key ('z') after a reject should succeed, got " .. tostring(SettingsState.keybinds.down))
    assert(scene._capturing == nil, "a successful retry should clear self._capturing")

    -- Escape during capture cancels rather than rebinding.
    scene.selected = 3 -- "left" row
    tap(scene, "return")
    assert(scene._capturing == "left", "sanity: should be capturing 'left'")
    local esc_consumed = scene:keypressed("escape")
    assert(esc_consumed == true, "escape during capture should be consumed")
    assert(scene._capturing == nil, "escape during capture should clear self._capturing (cancel, not rebind)")
    assert(SettingsState.keybinds.left == "a", "escape during capture must not rebind the action, got " .. tostring(SettingsState.keybinds.left))

    SettingsState:reset()
    print("PASS: settings_scene: duplicate-key rejection shakes and stays capturing; modifier keys are ignored; escape cancels capture")
end

-- Test 9: the "all bound" gate (_all_bound, settings_scene.lua:75-80). Since
-- SettingsState:set_keybind never assigns nil, a gap can't arise through
-- normal rebind usage -- but SettingsState:apply_save (a real, documented
-- public method, see game/settings_state.lua:84-91) assigns
-- self.keybinds = data.keybinds verbatim with no per-key defaulting, so a
-- partial/corrupted settings.dat loaded via apply_save is a legitimate,
-- non-fabricated way to reach a genuine gap (e.g. an old or hand-edited
-- settings.dat missing a key). This is used here instead of directly
-- clobbering SettingsState.keybinds, to exercise the gate through real
-- public API surface rather than forcing an otherwise-impossible internal
-- state. With such a gap present, leaving the Keybinds subscreen via escape
-- must be blocked: self._subscreen stays "keybinds", and :keypressed("escape")
-- must still return true (consumed) -- the press WAS handled, by being
-- intentionally ignored, so main.lua's own top-level escape-closes-Settings
-- fallthrough must not also fire and close the whole overlay (see
-- game/scenes/settings_scene.lua:keypressed).
do
    reset_fs()
    SettingsState:reset()
    SettingsState:apply_save({
        version = 1,
        fullscreen = false,
        keybinds = { up = "w", down = "s", left = "a", right = "d", interact = "e" }, -- rotate_piece omitted
    })
    assert(SettingsState.keybinds.rotate_piece == nil,
        "sanity: apply_save with a partial keybinds table should leave rotate_piece unbound")

    local scene = SettingsScene.new()
    scene:open(false, nil, nil)
    scene.selected = 2
    tap(scene, "return")
    assert(scene._subscreen == "keybinds", "sanity: should be in the Keybinds subscreen")

    local consumed = scene:keypressed("escape")
    assert(consumed == true,
        "escape must still be reported as consumed when the all-bound gate blocks leaving -- "
            .. "main.lua relies on this to avoid also closing the whole Settings overlay")
    assert(scene._subscreen == "keybinds",
        "the _all_bound gate should block leaving the Keybinds subscreen while an action is unbound")

    SettingsState:reset()
    print("PASS: settings_scene: the all-bound gate blocks leaving the Keybinds subscreen when a keybind gap exists, while still reporting the escape as consumed (reached via apply_save, not fabricated internal state)")
end

-- Test 9b: sanity complement to Test 9 -- with the default, fully-bound
-- keybinds (the only state reachable through ordinary rebind usage),
-- escape DOES leave the Keybinds subscreen, landing back on the top-level
-- Keybinds row (2).
do
    reset_fs()
    SettingsState:reset()
    local scene = SettingsScene.new()
    scene:open(false, nil, nil)
    scene.selected = 2
    tap(scene, "return")
    assert(scene._subscreen == "keybinds")

    local consumed = scene:keypressed("escape")
    assert(consumed == true, "escape should be consumed when all actions are bound (the ordinary case)")
    assert(scene._subscreen == nil, "escape should clear _subscreen when all actions are bound")
    assert(scene.selected == 2, "leaving the Keybinds subscreen should land selection back on the top-level Keybinds row (2)")

    print("PASS: settings_scene: escape leaves the Keybinds subscreen when every action is bound (the gate's normal, always-passing case)")
end

-- Test 10: :gamepadpressed(button) drives the same nav/confirm behavior as
-- keyboard. dpdown/dpup move top-level selection, "a" confirms (toggling
-- Fullscreen), and gamepadpressed returns false/not-consumed when the scene
-- isn't open or while a capture is in progress.
do
    reset_fs()
    SettingsState:reset()
    local closed_scene = SettingsScene.new()
    assert(closed_scene:gamepadpressed("dpdown") == false,
        "gamepadpressed should return false/not-consumed when the settings scene is not open")

    local scene = SettingsScene.new()
    scene:open(false, nil, nil)
    assert(scene.selected == 1, "sanity: scene should open with selected == 1")

    local consumed = scene:gamepadpressed("dpdown")
    assert(consumed == true, "dpdown should be consumed by gamepad nav")
    assert(scene.selected == 2, "dpdown should move top-level selection down, got " .. tostring(scene.selected))

    consumed = scene:gamepadpressed("dpup")
    assert(consumed == true, "dpup should be consumed by gamepad nav")
    assert(scene.selected == 1, "dpup should move top-level selection back up, got " .. tostring(scene.selected))

    assert(SettingsState.fullscreen == false, "sanity: fullscreen should start false")
    consumed = scene:gamepadpressed("a")
    assert(consumed == true, "'a' should be consumed as gamepad confirm")
    assert(SettingsState.fullscreen == true,
        "gamepad confirm ('a') on the Fullscreen row should toggle SettingsState.fullscreen")

    print("PASS: settings_scene: :gamepadpressed drives top-level nav (dpdown/dpup) and confirm ('a')")
end

-- Test 11: gamepad "start" at the top level is NOT consumed by
-- SettingsScene:gamepadpressed -- closing the overlay from "start" is
-- main.lua's job (Task 6), not this scene's. Inside the Keybinds
-- subscreen, "start" IS consumed and leaves the subscreen, gated on
-- _all_bound the same way :keypressed("escape") is (settings_scene.lua:
-- 343-350) -- and while capturing, gamepadpressed never fires (capture only
-- reacts to raw keyboard :keypressed).
do
    reset_fs()
    SettingsState:reset()
    local scene = SettingsScene.new()
    scene:open(false, nil, nil)

    local consumed = scene:gamepadpressed("start")
    assert(consumed == false,
        "'start' at the top level should not be consumed by SettingsScene:gamepadpressed (main.lua owns closing)")

    scene.selected = 2
    tap(scene, "return") -- enter Keybinds subscreen
    assert(scene._subscreen == "keybinds")

    consumed = scene:gamepadpressed("start")
    assert(consumed == true, "'start' should be consumed and leave the Keybinds subscreen when every action is bound")
    assert(scene._subscreen == nil, "'start' should clear _subscreen when the all-bound gate passes")
    assert(scene.selected == 2, "'start' leaving the Keybinds subscreen should land selection back on row 2")

    -- While capturing, gamepadpressed is never consumed.
    scene.selected = 2
    tap(scene, "return") -- re-enter Keybinds subscreen
    scene.selected = 1
    tap(scene, "return") -- begin capturing "up"
    assert(scene._capturing == "up", "sanity: should be capturing 'up'")

    consumed = scene:gamepadpressed("a")
    assert(consumed == false, "gamepadpressed should not be consumed while a keyboard capture is in progress")
    assert(scene._capturing == "up", "gamepadpressed during capture should not disturb capturing state")

    SettingsState:reset()
    print("PASS: settings_scene: gamepad 'start' only closes/exits the Keybinds subscreen (never the top level), and is ignored while capturing")
end

-- Test 12: gamepad nav also works through the shared self.input instance's
-- own gamepad polling (not just the :gamepadpressed event dispatch tested
-- above) -- a connected fake joystick holding dpdown, driven through
-- scene:update(dt) inside with_joysticks(), moves the top-level selection
-- exactly like a keyboard tap() does. Confirms self.input was built with
-- gamepad_buttons = {up={"dpup"}, down={"dpdown"}, confirm={"a"}} and
-- joystick_scope = "first_two" per the design doc.
do
    reset_fs()
    SettingsState:reset()
    local scene = SettingsScene.new()
    scene:open(false, nil, nil)
    assert(scene.selected == 1, "sanity: scene should open with selected == 1")

    with_joysticks({ fake_stick({ dpdown = true }) }, function()
        scene:update(1 / 60)
    end)
    assert(scene.selected == 2,
        "a connected gamepad holding dpdown should move top-level selection down via self.input's own polling, got " .. tostring(scene.selected))

    -- Release frame (no joystick connected) resets the edge so a later
    -- press can register again -- mirrors tap()'s press/release pairing.
    scene:update(1 / 60)

    print("PASS: settings_scene: a connected gamepad's dpdown drives nav through self.input's own gamepad_buttons polling")
end

-- Test 13: _keyboard_rebindable propagation to live players (overlay mode
-- only). After a successful rebind, scene.player/scene.player2's
-- .input._map is rebuilt to SettingsState:key_map() only when
-- .input._keyboard_rebindable == true; a player whose Input isn't tagged
-- (falsy/absent, e.g. a gamepad-assigned player2) is left completely
-- untouched -- settings_scene.lua:200-211, the 2P split-screen safety
-- mechanism from the design doc's "Wiring rebinds into live Input
-- instances" section.
do
    reset_fs()
    SettingsState:reset()

    local original_map1 = { sentinel = "player1-original" }
    local original_map2 = { sentinel = "player2-original" }
    local fake_scene = {
        player  = { input = { _map = original_map1, _keyboard_rebindable = true } },
        player2 = { input = { _map = original_map2, _keyboard_rebindable = false } },
    }

    local scene = SettingsScene.new()
    scene:open(false, fake_scene, nil)
    scene.selected = 2
    tap(scene, "return") -- enter Keybinds subscreen
    scene.selected = 1   -- "up" row
    tap(scene, "return") -- begin capturing "up"
    assert(scene._capturing == "up", "sanity: should be capturing 'up'")

    scene:keypressed("z") -- rebind "up" to an unused key

    assert(SettingsState.keybinds.up == "z", "sanity: the rebind itself should have succeeded")
    assert(fake_scene.player.input._map ~= original_map1,
        "a player whose Input is tagged _keyboard_rebindable == true should have its ._map replaced after a successful rebind")
    assert(fake_scene.player.input._map.up ~= nil and fake_scene.player.input._map.up[1] == "z",
        "the replaced ._map should reflect the new keybind (key_map().up == {'z'})")
    assert(fake_scene.player2.input._map == original_map2,
        "a player whose Input is tagged _keyboard_rebindable == false must have its ._map left completely untouched")

    SettingsState:reset()
    print("PASS: settings_scene: a successful rebind updates only _keyboard_rebindable == true players' Input._map, leaving others untouched")
end

-- Test 13b: complement to Test 13 -- a player2 field that's entirely absent
-- (the common case for a 1P game, or opaque mode with no live scene at all)
-- must not error when a rebind is applied.
do
    reset_fs()
    SettingsState:reset()

    local original_map1 = { sentinel = "player1-original" }
    local fake_scene = {
        player = { input = { _map = original_map1, _keyboard_rebindable = true } },
        -- player2 intentionally omitted
    }

    local scene = SettingsScene.new()
    scene:open(false, fake_scene, nil)
    scene.selected = 2
    tap(scene, "return")
    scene.selected = 2 -- "down" row
    tap(scene, "return")
    assert(scene._capturing == "down")

    local ok, err = pcall(function() scene:keypressed("z") end)
    assert(ok, "rebinding with no scene.player2 present should not error, got: " .. tostring(err))
    assert(fake_scene.player.input._map ~= original_map1,
        "the sole tagged player should still get its ._map replaced when player2 is absent")

    SettingsState:reset()
    print("PASS: settings_scene: a rebind with no scene.player2 present does not error and still updates scene.player")
end

-- Test 14: opaque mode never touches live players, even if a `scene` with
-- tagged players is (unrealistically) passed in -- _apply_rebind_to_live_players
-- returns immediately when self._opaque is true (settings_scene.lua:201),
-- since opaque mode (reached from the Start Scene) has no live game
-- underneath by construction.
do
    reset_fs()
    SettingsState:reset()

    local original_map1 = { sentinel = "should-not-change" }
    local fake_scene = {
        player = { input = { _map = original_map1, _keyboard_rebindable = true } },
    }

    local scene = SettingsScene.new()
    scene:open(true, fake_scene, nil) -- opaque == true
    scene.selected = 2
    tap(scene, "return")
    scene.selected = 1
    tap(scene, "return")
    assert(scene._capturing == "up")

    scene:keypressed("z")

    assert(SettingsState.keybinds.up == "z", "sanity: the rebind itself should still succeed in opaque mode")
    assert(fake_scene.player.input._map == original_map1,
        "opaque mode must never touch scene.player.input._map, even if a scene object happens to be present")

    SettingsState:reset()
    print("PASS: settings_scene: opaque mode never propagates rebinds to live players, regardless of what `scene` was passed to :open()")
end

print("ALL TESTS PASSED")

-- Leave the process-lifetime SettingsState singleton clean for whichever
-- test file the headless runner executes next.
SettingsState:reset()
