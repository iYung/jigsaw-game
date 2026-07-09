## Goal

Today `JigsawSolver.is_assembled` (`game/jigsaw_solver.lua:10`) rejects a
puzzle outright if *any* piece has a non-zero `rotation_step`, and only
recognizes the single unrotated arrangement as "solved" (README.md:12: "right
rotation, right relative position"). Pieces spawn with a random 0-3
`rotation_step` (`game/jigsaw_box.lua:127-130`), so today the player must
rotate every piece back to upright before the puzzle can complete.

This feature relaxes that: a puzzle should also count as solved if the whole
assembled picture is coherent but rotated as a single rigid unit — 90°, 180°,
or 270° from upright — rather than only the fully-upright arrangement.
Confirmed with the user: this means **all pieces share one consistent
rotation** (the picture still looks correct, just sideways/upside-down), not
each piece rotated independently of its neighbors, and not free/continuous-
angle rotation (rotation stays in the existing 90°-step model).

## Affected files

- `game/jigsaw_solver.lua` — `M.is_assembled` (currently lines 5-22): replace
  the hard `rotation_step ~= 0` rejection (line 10) and the direct
  `sprite.x/SLOT - piece.col` / `sprite.y/SLOT - piece.row` comparison (lines
  12-13) with a rotation-aware version (see "What changes" below). This is
  the only file with real logic changes.

- `tests/test_jigsaw.lua` — the existing `is_assembled` tests (lines
  1093-1151, `build_assembled_pieces` helper at 1099-1112) assert the old
  all-zero-rotation-only behavior and must be extended:
  - line 1122-1128 ("false when a piece is rotated") stays valid *only* as
    "false when pieces disagree on rotation" — needs its fixture changed to
    mixed rotation_steps (e.g. piece 1 at step 1, rest at step 0), since a
    puzzle uniformly rotated to step 1 must now pass.
  - new cases: a fully-assembled layout with every piece at
    `rotation_step = 1` (and 2, and 3) arranged per the rotated-grid mapping
    should return `true`; a layout where every piece shares the same
    non-zero `rotation_step` but is still arranged using the *unrotated*
    grid mapping should return `false` (rotation and layout must agree).
  - the "two pieces swapped" case (1130-1141) and "constant offset" case
    (1143-1151) should be repeated at a non-zero shared rotation step too, to
    confirm the relative/offset-invariance logic still holds once rotated.
  - integration tests around solve→vanish (lines ~1153+) are unaffected in
    behavior (they use `rotation_step = 0` throughout), but worth a note/
    comment that solving-while-rotated is exercised at the unit level, not
    duplicated at the integration level.

- `README.md` — line 12 ("right rotation, right relative position") and line
  25 (`jigsaw_solver.lua` structure blurb: "all unrotated and in correct
  relative arrangement") both describe the old any-piece-rotated-fails rule
  and need updating once the behavior changes.

No changes needed to `game/jigsaw_piece.lua` (`:rotate()` stays a plain
90°-step cycle), `game/player.lua` (rotation input is unchanged — still
R-key, still only while holding a piece), `lua/core/sprite.lua` (rendering
already supports arbitrary rotation), or `game/scenes/game_scene.lua` (still
just calls `is_assembled` once per active puzzle per frame).

## What changes

**Rotation-aware grid mapping.** Today "correct" position is derived by
subtracting the piece's source-image coordinates directly from its world
grid cell: `px, py = sprite.x/SLOT - col, sprite.y/SLOT - row`, then
requiring every piece to produce the same `(px, py)` (the shared offset is
the puzzle's arbitrary world position). To support the whole picture being
rotated as a rigid body, `(row, col)` needs to be run through a 90°-step
rotation transform *before* that subtraction, matching whichever
`rotation_step` the pieces have adopted:

| rotation_step (`k`) | `(gx, gy)` used in place of `(col, row)` |
|---|---|
| 0 | `(col, row)` |
| 1 | `(-row, col)` |
| 2 | `(-col, -row)` |
| 3 | `(row, -col)` |

This is a 90°-per-step rotation of the `(col, row)` point, applied `k`
times, and it uses the same rotation direction `sprite.rotation = k *
(pi/2)` already draws pieces in (`jigsaw_piece.lua:27`) — so a player who
rotates every piece with `R` the same number of times and re-lays them out
consistently with that rotation direction is the case this is meant to
recognize. As before, the resulting `(gx, gy)` are only ever compared for
*relative* consistency (subtracted from `sprite.x/y / SLOT`, then checked
for one shared `(ox, oy)` across all pieces) — absolute world position is
still irrelevant.

**Single shared rotation, not per-piece.** `k` is read once from the first
piece (`pieces[1].rotation_step`) and every other piece must match it
exactly — if rotations differ across pieces, the puzzle is not solved,
matching the user's chosen interpretation (whole puzzle rotated together,
not each piece independently). This replaces the old blanket "any non-zero
rotation_step fails" check with "all pieces must agree on one rotation_step
(0, 1, 2, or 3), and their positions must line up under that rotation's grid
mapping."

**Shape of the new function**, replacing the current body:

```lua
function M.is_assembled(pieces, expected_count)
    if #pieces ~= expected_count then return false end

    local k = pieces[1].rotation_step
    local ox, oy
    for i, piece in ipairs(pieces) do
        if piece.rotation_step ~= k then return false end

        local gx, gy = M.rotate_cell(piece.row, piece.col, k)
        local px = piece.sprite.x / C.SLOT - gx
        local py = piece.sprite.y / C.SLOT - gy
        if i == 1 then
            ox, oy = px, py
        elseif px ~= ox or py ~= oy then
            return false
        end
    end

    return true
end
```

with a small `M.rotate_cell(row, col, k)` helper implementing the table
above (`k` taken mod 4). Exact naming/shape is left to the implementing
task, but the algorithm shape (single pass, one early `k` read, no nested
loop over candidate rotations) is intentional — since all pieces must
already agree on `k`, there's no need to try all four rotations per call.

## What stays the same

- Rotation stays a 90°-step integer model (`rotation_step` 0-3) — no free
  or continuous-angle rotation is introduced.
- `R` still only rotates the currently-held piece; no new input, no
  rotate-while-grounded, no mouse/drag rotation.
- Piece ejection still assigns a random initial `rotation_step` per piece
  (`jigsaw_box.lua:127-130`), unchanged.
- Grid-snap-on-drop (`jigsaw_piece.lua:34-38`) and the ghost drop preview
  (`draw_ghost`) are unchanged — neither currently considers correctness,
  only grid alignment.
- Absolute world position of a solved puzzle remains irrelevant — only
  relative arrangement (now also relative *rotation*) is checked.
- Piece count check (`#pieces ~= expected_count`) is unchanged and still
  runs first.
- Solve detection is still polled once per frame per active puzzle from
  `game_scene.lua`'s existing loop; vanish/fade/shelf behavior downstream of
  a puzzle becoming solved is entirely unchanged.

## Open questions

Resolved by the user before this doc was written:
1. "Any orientation" means the whole assembled puzzle can be solved rotated
   as one rigid unit (all pieces sharing one `rotation_step`), not each
   piece independently, and not free-angle rotation.

Still open: none blocking. One implementation-level detail intentionally
left to the task/checklist phase rather than decided here: the exact name
and internal form of the rotation-mapping helper (e.g. whether it's a
standalone `M.rotate_cell` function or inlined) — functionally equivalent
either way.
