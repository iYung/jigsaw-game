# Background Music Checklist

Source design doc: `docs/design/background-music.md`. Full port of wip's
music system: menu track + shuffled 4-track background playlist, a
dedicated Music Volume setting, and `love.focus` handling.

## Group 1 — Parallel-safe, no dependencies

These two tasks touch entirely disjoint files and don't need to read each
other's output. Safe to run as separate parallel subagents.

- [x] Task 1 — `assets/music/menu.mp3`, `background.mp3`, `background2.mp3`, `background3.mp3`, `background4.mp3`, `assets/sounds/attribution.txt` — **new files + one edit**: copy music assets from `../wip/assets/music/` into this repo.
  - Copy verbatim (byte-for-byte): `menu.mp3`, `background.mp3`, `background2.mp3`, `background3.mp3`, `background4.mp3` from `../wip/assets/music/` to a new `assets/music/` directory in this repo, same filenames. Do not copy the stray `.DS_Store`.
  - Append the 5 music attribution lines from `../wip/assets/sounds/attribution.txt` to the end of this repo's existing `assets/sounds/attribution.txt` (do not create a separate `assets/music/attribution.txt` — wip keeps music attribution in the sounds attribution file too): `"Menu music is kickback kroose trash kid"`, `"background is sarcastic shop trash kid"`, `"background2 is hillacious hiltops by thrash kid"`, `"background3 is sassy shells by thrash kid"`, `"background4 is nocturnal knoll by thrash kid"`. Carry the "trash kid"/"thrash kid" spelling inconsistency over as-is from wip's original — don't correct it.

