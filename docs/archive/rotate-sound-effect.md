## Rotate Sound Effect Checklist

- [x] Task A — `assets/sounds/rotate.wav` + `assets/sounds/attribution.txt` — Create `rotate.wav` as a copy of `menu_navigate.wav` (temporary placeholder). Add a line to `attribution.txt` noting `rotate.wav` is a placeholder copy of `menu_navigate.wav`, pending a real sourced sound.
- [x] Task B — `main.lua` — Add `"rotate"` to the `sfx` array inside `SFX_MANIFEST` (currently listing `pick_up`, `put_down`, `fail`, `menu_navigate`, `menu_confirm`, `puzzle_complete`, around line 39-46), so it is preloaded by `Sound.load(SFX_MANIFEST)`.
- [x] Task C — `game/player.lua` — In `Player:update`, at the `rotate_piece` input handling block (~line 203-207), call `Sound.play("rotate")` immediately after `self.held_piece:rotate()`, only inside the branch where `self.held_piece` is non-nil.

Dependency note: Task B (manifest) must land before/with Task A (asset file) since `Sound.load` will error at startup if `rotate.wav` is listed but missing, or if the code plays a sound that was never loaded. Run A and B together, then C. Not parallelized due to this coupling.
