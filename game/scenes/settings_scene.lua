-- Settings menu/overlay. Deliberately NOT a lua/core/scene.lua subclass and
-- never handed to SceneManager:switch -- see docs/design/settings-menu.md's
-- "Settings scene/overlay" section for why: switching away from a live
-- GameScene would tear down its drawer (Scene:on_exit clears it), which a
-- pause overlay must never do. Instead this is a plain, persistent object
-- that main.lua owns as a module-local and draws on top of whatever
-- SceneManager.current already drew this frame.
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
--
-- Settings exposed today are the fullscreen toggle, SFX volume, and Music
-- volume -- keybind remapping was deliberately dropped, see git history for
-- the removed Keybinds subscreen.
local SettingsState = require("game/settings_state")
local Save           = require("lua/core/save")
local Input           = require("lua/core/input")
local StartScene      = require("game/scenes/start_scene")
local GameState       = require("game/game_state")
local Sound           = require("lua/core/sound")

local SettingsScene = {}
SettingsScene.__index = SettingsScene

local LOGICAL_W, LOGICAL_H = 1280, 720

local ITEM_W = 300
local ITEM_H = 60
local ITEM_GAP = 20
local ITEMS_TOP = 220

local PANEL_NORMAL   = love.graphics.newImage("assets/ui/panel_normal.png")
local PANEL_SELECTED = love.graphics.newImage("assets/ui/panel_selected.png")
local SOLID          = love.graphics.newImage("assets/ui/solid.png")

local OPAQUE_BG_COLOR = { 0.08, 0.08, 0.08, 1 }

-- Top-level item list always has exactly 4 rows; row 1 is the fullscreen
-- toggle, row 2 is the SFX volume control, row 3 is the music volume
-- control, and row 4's label/action flips between "Back" (opaque) and
-- "Main Menu" (overlay) -- see :_top_item_label / :_confirm_top below. This
-- satisfies the design doc's "Back is opaque-only, Main Menu is
-- overlay-only" requirement without needing a variable-length item list,
-- since the two are mutually exclusive per mode.
local TOP_ITEM_COUNT = 4

-- Amount SFX volume changes per left/right press (see :_adjust_volume).
local SFX_VOLUME_STEP = 10

-- Amount music volume changes per left/right press (see :_adjust_volume).
local MUSIC_VOLUME_STEP = 10

-- Gamepad buttons that drive this scene's own menu-nav Input instance.
local GAMEPAD_NAV_ACTION = { dpup = "up", dpdown = "down", dpleft = "left", dpright = "right", a = "confirm" }

