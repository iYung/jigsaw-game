# Sound Effects Checklist

Source design doc: `docs/design/sound-effects.md`. Background music is out
of scope — no task below should touch music/fade/loop machinery.

## Group 1 — Parallel-safe, no dependencies

These two tasks touch entirely disjoint, brand-new files and don't need to
read each other's output. Safe to run as separate parallel subagents.

- [x] Task 1 — `assets/sounds/pick_up.wav`, `put_down.wav`, `menu_navigate.wav`, `menu_confirm.wav`, `fail.wav`, `puzzle_complete.wav`, `attribution.txt` — **new files**: copy sound assets from `../wip/assets/sounds/` into this repo.
  - Copy verbatim (byte-for-byte): `pick_up.wav`, `put_down.wav`, `menu_navigate.wav`, `menu_confirm.wav`, `fail.wav` from `../wip/assets/sounds/` to `assets/sounds/` in this repo, same filenames.
  - Copy `../wip/assets/sounds/clone_success.wav` to `assets/sounds/puzzle_complete.wav` — **renamed**, this repo has no puzzle-complete-shaped sound in wip so `clone_success.wav` is reused as the closest generic "success chime".
  - Create `assets/sounds/attribution.txt` as a **trimmed** copy of `../wip/assets/sounds/attribution.txt`, keeping only the lines for the five verbatim-copied files above (`put_down`, `menu_navigate`, `menu_confirm`, `fail` have attribution lines in wip's original; `pick_up` has none there either — carry that omission over as-is, don't invent one). Do **not** include a line for `clone_success`/`puzzle_complete` or any music-track lines (`water_plant`, `shop_navigate`, "Menu music", "background", etc.) — per the design doc, attribution.txt covers only those five files.
  - Do not copy `animalese.wav`, `plant_ready.wav`, `sell_plant.wav`, `shop_buy.wav`, `shop_navigate.wav`, `water_plant.wav`, or `clone_fail.wav` — unused by this feature.

