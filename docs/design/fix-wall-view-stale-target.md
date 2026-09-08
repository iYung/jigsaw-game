## Goal

Fix the wall-view tile so it reliably frames **all** completed puzzles,
including ones that were added to the shelf after wall view was entered.

## Root cause

`GameScene:_toggle_wall_view` computes the bounding box of
`self.completed_puzzles` **once**, at the instant the player presses E to
enter wall view. The result is stored in `self.wall_target1` and never
updated. Two failure scenarios follow from this static snapshot:

**Scenario A — puzzle completes while already in wall view**
The player enters wall view. While the camera is panning to the shelf, a
puzzle whose pieces were already fully assembled finishes its 0.5-second fade
and is shelved via `GameScene:_shelve`. The new entry is appended to
`self.completed_puzzles` and added to the drawer, but `wall_target1` was
already computed without it. The camera settles on the old bounding box;
the new puzzle image sits on the shelf but outside the framed area.

**Scenario B — player presses E within 0.5 s of completing a puzzle**
If the player is already standing near the wall tile when the last piece
snaps into place, they can press E before the 0.5-second piece fade
finishes. `completed_puzzles` has only previously shelved puzzles at that
moment; the newest puzzle is not yet shelved. The camera pans to the old
bounding box, leaving the most recent puzzle invisible.

In both cases the result is "camera pans but doesn't show all the completed
puzzles."

## Affected files

- **`game/scenes/game_scene.lua`** — refactor `_toggle_wall_view` to extract
  the bounding-box + zoom computation into a private helper
  `_compute_wall_target(which)` that returns `{x, y, zoom}` (or `nil` when
  `completed_puzzles` is empty). Call this helper:
  1. Inside `_toggle_wall_view` (as today, to populate the target on entry).
  2. Every frame in `GameScene:update()` while `view1 == "wall"` (and
     `view2 == "wall"` in 2-player mode), so `wall_target1/2` always reflects
     the current shelf contents. The camera's lerp will then smoothly track
     any new additions.

  No other files need to change — `Camera:follow` already lerps toward a
  changing target correctly, and `_shelve` already appends to
  `completed_puzzles` and the drawer.

- **`tests/test_scene.lua`** — update the existing wall-view tests to cover
  the dynamic-target case: add a puzzle to `completed_puzzles` after entering
  wall view, then call `update(dt, ...)` and assert that `wall_target1` shifts
  to include the new puzzle.

## What changes

- `wall_target1` / `wall_target2` are recomputed every frame while the
  corresponding player is in wall view, so the camera always frames the full
  current shelf bounding box, including any puzzles added during the session
  of wall view.
- Pressing E to enter wall view when `completed_puzzles` is empty remains a
  no-op (the helper returns `nil`; no target is set and `view1` stays `"play"`).

## What stays the same

- The `_toggle_wall_view` toggle logic (enter on first press, exit on second)
  is unchanged.
- `_shelve`'s shelf layout math is unchanged.
- Camera lerp rate (`0.85`) is unchanged.
- 2-player independence is unchanged — each player's target is computed
  from the shared `completed_puzzles` list, but tracked in separate fields.
- Save/load is unchanged — `wall_target` is transient and never persisted.
- The fix is purely in the update loop, not in the draw or interaction paths.

## Open questions

None — root cause is identified, fix is targeted and minimal.
