# Box Land Sound

## Goal
Play the existing `put_down` sound effect whenever a box that flew out of the box pile lands on the ground (i.e. finishes its spawn-in flight and settles into its grid cell).

## Affected files
- `game/jigsaw_box.lua` — add `Sound.play("put_down")` at the flying→waiting transition in `JigsawBox:update`.

## What changes
- `game/jigsaw_box.lua` requires `lua/core/sound` (mirroring the pattern used for the `poof` sound in `_eject_next`).
- In `JigsawBox:update`, inside the `"flying"` branch, when `self.fly_timer <= 0` (line 100-102 today) — the single, non-repeating moment the box snaps to its target position and transitions `self.state = "waiting"` — add a call to `Sound.play("put_down")`.
- No new sound asset or manifest entry needed: `put_down` is already registered in `main.lua`'s `SFX_MANIFEST.sfx` (line 36) and already loaded by `lua/core/sound.lua`. It's currently also used in `game/player.lua:127` when the player drops a held piece; `Sound.play` already supports overlapping/simultaneous playback (used today for rapid `pick_up`/`put_down`/`poof` events), so reusing the same sfx name for box landings needs no changes to the sound system itself.

## What stays the same
- The very first box of a game session (`game_scene.lua:193`, created without `spawn_from`) starts directly in `"waiting"` state and never enters `"flying"`. It will remain silent — it never visually lands, so no sound plays. (Confirmed with user — this is the desired behavior.)
- No changes to `lua/core/sound.lua`, `main.lua`'s `SFX_MANIFEST`, or any asset files.
- No changes to box spawning, flight arc, timing, or any other box behavior.
- No debounce/throttle logic needed for simultaneous landings.

## Open questions
None outstanding — the one ambiguity (whether the non-flying first box should also play the sound) was resolved with the user: it stays silent.
