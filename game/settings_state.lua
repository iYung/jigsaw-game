-- Session-lifetime settings singleton: currently just the fullscreen flag
-- and the SFX volume. to_save()/apply_save() exist for the settings.dat
-- persistence feature, mirroring game/game_state.lua's GameState pattern --
-- a process-lifetime singleton, require'd directly wherever needed, not
-- constructor-injected.
local Sound = require("lua/core/sound")

local SettingsState = {}
SettingsState.__index = SettingsState

function SettingsState.new()
    local self = setmetatable({}, SettingsState)
    self.fullscreen = false
    self.sfx_volume = 100
    return self
end

-- Flips the fullscreen flag and applies it to the live window.
function SettingsState:toggle_fullscreen()
    self.fullscreen = not self.fullscreen
    love.window.setFullscreen(self.fullscreen)
end

-- Clamps v to [0, 100], stores it, and pushes the normalized 0..1 volume
-- into the live Sound subsystem -- the single point that touches Sound,
-- mirroring toggle_fullscreen's relationship with love.window.setFullscreen.
function SettingsState:set_sfx_volume(v)
    v = math.max(0, math.min(100, v))
    self.sfx_volume = v
    Sound.set_sfx_volume(v / 100)
end

-- Resets to fullscreen off and full SFX volume, for test isolation, same
-- purpose as GameState:reset(). Nothing in game-runtime code calls this.
function SettingsState:reset()
    self.fullscreen = false
    self.sfx_volume = 100
end

-- Returns a plain snapshot table of this singleton's persistable fields,
-- suitable for handing to lua/core/save.lua's serializer.
function SettingsState:to_save()
    return {
        version = 2,
        fullscreen = self.fullscreen,
        sfx_volume = self.sfx_volume,
    }
end

-- Restores previously-saved fields onto this singleton, mutating it in
-- place rather than replacing self itself, since every other module holds
-- a reference to this exact singleton table via require("game/settings_state")
-- -- replacing self would leave those references stale. Falls back to a
-- fresh reset() if data is missing or from an incompatible version.
function SettingsState:apply_save(data)
    if not data then
        self:reset()
        return
    end
    if data.version == 1 then
        -- Legacy save, predates sfx_volume: apply fullscreen as today and
        -- default sfx_volume to full, keeping the live Sound subsystem in
        -- sync with the default.
        self.fullscreen = data.fullscreen
        self.sfx_volume = 100
        Sound.set_sfx_volume(1.0)
    elseif data.version == 2 then
        self.fullscreen = data.fullscreen
        self.sfx_volume = data.sfx_volume
        Sound.set_sfx_volume(data.sfx_volume / 100)
    else
        self:reset()
    end
end

-- Module returns a singleton instance (not the class table) so every
-- require("game/settings_state") caller shares one state object for the
-- process lifetime, exactly like game/game_state.lua.
return SettingsState.new()
