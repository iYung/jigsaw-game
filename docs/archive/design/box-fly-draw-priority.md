# Box Fly Draw Priority

## Goal

When a puzzle box is spawned from `PuzzlePile` (`GameScene:_spawn_box()`), it
plays a "flying" arc animation (`JigsawBox.state == "flying"`) from the pile
to its resting slot. Today that box is added to the `Drawer` at
`C.PRIORITY_PIECE` (5), the same layer as every other grounded piece/box. The
player sprite draws at priority 10, above that layer, so the flying box can
currently pass behind the player mid-arc. The box should draw above
everything else — including the player — for the duration of the flight, then
return to normal layering once it lands.

Scope (confirmed with user): only the `"flying"` state gets the elevated
priority. The box's `"ejecting"` state (spawning pieces after the box itself
is interacted with) and its idle `"waiting"` state are unaffected.

## Affected files

- `game/constants.lua` — add a new priority constant above the player's.
- `lua/core/drawer.lua` — `Drawer` currently has no way to change an already-
  added entry's priority; needs one.
- `game/scenes/game_scene.lua` — spawn flying boxes at the new top priority;
  restore `C.PRIORITY_PIECE` once a box finishes flying.

## What changes

1. `game/constants.lua`: add `PRIORITY_BOX_FLYING = 20` (any value above the
   player's `10`), exported alongside `PRIORITY_PIECE`.
2. `lua/core/drawer.lua`: add `Drawer:set_priority(sprite, priority)` — finds
   the existing layer entry for `sprite`, updates its priority, and re-sorts
   `self.layers`. Mirrors the existing `add`/`remove` style.
3. `game/scenes/game_scene.lua`:
   - In `_spawn_box()`, the box created with `spawn_from` (the one that
     starts in `"flying"`) is added to the drawer at `C.PRIORITY_BOX_FLYING`
     instead of `C.PRIORITY_PIECE`.
   - In `GameScene:update()`, the loop that calls `box:update(dt, ...)` for
     each box records whether the box was `"flying"` before the call; if it
     was flying and no longer is afterward (i.e. it just landed), call
     `self.drawer:set_priority(box, C.PRIORITY_PIECE)` to drop it back to the
     normal piece layer.

## What stays the same

- The box created in `on_enter()` without `spawn_from` (starts directly in
  `"waiting"`) keeps using `C.PRIORITY_PIECE` — it never flies, so nothing
  changes for it.
- Boxes restored from a save (`JigsawBox.from_save`) never resume in
  `"flying"` (state collapses to `"waiting"`/`"ejecting"` on save), so the
  restore path is untouched.
- `"ejecting"` and `"waiting"` box states keep their current `C.PRIORITY_PIECE`
  layering — no change to how the box looks once it's landed and popping out
  pieces.
- The arc motion, timing, and all other `JigsawBox` animation logic are
  unchanged; this is purely a draw-order fix.

## Open questions

None outstanding — scope was clarified with the user before writing this doc
(elevated priority applies only during the `"flying"` state, reverting once
the box lands).
