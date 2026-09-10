# Puzzle Complete Animation Checklist

- [x] Task A — `game/constants.lua` — Add `PIECE_CELEBRATE_DURATION = 0.45` to the returned constants table
- [x] Task B — `game/jigsaw_piece.lua` — Add `start_celebrate()` (sets state to `"celebrating"`, initialises `celebrate_timer`) and `update_celebrate(dt)` (drives spring-bounce scale on `sprite.scale_x/y`; when timer expires resets scale to 1, calls `self:start_vanish()`, returns `true`)
- [x] Task C — `game/scenes/game_scene.lua` — In the solved-detection loop (line ~333), replace `piece:start_vanish()` with `piece:start_celebrate()`; in the piece-update loop (line ~341), add a branch for `piece.state == "celebrating"` that calls `piece:update_celebrate(dt)` (no removal — removal happens via the existing vanish path)
