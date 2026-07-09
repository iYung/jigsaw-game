## Goal

Once a solved puzzle finishes fading out (today its pieces just vanish and its
`active_puzzles` entry is silently pruned — `game/scenes/game_scene.lua`
lines ~155-169), show the fully assembled puzzle image, at its real size, on
a permanent "trophy shelf" above the world's top bound. Puzzles accumulate
left-to-right in solve order as the session progresses, so the shelf is a
running record of every puzzle solved so far — not just the up-to-3
concurrently-active puzzles the existing cap allows.

## Affected files

- `game/jigsaw_box.lua` — `JigsawBox.new` currently loads
  `local puzzle_image = love.graphics.newImage(path)` (line 36) but never
  keeps a reference past building quads. Store it as `self.image =
  puzzle_image` so callers can read `box.image` after the box has finished
  ejecting pieces (today nothing on `self` survives that lets a caller later
  identify which image a spawned set of pieces came from).

- `game/scenes/game_scene.lua`:
  - `on_enter()` (~line 62-66) and `_spawn_box()` (~line 100-104): both
    construct an `active_puzzles` entry as `{pieces = box.spawned,
    piece_count = box.piece_count, solved = false}`. Both add `image =
    box.image, cols = box.cols, rows = box.rows` to that entry so the image
    and its cell dimensions (already computed in `JigsawBox.new` as
    `self.cols`/`self.rows`) survive independently of the box, which is
    already gone from `self.boxes` by the time the puzzle is solved.
  - `on_enter()`: initialize `self.completed_puzzles = {}` alongside the
    existing `self.active_puzzles = {}` (line 52). This is the permanent,
    never-pruned list backing the trophy shelf, kept separate from
    `active_puzzles` (which is still pruned once fade completes, per its
    existing role).
  - `update()`'s existing fade-prune loop (~line 155-169): today, once every
    piece in a solved entry reaches alpha 0, the entry is simply removed from
    `active_puzzles`. Right before removal, compute that puzzle's shelf slot
    (see below), build a small drawable `{image, x, y, draw = ...}` wrapper,
    append it to `self.completed_puzzles`, and `self.drawer:add(...)` it
    (same pattern as pieces/boxes) so it renders through the normal
    camera-transformed draw pass. No changes to `draw()` itself — the shelf
    draws through the existing `Scene.draw()` → `camera:attach()` →
    `drawer:draw()` pipeline, same as everything else in the world.

