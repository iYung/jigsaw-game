# Sound Effects

## Goal

Add sound-effect (SFX) playback to the jigsaw game, ported from `../wip`'s
`lua/core/sound.lua` architecture, with a player-adjustable SFX volume
control in the Settings menu. **Background music is explicitly out of
scope** — no music manifest, no `Sound.play_music`/fade/loop machinery is
ported.

Decisions locked in with the user before writing this doc:
- Sound assets are reused from `../wip/assets/sounds/*.wav` rather than
  sourced fresh.
- The Settings menu gets a volume slider (0–100, step 10), matching wip's
  pattern, not a simple on/off mute toggle.
- SFX triggers cover: piece pickup/put-down, puzzle complete, menu
  navigate/confirm, and invalid/blocked actions.

## Affected files

New:
- `lua/core/sound.lua` — SFX-only module ported from wip, music API
  stripped.
- `assets/sounds/pick_up.wav`, `put_down.wav`, `menu_navigate.wav`,
  `menu_confirm.wav`, `fail.wav` — copied verbatim from
  `../wip/assets/sounds/`.
- `assets/sounds/puzzle_complete.wav` — copy of wip's `clone_success.wav`,
  renamed (wip has no puzzle-complete-shaped sound; this is its closest
  generic "success chime").
- `assets/sounds/attribution.txt` — trimmed copy of wip's attribution file,
  covering only the five files above (`pick_up` has no listed attribution
  in wip's original file either — carried over as-is, not invented).
- `tests/test_sound.lua` — unit tests for the new module.

Changed:
- `game/settings_state.lua` — new `sfx_volume` field + setter, save format
  version bump.
- `game/scenes/settings_scene.lua` — new "SFX Volume" row, left/right input
  binding, menu nav/confirm SFX calls.
- `game/scenes/start_scene.lua` — menu nav/confirm SFX calls, invalid-action
  SFX on blocked rows (disabled Continue, disabled Players toggle).
- `game/player.lua` — SFX calls at pickup, successful drop, and
  rejected/occupied-cell drop.
- `game/scenes/game_scene.lua` — SFX call when a puzzle becomes assembled.
- `main.lua` — `Sound.load(manifest)` in `love.load`, after
  `SettingsState:apply_save`, so the saved volume applies from the first
  frame.
- `tests/test_settings_state.lua`, `tests/test_settings_scene.lua` —
  coverage for the new field/row.

Unchanged:
- `lua/core/save.lua` (generic serializer, no changes needed).
- `lua/headless/stubs.lua`'s `love.audio` shim already stubs
  `newSource`/`clone`/`setVolume`/`play` — sufficient for the new module to
  run under headless tests without modification. Its `love.filesystem.getInfo`
  stub always returns `nil`, so `Sound.load` will skip creating every source
  under headless tests (mirroring wip's own missing-file guard) — `Sound.play`
  becomes a safe no-op in that environment, which is correct, not a gap to
  fix.
- `conf.lua`'s headless audio-module disabling (unrelated, already correct).

## What changes

### `lua/core/sound.lua` (new)

Singleton module, same shape as wip's but with `play_music`, `fade_music`,
`stop_music`, `play_random_music`, `is_music_playing`, `on_focus`,
`play_animalese`, and the `_music_tracks`/`_music_volume` state all
dropped. Kept:

```lua
Sound.load(manifest)        -- manifest = { sfx_dir = "assets/sounds/", sfx = { "pick_up", ... } }
Sound.play(name)            -- clone-per-play, applies current sfx volume
Sound.set_sfx_volume(v)     -- v is 0..1 float
```

Every function no-ops if `love.audio` is nil, matching wip's guard and this
repo's headless mode. No `Sound.update(dt)` is needed since there's no
music fading.

Sound name → asset file map (all under `assets/sounds/`):
`pick_up`, `put_down`, `fail`, `menu_navigate`, `menu_confirm`,
`puzzle_complete`.

### Settings state and persistence

`game/settings_state.lua` gains:
```lua
self.sfx_volume = 100  -- 0..100 int, default full volume

function SettingsState:set_sfx_volume(v)
    v = math.max(0, math.min(100, v))
    self.sfx_volume = v
    Sound.set_sfx_volume(v / 100)
end
```
`to_save()` bumps to `version = 2` and adds `sfx_volume`. `apply_save(data)`
accepts both `version == 1` (pre-existing saves, missing `sfx_volume`,
defaults to 100) and `version == 2`, still falling back to `reset()` for
anything else — mirrors the existing guard at settings_state.lua:41 rather
than hard-breaking old save files. `reset()` also resets `sfx_volume` to
100.

`main.lua`'s `love.load` calls `Sound.load(manifest)` once, then (if a save
exists) `SettingsState:apply_save` runs as today — its `set_sfx_volume`
call inside `apply_save` pushes the restored volume into `Sound`
automatically, same as `set_fullscreen`'s existing pattern of the setter
being the single point that touches the live subsystem.

### Settings menu UI

`game/scenes/settings_scene.lua`:
- `TOP_ITEM_COUNT` goes from 2 to 3. New row 2 is "SFX Volume", pushing
  "Back"/"Main Menu" to row 3.
- `Input.new` gains `left`/`right` bindings (`"a"/"left"` and `"d"/"right"`
  physical keys, `dpleft`/`dpright` gamepad), matching StartScene's existing
  left/right convention (start_scene.lua:33-34) — this menu currently has
  no horizontal nav at all.
- `:update()` polls `pressed("left")`/`pressed("right")` and, when
  `self.selected == 2`, calls `SettingsState:set_sfx_volume(SettingsState.sfx_volume - 10)` /
  `+ 10`, then `Save.write_settings(SettingsState:to_save())` — same
  immediate-persist pattern the fullscreen toggle already uses at
  settings_scene.lua:157-158.
- `:_top_item_label(2)` renders `"SFX Volume: " .. SettingsState.sfx_volume .. "%"`.
- `gamepadpressed` gains dpleft/dpright handling parallel to its existing
  dpup/dpdown case.
- Up/down navigation and confirm both call `Sound.play("menu_navigate")` /
  `Sound.play("menu_confirm")` respectively; left/right volume adjustment
  also plays `menu_navigate` (matches wip's settings_menu.lua:243-253
  pattern exactly — quoted in the research above).

`game/scenes/start_scene.lua`: up/down navigation calls
`Sound.play("menu_navigate")`, confirm calls `Sound.play("menu_confirm")`
on a successful selection. The two existing blocked-confirm guards —
confirming "Continue" with `self._has_save == false`
(start_scene.lua:98) and confirming/toggling the "Players" row with
`self._has_controller == false` (start_scene.lua:145) — play
`Sound.play("fail")` instead of silently no-opping, giving the player
audible feedback that the row is disabled.

### Gameplay hooks

`game/player.lua`, inside the `interact` handling (around player.lua:109-119):
- Successful drop (not `occupied`): `Sound.play("put_down")`.
- Rejected drop (`occupied == true`): `Sound.play("fail")`.
- Picking up a piece (the `nearest:pick_up()` branch, ~player.lua:145):
  `Sound.play("pick_up")`.

`game/scenes/game_scene.lua`, inside the `is_assembled` branch
(game_scene.lua:320-324): `Sound.play("puzzle_complete")` once per puzzle,
right where `entry.solved = true` is set (so it can't re-fire on
subsequent frames).

Interacting with a box/pile/wall-tile while already holding a piece
(the other guarded branches found in player.lua) is left silent — these
are edge-of-screen no-ops during normal movement rather than a deliberate
"I tried and failed" action, and wip has no equivalent SFX for them either.

## What stays the same

- No background music, no `Sound.update(dt)` call, no focus-handling hook.
- `lua/core/save.lua`'s generic serializer is untouched — only the payload
  `SettingsState:to_save()` returns grows.
- Scene architecture, `SceneManager`, and the settings overlay's
  opaque/overlay dual-mode design (docs/archive/design/settings-menu.md)
  are unchanged.
- Keybind remapping remains dropped (per `757f942`) — this feature does not
  reopen that.

## Open questions

None outstanding — asset sourcing, volume-control UI shape, and trigger
event list were confirmed with the user before writing this doc. Minor
implementation calls (exact row label text, `puzzle_complete.wav` sourced
from `clone_success.wav`, silence on the box/pile/wall-tile guards) are
recorded above as decisions, not questions, since they follow directly from
existing patterns in this repo and in wip.
