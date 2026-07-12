local SettingsState = require("game/settings_state")

-- singleton identity ----------------------------------------------------

do
    SettingsState:reset()
    local a = require("game/settings_state")
    local b = require("game/settings_state")
    assert(a == SettingsState, "require(\"game/settings_state\") should return the same singleton as the top-level require")
    assert(a == b, "multiple require(\"game/settings_state\") calls should return the same singleton instance")
    print("PASS: settings_state: require() returns the same singleton across multiple calls")
end

-- construction defaults --------------------------------------------------

do
    SettingsState:reset()
    assert(SettingsState.fullscreen == false,
        "fullscreen should default to false, got " .. tostring(SettingsState.fullscreen))
    assert(SettingsState.keybinds.up == "w",
        "keybinds.up should default to 'w', got " .. tostring(SettingsState.keybinds.up))
    assert(SettingsState.keybinds.down == "s",
        "keybinds.down should default to 's', got " .. tostring(SettingsState.keybinds.down))
    assert(SettingsState.keybinds.left == "a",
        "keybinds.left should default to 'a', got " .. tostring(SettingsState.keybinds.left))
    assert(SettingsState.keybinds.right == "d",
        "keybinds.right should default to 'd', got " .. tostring(SettingsState.keybinds.right))
    assert(SettingsState.keybinds.interact == "e",
        "keybinds.interact should default to 'e', got " .. tostring(SettingsState.keybinds.interact))
    assert(SettingsState.keybinds.rotate_piece == "r",
        "keybinds.rotate_piece should default to 'r', got " .. tostring(SettingsState.keybinds.rotate_piece))
    print("PASS: settings_state: defaults to fullscreen == false and keybinds w/s/a/d/e/r")
end

-- toggle_fullscreen() flips .fullscreen, and flips back on a second call --

do
    SettingsState:reset()
    assert(SettingsState.fullscreen == false, "sanity: fullscreen should start false before toggling")

    SettingsState:toggle_fullscreen()
    assert(SettingsState.fullscreen == true,
        "toggle_fullscreen() should flip fullscreen to true, got " .. tostring(SettingsState.fullscreen))

    SettingsState:toggle_fullscreen()
    assert(SettingsState.fullscreen == false,
        "a second toggle_fullscreen() call should flip fullscreen back to false, got " .. tostring(SettingsState.fullscreen))
    print("PASS: settings_state: toggle_fullscreen() flips .fullscreen and flips back on a second call")
end

-- set_keybind(action, key) updates exactly one action ---------------------

do
    SettingsState:reset()
    SettingsState:set_keybind("up", "i")

    assert(SettingsState.keybinds.up == "i",
        "set_keybind('up', 'i') should update keybinds.up, got " .. tostring(SettingsState.keybinds.up))
    assert(SettingsState.keybinds.down == "s",
        "set_keybind('up', ...) should leave keybinds.down untouched, got " .. tostring(SettingsState.keybinds.down))
    assert(SettingsState.keybinds.left == "a",
        "set_keybind('up', ...) should leave keybinds.left untouched, got " .. tostring(SettingsState.keybinds.left))
    assert(SettingsState.keybinds.right == "d",
        "set_keybind('up', ...) should leave keybinds.right untouched, got " .. tostring(SettingsState.keybinds.right))
    assert(SettingsState.keybinds.interact == "e",
        "set_keybind('up', ...) should leave keybinds.interact untouched, got " .. tostring(SettingsState.keybinds.interact))
    assert(SettingsState.keybinds.rotate_piece == "r",
        "set_keybind('up', ...) should leave keybinds.rotate_piece untouched, got " .. tostring(SettingsState.keybinds.rotate_piece))
    print("PASS: settings_state: set_keybind(action, key) updates exactly one action, leaving the rest untouched")
end

-- key_map() returns the exact {action = {key}} shape ----------------------

