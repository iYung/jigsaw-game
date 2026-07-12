-- Session-lifetime settings singleton: fullscreen flag + remappable keyboard
-- keybinds. to_save()/apply_save() exist for the settings.dat persistence
-- feature, mirroring game/game_state.lua's GameState pattern -- a
-- process-lifetime singleton, require'd directly wherever needed, not
-- constructor-injected.
local SettingsState = {}
SettingsState.__index = SettingsState

-- The exact six gameplay actions that are keyboard-remappable, matching
-- game/player.lua's Player.build_input. Menu-chrome navigation
-- (up/down/left/right/confirm used by StartScene/SettingsScene) is
-- intentionally not part of this set -- see docs/design/settings-menu.md.
SettingsState.DEFAULT_KEYBINDS = {
    up = "w",
    down = "s",
    left = "a",
    right = "d",
    interact = "e",
    rotate_piece = "r",
}

local function copy_keybinds(keybinds)
    local result = {}
    for action, key in pairs(keybinds) do
        result[action] = key
    end
    return result
end

function SettingsState.new()
    local self = setmetatable({}, SettingsState)
    self.fullscreen = false
    self.keybinds = copy_keybinds(SettingsState.DEFAULT_KEYBINDS)
    return self
end

-- Flips the fullscreen flag and applies it to the live window.
function SettingsState:toggle_fullscreen()
    self.fullscreen = not self.fullscreen
    love.window.setFullscreen(self.fullscreen)
end

-- Rebinds a single action to a single key. No duplicate-key rejection here
-- -- that policy lives in game/scenes/settings_scene.lua, which is the only
-- caller with enough context (the other actions' current bindings) to
-- decide what counts as a rejected rebind.
function SettingsState:set_keybind(action, key)
    self.keybinds[action] = key
end

-- Returns keybinds in the {action = {key}} shape lua/core/input.lua's
-- Input.new expects for its keyboard key-list argument -- each action maps
-- to a single-element list.
function SettingsState:key_map()
    local result = {}
    for action, key in pairs(self.keybinds) do
        result[action] = {key}
    end
    return result
end

-- Resets to default keybinds and fullscreen off, for test isolation, same
-- purpose as GameState:reset(). Nothing in game-runtime code calls this.
function SettingsState:reset()
    self.fullscreen = false
    self.keybinds = copy_keybinds(SettingsState.DEFAULT_KEYBINDS)
end

-- Returns a plain snapshot table of this singleton's persistable fields,
-- suitable for handing to lua/core/save.lua's serializer.
function SettingsState:to_save()
    return {
        version = 1,
        fullscreen = self.fullscreen,
        keybinds = self.keybinds,
    }
end

-- Restores previously-saved fields onto this singleton, mutating it in
-- place rather than replacing self itself, since every other module holds
-- a reference to this exact singleton table via require("game/settings_state")
-- -- replacing self would leave those references stale. Falls back to a
-- fresh reset() if data is missing or from an incompatible version.
function SettingsState:apply_save(data)
    if not data or data.version ~= 1 then
        self:reset()
        return
    end
    self.fullscreen = data.fullscreen
    self.keybinds = data.keybinds
end

-- Module returns a singleton instance (not the class table) so every
-- require("game/settings_state") caller shares one state object for the
-- process lifetime, exactly like game/game_state.lua.
return SettingsState.new()
