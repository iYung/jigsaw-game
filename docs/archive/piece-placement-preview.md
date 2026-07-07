## Piece Placement Preview Checklist

Design: `docs/design/piece-placement-preview.md`

- [x] Task A — `game/player.lua` — Extract the inline snap-target math currently at
      `game/player.lua:36-40` (`target_x`, `target_y`, `snap_x`, `snap_y`, computed from
      `self:centre()`, `C.U`, `C.SLOT`) into a new method `Player:drop_target()` that returns
      `{ x = target_x, y = target_y, snap_x = snap_x, snap_y = snap_y }`, using the exact same
      centre/offset/floor-to-grid formula (no behavior change). Update the interact-drop branch in
      `Player:update` (the `if self.held_piece ~= nil then ... end` block starting at line 35) to call
      `local drop_target = self:drop_target()` and use `drop_target.x`, `drop_target.y`,
      `drop_target.snap_x`, `drop_target.snap_y` in place of the local `target_x`/`target_y`/`snap_x`/
      `snap_y` it previously computed inline — the occupied-slot check and `self.held_piece:drop(...)`
      call must keep using these same values, just sourced from the new method. Do not change
      `Player:draw()` in this task (that's Task C). No dependency on Task B; can be done in parallel
      with it since they touch different files.

- [x] Task B — `game/jigsaw_piece.lua` — Add `JigsawPiece:draw_ghost(x, y, alpha)` (default
      `alpha = 0.35` when not passed). Implementation: save the sprite's current `x`, `y`, and
      `color[4]`; set `self.sprite.x = x`, `self.sprite.y = y`, `self.sprite.color[4] = alpha`; call
      `self.sprite:draw()`; then restore the saved `x`, `y`, and `color[4]` onto `self.sprite` before
      returning, so the piece's real state (`sprite.x/y/color[4]`, `state`, `rotation_step`) is
      byte-for-byte unchanged after the call returns. Keep the piece's current `sprite.rotation` as-is
      during the ghost draw (no rotation reset — there is no "correct rotation" concept here). Place
      the new method near the existing `JigsawPiece:draw()` (line 62-64); leave `draw()` and all other
      methods untouched. No dependency on Task A; can be done in parallel with it since they touch
      different files.

- [x] Task C — `game/player.lua` — Depends on Task A (needs `Player:drop_target()`) and Task B (needs
      `JigsawPiece:draw_ghost`). In `Player:draw()` (currently lines 116-121), when
      `self.held_piece ~= nil`, compute `local drop_target = self:drop_target()` and call
      `self.held_piece:draw_ghost(drop_target.snap_x, drop_target.snap_y)` *before* the existing
      `self.held_piece:draw()` call, so the faint ground-preview copy renders under the piece that's
      drawn floating above the player. Draw order in the block must end up: `self.sprite:draw()`, then
      (if holding) `self.held_piece:draw_ghost(...)`, then `self.held_piece:draw()`. No occupancy check
      here — the ghost always renders at the snap target regardless of whether another piece currently
      occupies it; that check stays exclusive to the actual-drop branch touched in Task A.

- [x] Task D — `tests/test_jigsaw.lua` — Depends on Tasks A, B, and C all being complete. Add test
      coverage (follow the existing `do ... end` block + `assert` + `print("PASS: ...")` style already
      used in this file):
      - `Player:drop_target()` returns `{x, y, snap_x, snap_y}` matching the same centre/offset/
        floor-to-grid formula previously inlined at the interact-drop site — cover at least one case
        where the player's position is already grid-aligned and one where it isn't, confirming
        `snap_x`/`snap_y` floor to the nearest `C.SLOT` multiple.
      - Dropping a held piece via `Player:update` (interact pressed) still lands the piece at the same
        `snap_x`/`snap_y` as before the refactor, and the existing occupied-slot rejection still works
        — i.e. Task A's extraction didn't change drop behavior.
      - `JigsawPiece:draw_ghost(x, y, alpha)` draws (e.g. spy on `sprite:draw`/`love.graphics` calls to
        confirm a draw happened at the given position/alpha) and afterward leaves
        `sprite.x`, `sprite.y`, `sprite.color[4]`, `state`, and `rotation_step` identical to their
        values immediately before the call — capture those values beforehand and assert equality
        after.
      - Calling `draw_ghost` with no `alpha` argument defaults to `0.35`.

### Task dependency order
Tasks A and B touch different files (`game/player.lua` vs `game/jigsaw_piece.lua`) and have no
dependency on each other, so they can run in parallel. Task C touches `game/player.lua` again and
depends on both A (`Player:drop_target()`) and B (`JigsawPiece:draw_ghost`) existing first, so it must
run after both are done — do not parallelize C with A or B. Task D depends on A, B, and C all being
complete, since it tests the finished behavior of all three. Run order: {A, B} in parallel → C → D.
