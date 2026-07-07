# Infer Puzzle Size

## Goal
`JigsawBox` currently assumes every puzzle image is a 3x3 grid: `game/jigsaw_box.lua:24-25` hardcodes
`cellW = imgW / 3`, `cellH = imgH / 3`, and the slicing loop (`game/jigsaw_box.lua:28-33`) iterates
`row = 0, 2` / `col = 0, 2`. This works today only because all three source images
(`assets/puzzles/1.png`, `2.png`, `3.png`) happen to be 192x192 and are the only images that exist.
Nothing in the code actually reads the image and figures out how many pieces it should become — the
"3" is a bare literal in two places.

The user wants grid size **inferred from the puzzle image itself** rather than assumed. Per
discussion, the design settled on three points:

1. **Inference method** — fixed cell pixel size. Each cell is `C.SLOT` (64px, `game/constants.lua`)
   on a side, so `cols = imgW / C.SLOT` and `rows = imgH / C.SLOT`. This isn't a coincidence to
   preserve: today's 192x192 images already equal `3 * C.SLOT` per side, so this produces the exact
   same 3x3 grid for the existing images with zero data changes — purely a code fix.
2. **Grid shape** — rectangular grids are allowed (`rows` need not equal `cols`). A future
   192x256 image should infer a valid 3x4 grid rather than being rejected for not being square.
3. **Completion checking** — this repo's solver (`game/jigsaw_solver.lua`) currently checks
   *the whole field* against one hardcoded piece count (`C.PUZZLE_PIECE_COUNT = 9`,
   `game/constants.lua:12`), used at `game/jigsaw_solver.lua:6`. That assumption breaks the moment
   two boxes are active with different sizes, or even two same-size boxes at once (their pieces
   would sum to more than the expected count and never register as solved). This feature moves
   completion tracking to be **per-box**: each box's own spawned pieces are checked for assembly
   independently, using that box's own piece count, so differently-sized (and simultaneously active)
   puzzles can each be completed on their own.

## Affected files
- `game/jigsaw_box.lua`
  - `JigsawBox.new` computes `cols = imgW / C.SLOT` and `rows = imgH / C.SLOT` instead of dividing by
    the literal `3`. Both must come out to positive whole numbers — a puzzle image whose dimensions
    aren't exact multiples of `C.SLOT` is a content bug, not a runtime case to silently round; it
    should fail loudly (`assert` or `error`) at load time rather than slice a partial cell.
  - The slicing loop generalizes from `row = 0, 2` / `col = 0, 2` to `row = 0, rows - 1` /
    `col = 0, cols - 1`.
  - The box stores its own `self.rows`, `self.cols`, and `self.piece_count` (`rows * cols`) — new
    fields other code (the solver, tests) reads instead of assuming 9.
- `game/jigsaw_solver.lua`
  - `M.is_assembled(pieces)` currently takes one list (the whole field) and compares its length to
    the global `C.PUZZLE_PIECE_COUNT`. It changes to accept an explicit expected count —
    `M.is_assembled(pieces, expected_count)` — checked against `#pieces`, so callers scope both the
    piece list *and* the count to a single box rather than the whole field.
  - No change to the actual alignment/rotation check logic (relative row/col offset comparison) —
    only the piece-count gate and where the list/count come from.
- `game/scenes/game_scene.lua`
  - Today, `JigsawSolver.is_assembled(self.pieces)` is called once per frame against the single
    global `self.pieces` list, and a box is dropped from `self.boxes` as soon as it finishes
    ejecting (`state == "done"`), regardless of whether its puzzle has been solved yet
    (`game/scenes/game_scene.lua:82-86`). Per-box completion tracking needs *something* that outlives
    a box's presence in `self.boxes`, since a fully-ejected, not-yet-solved box is otherwise dropped.
    See "Open questions" for the exact mechanism.
  - The vanish-on-solve loop (`game/scenes/game_scene.lua:97-99`) changes from a single
    `self.puzzle_solved` boolean covering the whole field to per-puzzle tracking, so solving one
    box's puzzle doesn't require every other in-progress puzzle's pieces to also be absent from the
    field, and doesn't block subsequent puzzles from ever registering as solved.