- [x] Task 2 — `lua/core/sound.lua` — restore the music API from wip on top of the existing SFX-only module.
  - Base the additions on `../wip/lua/core/sound.lua`'s music section (lines ~68-185 in wip). Add module-local state `local _music_volume = 1.0` and `local _music_tracks = {}` alongside the existing SFX locals.
  - `Sound.load(manifest)` — extend to also handle `manifest.music`: for each `name, track` in `manifest.music`, if `love.filesystem.getInfo(track.path)` is truthy, `love.audio.newSource(track.path, "stream")` (note: `"stream"`, not `"static"` — SFX uses static, music uses stream), `src:setLooping(track.looping ~= false)` (defaults to `true` when `looping` is omitted), initial volume `(track.autoplay and _music_volume or 0)`, store `_music_tracks[name] = { src = src, fade_vol = 1, fade_target = 1, fade_rate = 0, stop_on_done = false, playing_intent = track.autoplay or false }`, and `src:play()` if `track.autoplay`.
  - Add `Sound.set_music_volume(v)` — stores `v` (0..1 float) in `_music_volume`, then for every entry in `_music_tracks` where `entry.src:isPlaying()`, immediately `entry.src:setVolume(entry.fade_vol * v)` (live re-apply, factoring in the track's current fade level so a mid-fade volume change doesn't fight the fade).
  - Add `Sound.update(dt)` — for every track with `fade_rate ~= 0`, step `fade_vol` toward `fade_target` at `fade_rate` per second, clamp to `[0, 1]`, call `entry.src:setVolume(entry.fade_vol * _music_volume)`, and once `fade_vol` reaches `fade_target`: set `fade_rate = 0`, and if `stop_on_done` is true, `entry.src:stop()` and `entry.playing_intent = false`.
  - Add `Sound.play_music(name)` — looks up `_music_tracks[name]`; no-ops if not found or `love.audio` is nil; otherwise sets `fade_vol = 1`, `fade_target = 1`, `fade_rate = 0`, `src:setVolume(_music_volume)`, `src:play()`, `playing_intent = true`.
  - Add `Sound.fade_music(name, target_vol, duration)` — looks up the track; no-ops if not found. If not currently playing and `target_vol > 0`, start it at volume 0 first (`fade_vol = 0`, `setVolume(0)`, `src:play()`). Sets `fade_target = target_vol`, `fade_rate = (target_vol - fade_vol) / duration`, `stop_on_done = (target_vol == 0)`, `playing_intent = (target_vol > 0)`.
  - Add `Sound.stop_music(name)` — looks up the track; no-ops if not found; otherwise `src:stop()`, resets `fade_vol = 0`, `fade_target = 0`, `fade_rate = 0`, `stop_on_done = false`, `playing_intent = false`.
  - Add `Sound.play_random_music(names, fade_duration)` — stops any track in `names` that's currently playing (via `Sound.stop_music`), picks one at random from `names` (`names[math.random(#names)]`), and `Sound.fade_music(picked, 1, fade_duration)`. No-ops safely on an empty `names` list or a list containing names not present in `_music_tracks`.
  - Add `Sound.is_music_playing(name)` — returns `_music_tracks[name] ~= nil and _music_tracks[name].src:isPlaying()` (false if the track doesn't exist).
  - Add `Sound.on_focus(focused)` — no-ops if `focused` is falsy; if truthy, for every entry in `_music_tracks` where `entry.playing_intent == true and not entry.src:isPlaying()`, call `entry.src:play()`.
  - `Sound.play`/`Sound.set_sfx_volume` (existing SFX functions) are unchanged. Every new function no-ops if `love.audio` is nil, matching the existing SFX guard convention.

## Group 2 — Sequential: depends on Task 2 (`lua/core/sound.lua`)

Each of these calls one or more of the new music functions, so Task 2 must
be done first. The five tasks below touch disjoint files from each other
and are safe to run as parallel subagents once Task 2 is done.

- [x] Task 3 — `game/settings_state.lua` — add `music_volume` field, setter, and save-format version bump. **Depends on Task 2.**
  - Add `self.music_volume = 100` (0..100 int, default full volume) in `SettingsState.new()`, alongside the existing `self.sfx_volume = 100`.
  - Add `function SettingsState:set_music_volume(v)` — clamps `v` to `[0, 100]` via `math.max(0, math.min(100, v))`, stores it on `self.music_volume`, then calls `Sound.set_music_volume(v / 100)` (reuse whatever `require` for `lua/core/sound` this file already has from the SFX feature).
  - `SettingsState:reset()` also resets `self.music_volume = 100`.
  - `SettingsState:to_save()` bumps `version` from `2` to `3` and adds `music_volume = self.music_volume` to the returned table.
  - `SettingsState:apply_save(data)`: add a `version == 3` branch that applies both `fullscreen`, `sfx_volume`, and `music_volume` (calling both `Sound.set_sfx_volume` and `Sound.set_music_volume`). The existing `version == 1` and `version == 2` branches (neither has a `music_volume` key) should additionally default `music_volume` to `100` and call `Sound.set_music_volume(1.0)`, same way they already default/apply `sfx_volume` for `version == 1`. Anything else (including no match) still falls back to `self:reset()`.

- [x] Task 4 — `game/scenes/start_scene.lua` — start/stop the `menu` music track. **Depends on Task 2.**
  - `require("lua/core/sound")` should already be present from the SFX feature — reuse it.
  - In `:on_enter()` (start_scene.lua:70): add `if not Sound.is_music_playing("menu") then Sound.play_music("menu") end` — idempotent so re-entering the start scene (e.g. returning from the settings overlay) doesn't restart a track that's already playing.
  - In `:_confirm()` (start_scene.lua:89-122), immediately before each call to `self.manager:switch(GameScene.new(...))` on both the New Game and Continue success paths, add `Sound.fade_music("menu", 0, 2)` — a 2-second fade-out overlapping the scene switch itself, not a hard stop.

- [x] Task 5 — `game/scenes/game_scene.lua` — start the shuffled background playlist and auto-advance it. **Depends on Task 2.**
  - `require("lua/core/sound")` should already be present from the SFX feature — reuse it.
  - In the constructor (`GameScene.new`), add `self._bg_list = { "bg1", "bg2", "bg3", "bg4" }` and `self._bg_index = math.random(4)`.
  - In `:on_enter()` (game_scene.lua:37): add `Sound.stop_music("menu")` (hard stop, belt-and-suspenders after the start scene's fade already silenced it), then — only if none of `self._bg_list` is currently playing (loop with `Sound.is_music_playing`, guards against re-entering the scene via the settings overlay restarting/double-playing music) — `Sound.fade_music(self._bg_list[self._bg_index], 1, 2)`.
  - In `:update(dt)` (game_scene.lua:290), add a playlist-advance check (in addition to the existing logic, doesn't need to run every single frame but simplest to check every frame): if `not Sound.is_music_playing(self._bg_list[self._bg_index])` (the current track finished, since bg tracks are non-looping), advance `self._bg_index = (self._bg_index % #self._bg_list) + 1` and `Sound.fade_music(self._bg_list[self._bg_index], 1, 2)`.
  - Leave the existing `Sound.play("puzzle_complete")` SFX call (game_scene.lua:324) untouched — that's the SFX subsystem, unrelated to this task.

- [x] Task 6 — `main.lua` — register the music manifest, drive fades, and handle focus changes. **Depends on Task 2.**
  - Extend the existing manifest local (main.lua:37-47, currently `SFX_MANIFEST` covering only `sfx`) with a `music` table: `{ menu = { path = "assets/music/menu.mp3", autoplay = true, looping = true }, bg1 = { path = "assets/music/background.mp3", autoplay = false, looping = false }, bg2 = { path = "assets/music/background2.mp3", autoplay = false, looping = false }, bg3 = { path = "assets/music/background3.mp3", autoplay = false, looping = false }, bg4 = { path = "assets/music/background4.mp3", autoplay = false, looping = false } }`. Renaming the manifest local (e.g. to `SOUND_MANIFEST`) to reflect it's no longer SFX-only is fine but not required.
  - In `love.update(dt)` (main.lua:80-87), add an unconditional `Sound.update(dt)` call each frame (alongside/regardless of the existing settings-open branch) — without this, fades started by `fade_music`/`play_random_music` never progress.
  - Add a new top-level `function love.focus(focused) Sound.on_focus(focused) end` (no `love.focus` handler exists in this repo today — this is a wholly new function, not an edit to an existing one).
  - `Sound.load(manifest)` (already called in `love.load`, from the SFX feature) picks up the new `music` table automatically since Task 2 makes `Sound.load` handle both `sfx` and `music` keys on the same manifest table — no separate `Sound.load` call needed.

- [x] Task 7 — `tests/test_sound.lua` — add unit tests for the new music functions. **Depends on Task 2.**
  - Follow this file's existing `do ... end` block / `print("PASS: ...")` style (see the existing SFX tests in this same file for convention).
  - Since `love.filesystem.getInfo` always returns `nil` under headless stubs, `Sound.load` never actually creates music sources in tests either — write tests accordingly (basic no-error coverage), matching how the existing SFX tests in this file handle the same constraint:
    - `Sound.set_music_volume(v)` doesn't error across a range of values (e.g. `0`, `0.5`, `1.0`).
    - `Sound.update(dt)` doesn't error when called with no tracks loaded.
    - `Sound.play_music(name)`, `Sound.fade_music(name, target, duration)`, `Sound.stop_music(name)` don't error for a name never passed to `Sound.load` (safe no-op), and don't error for a name that was in a manifest passed to `Sound.load` (still safe no-op under headless, since no real source was created).
    - `Sound.is_music_playing(name)` returns `false` for both a never-loaded name and a name that was in the manifest (headless stub's `isPlaying` always returns `false`, and unloaded tracks aren't in `_music_tracks` at all).
    - `Sound.play_random_music(names, duration)` doesn't error for a normal list, an empty list `{}`, or a list containing a name not in `_music_tracks`.
    - `Sound.on_focus(true)` and `Sound.on_focus(false)` don't error with no tracks loaded.
    - If `love.audio` is nil (simulate by temporarily setting the global to `nil` and restoring it after, same pattern the existing SFX nil-audio test uses), all of the above music functions are safe no-ops too.
  - This task does not depend on Task 1's actual `.mp3` files being present.

## Group 3 — Sequential: depends on Task 3 (`game/settings_state.lua`)

- [x] Task 8 — `game/scenes/settings_scene.lua` — add the "Music Volume" row and left/right volume control. **Depends on Task 2 and Task 3.**
  - `require("lua/core/sound")` should already be present from the SFX feature — reuse it.
  - Bump `TOP_ITEM_COUNT` (settings_scene.lua:51) from `3` to `4`. New row 3 is "Music Volume"; the existing row 3 ("Back"/"Main Menu") becomes row 4 — update `:_top_item_label(i)` and the `:_confirm()` branch that currently matches `self.selected == 3` for Back/Main Menu (settings_scene.lua, near the SFX-volume confirm-noop logic) to `self.selected == 4`.
  - `:_top_item_label(3)` returns `"Music Volume: " .. SettingsState.music_volume .. "%"`.
  - Existing left/right input bindings (added by the SFX feature at settings_scene.lua:72-87) are reused as-is — no new bindings needed, just a new selected-row branch.
  - In `:_adjust_volume(delta)` (settings_scene.lua:172-176) or wherever the SFX volume left/right logic lives: extend the `self.selected == 2` (SFX Volume) check with a sibling `self.selected == 3` (Music Volume) branch calling `SettingsState:set_music_volume(SettingsState.music_volume + delta)` instead of the SFX setter, then the same `Save.write_settings(SettingsState:to_save())` immediate-persist and `Sound.play("menu_navigate")` calls the SFX branch already makes.
  - `:update()` (settings_scene.lua:193-217): extend the `if self.selected == 2 then ... end` volume-adjust polling to also cover `self.selected == 3`, routing to the same adjustment logic (parameterized or branched by row).
  - `:gamepadpressed()` (settings_scene.lua:231-256): extend the dpleft/dpright handling's `self.selected == 2` check to also cover `self.selected == 3`, same pre-empt-`_down` pattern as the existing SFX row.
  - `:draw()`'s loop already iterates `1..TOP_ITEM_COUNT` and calls `:_top_item_label(i)`, so it needs no changes beyond `TOP_ITEM_COUNT` now being 4.

- [x] Task 9 — `tests/test_settings_state.lua` — add coverage for `music_volume`. **Depends on Task 3.**
  - Add tests following the file's existing `do ... end` block / `print("PASS: ...")` style, mirroring the existing `sfx_volume` tests added by the SFX feature:
    - `SettingsState:reset()` sets `music_volume == 100`.
    - `SettingsState:set_music_volume(v)` clamps below 0 and above 100 (e.g. `-10` → `0`, `150` → `100`), and sets in-range values as-is (e.g. `30` → `30`).
    - `to_save()` reports `version == 3` and includes the current `music_volume` alongside `sfx_volume`.
    - `apply_save()` round-trips `music_volume` correctly for a `version == 3` payload.
    - `apply_save({ version = 2, fullscreen = true, sfx_volume = 40 })` (a version-2 save with no `music_volume` key) applies `fullscreen`/`sfx_volume` as before and defaults `music_volume` to `100` rather than erroring or resetting everything.
    - `apply_save({ version = 1, fullscreen = true })` (legacy, no `sfx_volume` or `music_volume`) still applies `fullscreen` and defaults both `sfx_volume` and `music_volume` to `100`.
    - `apply_save()` with a mismatched version (e.g. `version = 999`) still falls back to a full `reset()`, including `music_volume == 100` — extend the existing mismatched-version test rather than skipping it.
  - Leave the singleton reset at the bottom of the file in place.

## Group 4 — Sequential: depends on Task 8 (`game/scenes/settings_scene.lua`)

- [x] Task 10 — `tests/test_settings_scene.lua` — add coverage for the Music Volume row. **Depends on Task 8.**
  - Follow the file's existing helper style (`fake_stick`, `with_joysticks`, in-memory `love.filesystem` stub) — reuse it, don't duplicate.
  - Add tests covering:
    - The top-level item list now has 4 rows; row 3's label reads `"Music Volume: 100%"` by default and updates after a volume change (e.g. `"Music Volume: 90%"`).
    - Navigating down from row 2 ("SFX Volume") lands on row 3 ("Music Volume"), and down again lands on row 4 ("Back"/"Main Menu") — wrap-around still works with the new 4-row count.
    - Pressing "right" while row 3 is selected increases `SettingsState.music_volume` by 10 (capped at 100) and persists via `Save.write_settings` (assert against the in-memory `love.filesystem` stub).
    - Pressing "left" while row 3 is selected decreases `SettingsState.music_volume` by 10 (floored at 0) and persists.
    - Left/right presses while row 1, 2, or 4 is selected do not change `music_volume`.
    - `gamepadpressed("dpleft")`/`gamepadpressed("dpright")` behave the same as the keyboard left/right case when row 3 is selected.
  - Reset `SettingsState` (and the in-memory filesystem stub) between test blocks the same way the existing tests already do.

## Group 5 — Final verification

- [x] Task 11 — Run the full headless test suite and confirm it's green. **Depends on every task above.**
  - Run `love . --headless` from the repo root and confirm every test file prints its `PASS`/`ALL TESTS PASSED` lines with no failures or Lua errors.
  - Also spot-check the changed file in isolation: `love . --headless tests/test_sound.lua`.
  - Sanity-check the manifest paths in `main.lua` (Task 6) actually match the filenames copied in Task 1 (`assets/music/menu.mp3`, `background.mp3`, `background2.mp3`, `background3.mp3`, `background4.mp3`) — a typo here would silently no-op every track under the real `love.filesystem.getInfo` check (not caught by headless tests, since that stub always returns `nil` regardless).
  - If anything fails, do not silently patch it here — report which task's file is implicated so the fix can go back through a Task Agent.
