## Goal

Individual jigsaw pieces should no longer render with the rounded-corner mask
shader while a puzzle is being actively assembled. The shader should continue
to be applied to the "trophy shelf" image shown once a puzzle is completed.

## Affected files

- `game/jigsaw_piece.lua` — defines and applies the module-level `piece_shader`
  (loaded from `assets/shaders/rounded_corners.frag`) to every piece's
  `self.sprite.shader` in `JigsawPiece.new()` whenever the piece is constructed
  with a `visual` (i.e. every real, in-play piece — held, grounded, or still
  sitting in a spawned box). `start_vanish()` (line 49) already sets
  `self.sprite.shader = nil` once a puzzle is solved and its pieces begin
  fading out.
- `game/scenes/game_scene.lua` (lines ~206-223) — separately loads its own
  `entry_shader` from the same `assets/shaders/rounded_corners.frag` and
  applies it only to the consolidated "shelved" full-puzzle-image entry added
  to `self.completed_puzzles` once every piece in a solved puzzle has finished
  fading. This is the "completed puzzle" rendering path and is untouched by
  this change.
- `tests/test_jigsaw.lua` (lines 1282-1303) — three existing assertions
  currently encode the *current* (to-be-removed) behavior: that
  `JigsawPiece.new()` assigns a non-nil `sprite.shader` when constructed with a
  `visual`, and nil otherwise. These need to be updated to assert
  `sprite.shader` is always `nil` regardless of `visual`, for both the
  constructor and `start_vanish()`.
- `tests/test_jigsaw.lua` (~line 1749) — asserts the shelved/completed-puzzle
  entry still carries a non-nil shader; this assertion is correct as-is and
  should NOT change.
- `assets/shaders/rounded_corners.frag` — not modified. Its header comment
  ("shared by jigsaw pieces and the trophy shelf") will become stale once
  pieces stop using it; comment should be updated to reflect it's used by the
  trophy shelf only (and by extension, whatever the checklist agent decides to
  do with the piece-side dead code).

## What changes

- `JigsawPiece.new()` no longer sets `self.sprite.shader = piece_shader` when
  constructed with a `visual`. Individual pieces (on the ground, held by the
  player, or freshly spawned from a box) render with square corners.
- The now-unused module-level `piece_shader` object and its two `:send(...)`
  calls (lines 10-12 of `game/jigsaw_piece.lua`) are removed as dead code,
  since nothing will reference them anymore.
- The now-redundant `self.sprite.shader = nil` line in `start_vanish()`
  (line 49) becomes a no-op (shader is already nil) — left in place is
  harmless, but the checklist agent may choose to remove it for cleanliness
  since it no longer does anything.
- `tests/test_jigsaw.lua`'s three piece-shader-wiring tests (lines
  1284-1303) are updated to assert `sprite.shader == nil` in all three cases
  (with visual, after `start_vanish()`, without visual), since the shader is
  never assigned to a piece sprite anymore.
- The comment atop `assets/shaders/rounded_corners.frag` is updated to no
  longer describe itself as "shared by jigsaw pieces and the trophy shelf."

## What stays the same

- `game/scenes/game_scene.lua`'s shelved/completed-puzzle rendering path
  (lines ~189-228) is untouched: once a solved puzzle's pieces finish fading
  out, the consolidated full-image "shelf" entry still gets its own
  `entry_shader` (rounded corners) applied via `love.graphics.setShader`.
- The shader file itself, `assets/shaders/rounded_corners.frag`, is not
  deleted or functionally modified — it's still a valid, working shader,
  just no longer loaded/applied from `jigsaw_piece.lua`.
- Pile boxes (`game/jigsaw_box.lua`, `game/puzzle_pile.lua`) are unaffected —
  confirmed by reading both files, neither currently references the shader at
  all (consistent with commit 959ed01 having reverted da72a4b). This request
  does not reintroduce it there.
- The brief "solved but still fading" period (`entry.solved == true`,
  individual pieces fading via `update_fade`) is unaffected in *behavior*:
  those pieces already have `sprite.shader == nil` today via the existing
  `start_vanish()` call, so there is no visible change to that transition —
  it just becomes true for the piece's entire lifetime instead of only from
  `start_vanish()` onward.

## Open questions

None blocking. The codebase gave an unambiguous, single-piece answer:
exactly one place assigns the shader to individual pieces
(`game/jigsaw_piece.lua`'s `JigsawPiece.new()`), and exactly one separate,
already-independent place applies it to completed puzzles
(`game/scenes/game_scene.lua`'s shelved-entry code). There is only one scene
file in the codebase, so no other rendering path needed to be checked. Two
small judgment calls are left for the checklist/task agent rather than user
input, since they don't change behavior either way:

1. Whether to delete the dead `piece_shader` load/`:send()` lines in
   `jigsaw_piece.lua` outright (recommended) versus leaving them defined but
   unused.
2. Whether to leave the now-inert `self.sprite.shader = nil` line in
   `start_vanish()` or remove it as dead code.
