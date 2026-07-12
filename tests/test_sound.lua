local Sound = require("lua/core/sound")

-- NOTE: under headless stubs (lua/headless/stubs.lua), love.filesystem.getInfo
-- always returns nil, so Sound.load never actually creates a source for any
-- name. That makes Sound.play a safe no-op for every name in this file --
-- these tests only assert "doesn't error", not "a source was created" or
-- "a source actually played".

-- Test 1: Sound.load(manifest) doesn't error when given a manifest whose
-- files don't exist (always true under headless stubs).
do
    local manifest = {
        sfx_dir = "assets/sounds/",
        sfx = { "pick_up", "put_down", "fail", "menu_navigate", "menu_confirm", "puzzle_complete" },
    }
    Sound.load(manifest)
    print("PASS: sound: Sound.load() doesn't error with a manifest whose files don't exist")
end

-- Test 2: Sound.play(name) doesn't error when no source was loaded for name
-- (safe no-op) -- pick_up is in the manifest above but headless getInfo()
-- returning nil means Sound.load skipped creating a source for it.
do
    Sound.play("pick_up")
    print("PASS: sound: Sound.play() doesn't error when no source was loaded for name")
end

-- Test 3: Sound.play(name) doesn't error for a name never passed to
-- Sound.load at all.
do
    Sound.play("some_totally_unknown_sound_name")
    print("PASS: sound: Sound.play() doesn't error for a name never passed to Sound.load")
end

-- Test 4: Sound.set_sfx_volume(v) doesn't error across a range of values,
-- and a subsequent Sound.play still doesn't error.
do
    Sound.set_sfx_volume(0)
    Sound.play("menu_navigate")
    Sound.set_sfx_volume(0.5)
    Sound.play("menu_navigate")
    Sound.set_sfx_volume(1.0)
    Sound.play("menu_navigate")
    print("PASS: sound: Sound.set_sfx_volume() doesn't error across a range of values, and Sound.play() still doesn't error afterward")
end

-- Test 5: with love.audio nil, Sound.load/Sound.play/Sound.set_sfx_volume
-- are all safe no-ops.
do
    local saved_audio = love.audio
    love.audio = nil

    local manifest = {
        sfx_dir = "assets/sounds/",
        sfx = { "pick_up", "put_down", "fail", "menu_navigate", "menu_confirm", "puzzle_complete" },
    }
    Sound.load(manifest)
    Sound.play("pick_up")
    Sound.set_sfx_volume(0.5)
    Sound.play("pick_up")

    love.audio = saved_audio
    print("PASS: sound: Sound.load()/Sound.play()/Sound.set_sfx_volume() are safe no-ops when love.audio is nil")
end

print("ALL TESTS PASSED")
