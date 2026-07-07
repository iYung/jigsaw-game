# Box Disappear On Interact

## Goal
Today a `JigsawBox` only disappears once it has finished ejecting all 9 of its pieces:
`JigsawBox:interact()` (`game/jigsaw_box.lua:43-48`) flips `state` from `"waiting"` to
`"ejecting"`, and `GameScene:update` (`game/scenes/game_scene.lua:85-91`) only sets
`box.sprite.visible = false` and removes the box from `self.boxes` once `box.state == "done"` —
which only happens after the 9th piece has been ejected (`game/jigsaw_box.lua:110-112`), roughly
2.7 seconds after the player pressed `E` (9 pieces, 0.3s apart, per
`game/jigsaw_box.lua:50-57`). The player presses interact once but the box visibly lingers for
several seconds afterward, which reads as unresponsive.

The user wants the box to vanish **the instant** the player interacts with it, not after the full
eject sequence completes. Per an already-resolved decision with the user, the remaining pieces
should keep trickling out on their existing 0.3s stagger from the box's last known position in the
background — only the box's own visibility/interactability changes, not the piece-spawn timing or
the state machine driving it.

## Affected files
- `game/jigsaw_box.lua` — `JigsawBox:interact()` gains one line: when it transitions `state` from
  `"waiting"` to `"ejecting"`, it also sets `self.sprite.visible = false` immediately, in the same
  branch. Nothing else about the state machine, `update()`, or `_eject_next()` changes — the box
  keeps counting down `spawn_timer` and ejecting pieces exactly as before, it's just no longer
  drawn while doing so.
  Separately (bundled into this same change because it was surfaced while reviewing this code):
  `JigsawBox.new(x, y, world_w, world_h)` gains two new parameters, stored as `self.world_w` /
  `self.world_h`. `_eject_next` rejects any candidate slot where `tx < 0 or tx >= self.world_w or
  ty < 0 or ty >= self.world_h`, in addition to the existing occupied-slot check, before accepting
  it. This is a pre-existing bug fix, unrelated to the box-visibility change: today `_eject_next`
  has no bounds check at all, so a box spawned near the world edge (e.g. via the spawn button,
  which places boxes anywhere in `[0, cols-1] x [0, rows-1]`) can eject pieces at `tx == world_w`
  or negative coordinates, off the playable ground. The box's own tile (Manhattan distance `d = 0`)
  remains excluded from the search, unchanged — that stays out of scope for this change.
- `game/scenes/game_scene.lua` — both `JigsawBox.new(...)` call sites (`on_enter` and
  `_spawn_box`) pass `self.world_w, self.world_h` as the new trailing arguments. No other
  functional change. `GameScene:update`'s existing removal loop
  (`game/scenes/game_scene.lua:85-91`) keeps checking `box.state == "done"` before removing the box
  from `self.boxes`, which is still the correct gate: the box must stay in `self.boxes` (so
  `box:update(dt, self.pieces)` keeps firing every frame) until all 9 pieces have actually been
  ejected, even though it's been invisible since the moment of interact. The loop's
  `box.sprite.visible = false` line becomes a redundant no-op by the time it runs (the sprite was
  already hidden back in `interact()`), but it's left in place — it's harmless, keeps the loop
  self-explanatory on its own, and costs nothing since `state` can only reach `"done"` after
  `interact()` has already run.
- `tests/test_jigsaw.lua` — add coverage: (1) `box.sprite.visible` becomes `false` immediately
  after `interact()`, while `box.state` is `"ejecting"` (not waiting for `"done"`). (2) after
  `interact()`, the box keeps ejecting pieces on subsequent `update()` calls exactly as before
  (same 9-updates-to-`"done"` behavior), proving invisibility doesn't interrupt the eject sequence.
  (3) a `GameScene`-level check that an interacted-with box remains in `self.boxes` (and thus keeps
  receiving `update()`) until its 9th piece is ejected, even though its sprite is already invisible
  from the first frame.

## What changes
- `box.sprite.visible` is set to `false` inside `JigsawBox:interact()`, at the same moment `state`
  flips to `"ejecting"` — i.e. on the very frame the player presses `E`, not ~2.7s later when the
  last piece pops out.
- The box visually disappears instantly on interact, while its 9 pieces continue to eject one at a
  time every 0.3s from its last on-screen position, exactly as they do today — just with no box
  sprite drawn there anymore.
- `JigsawBox` now knows the world bounds and `_eject_next`'s slot search skips any candidate outside
  `[0, world_w) x [0, world_h)`, so boxes near an edge or corner no longer eject pieces off the
  playable ground.

## What stays the same
- The state machine is unchanged: `"waiting"` → `"ejecting"` → `"done"`, driven by the same
  `spawn_timer` / `_eject_next` logic in `game/jigsaw_box.lua`. `state` still only becomes `"done"`
  once all 9 pieces have been ejected.
- `GameScene:update`'s loop still keeps an `"ejecting"` box in `self.boxes` and still calls
  `box:update(dt, self.pieces)` on it every frame, so the staggered piece spawning is completely
  unaffected — only its visibility timing changes, not its behavior.
- The box is only removed from `self.boxes` (and thus stops updating / stops ejecting) once
  `state == "done"`, same as today.
- `Player:update`'s nearest-box search (`game/player.lua:89-101`) already filters on
  `b.state == "waiting"`, so a box mid-eject is already excluded from being re-interacted with —
  this was already correct before this change and needs no modification. Since `interact()` flips
  `state` away from `"waiting"` in the same call that hides the sprite, there is no window where an
  invisible box could still be found and re-triggered (no double-interact bug).
- No change to how the `Drawer` (`lua/core/drawer.lua`) or `Sprite` (`lua/core/sprite.lua`) work:
  `Drawer:draw()` unconditionally calls `entry.sprite:draw()` on every layer entry, but
  `Sprite:draw()` itself checks `if not self.visible then return end` before drawing anything
  (`lua/core/sprite.lua:22`), and `JigsawBox:draw()` just delegates to `self.sprite:draw()`. So
  setting `sprite.visible = false` is already sufficient to suppress drawing without ever calling
  `self.drawer:remove(box)` — this is the same pattern `GameScene:update` already relies on today
  for the "done" case, just triggered earlier.

## Open questions
None outstanding. Three questions were raised and resolved with the user before/while this doc was
written:
- **What happens to the remaining un-ejected pieces when the box vanishes early?** Resolved: keep
  the existing staggered spawn. The box sprite vanishes instantly on interact, but the box's
  internal state machine and `update()` loop keep running in the background exactly as before, so
  the remaining pieces still trickle out one every 0.3s from the box's last known position — only
  the box itself stops being drawn and stops being a valid interact target.
- **Should the box's own tile (Manhattan distance `d = 0`) become a valid eject slot now that the
  box disappears immediately, instead of staying permanently excluded?** Resolved: leave as-is,
  out of scope for this change.
- **Should the pre-existing lack of world-bounds checking in `_eject_next` (pieces can eject off
  the edge of the map) be fixed as part of this change?** Resolved: yes, fix now. `JigsawBox` takes
  `world_w`/`world_h` and rejects out-of-bounds candidate slots (see "What changes").
