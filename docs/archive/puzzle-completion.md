# Puzzle Completion Checklist

- [x] Task A — `game/constants.lua` — Add `C.PIECE_FADE_DURATION = 0.5` (seconds, fade-out duration
      for a solved piece) and `C.PUZZLE_PIECE_COUNT = 9` (expected piece count for a solved 3x3
      puzzle) to the returned table. No other changes to this file.

- [x] Task B — `game/jigsaw_box.lua` — In `JigsawBox.new`, the loop that builds
      `self.pieces_to_spawn` (`for row = 0, 2 do for col = 0, 2 do ... end end`) currently pushes
      `{ image = puzzle_image, quad = quad }`. Add `row = row, col = col` to that table so each spec
      carries its correct-cell identity (e.g. `{ image = puzzle_image, quad = quad, row = row, col =
      col }`). Do not change the shuffle logic, ejection animation, or anything else in this file.

- [x] Task C — `game/jigsaw_piece.lua` — Depends on Task A (`C.PIECE_FADE_DURATION` must exist).
      1. In `JigsawPiece.new(x, color, visual)`, inside the existing `if visual then ... end` block
         (where `self.sprite.image`/`self.sprite.quad` are set from `visual`), also set
         `self.row = visual.row` and `self.col = visual.col`.
      2. Add a new method `JigsawPiece:start_vanish()` that sets `self.state = "vanishing"` and
         `self.fade_timer = C.PIECE_FADE_DURATION`.
      3. Add a new method `JigsawPiece:update_fade(dt)` that decrements `self.fade_timer` by `dt`,
         sets `self.sprite.color[4] = math.max(0, self.fade_timer / C.PIECE_FADE_DURATION)`, and
         returns `true` once `self.fade_timer <= 0` (fade complete), `false` otherwise.
      Do not change `pick_up`, `drop`, `update`, `rotate`, or `draw`.

- [x] Task D — `game/jigsaw_solver.lua` (**new file**) — Depends on Task A
      (`C.PUZZLE_PIECE_COUNT`) and the piece interface added in Task C (`piece.row`, `piece.col`,
      `piece.rotation_step`, `piece.sprite.x/y`, `piece.state`) — write against that interface as
      specified here without needing Task C's file changes to land first. Export a single function
      `is_assembled(pieces)` that returns `true` only if:
      - `#pieces == C.PUZZLE_PIECE_COUNT` (this also guarantees no piece is currently held, since
        held pieces are never members of the scene's `pieces` array).
      - Every piece has `rotation_step == 0`.
      - There exists a single constant grid offset `(ox, oy)` such that for every piece,
        `piece.sprite.x / C.SLOT - piece.col == ox` and `piece.sprite.y / C.SLOT - piece.row == oy`
        (take the offset from the first piece, then check every other piece matches it).
      Follow the module style of `game/jigsaw_box.lua` (`local M = {}` / `return M`, or a plain
      table with the function — match whichever pattern reads more consistently with sibling files).

- [x] Task E — `game/scenes/game_scene.lua` — Depends on Tasks C and D.
      1. `require("game/jigsaw_solver")` at the top alongside the other requires.
      2. In `GameScene:update(dt)`, after the existing `self.player:update(...)` call: if
         `not self.puzzle_solved` and `JigsawSolver.is_assembled(self.pieces)` is true, set
         `self.puzzle_solved = true` and call `piece:start_vanish()` on every piece in
         `self.pieces`.
      3. Still in `GameScene:update(dt)`, each frame, iterate `self.pieces` (backwards, since
         entries may be removed) and for any piece with `piece.state == "vanishing"`, call
         `piece:update_fade(dt)`; if it returns `true`, remove that piece from `self.pieces`, call
         `self.drawer:remove(piece)`, and clear its entry from `self.pieces_in_drawer`.
      4. Initialize `self.puzzle_solved = false` in `GameScene:on_enter`.

- [x] Task F — `tests/test_jigsaw.lua` — Depends on Tasks A–E all being complete. Add tests for:
      - `JigsawBox.new`'s `pieces_to_spawn` entries each carry correct, non-nil `row`/`col` fields
        matching their quad's source cell (0,1,2 range, all 9 combinations present exactly once).
      - `JigsawPiece.new` copies `row`/`col` from `visual` onto the piece.
      - `JigsawPiece:start_vanish()` sets `state == "vanishing"` and a positive `fade_timer`.
      - `JigsawPiece:update_fade(dt)` progressively lowers `sprite.color[4]` and returns `true` only
        once the timer is exhausted (test with a couple of partial-dt calls, then enough to finish).
      - `jigsaw_solver.is_assembled`: returns `false` for fewer than 9 pieces, `false` when any piece
        is rotated, `false` when relative arrangement is wrong, and `true` for a correctly-arranged
        set of 9 pieces regardless of *which* absolute world offset they're arranged at.
      - A `GameScene`-level (or equivalent) integration check: once assembled, pieces move to
        `"vanishing"` and are eventually removed from both the scene's piece list and the drawer
        after the fade duration elapses.
