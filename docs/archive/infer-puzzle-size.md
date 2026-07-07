## Infer Puzzle Size Checklist

**Run order** (dependencies noted per-task below):
- **Wave 1 — parallel:** Task A (`game/jigsaw_box.lua`) and Task B (`game/jigsaw_solver.lua` +
  `game/constants.lua`) touch disjoint files and neither reads the other's new surface — safe to run
  as separate agents at the same time.
- **Wave 2 — sequential, after Wave 1:** Task C (`game/scenes/game_scene.lua`) calls the new
  `box.rows`/`box.cols`/`box.piece_count` fields from Task A and the new
  `JigsawSolver.is_assembled(pieces, expected_count)` signature from Task B, so both must land first.
- **Wave 3 — sequential, after Wave 2:** Task D (`tests/test_jigsaw.lua`) asserts on the final shape
  of all three code changes above, so it must run last, once Tasks A, B, and C are all complete.

---

- [x] Task A — `game/jigsaw_box.lua` — In `JigsawBox.new` (currently lines 26-35), replace the
  hardcoded 3x3 assumption with inference from the loaded image's pixel size against the fixed
  `C.SLOT` cell size:
  1. Replace `local cellW = imgW / 3` / `local cellH = imgH / 3` (lines 26-27) with `local cols =
     imgW / C.SLOT` and `local rows = imgH / C.SLOT` — cell size is fixed at `C.SLOT` x `C.SLOT`
     pixels per the design, so the cell dimensions passed into `love.graphics.newQuad` become
     `C.SLOT`, `C.SLOT` directly rather than a computed `cellW`/`cellH`.
  2. Immediately after computing `cols`/`rows`, assert both are positive whole numbers, e.g.:
     ```lua
     assert(cols == math.floor(cols) and cols > 0,
         "puzzle image width must be a positive multiple of C.SLOT, got " .. tostring(imgW))
     assert(rows == math.floor(rows) and rows > 0,
         "puzzle image height must be a positive multiple of C.SLOT, got " .. tostring(imgH))
     ```
     This is the fail-fast behavior resolved in the design's open question #2 — a non-multiple image
     dimension is a content bug and must error at load time, not floor/crop silently.
  3. Store `self.rows = rows`, `self.cols = cols`, and `self.piece_count = rows * cols` on the box —
     new fields other code (Task C's `game_scene.lua`, Task D's tests) reads instead of assuming 9.
  4. Generalize the slicing loop (lines 30-35) from `for row = 0, 2 do for col = 0, 2 do` to `for row
     = 0, rows - 1 do for col = 0, cols - 1 do`, passing `C.SLOT, C.SLOT` (not `cellW`/`cellH`) as the
     quad's width/height. The quad's pixel offset stays `col * C.SLOT, row * C.SLOT`. No other change
     to this loop's body (the `pieces_to_spawn` entry shape, including `image`/`quad`/`row`/`col`, is
     unchanged).
  5. No changes to `_eject_next`, `interact`, `update`, `centre`, or `draw` — piece rendering and
     ejection are already size-agnostic per the design's "what stays the same" section.
  - **No dependencies — parallel-safe with Task B.**

- [x] Task B — `game/jigsaw_solver.lua` and `game/constants.lua` — Move the piece-count gate from a
  global constant to an explicit per-call argument:
  1. In `game/jigsaw_solver.lua`, change the function signature at line 5 from `function
     M.is_assembled(pieces)` to `function M.is_assembled(pieces, expected_count)`, and change the
     guard at line 6 from `if #pieces ~= C.PUZZLE_PIECE_COUNT then return false end` to `if #pieces ~=
     expected_count then return false end`. `local C = require("game/constants")` at the top of the
     file stays — `C.SLOT` is still used later in the function (lines 12-13). No change to the
     alignment/rotation check logic below the guard (lines 8-21).
  2. In `game/constants.lua`, delete the `PUZZLE_PIECE_COUNT = 9,` entry (line 12) from the returned
     table. This task is the only reader of `C.PUZZLE_PIECE_COUNT` in production code, so it's safe to
     remove in the same task — after this change nothing reads a global piece count anywhere.
  - **No dependencies — parallel-safe with Task A.**

