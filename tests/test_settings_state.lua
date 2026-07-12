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
    print("PASS: settings_state: defaults to fullscreen == false")
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

-- to_save()/apply_save() round-trip correctly ------------------------------

do
    SettingsState:reset()
    SettingsState:toggle_fullscreen()
    assert(SettingsState.fullscreen == true, "sanity: fullscreen should be true before to_save()")

    local saved = SettingsState:to_save()
    assert(saved.version == 1, "to_save() should report version == 1, got " .. tostring(saved.version))
    assert(saved.fullscreen == true,
        "to_save().fullscreen should mirror the live singleton, got " .. tostring(saved.fullscreen))

    -- Reset to defaults, then restore the previously-saved snapshot.
    SettingsState:reset()
    assert(SettingsState.fullscreen == false, "sanity: reset() should clear fullscreen before apply_save")

    SettingsState:apply_save(saved)
    assert(SettingsState.fullscreen == true,
        "apply_save() should restore fullscreen == true, got " .. tostring(SettingsState.fullscreen))
    print("PASS: settings_state: to_save()/apply_save() round-trip fullscreen correctly")
end

-- apply_save() version-gate / reset-on-mismatch behavior -------------------

do
    -- apply_save(nil) resets to defaults.
    SettingsState:reset()
    SettingsState:toggle_fullscreen()
    assert(SettingsState.fullscreen == true, "test setup should have driven fullscreen to true before apply_save(nil)")

    SettingsState:apply_save(nil)
    assert(SettingsState.fullscreen == false,
        "apply_save(nil) should reset fullscreen to false, got " .. tostring(SettingsState.fullscreen))
    print("PASS: settings_state: apply_save(nil) falls back to a freshly-reset state")

    -- apply_save({}) (no version key at all) resets to defaults.
    SettingsState:reset()
    SettingsState:toggle_fullscreen()
    assert(SettingsState.fullscreen == true, "test setup should have driven fullscreen to true before apply_save({})")

    SettingsState:apply_save({})
    assert(SettingsState.fullscreen == false,
        "apply_save({}) with no version key should reset fullscreen to false, got " .. tostring(SettingsState.fullscreen))
    print("PASS: settings_state: apply_save({}) with no version key falls back to a freshly-reset state")

    -- apply_save({version = 999, ...}) (mismatched version) resets to
    -- defaults rather than applying the mismatched data's garbage values.
    SettingsState:reset()
    SettingsState:toggle_fullscreen()
    assert(SettingsState.fullscreen == true, "test setup should have driven fullscreen to true before apply_save(version mismatch)")

    SettingsState:apply_save({ version = 999, fullscreen = true })
    assert(SettingsState.fullscreen == false,
        "apply_save() with a mismatched version should reset fullscreen to false rather than apply the mismatched data, got " ..
        tostring(SettingsState.fullscreen))
    print("PASS: settings_state: apply_save() with a mismatched version falls back to a freshly-reset state instead of applying garbage data")
end

-- reset() restores defaults after prior mutation ----------------------------

do
    SettingsState:reset()
    SettingsState:toggle_fullscreen()
    assert(SettingsState.fullscreen == true, "test setup should have mutated fullscreen before reset()")

    SettingsState:reset()
    assert(SettingsState.fullscreen == false,
        "reset() should restore fullscreen to false, got " .. tostring(SettingsState.fullscreen))
    print("PASS: settings_state: reset() restores fullscreen default after prior mutation")
end

print("ALL TESTS PASSED")

-- Leave the process-lifetime SettingsState singleton clean for whichever
-- test file the headless runner executes next.
SettingsState:reset()
