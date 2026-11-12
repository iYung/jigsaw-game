# Pile Interaction Sound

## Goal

Give the player audible feedback when they use the puzzle pile. Today pressing
interact at the pile silently spawns a flying box; the only sounds nearby are
`poof` (when that box is later opened) and `put_down` (when it lands). A sound
at the moment of the press makes the action feel acknowledged.

Decisions locked in with the user:
- Trigger only on a successful press, i.e. the `pile:interact()` path that
  actually spawns a box.
- A blocked press (`GameState:can_start_puzzle()` false, or every unlocked
  puzzle pool exhausted so `JigsawBox.new` returns nil) stays silent, as today.
- One one-shot per successful press; no per-piece or looping behavior.
- Plays through the existing `Sound.play` SFX path, so the existing SFX Volume
  setting applies and nothing new is added to settings.
- The intended final asset is a NEW dedicated clip (`pile_open.wav`). Until it
  exists, an existing clip stands in as a placeholder.

## Affected files

Changed:
- `game/puzzle_pile.lua` or `game/scenes/game_scene.lua` (`_spawn_box`) -- play
  the sound once a box has actually been created. Either location fires only on
  a real spawn, for both players, with no change to `game/player.lua`. The
  implementation picks one; `_spawn_box` right after the box is created is the
  natural fit since the early-return failure paths are already there.
- `tests/` (e.g. `tests/test_scene.lua` or a pile-focused test) -- cover that a
  successful spawn plays the sound and a blocked spawn does not, using the
  existing `Sound.play` spy pattern from `tests/test_player.lua`.

Later, when the real asset is sourced (not part of this change):
- `assets/sounds/pile_open.wav` -- new clip.
- `main.lua` (`SFX_MANIFEST.sfx`) -- register `pile_open`.
- `assets/sounds/attribution.txt` -- credit line for the new clip.
- The play call is switched from the stand-in name to `pile_open`.

## What changes

- A successful pile press plays a one-shot SFX.
- Stand-in sound: `pick_up`. It is a real (not placeholder-copy) clip, reads as
  a physical grab/lift, and is a better fit for taking a box off the pile than
  the UI clicks (`menu_navigate`/`menu_confirm`) or `rotate`/`poof`, which are
  currently identical copies of `menu_navigate`. It is explicitly a
  placeholder: it will be swapped for `pile_open.wav` once that clip is sourced,
  at which point the manifest and attribution entries are added.
- Because the stand-in is already in the manifest, this change needs no new
  asset, manifest entry, or attribution line.

## What stays the same

- Pile behavior: spawning, `can_start_puzzle()` gating, pool exhaustion,
  occupancy checks, and the pile's drawing/count logic.
- Silent blocked presses (no `fail` sound).
- `poof` on box open and `put_down` on box landing.
- `game/player.lua` interaction/range logic, including piece pick-up, which
  also uses `pick_up`.
- SFX Volume / Music Volume settings and `lua/core/sound.lua` (no new API).
- Headless behavior: `Sound.play` is already a safe no-op without `love.audio`.

## Open questions

- Is `pick_up` acceptable as the stand-in, given players will also hear the
  same clip when grabbing a piece? Alternative: `menu_confirm`.
- Should the real `pile_open.wav` be sourced from freesound.org (CC0, matching
  the existing attribution style)? Not blocking; tracked as follow-up work.