- [x] Task C — `game/scenes/game_scene.lua` — Replace whole-field completion tracking with per-box
  tracking. **Depends on Task A** (`box.rows`/`box.cols`/`box.piece_count`) **and Task B**
  (`JigsawSolver.is_assembled(pieces, expected_count)`) — do not start until both are complete.
  1. In `GameScene:on_enter` (currently around line 36), remove `self.puzzle_solved = false` and add
     `self.active_puzzles = {}` instead.
  2. Both places a `JigsawBox` is created and appended to `self.boxes` — the initial box in
     `on_enter` (line 38) and the new box in `_spawn_box` (line 65) — also append an entry to
     `self.active_puzzles` at creation time (not when the box finishes ejecting), e.g. `{ pieces =
     box.spawned, piece_count = box.piece_count, solved = false }`. `box.spawned` is the same table
     the box appends newly-ejected pieces into (`game/jigsaw_box.lua:113`), so the entry's `pieces`
     reference stays live as ejection proceeds — no need to re-fetch it later.
  3. In `GameScene:update(dt)`, replace the single whole-field check (currently lines 95-100: `if not
     self.puzzle_solved and JigsawSolver.is_assembled(self.pieces) then ... end`) with a loop over
     `self.active_puzzles`: for each entry where `not entry.solved`, call
     `JigsawSolver.is_assembled(entry.pieces, entry.piece_count)`; if true, set `entry.solved = true`
     and call `piece:start_vanish()` on every piece in `entry.pieces` (mirroring what the old code did
     to `self.pieces`). This lets independently-sized and simultaneously-active puzzles each register
     as solved on their own, per the design's completion-checking goal.
  4. The existing vanish/fade/removal loop over `self.pieces` (lines 102-112) is unchanged — it
     already removes any piece whose fade completes regardless of which box spawned it.
  5. After that loop, prune `self.active_puzzles`: remove any entry where `entry.solved` is true and
     every piece in `entry.pieces` has fully faded (`piece.sprite.color[4] == 0`, the value
     `JigsawPiece:update_fade` clamps to once `fade_timer <= 0`, per `game/jigsaw_piece.lua:45-49`).
     This is the "decoupled from box lifecycle" mechanism from the design's resolved open question
     #1 — a fully-ejected, not-yet-solved box already left `self.boxes` (lines 85-91, unchanged) well
     before this point, so `self.active_puzzles` is the only place still tracking it.
  6. No changes to `_spawn_box`, the box-ejection loop, the box-removal loop (lines 85-91), player
     update, camera follow, or `draw`.

- [x] Task D — `tests/test_jigsaw.lua` — Update assertions to match the new per-box, explicit-count
  shape. **Depends on Tasks A, B, and C** — run only once all three land, since this task asserts on
  their final combined behavior.
  1. `JigsawBox.new` test (~line 291-295): alongside the existing `#box.pieces_to_spawn == 9`
     assertion, add `assert(box.rows == 3, ...)`, `assert(box.cols == 3, ...)`, and
     `assert(box.piece_count == 9, ...)` to actually exercise the new inference path (which happens to
     still produce 3x3 for the existing 192x192 images) rather than just its side effect.
  2. Every `JigsawSolver.is_assembled(pieces)` call site (currently ~lines 925, 933, 946, 954, 956)
     updates to pass an explicit expected count, e.g. `JigsawSolver.is_assembled(pieces, 9)` — the
     `build_assembled_pieces(ox, oy)` helper (line 907, builds a 3x3/9-piece set) is unaffected in
     shape, only the call signature changes.
  3. The `game_scene` integration test (~lines 964-1015) that currently reads
     `C.PUZZLE_PIECE_COUNT` (lines 987, 998) and checks `gs.puzzle_solved` (line 994) updates to:
     assert against a literal `9` (or a locally computed `#spawned`) instead of the now-deleted
     `C.PUZZLE_PIECE_COUNT`, and check the corresponding `self.active_puzzles` entry's `solved` field
     (or that the entry has been pruned once fully faded) instead of the removed
     `gs.puzzle_solved` boolean. Since this test manually replaces `gs.pieces` rather than going
     through a real `JigsawBox`, it will also need to seed `gs.active_puzzles` with a matching entry
     (`{ pieces = spawned, piece_count = 9, solved = false }`) so the new per-entry check in
     `GameScene:update` has something to evaluate.
  4. Add a small new test for the multi-puzzle scenario this feature enables: two boxes' pieces
     assembled independently (e.g. via two `active_puzzles` entries with different `piece_count`s, or
     two real `JigsawBox` instances ejected and arranged) should each be detected and vanish
     independently — solving one must not require the other's pieces to also be off the field, and
     must not block the other from later registering as solved. This directly exercises the behavior
     the design calls out as broken today (`game/scenes/game_scene.lua:95-96`'s single global check).
  5. No changes needed to unrelated tests earlier in the file (constants, `JigsawPiece`, `Player`,
     `SpawnButton`, `Drawer` sections) — this feature doesn't touch their behavior.
