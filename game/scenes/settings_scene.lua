-- Settings menu/overlay. Deliberately NOT a lua/core/scene.lua subclass and
-- never handed to SceneManager:switch -- see docs/design/settings-menu.md's
-- "Settings scene/overlay" section for why: switching away from a live
-- GameScene would tear down its drawer (Scene:on_exit clears it), which a
-- pause overlay must never do. Instead this is a plain, persistent object
-- that a later task (main.lua, Task 6) owns as a module-local and draws on
-- top of whatever SceneManager.current already drew this frame.
--
-- Two entry points, distinguished by :open(opaque, scene, manager)'s first
-- arg:
--   opaque == true  -- opened from the Start Scene (no live game underneath;
--                      `scene` is nil). Fills the whole canvas. Shows a
--                      "Back" row instead of "Main Menu".
--   opaque == false -- opened as an in-game pause overlay (`scene` is the
--                      live GameScene). Draws a translucent scrim over the
--                      frozen game world. Shows a "Main Menu" row instead of
--                      "Back".
local SettingsState = require("game/settings_state")
local Save           = require("lua/core/save")
local Input           = require("lua/core/input")
local StartScene      = require("game/scenes/start_scene")
local GameState       = require("game/game_state")

local SettingsScene = {}
SettingsScene.__index = SettingsScene

local LOGICAL_W, LOGICAL_H = 1280, 720

local ITEM_W = 300
local ITEM_H = 60
local ITEM_GAP = 20
local ITEMS_TOP = 220

local NORMAL_COLOR   = { 0.35, 0.35, 0.35, 1 }
local SELECTED_COLOR = { 0.55, 0.55, 0.55, 1 }

local OPAQUE_BG_COLOR = { 0.08, 0.08, 0.08, 1 }

-- Top-level item list always has exactly 3 rows; index 3's label/action
-- flips between "Back" (opaque) and "Main Menu" (overlay) -- see
-- :_top_item_label / :_confirm_top below. This satisfies the design doc's
-- "Back is opaque-only, Main Menu is overlay-only" requirement without
-- needing a variable-length item list, since the two are mutually exclusive
-- per mode.
local TOP_ITEM_COUNT = 3

-- The exact six remappable actions, matching game/settings_state.lua and
-- game/player.lua's Player.build_input.
local KEYBIND_ACTIONS = { "up", "down", "left", "right", "interact", "rotate_piece" }
local KEYBIND_LABELS  = { "Up", "Down", "Left", "Right", "Interact", "Rotate Piece" }

local SHAKE_DURATION = 0.5

-- Keys that must never be treated as a completed capture attempt by
-- themselves (ported from /root/wip/lua/game/scenes/settings_menu.lua's
-- _MODIFIERS table) -- e.g. holding Shift to type an uppercase letter
-- shouldn't bind "lshift" as the action's key.
local MODIFIER_KEYS = {
    lshift = true, rshift = true, lctrl = true, rctrl = true,
    lalt = true, ralt = true, lgui = true, rgui = true,
    capslock = true, numlock = true, scrolllock = true,
}

-- Gamepad buttons that drive this scene's own menu-nav Input instance,
-- mapped to the action names used both by the top-level item list and the
-- Keybinds subscreen's row list (self.input's _map is shared/reused between
-- them -- see the class doc comment above :open()).
local GAMEPAD_NAV_ACTION = { dpup = "up", dpdown = "down", a = "confirm" }

-- Mirrors /root/wip/lua/game/scenes/settings_menu.lua's _all_bound: true
-- iff every one of the six remappable actions currently has a key bound.
-- SettingsState:set_keybind never assigns nil, so this should never
-- actually observe a gap in practice -- it exists purely as a defensive
-- gate on leaving the Keybinds subscreen, ported faithfully from wip.
local function _all_bound(keybinds)
    for _, action in ipairs(KEYBIND_ACTIONS) do
        if keybinds[action] == nil then return false end
    end
    return true
end