- [x] Task 2 — `lua/core/sound.lua` — **new file**: port the SFX-only subset of wip's `lua/core/sound.lua` module.
  - Base it on `../wip/lua/core/sound.lua` but drop everything music-related: `play_music`, `fade_music`, `stop_music`, `play_random_music`, `is_music_playing`, `on_focus`, `play_animalese`, `Sound.update(dt)`, and the `_music_tracks`/`_music_volume`/`_animalese_*` state. No `Sound.update` is exported at all (there's no music fading to drive).
  - Keep exactly this API:
    - `Sound.load(manifest)` — `manifest = { sfx_dir = "assets/sounds/", sfx = { "pick_up", "put_down", "fail", "menu_navigate", "menu_confirm", "puzzle_complete" } }`. For each name in `manifest.sfx`, build `path = manifest.sfx_dir .. name .. ".wav"`; if `love.filesystem.getInfo(path)` is truthy, `love.audio.newSource(path, "static")` and store it keyed by name. No-ops entirely if `love.audio` is nil.
    - `Sound.play(name)` — no-ops if `love.audio` is nil or no source is loaded for `name`; otherwise clones the stored source, applies the current sfx volume via `:setVolume`, and `love.audio.play(clone)` — same clone-per-play pattern as wip.
    - `Sound.set_sfx_volume(v)` — stores `v` (a 0..1 float) for use by subsequent `Sound.play` calls.
  - This module doesn't need `assets/sounds/` files to exist to be authored or unit-tested — `lua/headless/stubs.lua`'s `love.filesystem.getInfo` always returns `nil`, so `Sound.load` skips every source under headless tests, making `Sound.play` a safe no-op there. No changes needed to `lua/headless/stubs.lua` or `conf.lua`.

## Group 2 — Sequential: depends on Task 2 (`lua/core/sound.lua`)

Each of these calls `Sound.play(...)`, `Sound.load(...)`, or `Sound.set_sfx_volume(...)`, so `lua/core/sound.lua` must exist with the API above before any of these start. The five tasks below touch disjoint files from each other and don't need to read each other's changes, so once Task 2 is done they're safe to run as parallel subagents.

- [x] Task 3 — `game/settings_state.lua` — add `sfx_volume` field, setter, and save-format version bump. **Depends on Task 2.**
  - Add `self.sfx_volume = 100` (0..100 int, default full volume) in `SettingsState.new()`.
  - Add `function SettingsState:set_sfx_volume(v)` — clamps `v` to `[0, 100]` via `math.max(0, math.min(100, v))`, stores it on `self.sfx_volume`, then calls `require("lua/core/sound"):set_sfx_volume(v / 100)` (require it at the top of the file like the other modules this file already requires — check current requires first).
  - `SettingsState:reset()` also resets `self.sfx_volume = 100`.
  - `SettingsState:to_save()` bumps `version` from `1` to `2` and adds `sfx_volume = self.sfx_volume` to the returned table.
  - `SettingsState:apply_save(data)` currently resets on anything but `data.version == 1` (see the guard at settings_state.lua:41). Change it to accept both: `version == 1` (legacy saves — no `sfx_volume` key — apply `fullscreen` as today and default `sfx_volume` to 100, calling `Sound.set_sfx_volume(1.0)` so the live subsystem matches) and `version == 2` (apply both `fullscreen` and `sfx_volume`, calling `Sound.set_sfx_volume(data.sfx_volume / 100)`). Anything else still falls back to `self:reset()`.

- [x] Task 4 — `game/scenes/start_scene.lua` — add menu nav/confirm/fail SFX calls. **Depends on Task 2.**
  - `require("lua/core/sound")` at the top.
  - In `:update()`, wherever `self.selected` changes via `self.input:pressed("down")`/`pressed("up")` (start_scene.lua:138-143), call `Sound.play("menu_navigate")` after a successful nav (i.e. `_next_selectable` actually moved `self.selected`).
  - In `:_confirm()` (start_scene.lua:88-115): on a successful selection (the `selected == 1` New Game branch, and the `selected == 4`/`selected == 5` branches), call `Sound.play("menu_confirm")`. The `selected == 2` (Continue) branch's `if not self._has_save then return end` guard (start_scene.lua:98) should instead play `Sound.play("fail")` before returning, since confirming a disabled Continue row currently no-ops silently.
  - In the `selected == 3` ("Players" row) handling inside `:update()` (start_scene.lua:145-152): the `if self._has_controller then self:_toggle_player_count() end` guard should play `Sound.play("fail")` in the implicit `else` (no controller connected) instead of silently no-opping, and the successful toggle path should play `Sound.play("menu_navigate")` (matches wip's left/right-as-nav convention, not `menu_confirm`).

- [x] Task 5 — `game/player.lua` — add pickup/put-down/fail SFX calls. **Depends on Task 2.**
  - `require("lua/core/sound")` at the top.
  - Inside the `interact` handling, held-piece branch (player.lua:106-126): after a successful drop (the `if not occupied then ... end` branch, player.lua:119-126), call `Sound.play("put_down")`. When `occupied == true` (the drop is rejected), call `Sound.play("fail")`.
  - In the pick-up branch (player.lua:144-156), when `nearest and nearest_dist <= 1.5 * C.U` is true and `nearest:pick_up()` fires, call `Sound.play("pick_up")`.
  - Leave the box/pile/wall-tile interact branches (player.lua:157-194) silent — no SFX — per the design doc, these are edge-of-screen no-ops during normal movement, not deliberate failed actions.

- [x] Task 6 — `game/scenes/game_scene.lua` — add puzzle-complete SFX call. **Depends on Task 2.**
  - `require("lua/core/sound")` at the top.
  - At game_scene.lua:320-323, inside `if not entry.solved and JigsawSolver.is_assembled(entry.pieces, entry.piece_count) then`, right where `entry.solved = true` is set, call `Sound.play("puzzle_complete")`. It must be inside this same `if` (not the pre-existing per-frame `entry.solved` checks elsewhere) so it fires exactly once per puzzle, not every subsequent frame.

- [x] Task 7 — `main.lua` — wire up `Sound.load(manifest)`. **Depends on Task 2.**
  - `require("lua/core/sound")` at the top alongside the other `local X = require(...)` lines.
  - In `love.load()`, call `Sound.load(manifest)` with `manifest = { sfx_dir = "assets/sounds/", sfx = { "pick_up", "put_down", "fail", "menu_navigate", "menu_confirm", "puzzle_complete" } }` (this list can be a local table literal built inline or as a module-local above `love.load`).
  - Place the `Sound.load(manifest)` call *before* the existing `if Save.settings_exists() then SettingsState:apply_save(Save.read_settings()) end` block (main.lua:57-59) — this ordering (load sources first, then apply the save which internally calls `SettingsState:set_sfx_volume` → `Sound.set_sfx_volume`) is what the design doc's "What changes" section describes ("`love.load` calls `Sound.load(manifest)` once, then ... `SettingsState:apply_save` runs ... its `set_sfx_volume` call ... pushes the restored volume into `Sound`").

- [x] Task 8 — `tests/test_sound.lua` — **new file**: unit tests for `lua/core/sound.lua`. **Depends on Task 2.**
  - Follow this repo's existing test-file conventions (see `tests/test_save.lua` or `tests/test_basics.lua` for style/`print("PASS: ...")` pattern).
  - Under headless stubs, `love.filesystem.getInfo` always returns `nil`, so `Sound.load` never actually creates sources — write tests accordingly (don't assert on real source creation). Cover:
    - `Sound.load(manifest)` doesn't error when given a manifest whose files don't exist (headless case).
    - `Sound.play(name)` doesn't error when no source was loaded for `name` (safe no-op).
    - `Sound.play(name)` doesn't error for a name never passed to `Sound.load` at all.
    - `Sound.set_sfx_volume(v)` doesn't error across a range of values (e.g. `0`, `0.5`, `1.0`) and a subsequent `Sound.play` still doesn't error.
    - If `love.audio` is nil (simulate by temporarily setting the global to `nil` and restoring it after), `Sound.load`/`Sound.play`/`Sound.set_sfx_volume` are all safe no-ops.
  - This task does not depend on Task 1's actual `.wav` files being present.

## Group 3 — Sequential: depends on Task 3 (`game/settings_state.lua`)

- [x] Task 9 — `game/scenes/settings_scene.lua` — add the "SFX Volume" row and left/right volume control. **Depends on Task 2 and Task 3.**
  - `require("lua/core/sound")` at the top.
  - Bump `TOP_ITEM_COUNT` from `2` to `3`. New row 2 is "SFX Volume"; the existing row 2 ("Back"/"Main Menu") becomes row 3 — update `:_top_item_label(i)` and `:_confirm()`'s `elseif self.selected == 2` branch (settings_scene.lua:159-165) to `elseif self.selected == 3`.
  - `:_top_item_label(2)` returns `"SFX Volume: " .. SettingsState.sfx_volume .. "%"`.
  - `Input.new` (settings_scene.lua:67-78) gains `left`/`right` bindings, matching StartScene's convention (`{ "a", "left" }` / `{ "d", "right" }` physical keys, `dpleft`/`dpright` gamepad).
  - In `:update()` (settings_scene.lua:168-182), poll `self.input:pressed("left")`/`pressed("right")`; when `self.selected == 2`, call `SettingsState:set_sfx_volume(SettingsState.sfx_volume - 10)` or `+ 10` respectively, then `Save.write_settings(SettingsState:to_save())` (same immediate-persist pattern the fullscreen toggle uses at settings_scene.lua:157-158), then `Sound.play("menu_navigate")`.
  - Up/down navigation (`:_nav`, called from `:update()`'s `pressed("down")`/`pressed("up")` handling) plays `Sound.play("menu_navigate")` after a successful nav. `:_confirm()` plays `Sound.play("menu_confirm")` on the fullscreen-toggle row (`selected == 1`) and the Back/Main Menu row (`selected == 3`); the SFX Volume row (`selected == 2`) has no confirm action (left/right only), so confirming it is a no-op as today.
  - `:gamepadpressed(button)` (settings_scene.lua:195-215): add `dpleft`/`dpright` to `GAMEPAD_NAV_ACTION` (mapped to new `"left"`/`"right"` actions) and handle them in the `if action == "confirm" ... else ...` dispatch, parallel to the existing dpup/dpdown case — when `self.selected == 2`, adjust volume by ±10 the same way `:update()` does (including the `Save.write_settings` persist and `Sound.play("menu_navigate")`); pre-set `self.input._down[action] = true` for the new actions too, matching the existing dpup/dpdown pre-empt.
  - `:draw()`'s loop already iterates `1..TOP_ITEM_COUNT` and calls `:_top_item_label(i)`, so it needs no changes beyond `TOP_ITEM_COUNT` now being 3.

- [x] Task 10 — `tests/test_settings_state.lua` — add coverage for `sfx_volume`. **Depends on Task 3.**
  - Add tests following the file's existing `do ... end` block / `print("PASS: ...")` style:
    - `SettingsState:reset()` sets `sfx_volume == 100`.
    - `SettingsState:set_sfx_volume(v)` clamps below 0 and above 100 (e.g. `set_sfx_volume(-10)` → `0`, `set_sfx_volume(150)` → `100`), and sets in-range values as-is (e.g. `set_sfx_volume(30)` → `30`).
    - `to_save()` reports `version == 2` and includes the current `sfx_volume`.
    - `apply_save()` round-trips `sfx_volume` correctly for a `version == 2` payload.
    - `apply_save({ version = 1, fullscreen = true })` (a legacy save with no `sfx_volume` key) applies `fullscreen` and defaults `sfx_volume` to `100` rather than erroring or resetting everything.
    - `apply_save()` with a mismatched version (e.g. `version = 999`) still falls back to a full `reset()`, including `sfx_volume == 100` — extend the existing mismatched-version test rather than skipping it.
  - Leave the singleton reset at the bottom of the file (`SettingsState:reset()`) in place.

## Group 4 — Sequential: depends on Task 9 (`game/scenes/settings_scene.lua`)

- [x] Task 11 — `tests/test_settings_scene.lua` — add coverage for the SFX Volume row. **Depends on Task 9.**
  - Follow the file's existing helper style (`fake_stick`, `with_joysticks`, in-memory `love.filesystem` stub already set up at the top of the file — reuse it, don't duplicate).
  - Add tests covering:
    - The top-level item list now has 3 rows; row 2's label reads `"SFX Volume: 100%"` by default and updates after a volume change (e.g. `"SFX Volume: 90%"`).
    - Navigating down from row 1 lands on row 2 ("SFX Volume"), and down again lands on row 3 ("Back"/"Main Menu" per existing opaque/overlay tests) — wrap-around still works with the new 3-row count.
    - Pressing "right" while row 2 is selected increases `SettingsState.sfx_volume` by 10 (capped at 100) and persists via `Save.write_settings` (assert against the in-memory `love.filesystem` stub, same pattern as the existing fullscreen-toggle persistence test).
    - Pressing "left" while row 2 is selected decreases `SettingsState.sfx_volume` by 10 (floored at 0) and persists.
    - Left/right presses while row 1 or row 3 is selected do not change `sfx_volume`.
    - `gamepadpressed("dpleft")`/`gamepadpressed("dpright")` behave the same as the keyboard left/right case when row 2 is selected (mirroring the existing dpup/dpdown gamepad tests).
  - Reset `SettingsState` (and the in-memory filesystem stub) between test blocks the same way the existing tests already do, so state doesn't leak between blocks.

## Group 5 — Final verification

- [x] Task 12 — Run the full headless test suite and confirm it's green. **Depends on every task above.**
  - Run `love . --headless` from the repo root (runs all files under `tests/`, per `README.md`'s documented invocation) and confirm every test file prints its `PASS`/`ALL TESTS PASSED` lines with no failures or Lua errors.
  - Also spot-check the new file in isolation: `love . --headless tests/test_sound.lua`.
  - If anything fails, do not silently patch it here — report which task's file is implicated so the fix can go back through a Task Agent.