- `game/constants.lua` — `PUZZLE_PIECE_COUNT = 9` is removed; nothing reads a global piece count
  after this change.
- `tests/test_jigsaw.lua`
  - The `JigsawBox.new` test asserting `#box.pieces_to_spawn == 9` (line ~293) stays correct for the
    current 192x192 images but should also assert `box.rows == 3`, `box.cols == 3`, and
    `box.piece_count == 9` to actually exercise the new inference path instead of just its side
    effect.
  - `jigsaw_solver` tests (lines ~926, ~987, ~998) that reference `C.PUZZLE_PIECE_COUNT` update to
    pass an explicit expected count to `is_assembled` instead.
  - Any test constructing pieces via `build_assembled_pieces(3, 3)` (line ~953) is unaffected in
    shape, just needs the updated `is_assembled(pieces, 9)` call signature.

## What changes
- Grid dimensions become a per-box computed property (`self.rows`, `self.cols`,
  `self.piece_count`), derived from the loaded image's pixel size divided by the fixed `C.SLOT` cell
  size, instead of a hardcoded `3`.
- Rectangular (non-square) grids are supported wherever square ones were assumed — piece slicing,
  storage, and the solver's expected count all key off `rows * cols`, not a literal 9 or an assumed
  square root.
- Puzzle completion becomes per-box: each box's own spawned pieces are checked for assembly against
  that box's own piece count, independent of any other box's pieces on the field. Multiple
  differently-sized (or same-sized) puzzles can be in progress and solved independently and
  concurrently.
- `C.PUZZLE_PIECE_COUNT` is deleted — piece count is no longer a global constant anywhere.

## What stays the same
- Piece **rendering** is already size-agnostic: `Sprite:draw()` (`lua/core/sprite.lua:22-46`) scales
  whatever quad it's given to the sprite's fixed `width`/`height` (`C.SLOT` x `C.SLOT`), so pieces
  from a differently-sized source grid still render on-screen at the same fixed piece size as today.
  No rendering code changes.
- The three existing puzzle images (`1.png`, `2.png`, `3.png`) are untouched — same 192x192
  dimensions, same pixel content, same generation script. They continue to infer to a 3x3 grid
  exactly as before; this feature adds no new puzzle images.
- Ejection order/shuffle, ejection stagger timing, spawn-position search, per-piece random initial
  rotation, drop/rotate mechanics, and the spawn button are untouched.
- The core alignment check inside `is_assembled` (comparing each piece's row/col-relative offset and
  requiring `rotation_step == 0`) is untouched — only its piece-count gate and the scope of pieces it
  receives change.

## Open questions
1. **Mechanism for tracking not-yet-solved boxes past ejection.** A box leaves `self.boxes` as soon
   as `state == "done"` (fully ejected), which can happen well before its puzzle is assembled. Per-box
   completion tracking needs a place to keep checking `{ pieces = box.spawned, piece_count =
   box.piece_count }` until solved, decoupled from box lifecycle/rendering. Proposed: `GameScene`
   keeps a separate `self.active_puzzles` list, appended to when a box is created (not when it
   finishes ejecting), each entry checked via `JigsawSolver.is_assembled` every frame and removed once
   solved (after its pieces finish vanishing). Flag before Phase 3 if a different structure is
   preferred.
2. **Non-multiple image dimensions.** Should an image whose width or height isn't an exact multiple
   of `C.SLOT` fail fast with a clear error (proposed default), or should it be handled some other
   way (e.g. floor and drop leftover pixels)? Proposed default is fail-fast since a silently-cropped
   puzzle piece would be a confusing runtime surprise.
3. **Scope of this pass.** No new (rectangular or otherwise non-3x3) puzzle image is being added as
   part of this feature — this is purely infrastructure so a future image of any `C.SLOT`-multiple
   size works without further code changes. Confirm that's the intended scope (vs. also wanting at
   least one non-3x3 test image added now to prove it end-to-end).