function SettingsScene.new()
    local self = setmetatable({}, SettingsScene)
    self.is_open = false
    self._opaque = false
    self._scene = nil
    self._manager = nil
    self.selected = 1
    self._subscreen = nil
    self._capturing = nil
    self._shake_row = nil
    self._shake_timer = 0

    -- Own menu-nav Input instance, identical in shape to StartScene's
    -- (start_scene.lua:29-44) minus left/right (this menu never needs
    -- horizontal nav) and minus any escape/close action -- closing Settings
    -- is handled one level up, by main.lua's global keypressed/gamepadpressed
    -- callbacks (Task 6), exactly like StartScene has no "quit" action of
    -- its own. Reused for both the top-level item list and the Keybinds
    -- subscreen's row list; self._subscreen just changes which list
    -- self.selected indexes into and what n :_nav wraps against.
    self.input = Input.new({
        up      = { "w", "up" },
        down    = { "s", "down" },
        confirm = { "e", "return" },
    }, {
        gamepad_buttons = {
            up      = { "dpup" },
            down    = { "dpdown" },
            confirm = { "a" },
        },
        joystick_scope = "first_two",
    })

    return self
end

-- opaque: true when reached from the Start Scene (no live game beneath,
-- `scene` will be nil); false/nil for the in-game pause overlay (`scene` is
-- the live GameScene). `manager` is the SceneManager, needed by the Main
-- Menu row (overlay mode) to switch back to a fresh StartScene.
function SettingsScene:open(opaque, scene, manager)
    self.is_open = true
    self._opaque = opaque and true or false
    self._scene = scene
    self._manager = manager
    self.selected = 1
    self._subscreen = nil
    self._capturing = nil
    self._shake_row = nil
    self._shake_timer = 0
end

function SettingsScene:close()
    self.is_open = false
end

-- Number of rows the currently-active list has, for :_nav's wraparound.
function SettingsScene:_row_count()
    if self._subscreen == "keybinds" then
        return #KEYBIND_ACTIONS
    end
    return TOP_ITEM_COUNT
end

-- Advances self.selected by delta (+1 down, -1 up), wrapping modulo the
-- active list's row count.
function SettingsScene:_nav(delta)
    local n = self:_row_count()
    self.selected = ((self.selected - 1 + delta) % n) + 1
end

function SettingsScene:_top_item_label(i)
    if i == 1 then
        return SettingsState.fullscreen and "Window" or "Fullscreen"
    elseif i == 2 then
        return "Keybinds"
    elseif i == 3 then
        return self._opaque and "Back" or "Main Menu"
    end
end

-- Overlay-mode Main Menu action: saves using the same {game_state=, scene=}
-- shape main.lua's own save path writes (see main.lua:64-68's
-- _save_current), then switches to a fresh StartScene, then closes the
-- overlay. Guarded so an opaque-mode misfire (no live `scene`) can't crash.
function SettingsScene:_go_to_main_menu()
    if self._scene and self._scene.to_save then
        Save.write({ game_state = GameState:to_save(), scene = self._scene:to_save() })
    end
    if self._manager then
        self._manager:switch(StartScene.new(self._manager))
    end
    self:close()
end

function SettingsScene:_confirm_top()
    if self.selected == 1 then
        SettingsState:toggle_fullscreen()
        Save.write_settings(SettingsState:to_save())
    elseif self.selected == 2 then
        self._subscreen = "keybinds"
        self.selected = 1
    elseif self.selected == 3 then
        if self._opaque then
            self:close()
        else
            self:_go_to_main_menu()
        end
    end
end

-- Reaches into the live scene's .player/.player2 (in overlay mode only --
-- opaque mode has no live Player) and rebuilds ._map on any whose Input is
-- tagged ._keyboard_rebindable == true (set by game/player.lua's
-- Player.build_input, Task 5). Players whose keyboard key lists were built
-- empty (a gamepad-assigned player2) are never tagged, so they're
-- deliberately skipped -- overwriting their ._map would otherwise hand
-- keyboard control to a controller-assigned player.
function SettingsScene:_apply_rebind_to_live_players()
    if self._opaque then return end
    local scene = self._scene
    if not scene then return end

    if scene.player and scene.player.input and scene.player.input._keyboard_rebindable then
        scene.player.input._map = SettingsState:key_map()
    end
    if scene.player2 and scene.player2.input and scene.player2.input._keyboard_rebindable then
        scene.player2.input._map = SettingsState:key_map()
    end
end

-- Confirms whatever's currently selected, dispatching by subscreen: at the
-- top level this runs the item's action (:_confirm_top); inside Keybinds it
-- begins capturing a new key for the selected row's action.
function SettingsScene:_confirm()
    if self._subscreen == "keybinds" then
        self._capturing = KEYBIND_ACTIONS[self.selected]
    else
        self:_confirm_top()
    end
