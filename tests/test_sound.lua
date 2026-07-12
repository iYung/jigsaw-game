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

-- Test 6: Sound.set_music_volume(v) doesn't error across a range of values.
do
    Sound.set_music_volume(0)
    Sound.set_music_volume(0.5)
    Sound.set_music_volume(1.0)
    print("PASS: sound: Sound.set_music_volume() doesn't error across a range of values")
end

-- Test 7: Sound.update(dt) doesn't error when called with no tracks loaded.
do
    Sound.update(0.016)
    print("PASS: sound: Sound.update() doesn't error with no tracks loaded")
end

-- Test 8: Sound.play_music/Sound.fade_music/Sound.stop_music don't error for
-- a name never passed to Sound.load, and don't error for a name that was in
-- a manifest passed to Sound.load (headless getInfo() returning nil means
-- Sound.load never actually created a source for either, so both are safe
-- no-ops).
do
    local manifest = {
        sfx_dir = "assets/sounds/",
        sfx = {},
        music = {
            menu = { path = "assets/music/menu.mp3", autoplay = true, looping = true },
            bg1 = { path = "assets/music/background.mp3", autoplay = false, looping = false },
        },
    }
    Sound.load(manifest)

    Sound.play_music("menu")
    Sound.fade_music("menu", 1, 2)
    Sound.stop_music("menu")

    Sound.play_music("some_totally_unknown_track_name")
    Sound.fade_music("some_totally_unknown_track_name", 1, 2)
    Sound.stop_music("some_totally_unknown_track_name")

    print("PASS: sound: Sound.play_music()/Sound.fade_music()/Sound.stop_music() don't error for a never-loaded name or a manifest name")
end

-- Test 9: Sound.is_music_playing(name) returns false for both a never-loaded
-- name and a name that was in the manifest (no real source was created under
-- headless, and the stub's isPlaying always returns false regardless).
do
    local manifest = {
        sfx_dir = "assets/sounds/",
        sfx = {},
        music = {
            menu = { path = "assets/music/menu.mp3", autoplay = true, looping = true },
        },
    }
    Sound.load(manifest)

    assert(Sound.is_music_playing("menu") == false, "expected is_music_playing() to be false for a manifest name under headless")
    assert(Sound.is_music_playing("some_totally_unknown_track_name") == false, "expected is_music_playing() to be false for a never-loaded name")

    print("PASS: sound: Sound.is_music_playing() returns false for both a never-loaded name and a manifest name")
end

-- Test 10: Sound.play_random_music(names, duration) doesn't error for a
-- normal list, an empty list, or a list with an unknown name.
do
    local manifest = {
        sfx_dir = "assets/sounds/",
        sfx = {},
        music = {
            bg1 = { path = "assets/music/background.mp3", autoplay = false, looping = false },
            bg2 = { path = "assets/music/background2.mp3", autoplay = false, looping = false },
        },
    }
    Sound.load(manifest)

    Sound.play_random_music({ "bg1", "bg2" }, 2)
    Sound.play_random_music({}, 2)
    Sound.play_random_music({ "some_totally_unknown_track_name" }, 2)

    print("PASS: sound: Sound.play_random_music() doesn't error for a normal list, an empty list, or a list with an unknown name")
end

-- Test 11: Sound.on_focus(true) and Sound.on_focus(false) don't error with
-- no tracks loaded.
do
    Sound.on_focus(true)
    Sound.on_focus(false)
    print("PASS: sound: Sound.on_focus() doesn't error with no tracks loaded")
end

-- Test 12: with love.audio nil, all the new music functions are safe no-ops.
do
    local saved_audio = love.audio
    love.audio = nil

    local manifest = {
        sfx_dir = "assets/sounds/",
        sfx = {},
        music = {
            menu = { path = "assets/music/menu.mp3", autoplay = true, looping = true },
            bg1 = { path = "assets/music/background.mp3", autoplay = false, looping = false },
        },
    }
    Sound.load(manifest)
    Sound.set_music_volume(0.5)
    Sound.update(0.016)
    Sound.play_music("menu")
    Sound.fade_music("menu", 1, 2)
    Sound.stop_music("menu")
    Sound.play_random_music({ "menu", "bg1" }, 2)
    Sound.play_random_music({}, 2)
    assert(Sound.is_music_playing("menu") == false, "expected is_music_playing() to be false when love.audio is nil")
    Sound.on_focus(true)
    Sound.on_focus(false)

    love.audio = saved_audio
    print("PASS: sound: music functions are safe no-ops when love.audio is nil")
end

print("ALL TESTS PASSED")
