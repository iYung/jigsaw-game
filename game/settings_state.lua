-- Session-lifetime settings singleton: currently just the fullscreen flag.
-- to_save()/apply_save() exist for the settings.dat persistence feature,
-- mirroring game/game_state.lua's GameState pattern -- a process-lifetime
-- singleton, require'd directly wherever needed, not constructor-injected.
local SettingsState = {}
SettingsState.__index = SettingsState

function SettingsState.new()
    local self = setmetatable({}, SettingsState)
    self.fullscreen = false
    return self
end

-- Flips the fullscreen flag and applies it to the live window.
function SettingsState:toggle_fullscreen()
    self.fullscreen = not self.fullscreen
    love.window.setFullscreen(self.fullscreen)
end

-- Resets to fullscreen off, for test isolation, same purpose as
-- GameState:reset(). Nothing in game-runtime code calls this.
function SettingsState:reset()
    self.fullscreen = false
end

-- Returns a plain snapshot table of this singleton's persistable fields,
-- suitable for handing to lua/core/save.lua's serializer.
function SettingsState:to_save()
    return {
        version = 1,
        fullscreen = self.fullscreen,
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
end

-- Module returns a singleton instance (not the class table) so every
-- require("game/settings_state") caller shares one state object for the
-- process lifetime, exactly like game/game_state.lua.
return SettingsState.new()