end

function SettingsScene:update(dt)
    if not self.is_open then return end

    if self._shake_timer > 0 then
        self._shake_timer = math.max(0, self._shake_timer - dt)
        if self._shake_timer == 0 then
            self._shake_row = nil
        end
    end

    -- Always run, even while capturing -- Input:update()'s _down/_pressed
    -- are edge-triggered (lua/core/input.lua:73-97), so skipping this while
    -- capturing would desync edge detection for whenever capturing ends,
    -- same reasoning game/player.lua:87-88 documents for its own frozen
    -- check.
    self.input:update()

    if self._capturing then
        -- Raw key capture is driven entirely by :keypressed(key) receiving
        -- the literal key event, not by this nav Input -- see the class doc
        -- comment and design doc's "Menu-chrome navigation" section.
        return
    end

    if self.input:pressed("down") then
        self:_nav(1)
    end
    if self.input:pressed("up") then
        self:_nav(-1)
    end
    if self.input:pressed("confirm") then
        self:_confirm()
    end
end

-- Handles one raw key event while capturing a rebind for self._capturing.
-- Ported from /root/wip/lua/game/scenes/settings_menu.lua:304-329's
-- keypressed logic (modifier-key skip, escape-cancels-capture, duplicate-key
-- shake-and-reject, successful bind), adapted to this file's simpler
-- plain-rectangle rendering and to SettingsState/Save instead of wip's
-- settings_state + shared input singleton.
--
-- On a duplicate-key reject, capturing deliberately STAYS active (matching
-- wip's exact behavior: the reject branch sets self._shake_row/_shake_timer
-- but never clears self._capturing) rather than cancelling -- the row shakes
-- and the player can immediately try a different key without having to
-- reselect the row.
function SettingsScene:_handle_capture_key(key)
    if key == "escape" then
        self._capturing = nil
        return true
    end
    if MODIFIER_KEYS[key] then
        -- Not consumed: a bare modifier press isn't a completed capture
        -- attempt (e.g. Shift held to type an uppercase letter) -- matches
        -- wip's `if _MODIFIERS[key] then return false end`.
        return false
    end

    local capturing_action = self._capturing
    for i, action in ipairs(KEYBIND_ACTIONS) do
        if action ~= capturing_action and SettingsState.keybinds[action] == key then
            self._shake_row = i
            self._shake_timer = SHAKE_DURATION
            return true
        end
    end

    SettingsState:set_keybind(capturing_action, key)
    Save.write_settings(SettingsState:to_save())
    self:_apply_rebind_to_live_players()
    self._capturing = nil
    return true
end

-- Returns true iff the keypress was consumed (caller -- main.lua, Task 6 --
-- must not also treat it as e.g. the global ESC-closes-Settings key). Two
-- jobs: (1) raw key capture while rebinding (self._capturing ~= nil), which
-- needs the literal key rather than a named Input action; (2) gating
-- "leave the Keybinds subscreen" on every action being bound, via ESC,
-- mirroring wip's own escape handling in that state.
function SettingsScene:keypressed(key)
    if not self.is_open then return false end

    if self._capturing then
        return self:_handle_capture_key(key)
    end

    if self._subscreen == "keybinds" then
        if key == "escape" then
            if _all_bound(SettingsState.keybinds) then
                self._subscreen = nil
                self.selected = 2 -- back on the top-level "Keybinds" row
                return true
            end
            -- Refused to leave: the press was still handled (intentionally
            -- blocked/ignored), so main.lua must not also treat it as an
            -- unhandled top-level escape and close the whole overlay.
            return true
        end
        return false
    end

    -- Top level: nothing to capture, and no escape/close action of our
    -- own (see class doc comment) -- never consumed here.
    return false
end

