# Poof Sound on Piece Emerge

## Goal
Play a "poof" sound effect each time a jigsaw piece is ejected from a box and appears on the board, mirroring the existing pattern used for the rotate sound effect (`b7749b9 Add rotate sound effect`).

## Affected files
- `game/jigsaw_box.lua` — `JigsawBox:_eject_next(pieces)` (lines 114-169) is where a new `JigsawPiece` is constructed and appended to the `pieces` table; this is the single call site for "a piece emerges from a box." Needs a `local Sound = require("lua/core/sound")` at the top and a `Sound.play("poof")` call added in this function.
- `main.lua` — `SFX_MANIFEST.sfx` list (lines 39-47) needs `"poof"` added alongside the existing `"pick_up", "put_down", "fail", "menu_navigate", "menu_confirm", "puzzle_complete", "rotate"` entries so `Sound.load` registers it.
- `assets/sounds/poof.wav` — new audio asset (does not exist yet).
- `assets/sounds/attribution.txt` — needs a new line crediting the source of `poof.wav` (existing convention — every file in `assets/sounds/` is attributed here, e.g. `rotate.wav is a temporary placeholder, copied from menu_navigate.wav, pending a real sourced sound`).
- `tests/test_jigsaw_box.lua` — does not currently exist (no unit tests for `JigsawBox` today). If a poof-sound test is desired, it would need to follow the pattern in `tests/test_player.lua`'s Test 4 (lines 127-181), which stubs `Sound.play` to record calls and asserts `played_contains(played, "rotate")`.

## What changes
- `lua/core/sound.lua` itself is unchanged — its `Sound.load`/`Sound.play` API already supports adding a new named sfx with zero code changes (confirmed by reading `Sound.load`, which just iterates `manifest.sfx` and looks up `manifest.sfx_dir .. name .. ".wav"`).
- `game/jigsaw_box.lua`:
  - Add `local Sound = require("lua/core/sound")` near the other top-of-file `require`s (alongside `Sprite`, `JigsawPiece`, `C`, `PuzzleCatalog`, `GameState`).
  - In `JigsawBox:_eject_next(pieces)`, after the piece is constructed and pushed into `pieces`/`self.spawned` (around line 163-164), call `Sound.play("poof")`. This mirrors `game/player.lua` line 206, where `Sound.play("rotate")` is called directly after the action it accompanies (`self.held_piece:rotate()`), rather than being buried deeper in a helper.
- `main.lua`: add `"poof"` to `SFX_MANIFEST.sfx` (same list `rotate` was added to when the rotate sound effect shipped).
- New asset file `assets/sounds/poof.wav`, added to `assets/sounds/attribution.txt` following the existing one-line-per-file convention.

## What stays the same
- `lua/core/sound.lua` — no API changes; `Sound.play(name)` already clones the source and applies current sfx volume (see lines 37-45), so volume/mute settings (`Settings` scene, `_sfx_volume`) apply to the new sound automatically.
- The box state machine (`"waiting"` → `"ejecting"` → `"done"` / `"flying"`) and the eject timing (`spawn_timer` reset to `0.3` between pieces) are unchanged.
- Piece placement search logic (`_eject_next`'s Manhattan-distance slot search) is unchanged.
- `JigsawBox.from_save` / `to_save` (serialization) are unchanged — no new persisted state is introduced.
- All other existing sound effects (`pick_up`, `put_down`, `fail`, `rotate`, etc.) and their trigger points in `game/player.lua` are unchanged.

## Open questions (resolved)
1. **Asset sourcing:** Placeholder now. Copy an existing sfx file to `assets/sounds/poof.wav` (mirroring how `rotate.wav` was copied from `menu_navigate.wav`), documented in `attribution.txt` as a temporary placeholder pending a real sourced sound.
2. **Frequency:** Every eject, no debounce. `Sound.play("poof")` is called unconditionally inside `_eject_next`, matching how `rotate`/`pick_up`/`put_down` already behave.
3. **Box arrival:** Piece ejects only. `Sound.play("poof")` is added only to `JigsawBox:_eject_next`, not to the box's own "flying" arrival animation.
