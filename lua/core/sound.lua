local Sound = {}

local _src = {}
local _sfx_volume = 1.0
local _music_volume = 1.0
local _music_tracks = {}

function Sound.load(manifest)
    if not love.audio then return end
    for _, name in ipairs(manifest.sfx) do
        local path = manifest.sfx_dir .. name .. ".wav"
        if love.filesystem.getInfo(path) then
            _src[name] = love.audio.newSource(path, "static")
        end
    end
    for name, track in pairs(manifest.music or {}) do
        if love.filesystem.getInfo(track.path) then
            local autoplay = track.autoplay or false
            local src = love.audio.newSource(track.path, "stream")
            src:setLooping(track.looping ~= false)
            src:setVolume(autoplay and _music_volume or 0)
            _music_tracks[name] = {
                src            = src,
                fade_vol       = 1,
                fade_target    = 1,
                fade_rate      = 0,
                stop_on_done   = false,
                playing_intent = autoplay,
            }
            if autoplay then
                src:play()
            end
        end
    end
end

function Sound.play(name)
    if not love.audio then return end
    local s = _src[name]
    if s then
        local clone = s:clone()
        clone:setVolume(_sfx_volume)
        love.audio.play(clone)
    end
end

function Sound.set_sfx_volume(v)
    _sfx_volume = v
end

function Sound.set_music_volume(v)
    if not love.audio then return end
    _music_volume = v
    for _, entry in pairs(_music_tracks) do
        if entry.src:isPlaying() then
            entry.src:setVolume(entry.fade_vol * v)
        end
    end
end

function Sound.update(dt)
    if not love.audio then return end
    for _, entry in pairs(_music_tracks) do
        if entry.fade_rate ~= 0 then
            entry.fade_vol = entry.fade_vol + entry.fade_rate * dt
            if entry.fade_vol < 0 then entry.fade_vol = 0 end
            if entry.fade_vol > 1 then entry.fade_vol = 1 end
            entry.src:setVolume(entry.fade_vol * _music_volume)

            local reached = (entry.fade_rate > 0 and entry.fade_vol >= entry.fade_target)
                or (entry.fade_rate < 0 and entry.fade_vol <= entry.fade_target)
            if reached then
                entry.fade_vol = entry.fade_target
                entry.src:setVolume(entry.fade_vol * _music_volume)
                entry.fade_rate = 0
                if entry.stop_on_done then
                    entry.src:stop()
                    entry.playing_intent = false
                end
            end
        end
    end
end

function Sound.play_music(name)
    if not love.audio then return end
    local entry = _music_tracks[name]
    if not entry then return end
    entry.fade_vol = 1
    entry.fade_target = 1
    entry.fade_rate = 0
    entry.src:setVolume(_music_volume)
    entry.src:play()
    entry.playing_intent = true
end

function Sound.fade_music(name, target_vol, duration)
    if not love.audio then return end
    local entry = _music_tracks[name]
    if not entry then return end

    if target_vol > 0 and not entry.src:isPlaying() then
        entry.fade_vol = 0
        entry.src:setVolume(0)
        entry.src:play()
    end

    entry.fade_target = target_vol
    entry.fade_rate = (target_vol - entry.fade_vol) / duration
    entry.stop_on_done = (target_vol == 0)
    entry.playing_intent = (target_vol > 0)
end

function Sound.stop_music(name)
    if not love.audio then return end
    local entry = _music_tracks[name]
    if not entry then return end
    entry.src:stop()
    entry.fade_vol = 0
    entry.fade_target = 0
    entry.fade_rate = 0
    entry.stop_on_done = false
    entry.playing_intent = false
end

function Sound.play_random_music(names, fade_duration)
    if not love.audio then return end
    if #names == 0 then return end

    for _, name in ipairs(names) do
        if _music_tracks[name] and _music_tracks[name].src:isPlaying() then
            Sound.stop_music(name)
        end
    end

    local picked = names[math.random(#names)]
    Sound.fade_music(picked, 1, fade_duration)
end

function Sound.is_music_playing(name)
    local entry = _music_tracks[name]
    if entry == nil then return false end
    return entry.src:isPlaying()
end

function Sound.on_focus(focused)
    if not love.audio then return end
    if not focused then return end
    for _, entry in pairs(_music_tracks) do
        if entry.playing_intent == true and not entry.src:isPlaying() then
            entry.src:play()
        end
    end
end

return Sound
