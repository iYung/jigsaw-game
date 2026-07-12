-- test_settings_scene.lua
-- Unit tests for game/scenes/settings_scene.lua: row navigation (wrap
-- semantics), opaque-vs-overlay top-level item set + confirm behavior, the
-- Fullscreen toggle + persistence, and :gamepadpressed(button) nav/confirm.
-- Matches tests/test_start_scene.lua's tap()/with_joysticks() helper style
-- (duplicated locally per this repo's no-shared-test-helpers convention)
-- and tests/test_save.lua's in-memory love.filesystem stub pattern.
--
-- Keybind remapping was deliberately dropped from this scene (no Keybinds
-- subscreen); only the Fullscreen toggle and Back/Main Menu rows exist.

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

-- Test 1: top-level row navigation (2 rows: Fullscreen/Back-or-Main-Menu)
-- wraps in both directions, per SettingsScene:_nav's modulo wraparound.
do
    reset_fs()
    SettingsState:reset()
    local scene = SettingsScene.new()
    scene:open(false, nil, nil)
    assert(scene.selected == 1, "opening the settings scene should start with selected == 1, got " .. tostring(scene.selected))

    tap(scene, "s")
    assert(scene.selected == 2, "pressing down from row 1 should land on row 2, got " .. tostring(scene.selected))

    tap(scene, "s")
    assert(scene.selected == 1, "pressing down from row 2 (the last top-level row) should wrap to row 1, got " .. tostring(scene.selected))

    tap(scene, "w")
    assert(scene.selected == 2, "pressing up from row 1 should wrap to row 2 (the last top-level row), got " .. tostring(scene.selected))

    print("PASS: settings_scene: top-level row navigation wraps in both directions across the 2 rows")
end

-- Test 2: opaque mode shows "Back" as row 2; overlay mode shows "Main Menu"
-- instead -- SettingsScene:_top_item_label(2).
do
    reset_fs()
    SettingsState:reset()
    local scene = SettingsScene.new()

    scene:open(true, nil, nil)
    assert(scene._opaque == true, "opening with opaque == true should set self._opaque == true")
    assert(scene:_top_item_label(2) == "Back",
        "opaque mode should show 'Back' as row 2, got " .. tostring(scene:_top_item_label(2)))

    scene:open(false, nil, nil)
    assert(scene._opaque == false, "opening with opaque == false should set self._opaque == false")
    assert(scene:_top_item_label(2) == "Main Menu",
        "overlay mode should show 'Main Menu' as row 2, got " .. tostring(scene:_top_item_label(2)))

    print("PASS: settings_scene: opaque mode shows 'Back' as row 2; overlay mode shows 'Main Menu' instead")
end

-- Test 3: opaque mode's "Back" row (row 2) closes the overlay via :close(),
-- and requires no live scene/manager to do so.
do
    reset_fs()
    SettingsState:reset()
    local scene = SettingsScene.new()
    scene:open(true, nil, nil)
    scene.selected = 2
    assert(scene.is_open == true, "sanity: scene should be open before confirming Back")

    tap(scene, "return")

    assert(scene.is_open == false, "confirming 'Back' in opaque mode should close the settings scene")
    print("PASS: settings_scene: confirming opaque-mode 'Back' (row 2) calls :close()")
end

-- Test 4: overlay mode's "Main Menu" row (row 2) writes a save (via
-- Save.write, the same {game_state=, scene=} shape main.lua's own save path
-- writes) using the live `scene`'s :to_save(), switches away via the
-- `manager` passed to :open() (manager:switch called with a StartScene
-- instance), and then closes the overlay.
do
    reset_fs()
    SettingsState:reset()

    local fake_scene = { to_save = function(self) return { marker = "from-fake-scene" } end }
    local switched_with = nil
    local manager = { switch = function(self, s) switched_with = s end }

    local scene = SettingsScene.new()
    scene:open(false, fake_scene, manager)
    scene.selected = 2
    assert(scene:_top_item_label(2) == "Main Menu", "sanity: row 2 should read 'Main Menu' in overlay mode")

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

    print("PASS: settings_scene: overlay-mode 'Main Menu' (row 2) saves, switches to StartScene via manager, and closes")
end

-- Test 5: the Fullscreen row (row 1) toggles SettingsState.fullscreen (flips
-- the flag, flips the label "Fullscreen" <-> "Window") and persists via
-- Save.write_settings(SettingsState:to_save()).
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

-- Test 6: :gamepadpressed(button) drives the same nav/confirm behavior as
-- keyboard. dpdown/dpup move top-level selection, "a" confirms (toggling
-- Fullscreen), and gamepadpressed returns false/not-consumed when the scene
-- isn't open, and "start" is never consumed here (closing/opening is
-- main.lua's job, not this scene's).
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

    local start_consumed = scene:gamepadpressed("start")
    assert(start_consumed == false,
        "'start' should not be consumed by SettingsScene:gamepadpressed (main.lua owns opening/closing)")

    print("PASS: settings_scene: :gamepadpressed drives top-level nav (dpdown/dpup) and confirm ('a'); 'start' is never consumed here")
end

-- Test 7: gamepad nav also works through the shared self.input instance's
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

-- Test 8: :keypressed(key) never consumes anything -- there's no subscreen
-- and no escape/close action of this scene's own; closing is handled by
-- main.lua.
do
    reset_fs()
    SettingsState:reset()
    local scene = SettingsScene.new()
    scene:open(false, nil, nil)

    assert(scene:keypressed("escape") == false, "keypressed('escape') should never be consumed by SettingsScene")
    assert(scene:keypressed("return") == false, "keypressed('return') should never be consumed by SettingsScene")

    print("PASS: settings_scene: :keypressed never consumes anything (no subscreen, no close action of its own)")