-- Returns true iff the gamepad button press was consumed. Gamepad rebinding
-- isn't a thing (gamepad bindings are fixed -- see docs/design/
-- settings-menu.md's "What stays the same"), so unlike :keypressed this
-- never feeds a capture step; it only drives nav/confirm (dpup/dpdown/a) and
-- gates leaving the Keybinds subscreen via "start", mirroring :keypressed's
-- escape handling.
function SettingsScene:gamepadpressed(button)
    if not self.is_open then return false end

    if self._capturing then
        -- Capture only reacts to raw keyboard keys via :keypressed.
        return false
    end

    if self._subscreen == "keybinds" and button == "start" then
        if _all_bound(SettingsState.keybinds) then
            self._subscreen = nil
            self.selected = 2
            return true
        end
        return false
    end

    local action = GAMEPAD_NAV_ACTION[button]
    if not action then return false end

    -- self.input:update() (called every settings:update(dt) tick) also
    -- polls isGamepadDown for these same actions each frame -- pre-empt its
    -- edge-detection state here so it doesn't see a fresh false->true
    -- transition for the button we just handled and fire the same action a
    -- second time later this frame (lua/core/input.lua:91-94 only produces
    -- a "pressed" edge when _down[action] was false the previous check).
    self.input._down[action] = true

    if action == "confirm" then
        self:_confirm()
    else
        self:_nav(action == "down" and 1 or -1)
    end
    return true
end

-- Logical (1280x720) bounding rect for row `i`, matching StartScene's own
-- _item_rect convention (start_scene.lua:51-55).
function SettingsScene:_item_rect(i)
    local x = (LOGICAL_W - ITEM_W) / 2
    local y = ITEMS_TOP + (i - 1) * (ITEM_H + ITEM_GAP)
    return x, y, ITEM_W, ITEM_H
end

function SettingsScene:_draw_top()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Settings", 0, 140, LOGICAL_W, "center")

    for i = 1, TOP_ITEM_COUNT do
        local label = self:_top_item_label(i)
        local x, y, w, h = self:_item_rect(i)

        if i == self.selected then
            love.graphics.setColor(SELECTED_COLOR)
        else
            love.graphics.setColor(NORMAL_COLOR)
        end
        love.graphics.rectangle("fill", x, y, w, h)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(label, x, y + h / 2 - 8, w, "center")
    end
end

function SettingsScene:_draw_keybinds()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Keybinds", 0, 140, LOGICAL_W, "center")

    for i, action in ipairs(KEYBIND_ACTIONS) do
        local x, y, w, h = self:_item_rect(i)
        local ox = 0
        local tint_r, tint_g, tint_b = 1, 1, 1

        if self._shake_row == i and self._shake_timer > 0 then
            -- Ported from wip's shake visual (settings_menu.lua's draw()):
            -- decaying sine-wave horizontal offset plus a reddish tint,
            -- decaying to 0/white as self._shake_timer runs out.
            ox = math.sin(self._shake_timer * 40) * 8 * (self._shake_timer / SHAKE_DURATION)
            tint_r, tint_g, tint_b = 1, 0.35, 0.35
        end

        if i == self.selected then
            love.graphics.setColor(SELECTED_COLOR[1], SELECTED_COLOR[2], SELECTED_COLOR[3], 1)
        else
            love.graphics.setColor(NORMAL_COLOR[1], NORMAL_COLOR[2], NORMAL_COLOR[3], 1)
        end
        love.graphics.rectangle("fill", x + ox, y, w, h)

        local value
        if self._capturing == action then
            value = "press a key"
        else
            value = tostring(SettingsState.keybinds[action] or "?"):upper()
        end

        love.graphics.setColor(tint_r, tint_g, tint_b, 1)
        love.graphics.printf(KEYBIND_LABELS[i] .. ":  " .. value, x + ox, y + h / 2 - 8, w, "center")
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function SettingsScene:draw()
    if not self.is_open then return end

    if self._opaque then
        -- Opaque mode: fills the whole 1280x720 canvas with a solid color
        -- (no patterned art -- this repo has none of wip's
        -- settings_pattern_*.png assets), fully hiding the Start Scene
        -- beneath it.
        love.graphics.setColor(OPAQUE_BG_COLOR)
        love.graphics.rectangle("fill", 0, 0, LOGICAL_W, LOGICAL_H)
    else
        -- Overlay mode: the live SceneManager.current has already been
        -- drawn by main.lua before this :draw() call runs -- this
        -- semi-transparent scrim sits on top of that frozen game world,
        -- exactly matching /root/wip/main.lua's settings_menu layering.
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.rectangle("fill", 0, 0, LOGICAL_W, LOGICAL_H)
    end

    if self._subscreen == "keybinds" then
        self:_draw_keybinds()
    else
        self:_draw_top()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return SettingsScene
