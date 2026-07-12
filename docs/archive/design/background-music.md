# Background Music

## Goal

Add background music playback to the jigsaw game, ported from `../wip`'s
`lua/core/sound.lua` music API (the parts the prior sound-effects feature
deliberately stripped out), with a player-adjustable Music Volume control in
the Settings menu, separate from the existing SFX Volume control.

Decisions locked in with the user before writing this doc:
- Music assets are reused from `../wip/assets/music/*.mp3` verbatim (menu
  track + 4-track background playlist), plus their attribution lines.
- The game scene replicates wip's full shuffled 4-track playlist behavior
  (random start index, auto-advance on track end) rather than a single
  looping track.
- Settings gains a dedicated "Music Volume" row (0–100, step 10), a sibling
  of "SFX Volume" with its own persisted field — not shared/derived from
  SFX volume.
- `love.focus` handling (`Sound.on_focus`) is ported so backgrounding and
  restoring the window doesn't leave a track silently stuck paused, even
  though jigsaw-game's `main.lua` has no `love.focus` handler today.

## Affected files

New:
- `assets/music/menu.mp3`, `background.mp3`, `background2.mp3`,
  `background3.mp3`, `background4.mp3` — copied verbatim from
  `../wip/assets/music/`.

Changed:
- `assets/sounds/attribution.txt` — append the 5 music attribution lines
  from wip's attribution file (menu/background/background2-4, "trash kid").
  Kept in the existing sounds attribution file rather than a new
  `assets/music/attribution.txt`, matching wip's own layout (wip has no
  separate attribution file under `assets/music/` either).
- `lua/core/sound.lua` — add back the music API wip has: `Sound.update(dt)`,
  `Sound.play_music`, `Sound.fade_music`, `Sound.stop_music`,
  `Sound.play_random_music`, `Sound.is_music_playing`, `Sound.on_focus`,
  `Sound.set_music_volume`, plus `manifest.music` handling in `Sound.load`
  and the `_music_volume`/`_music_tracks` module-local state. `Sound.play`
  (SFX) and `Sound.set_sfx_volume` are unchanged.
- `game/settings_state.lua` — new `music_volume` field + setter, save
  format version bump to 3.
- `game/scenes/settings_scene.lua` — new "Music Volume" row (row 3),
  pushing Back/Main Menu to row 4; `TOP_ITEM_COUNT` 3 → 4.
- `game/scenes/start_scene.lua` — `:on_enter()` starts/resumes the `menu`
  track; confirming New Game/Continue fades it out during the scene switch.
- `game/scenes/game_scene.lua` — `:on_enter()` stops the menu track and
  fades in a random track from the 4-track playlist; `:update(dt)` advances
  the playlist when the current track finishes.
- `main.lua` — register `manifest.music` alongside the existing SFX
  manifest passed to `Sound.load`; call `Sound.update(dt)` every frame in
  `love.update`; add a `love.focus(focused)` handler calling
  `Sound.on_focus(focused)`.
- `tests/test_sound.lua` — coverage for the new music functions, following
  wip's monkey-patching approach for assertions beyond "doesn't error".
- `tests/test_settings_state.lua`, `tests/test_settings_scene.lua` —
  coverage for the new field/row.

Unchanged:
- `lua/core/save.lua` (generic serializer, no changes needed).
- `lua/headless/stubs.lua`'s `love.audio` shim already stubs
  `newSource`/`clone`/`setVolume`/`play`/`setLooping`/`isPlaying` —
  confirmed matching wip's own stub, sufficient for the music module to run
  under headless tests without modification. `love.filesystem.getInfo`
  always returns `nil` under the stub, so `Sound.load` skips creating every
  music source in tests, same guard pattern the SFX module already relies
  on.
- `conf.lua`'s headless audio-module disabling (unrelated, already
  correct).
- SFX trigger points added by the prior feature (`game/player.lua`,
  puzzle-complete in `game_scene.lua`, menu nav/confirm/fail sounds) are
  untouched.

## What changes

### `lua/core/sound.lua`

Restores wip's full music surface on top of the existing SFX-only module:

```lua
Sound.load(manifest)                 -- manifest.music: { [name] = {path, autoplay, looping} }
Sound.set_music_volume(v)            -- v is 0..1 float; live-reapplies to any currently-playing track
Sound.update(dt)                     -- drives per-track linear fades; must be called every frame
Sound.play_music(name)               -- instant full-volume play
Sound.fade_music(name, target_vol, duration)  -- linear fade; auto-starts at vol 0 if target > 0 and not playing
Sound.stop_music(name)               -- hard stop, resets fade state
Sound.play_random_music(names, fade_duration) -- stops any currently-playing track in the list, fades in a random pick
Sound.is_music_playing(name)
Sound.on_focus(focused)              -- replays tracks with playing_intent == true that got OS-paused
```

`Sound.load` gains music handling: for each `name, track` in
`manifest.music`, if `love.filesystem.getInfo(track.path)` is truthy,
`love.audio.newSource(track.path, "stream")` (streamed, unlike SFX's
`"static"`), `src:setLooping(track.looping ~= false)` (defaults to `true`),
initial volume `autoplay and _music_volume or 0`, and `src:play()` if
`autoplay`. Per-track state stored in `_music_tracks[name] = { src,
fade_vol=1, fade_target=1, fade_rate=0, stop_on_done=false,
playing_intent=autoplay }`.

