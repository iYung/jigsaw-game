## Remove Piece Shader Checklist

- [x] Task A — `game/jigsaw_piece.lua` — Remove all piece-side shader wiring, bundled as one edit since it's three tiny changes in the same small file:
  1. Delete the module-level dead code at lines 10-12: `local piece_shader = Shader.load("assets/shaders/rounded_corners.frag")`, `piece_shader:send("size", {C.SLOT, C.SLOT})`, and `piece_shader:send("uv_rect", {0, 0, 1, 1})`.
  2. In `JigsawPiece.new()`, delete line 24, `self.sprite.shader = piece_shader`, from inside the `if visual then ... end` block (lines 19-25). Do not remove any other lines in that block (`self.sprite.image`, `self.sprite.quad`, `self.row`, `self.col` all stay).
  3. In `start_vanish()` (currently lines 46-50), delete the now-redundant line `self.sprite.shader = nil` (line 49), since the sprite's shader is never set to anything else, so clearing it there is a no-op. Leave the rest of the method (`self.state = "vanishing"` and `self.fade_timer = C.PIECE_FADE_DURATION`) unchanged.
  - After this task, check whether the `local Shader = require("lua/core/shader")` at the top of the file (line 3) is still used elsewhere in `game/jigsaw_piece.lua`; if not, remove that require too. (Grep the file for `Shader` after making the above deletions.)
  - Result: `JigsawPiece.new()` never assigns anything to `self.sprite.shader`, so it stays `nil` for the sprite's entire lifetime (Sprite.new's default), for pieces constructed with or without a `visual`, and after `start_vanish()`.

- [x] Task B — `tests/test_jigsaw.lua` — Update the three shader-wiring assertions in the "shader wiring (rounded tile corners)" block (currently lines 1282-1303) to match the new always-nil behavior:
  1. Lines 1284-1289 (piece constructed *with* a `visual`): change `assert(p.sprite.shader ~= nil, "piece constructed with a visual should carry a non-nil sprite.shader")` to `assert(p.sprite.shader == nil, "piece constructed with a visual should not carry a shader")`, and update the following `print("PASS: ...")` message to say the shader is nil (not "assigns a non-nil sprite.shader"), e.g. `"PASS: jigsaw_piece: new() with visual leaves sprite.shader nil"`.
  2. Lines 1291-1297 (`start_vanish()` after a `visual`-constructed piece): the assertion `assert(p.sprite.shader == nil, "start_vanish() should clear sprite.shader to nil")` and its print message are already correct (shader was already nil before `start_vanish()` runs, and stays nil) — leave as-is, no change needed.
  3. Lines 1299-1303 (piece constructed *without* a `visual`): already asserts `p.sprite.shader == nil` — already correct, leave as-is, no change needed.
  - Net effect: only the first do-block's assertion message/direction actually needs editing; the other two do-blocks in this section are already consistent with the new behavior and should not be touched.
  - This task's expected final state (`sprite.shader == nil` in all three cases) is fully specified by the design doc and does not require inspecting Task A's actual diff — it can be done in parallel with Task A. However, note for the orchestrator: if both tasks are applied to the *same* working copy sequentially, running the test suite after only one of the two tasks lands will show a transient failure (test expects nil, but code hasn't been changed yet, or vice versa) — this is expected and not a bug. Only run/rely on `tests/test_jigsaw.lua` as a pass/fail gate once both Task A and Task B are merged together. If run in isolated worktrees, no such ordering concern applies.

- [x] Task C — `assets/shaders/rounded_corners.frag` — Update the stale header comment (line 1) to no longer claim the shader is shared by jigsaw pieces. Change:
  `// Rounded-corner mask shader, shared by jigsaw pieces and the trophy shelf.`
  to something reflecting that it's used by the completed-puzzle/trophy-shelf rendering path only, e.g.:
  `// Rounded-corner mask shader, used by the completed-puzzle trophy shelf.`
  Do not change any other line in this file (the `RADIUS` constant, `uniform vec2 size`, or the UV-bounds comment/logic below it are untouched — the shader itself is still fully functional and used by `game/scenes/game_scene.lua`'s shelved-entry rendering).
  This task is fully independent of Tasks A and B (different file, no shared code path) and can run in parallel with both.

### Task dependencies

- Tasks A, B, and C touch three different files and can all run in parallel (parallel-safe).
- Task B's expected assertions are fully determined by the design doc already, so it does not need to wait for Task A's actual diff to be written correctly — but the full test suite should only be treated as a green/red gate once both A and B have landed in the same working copy (a partial state, with only one of the two applied, will show an expected transient failure).
- Task C has no coupling to A or B at all.