end

-- Test 9: holding the confirm key ("return") through the Settings ->
-- StartScene "Main Menu" transition must not cause the fresh StartScene to
-- immediately fire its own default selection ("New Game"). Regression test
-- for a real reported bug: SettingsScene:_go_to_main_menu() constructs a
-- brand-new StartScene (lua/core/input.lua's Input starts with _down
-- entirely false), and StartScene's own "confirm" binding is the same
-- "e"/"return" key that just confirmed this "Main Menu" row -- without
-- priming the new Input to the currently-held key state, the very next
-- :update() on the fresh scene would see a false->true edge and immediately
-- fire StartScene:_confirm() on its default row 1.
do
    reset_fs()
    SettingsState:reset()

    local fake_scene = { to_save = function(self) return {} end }
    local switch_calls = 0
    local switched_with = nil
    local manager = { switch = function(self, s) switch_calls = switch_calls + 1; switched_with = s end }

    local scene = SettingsScene.new()
    scene:open(false, fake_scene, manager)
    scene.selected = 2 -- "Main Menu" row

    local original_isDown = love.keyboard.isDown
    love.keyboard.isDown = function(k) return k == "return" end

    scene:update(1 / 60) -- holds "return": fires confirm, triggers Main Menu -> switch

    assert(switch_calls == 1, "confirming Main Menu should call manager:switch exactly once, got " .. tostring(switch_calls))
    assert(switched_with ~= nil and switched_with.items ~= nil, "manager:switch should receive a StartScene-shaped instance")

    -- Still holding "return" (never released) -- simulate the next frame's
    -- manager:update(dt) ticking the freshly-switched StartScene.
    switched_with:update(1 / 60)

    love.keyboard.isDown = original_isDown

    assert(switch_calls == 1,
        "the fresh StartScene must not auto-fire its own confirm (New Game) just because the key that " ..
        "confirmed Main Menu is still held -- manager:switch should still have been called exactly once, got " ..
        tostring(switch_calls))
    assert(switched_with.selected == 1, "sanity: the fresh StartScene's selection should remain at its default, row 1")

    print("PASS: settings_scene: holding the confirm key through the Main Menu -> StartScene transition does not auto-fire the new scene's default selection")
end

-- Test 10: opening Settings while the confirm key ("e"/"return") is still
-- physically held -- e.g. the same key that confirmed a "Settings" row on
-- the Start Scene -- must not immediately fire this menu's own row 1.
-- Regression test for the mirror-image of Test 9's bug: self.input:update()
-- is skipped entirely while the scene is closed (see :update()), so
-- self.input._down is stale from whenever Settings last closed; :open()
-- must prime it to the current physical key state before the next real
-- :update() call, or a still-held key would read as a fresh press.
do
    reset_fs()
    SettingsState:reset()
    local scene = SettingsScene.new()

    local original_isDown = love.keyboard.isDown
    love.keyboard.isDown = function(k) return k == "return" end

    scene:open(false, nil, nil) -- primes self.input against the held key

    scene:update(1 / 60) -- still held; must not register a fresh edge

    love.keyboard.isDown = original_isDown

    assert(SettingsState.fullscreen == false,
        "opening Settings while the confirm key is already held must not immediately toggle Fullscreen (row 1), got fullscreen == " ..
        tostring(SettingsState.fullscreen))
    assert(scene.selected == 1, "sanity: selection should remain at row 1")

    print("PASS: settings_scene: opening Settings while the confirm key is already held does not auto-fire row 1")
end

-- Test 11: the fresh StartScene reached via "Main Menu" must have a working
-- "Settings" row -- StartScene.new must be constructed with an on_settings
-- callback that reopens this SettingsScene instance in opaque mode.
-- Regression test for a real reported bug: _go_to_main_menu() previously
-- called StartScene.new(manager) with no second argument, leaving the new
-- Start Scene's Settings row a silent no-op (start_scene.lua's nil-safe
-- on_settings handling).
do
    reset_fs()
    SettingsState:reset()

    local fake_scene = { to_save = function(self) return {} end }
    local switched_with = nil
    local manager = { switch = function(self, s) switched_with = s end }

    local scene = SettingsScene.new()
    scene:open(false, fake_scene, manager)
    scene.selected = 2 -- "Main Menu" row
    tap(scene, "return")

    assert(switched_with ~= nil, "sanity: confirming Main Menu should switch to a fresh StartScene")
    assert(type(switched_with.on_settings) == "function",
        "the fresh StartScene reached via Main Menu must have a working on_settings callback, got " .. type(switched_with.on_settings))

    -- Selecting Settings on the fresh StartScene should reopen this exact
    -- SettingsScene instance, in opaque mode, with no live scene.
    assert(scene.is_open == false, "sanity: settings scene should be closed after Main Menu")
    switched_with.on_settings()
    assert(scene.is_open == true, "selecting Settings on the fresh StartScene should reopen this SettingsScene instance")
    assert(scene._opaque == true, "reopening via the fresh StartScene's Settings row should open in opaque mode")
    assert(scene._scene == nil, "reopening via the fresh StartScene's Settings row should have no live scene (opaque, from the start menu)")

    print("PASS: settings_scene: the StartScene reached via Main Menu has a working Settings row that reopens this SettingsScene instance")
end

print("ALL TESTS PASSED")

-- Leave the process-lifetime SettingsState singleton clean for whichever
-- test file the headless runner executes next.
SettingsState:reset()