Every function no-ops if `love.audio` is nil, matching the existing SFX
guard.

Music name → asset file map (all under `assets/music/`): `menu` (loops,
autoplay), `bg1`/`bg2`/`bg3`/`bg4` (non-looping, `background.mp3` /
`background2.mp3` / `background3.mp3` / `background4.mp3` — kept as `bg1`
rather than `background` to match wip's in-code track-name convention used
by the playlist array, even though the file itself is `background.mp3`
with no digit).

### Settings state and persistence

`game/settings_state.lua` gains:
```lua
self.music_volume = 100  -- 0..100 int, default full volume

function SettingsState:set_music_volume(v)
    v = math.max(0, math.min(100, v))
    self.music_volume = v
    Sound.set_music_volume(v / 100)
end
```
`to_save()` bumps to `version = 3` and adds `music_volume`. `apply_save(data)`
gains a `version == 3` branch applying both `sfx_volume` and
`music_volume`; `version == 1` and `version == 2` branches are kept as-is
but now also default `music_volume` to 100 (and call
`Sound.set_music_volume(1.0)`) since neither older format has the field;
anything else still falls back to `reset()`. `reset()` also resets
`music_volume` to 100.

### Settings menu UI

`game/scenes/settings_scene.lua`:
- `TOP_ITEM_COUNT` goes from 3 to 4. New row 3 is "Music Volume", pushing
  "Back"/"Main Menu" to row 4.
- `:_top_item_label(3)` renders `"Music Volume: " .. SettingsState.music_volume .. "%"`.
- `:_adjust_volume` gains a music-volume branch: when `self.selected == 3`,
  calls `SettingsState:set_music_volume(SettingsState.music_volume ± 10)`
  (reusing the existing `SFX_VOLUME_STEP = 10` value, or a sibling
  `MUSIC_VOLUME_STEP = 10` constant for clarity), then
  `Save.write_settings(SettingsState:to_save())`, then
  `Sound.play("menu_navigate")` — same immediate-persist pattern SFX volume
  already uses.
- `:update()` and `gamepadpressed()` extend their `self.selected == 2`
  left/right checks to also cover `self.selected == 3`, routing to the same
  `_adjust_volume` helper (already parameterized by which field to touch).

### Scene hooks

`game/scenes/start_scene.lua`:
- `:on_enter()` (line 70) gains: `if not Sound.is_music_playing("menu")
  then Sound.play_music("menu") end` — idempotent, so returning to the
  start scene (e.g. from the settings overlay) doesn't restart a track
  that's already playing.
- `:_confirm()`, immediately before `self.manager:switch(GameScene.new(...))`
  on both the New Game and Continue paths: `Sound.fade_music("menu", 0, 2)`
  — a 2-second fade-out overlapping the scene switch, not a hard cutover.

`game/scenes/game_scene.lua`:
- Constructor gains `self._bg_list = {"bg1", "bg2", "bg3", "bg4"}` and
  `self._bg_index = math.random(4)`.
- `:on_enter()` (line 37) gains: `Sound.stop_music("menu")` (belt-and-
  suspenders hard stop after the start scene's fade), then — only if no bg
  track is already playing (guards against re-entering the scene via the
  settings overlay) — `Sound.fade_music(self._bg_list[self._bg_index], 1, 2)`.
- `:update(dt)` (line 290) gains a playlist-advance check: if
  `not Sound.is_music_playing(self._bg_list[self._bg_index])` (the current
  track finished, since bg tracks are non-looping), advance
  `self._bg_index` to the next track (wrapping via `% #self._bg_list + 1`)
  and `Sound.fade_music(...)` it in over 2 seconds.

### `main.lua`

- `SFX_MANIFEST` (lines 37-47) gains a `music` table alongside `sfx`,
  registering the 5 tracks above with their `autoplay`/`looping` flags —
  or the manifest local is renamed to reflect it's no longer SFX-only
  (exact naming is an implementation call, not a design decision).
- `love.update(dt)` (lines 80-87) calls `Sound.update(dt)` unconditionally
  each frame, alongside the existing settings/manager update branch —
  needed for fades to progress; without it `fade_music`/`play_random_music`
  never actually change volume over time.
- New `love.focus(focused)` handler: `Sound.on_focus(focused)`.

## What stays the same

- `Sound.play` (SFX) and `Sound.set_sfx_volume` are untouched — SFX and
  music are independent subsystems inside the same module, matching wip.
- `lua/core/save.lua`'s generic serializer is untouched — only the payload
  `SettingsState:to_save()` returns grows.
- Scene architecture, `SceneManager`, and the settings overlay's
  opaque/overlay dual-mode design are unchanged.
- Keybind remapping remains dropped (per `757f942`) — this feature does not
  reopen that.
- `play_animalese` (present in wip's sound module) is not ported — it's
  unrelated to background music and out of scope here, same as it was
  implicitly out of scope for the SFX feature.

## Open questions

None outstanding — asset sourcing, playlist behavior, volume-control UI
shape, and focus-handling scope were confirmed with the user before writing
this doc.
