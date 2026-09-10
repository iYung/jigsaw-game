# Puzzle Complete Animation

## Goal
Play a brief "celebration" animation on the assembled jigsaw pieces before they fade out, making puzzle completion feel more satisfying.

## Affected files
- `game/constants.lua` — add `PIECE_CELEBRATE_DURATION`
- `game/jigsaw_piece.lua` — add `start_celebrate()` and `update_celebrate(dt)` methods; add `"celebrating"` state
- `game/scenes/game_scene.lua` — call `start_celebrate()` instead of `start_vanish()` on solve; update celebrating pieces in the update loop

## What changes

### New piece state: `"celebrating"`
A new state inserted between `"grounded"` and `"vanishing"`. When a puzzle is solved, each piece enters `"celebrating"` instead of jumping straight to `"vanishing"`. At the end of the celebration, the piece automatically transitions to `"vanishing"` (existing fade behavior).

### Spring-bounce scale animation (0.45 s)
The `update_celebrate(dt)` method drives a three-phase spring effect on `sprite.scale_x` / `sprite.scale_y`:
- **Phase 1 (0 → 40%):** scale 1.0 → 1.3 (quick pop outward)
- **Phase 2 (40 → 70%):** scale 1.3 → 0.95 (overshoot back)
- **Phase 3 (70 → 100%):** scale 0.95 → 1.0 (settle)

Scale resets to 1.0 before `start_vanish()` is called, so the fade starts at normal size.

### game_scene.lua update loop
A new branch in the existing piece-update loop handles `"celebrating"` pieces — calls `update_celebrate(dt)` and does not remove the piece (removal still happens through the vanish path). The `all_faded` check is unchanged: celebrating pieces have alpha = 1 so they correctly fail it.

## What stays the same
- Fade duration and logic (`PIECE_FADE_DURATION`, `update_fade`, `start_vanish`)
- Shelving logic and timing (shelve still happens after all pieces reach alpha = 0)
- Sound cue timing (`puzzle_complete` still plays at the moment of solve detection)
- Save/restore logic (celebrating is transient, never persisted; `to_save` already collapses solved entries)
- 2-player behavior

## Open questions
None — proceeding to checklist.