- `game/constants.lua` — no required change; the trophy drawable can reuse
  `C.PRIORITY_PIECE` for its drawer priority since it never overlaps pieces
  spatially (it's off past the top bound). Called out here in case review
  prefers a dedicated priority constant instead.

- `tests/test_jigsaw.lua` — will need new coverage for: `box.image` being
  set, the `active_puzzles` entry carrying `image`/`cols`/`rows`, and a
  fully-faded solved entry producing a `completed_puzzles` entry at the
  expected slot position. (Left to the checklist/task phase to spell out
  exact assertions.)

- `README.md` — document the trophy shelf briefly, matching how seen-
  tracking and the 3-puzzle cap are already documented.

## What changes

- **Image survives past the box and past fade-pruning.** `JigsawBox` keeps
  its loaded `love.graphics.Image` on `self.image`; `GameScene` copies that
  reference (plus `cols`/`rows`) onto the `active_puzzles` entry at spawn
  time, so it's still available once the box object is long gone and the
  pieces have finished fading.

- **A new permanent list, `self.completed_puzzles`, on `GameScene`.** Unlike
  `active_puzzles` (pruned once fade completes) or `GameState.solved_count`
  (a plain counter, no image data), this list holds one entry per puzzle
  ever solved this session, in solve order, and is never pruned. It lives on
  `GameScene` rather than the `GameState` singleton because it holds
  `love.graphics.Image`/drawable objects — `GameState` is deliberately kept
  headless-testable with no `love.graphics` dependency (per its own header
  comment), and drawing is the scene's responsibility.

- **Deterministic shelf layout.** Each newly-completed puzzle is placed at:
  - `y = -(C.SLOT + rows * C.SLOT)` — i.e. the image's *bottom* edge lands
    at `y = -C.SLOT`, one piece-size gap above the world's top bound
    (`y = 0`), and the image extends upward (further negative y) from
    there. Confirmed by the user: "one piece size above the top bound"
    means the gap between the play area and the shelf (not the display
    height), and the image's bottom edge (not top) is what's anchored at
    that offset — so images grow upward, staying entirely outside the
    playable world regardless of size.
  - `x` = the sum of the pixel widths (`cols * C.SLOT`) of every
    previously-shelved puzzle, plus a fixed `C.SLOT` gap after each one, in
    solve order. The first solved puzzle's slot starts at `x = 0`; the next
    starts at `x = prev_x + prev_cols * C.SLOT + C.SLOT`, and so on.
  - Because puzzles can differ in `cols`/`rows` (and therefore pixel
    width/height) between difficulty tiers, **slot width is variable per
    puzzle**, computed from that puzzle's own image dimensions rather than
    a fixed piece-size or fixed shelf-slot width.

- **Visibility works with no camera changes.** The camera (`lua/core/
  camera.lua`) has no hard clamp of its own — it lerps toward the player,
  and the player's position is clamped to the world's `[0, world_h -
  C.SLOT]` bound. When the player is near the top edge, the camera already
  shows negative world-y coordinates on screen (confirmed via the
  camera's transform math: `screen_y=0` maps to `world_y = camera.y -
  360` at zoom 1, and `camera.y` tracks near the player's y, which can be
  as low as ~32). So a shelf anchored at `y <= -C.SLOT` becomes visible
  simply by walking toward the top of the world — no new camera logic is
  needed.

## What stays the same

- `active_puzzles` keeps its existing role and pruning behavior — pieces
  still fade the same way, over the same `C.PIECE_FADE_DURATION`, and the
  entry is still removed from `active_puzzles` once fully faded. The only
  addition is that removal now also produces a `completed_puzzles` entry
  instead of the puzzle's image simply being discarded.
- `GameState.solved_count`/`active_count` and the 3-puzzle active cap
  (`docs/archive/design/puzzle-count-tracking.md`) are untouched — this
  feature is purely additive display, not a change to solve/spawn
  bookkeeping.
- No persistence to disk — like the rest of `GameState`/session data, the
  trophy shelf is in-memory and reset on process restart (and via
  `GameState:reset()`/a fresh `GameScene`, for test isolation).
- **Assumption: purely decorative.** The shelf images are drawn only — no
  collision, no pickup, no interaction. This wasn't explicitly asked for in
  the original request; recommended as the lowest-risk default given the
  otherwise display-only scope of this feature. If interactivity is wanted
  later, it's a separate follow-up.
- `JigsawBox`'s piece-cutting, shuffling, and ejection animation are
  unchanged — the only change to the box is retaining one extra reference
  (`self.image`) it already loads today.
- Player movement/clamping, floor rendering, and the spawn button are all
  unaffected.

## Open questions

Resolved by the user before this doc was written:
1. Visual form — full assembled image at actual size (not a piece-size
   thumbnail).
2. Multiple puzzles — all accumulate on the shelf, left-to-right in solve
   order, for the whole session (not capped at 3).
3. Persistence — permanent once shown; does not fade again.
4. Placement — fixed slot along the top edge, deterministic by solve order,
   independent of where in the world the puzzle was actually solved.
5. Gap between shelf slots — a fixed `C.SLOT` gap is inserted between
   adjacent shelved images (not packed edge-to-edge).
6. Vertical anchor — each image's *bottom* edge sits one piece-size above
   `y = 0` (images grow upward, staying entirely outside the playable
   world regardless of size).

Still open:
1. **Interactivity** — assumed purely decorative (no collision/pickup); see
   "What stays the same." Only blocking if this assumption is wrong.
