local Sound = {}

local _src = {}
local _sfx_volume = 1.0

function Sound.load(manifest)
    if not love.audio then return end
    for _, name in ipairs(manifest.sfx) do
        local path = manifest.sfx_dir .. name .. ".wav"
        if love.filesystem.getInfo(path) then
            _src[name] = love.audio.newSource(path, "static")
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

return Sound