do
    SettingsState:reset()
    local map = SettingsState:key_map()

    assert(type(map.up) == "table", "key_map().up should be a table, got " .. type(map.up))
    assert(#map.up == 1, "key_map().up should be a single-element list, got length " .. tostring(#map.up))
    assert(map.up[1] == "w", "key_map().up[1] should be 'w', got " .. tostring(map.up[1]))

    assert(#map.down == 1 and map.down[1] == "s",
        "key_map().down should be {'s'}, got length " .. tostring(#map.down) .. " first=" .. tostring(map.down[1]))
    assert(#map.left == 1 and map.left[1] == "a",
        "key_map().left should be {'a'}, got length " .. tostring(#map.left) .. " first=" .. tostring(map.left[1]))
    assert(#map.right == 1 and map.right[1] == "d",
        "key_map().right should be {'d'}, got length " .. tostring(#map.right) .. " first=" .. tostring(map.right[1]))
    assert(#map.interact == 1 and map.interact[1] == "e",
        "key_map().interact should be {'e'}, got length " .. tostring(#map.interact) .. " first=" .. tostring(map.interact[1]))
    assert(#map.rotate_piece == 1 and map.rotate_piece[1] == "r",
        "key_map().rotate_piece should be {'r'}, got length " .. tostring(#map.rotate_piece) .. " first=" .. tostring(map.rotate_piece[1]))

    SettingsState:set_keybind("up", "i")
    local map2 = SettingsState:key_map()
    assert(#map2.up == 1 and map2.up[1] == "i",
        "key_map() should reflect a rebound action as a single-element list, got length " ..
        tostring(#map2.up) .. " first=" .. tostring(map2.up[1]))
    print("PASS: settings_state: key_map() returns the exact {action = {key}} single-element-list shape")
end

-- to_save()/apply_save() round-trip correctly ------------------------------

do
    SettingsState:reset()
    SettingsState:set_keybind("up", "i")
    SettingsState:set_keybind("interact", "f")
    SettingsState:toggle_fullscreen()
    assert(SettingsState.fullscreen == true, "sanity: fullscreen should be true before to_save()")

    local saved = SettingsState:to_save()
    assert(saved.version == 1, "to_save() should report version == 1, got " .. tostring(saved.version))
    assert(saved.fullscreen == true,
        "to_save().fullscreen should mirror the live singleton, got " .. tostring(saved.fullscreen))
    assert(saved.keybinds.up == "i",
        "to_save().keybinds.up should mirror the customized binding, got " .. tostring(saved.keybinds.up))
    assert(saved.keybinds.interact == "f",
        "to_save().keybinds.interact should mirror the customized binding, got " .. tostring(saved.keybinds.interact))

    -- Reset to defaults, then restore the previously-saved snapshot.
    SettingsState:reset()
    assert(SettingsState.fullscreen == false, "sanity: reset() should clear fullscreen before apply_save")
    assert(SettingsState.keybinds.up == "w", "sanity: reset() should restore default keybinds before apply_save")

    SettingsState:apply_save(saved)
    assert(SettingsState.fullscreen == true,
        "apply_save() should restore fullscreen == true, got " .. tostring(SettingsState.fullscreen))
    assert(SettingsState.keybinds.up == "i",
        "apply_save() should restore the customized keybinds.up == 'i', got " .. tostring(SettingsState.keybinds.up))
    assert(SettingsState.keybinds.interact == "f",
        "apply_save() should restore the customized keybinds.interact == 'f', got " .. tostring(SettingsState.keybinds.interact))
    assert(SettingsState.keybinds.down == "s",
        "apply_save() should restore untouched keybinds.down == 's' from the saved snapshot, got " .. tostring(SettingsState.keybinds.down))
    assert(SettingsState.keybinds.left == "a",
        "apply_save() should restore untouched keybinds.left == 'a' from the saved snapshot, got " .. tostring(SettingsState.keybinds.left))
    assert(SettingsState.keybinds.right == "d",
        "apply_save() should restore untouched keybinds.right == 'd' from the saved snapshot, got " .. tostring(SettingsState.keybinds.right))
    assert(SettingsState.keybinds.rotate_piece == "r",
        "apply_save() should restore untouched keybinds.rotate_piece == 'r' from the saved snapshot, got " .. tostring(SettingsState.keybinds.rotate_piece))
    print("PASS: settings_state: to_save()/apply_save() round-trip fullscreen and customized keybinds correctly")
end

-- apply_save() version-gate / reset-on-mismatch behavior -------------------

do
    -- apply_save(nil) resets to defaults.
    SettingsState:reset()
    SettingsState:set_keybind("up", "i")
    SettingsState:toggle_fullscreen()
    assert(SettingsState.fullscreen == true, "test setup should have driven fullscreen to true before apply_save(nil)")

    SettingsState:apply_save(nil)
    assert(SettingsState.fullscreen == false,
        "apply_save(nil) should reset fullscreen to false, got " .. tostring(SettingsState.fullscreen))
    assert(SettingsState.keybinds.up == "w",
        "apply_save(nil) should reset keybinds.up to the default 'w', got " .. tostring(SettingsState.keybinds.up))
    print("PASS: settings_state: apply_save(nil) falls back to a freshly-reset state")

    -- apply_save({}) (no version key at all) resets to defaults.
    SettingsState:reset()
    SettingsState:set_keybind("down", "j")
    SettingsState:toggle_fullscreen()
    assert(SettingsState.fullscreen == true, "test setup should have driven fullscreen to true before apply_save({})")

    SettingsState:apply_save({})
    assert(SettingsState.fullscreen == false,
        "apply_save({}) with no version key should reset fullscreen to false, got " .. tostring(SettingsState.fullscreen))
    assert(SettingsState.keybinds.down == "s",
        "apply_save({}) with no version key should reset keybinds.down to the default 's', got " .. tostring(SettingsState.keybinds.down))
    print("PASS: settings_state: apply_save({}) with no version key falls back to a freshly-reset state")

    -- apply_save({version = 999, ...}) (mismatched version) resets to
    -- defaults rather than applying the mismatched data's garbage values.
    SettingsState:reset()
    SettingsState:set_keybind("left", "j")
    SettingsState:toggle_fullscreen()
    assert(SettingsState.fullscreen == true, "test setup should have driven fullscreen to true before apply_save(version mismatch)")

    SettingsState:apply_save({
        version = 999,
        fullscreen = true,
        keybinds = { up = "z", down = "z", left = "z", right = "z", interact = "z", rotate_piece = "z" },
    })
    assert(SettingsState.fullscreen == false,
        "apply_save() with a mismatched version should reset fullscreen to false rather than apply the mismatched data, got " ..
        tostring(SettingsState.fullscreen))
    assert(SettingsState.keybinds.up == "w",
        "apply_save() with a mismatched version should reset keybinds.up to the default 'w' rather than apply the mismatched data, got " ..
        tostring(SettingsState.keybinds.up))
    assert(SettingsState.keybinds.left == "a",
        "apply_save() with a mismatched version should reset keybinds.left to the default 'a' rather than apply the mismatched data, got " ..
        tostring(SettingsState.keybinds.left))
    print("PASS: settings_state: apply_save() with a mismatched version falls back to a freshly-reset state instead of applying garbage data")
end

-- reset() restores defaults after prior mutation ----------------------------

do
    SettingsState:reset()
    SettingsState:set_keybind("rotate_piece", "q")
    SettingsState:toggle_fullscreen()
    assert(SettingsState.fullscreen == true and SettingsState.keybinds.rotate_piece == "q",
        "test setup should have mutated fullscreen and keybinds.rotate_piece before reset()")

    SettingsState:reset()
    assert(SettingsState.fullscreen == false,
        "reset() should restore fullscreen to false, got " .. tostring(SettingsState.fullscreen))
    assert(SettingsState.keybinds.up == "w" and SettingsState.keybinds.down == "s" and
        SettingsState.keybinds.left == "a" and SettingsState.keybinds.right == "d" and
        SettingsState.keybinds.interact == "e" and SettingsState.keybinds.rotate_piece == "r",
        "reset() should restore every keybind to its default")
    print("PASS: settings_state: reset() restores fullscreen and keybind defaults after prior mutation")
end

print("ALL TESTS PASSED")

-- Leave the process-lifetime SettingsState singleton clean for whichever
-- test file the headless runner executes next.
SettingsState:reset()