function SettingsScene.new()
    local self = setmetatable({}, SettingsScene)
    self.is_open = false
    self._opaque = false
    self._scene = nil
    self._manager = nil
    self.selected = 1

    -- Own menu-nav Input instance, identical in shape to StartScene's
    -- (start_scene.lua:29-44) minus any escape/close action -- closing
    -- Settings is handled one level up, by main.lua's global
    -- keypressed/gamepadpressed callbacks, exactly like StartScene has no
    -- "quit" action of its own. left/right drive the SFX Volume row (row 2)
    -- and the Music Volume row (row 3).
    self.input = Input.new({
        up      = { "w", "up" },
        down    = { "s", "down" },
        left    = { "a", "left" },
        right   = { "d", "right" },
        confirm = { "e", "return" },
    }, {
        gamepad_buttons = {
            up      = { "dpup" },
            down    = { "dpdown" },
            left    = { "dpleft" },
            right   = { "dpright" },
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

    -- self.input:update() is skipped entirely while is_open == false (see
    -- :update() below), so self.input._down is frozen/stale from whenever
    -- Settings last closed. Sync it to the current physical key/gamepad
    -- state right now, before we start actively polling it again -- e.g.
    -- the "e"/"return" key that just confirmed the Start Scene's "Settings"
    -- row is the same key this menu's own "confirm" is bound to, and if
    -- still physically held, the next real :update() would otherwise see a
    -- stale-false -> true edge and immediately fire this menu's row 1.
    self.input:update()
end

function SettingsScene:close()
    self.is_open = false
end

function SettingsScene:_top_item_label(i)
    if i == 1 then
        return SettingsState.fullscreen and "Window" or "Fullscreen"
    elseif i == 2 then
        return "SFX Volume: " .. SettingsState.sfx_volume .. "%"
    elseif i == 3 then
        return "Music Volume: " .. SettingsState.music_volume .. "%"
    elseif i == 4 then
        return self._opaque and "Back" or "Main Menu"
    end
end

-- Advances self.selected by delta (+1 down, -1 up), wrapping modulo the
-- top-level item count.
function SettingsScene:_nav(delta)
    self.selected = ((self.selected - 1 + delta) % TOP_ITEM_COUNT) + 1
end

-- Overlay-mode Main Menu action: saves using the same {game_state=, scene=}
-- shape main.lua's own save path writes (see main.lua's _save_current),
-- then switches to a fresh StartScene, then closes the overlay. Guarded so
-- an opaque-mode misfire (no live `scene`) can't crash.
function SettingsScene:_go_to_main_menu()
    if self._scene and self._scene.to_save then
        Save.write({ game_state = GameState:to_save(), scene = self._scene:to_save() })
    end
    if self._manager then
        local manager = self._manager
        -- Wire the fresh StartScene's "Settings" row the same way main.lua
        -- wires every other StartScene it constructs (see main.lua's
        -- _new_start_scene()): selecting it reopens this very SettingsScene
        -- instance in opaque mode. Without this, the Start Scene reached via
        -- "Main Menu" would construct with on_settings == nil, and its
        -- Settings row would be a silent no-op (see start_scene.lua's
        -- nil-safe on_settings handling) -- a real reported bug.
        local start_scene = StartScene.new(manager, function() self:open(true, nil, manager) end)
        -- Sync the fresh StartScene's own nav Input to the current
        -- physical key/gamepad state before switching to it. StartScene's
        -- "confirm" binding ("e"/"return") is the very key that just
        -- confirmed this "Main Menu" row -- a brand-new Input starts with
        -- _down entirely false (lua/core/input.lua), so without this, a
        -- still-held key would read as a fresh press on StartScene's first
        -- real :update() next frame and immediately fire its default
        -- selection ("New Game").
        start_scene.input:update()
        manager:switch(start_scene)
    end
    self:close()
end

-- Shared by :update()'s left/right polling and :gamepadpressed()'s
-- dpleft/dpright handling -- adjusts the SFX volume (row 2) or Music volume
-- (row 3) by `delta` (already signed, e.g. +SFX_VOLUME_STEP /
-- -SFX_VOLUME_STEP or the music equivalent), persists immediately (same
-- pattern the fullscreen toggle uses in :_confirm()), and plays the nav SFX
-- cue. Only meaningful when row 2 or row 3 is selected -- callers are
-- expected to guard on that themselves.
function SettingsScene:_adjust_volume(delta)
    if self.selected == 3 then
        SettingsState:set_music_volume(SettingsState.music_volume + delta)
    else
        SettingsState:set_sfx_volume(SettingsState.sfx_volume + delta)
    end
    Save.write_settings(SettingsState:to_save())
    Sound.play("menu_navigate")
end

function SettingsScene:_confirm()
    if self.selected == 1 then
        SettingsState:toggle_fullscreen()
        Save.write_settings(SettingsState:to_save())
        Sound.play("menu_confirm")
    elseif self.selected == 4 then
        if self._opaque then
            self:close()
        else
            self:_go_to_main_menu()
        end
        Sound.play("menu_confirm")
    end
end

function SettingsScene:update(dt)
    if not self.is_open then return end

    self.input:update()

    if self.input:pressed("down") then
        self:_nav(1)
        Sound.play("menu_navigate")
    end
    if self.input:pressed("up") then
        self:_nav(-1)
        Sound.play("menu_navigate")
    end
    if self.selected == 2 then
        if self.input:pressed("left") then
            self:_adjust_volume(-SFX_VOLUME_STEP)
        end
        if self.input:pressed("right") then
            self:_adjust_volume(SFX_VOLUME_STEP)
        end
    end
    if self.selected == 3 then
        if self.input:pressed("left") then
            self:_adjust_volume(-MUSIC_VOLUME_STEP)
        end
        if self.input:pressed("right") then
            self:_adjust_volume(MUSIC_VOLUME_STEP)
        end
    end
    if self.input:pressed("confirm") then
        self:_confirm()
    end
end

-- Returns true iff the keypress was consumed. Nothing at the top level is
-- ever consumed here -- there's no subscreen and no escape/close action of
-- our own (see class doc comment) -- so this is always a no-op passthrough,
-- kept so main.lua has a stable interface to call.
function SettingsScene:keypressed(key)
    return false
end

-- Returns true iff the gamepad button press was consumed. Drives
-- nav/confirm/volume (dpup/dpdown/dpleft/dpright/a) directly, same reasoning
-- as :update's polling but pre-empts a same-frame double-fire -- see the
-- _down pre-set below.
function SettingsScene:gamepadpressed(button)
    if not self.is_open then return false end

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
    elseif action == "up" or action == "down" then
        self:_nav(action == "down" and 1 or -1)
        Sound.play("menu_navigate")
    elseif action == "left" or action == "right" then
        if self.selected == 2 then
            self:_adjust_volume(action == "right" and SFX_VOLUME_STEP or -SFX_VOLUME_STEP)
        elseif self.selected == 3 then
            self:_adjust_volume(action == "right" and MUSIC_VOLUME_STEP or -MUSIC_VOLUME_STEP)
        end
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

function SettingsScene:draw()
    if not self.is_open then return end

    if self._opaque then
        -- Opaque mode: fills the whole 1280x720 canvas with a solid color
        -- (no patterned art -- this repo has none of wip's
        -- settings_pattern_*.png assets), fully hiding the Start Scene
        -- beneath it.
        love.graphics.setColor(OPAQUE_BG_COLOR)
        love.graphics.draw(SOLID, 0, 0, 0, LOGICAL_W / SOLID:getWidth(), LOGICAL_H / SOLID:getHeight())
    else
        -- Overlay mode: the live SceneManager.current has already been
        -- drawn by main.lua before this :draw() call runs -- this
        -- semi-transparent scrim sits on top of that frozen game world,
        -- exactly matching /root/wip/main.lua's settings_menu layering.
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.draw(SOLID, 0, 0, 0, LOGICAL_W / SOLID:getWidth(), LOGICAL_H / SOLID:getHeight())
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Settings", 0, 140, LOGICAL_W, "center")

    for i = 1, TOP_ITEM_COUNT do
        local label = self:_top_item_label(i)
        local x, y, w, h = self:_item_rect(i)

        local panel = (i == self.selected) and PANEL_SELECTED or PANEL_NORMAL
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(panel, x, y, 0, w / panel:getWidth(), h / panel:getHeight())

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(label, x, y + h / 2 - 8, w, "center")
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return SettingsScene
