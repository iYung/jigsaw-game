## Goal

After using "Continue" to resume a save that already has a puzzle fully laid
out on the board (its box already finished ejecting all pieces before the
save happened), finishing that puzzle never fires completion: no fade, no
`GameState.solved_count`/`active_count` update, no shelving. Puzzles whose
box is still mid-ejection at save time, and puzzles started fresh (no
Continue involved), both work correctly. Fix `GameScene`'s resume path so
every in-progress puzzle's completion bookkeeping survives save/load,
regardless of whether its box object still exists at save time.

## Affected files

- `game/scenes/game_scene.lua` — `GameScene:on_enter()`'s save-restore
  branch (step "(e)", lines ~93–112) and `GameScene:to_save()` (lines
  ~396–456).
- `tests/test_jigsaw.lua` — new integration test(s) covering resume +
  completion detection, alongside the existing `active_puzzles`
  integration tests around lines 1978–2010 and 2317–2379.
- `docs/archive/design/save-load.md` — the original save/load design doc's
  assumption ("`active_puzzles` is fully derived today ... so it needs no
  separate save format of its own") is the source of this bug; no code
  change to this archived doc, but the new design doc should be read
  alongside it since it corrects that assumption.

## What changes

### Root cause

`GameScene:update()`'s completion check only looks at `self.active_puzzles`:

```lua
for _, entry in ipairs(self.active_puzzles) do
    if not entry.solved and JigsawSolver.is_assembled(entry.pieces, entry.piece_count) then
```

`self.active_puzzles` is never itself serialized. `GameScene:to_save()`
only writes `pieces` (loose grounded pieces), `boxes` (still-live
`JigsawBox` objects), and `completed_puzzles` (already-shelved puzzles).
On restore, `on_enter()`'s step (e) rebuilds `active_puzzles` entries
*only by iterating `self._save_data.boxes`* — for each restored box, it
matches loose pieces by `path` and creates one `active_puzzles` entry.

A box is removed from `self.boxes` the moment its last piece is ejected
(`GameScene:update()`, lines 245–251: `if box.state == "done" then
table.remove(self.boxes, i) end`), well before the puzzle is actually
solved. So a puzzle whose box already finished ejecting — i.e. the puzzle
is "already out," fully laid on the board — has **no box left to save**.
Its pieces are still saved (they're `state == "grounded"` in `self.pieces`),
but on load there is no box to drive step (e), so **no `active_puzzles`
entry is ever created for it**. The pieces sit on the board, correctly
drawn, but nothing in `GameScene:update()`'s per-entry loop is watching
them — completion can never fire no matter how the player arranges them.

This is exactly the scenario the original save-load design doc
(`docs/archive/design/save-load.md`) got wrong: it assumed "`active_puzzles`
... is fully derived today ... so it needs no separate save format of its
own," which held only while every active puzzle still had a live box.

A second, narrower instance of the same root cause: a piece the player is
actively holding at save time (`self._save_data.player.held_piece`) is
restored straight into `self.player.held_piece` (step (b)) but is never
added to `self.pieces`, and is therefore never picked up by step (e)'s
path-matching loop either. In the normal (non-Continue) flow, a held piece
was already added to its puzzle's `entry.pieces` at the moment it was
ejected from the box and simply stays there while carried (pickup only
removes it from `self.pieces`, the loose-piece list — not from
`entry.pieces`). Resume breaks that invariant: a puzzle whose only "missing"
piece was in the player's hand at save time can never reach
`#entry.pieces == entry.piece_count` after resume, even after the piece is
dropped correctly, because it was never linked into that entry's `pieces`
table in the first place.

### Fix

Make the set of in-progress puzzles an explicit part of the save, instead
of trying to re-derive it solely from `self.boxes`:

1. **`GameScene:to_save()`**: after the existing loop that force-shelves
   any `entry.solved == true` puzzle still mid-fade, add a new saved field
   built from the remaining (unsolved) `self.active_puzzles` entries:
   ```lua
   local active_puzzles = {}
   for _, entry in ipairs(self.active_puzzles) do
       if not entry.solved then
           active_puzzles[#active_puzzles + 1] = {
               path = entry.path,
               tier = entry.tier,
               cols = entry.cols,
               rows = entry.rows,
               piece_count = entry.piece_count,
           }
       end
   end
   ```
   Include `active_puzzles = active_puzzles` in the returned table. (Image
   isn't saved — like `completed_puzzles` already does, it's reloaded from
   `path` via `love.graphics.newImage`.)

2. **`GameScene:on_enter()` step (e)**: rebuild `self.active_puzzles`
   directly from `self._save_data.active_puzzles` (default to `{}` if the
   field is absent, for saves written before this fix — no crash, just no
   retroactive recovery of their in-flight puzzles, same as today's
   behavior). For each saved entry, build its `pieces` list by scanning
   `self.pieces` for matching `path`, **plus** `self.player.held_piece`
   when its `path` matches — closing the held-piece gap described above.
   (`self.player2` is never restored from save data at all — it's created
   fresh unconditionally at line 170 whenever `GameState.player_count == 2`
   — so there is no player2-held-piece case to handle here; see "What stays
   the same.") Then rebuild `self.boxes`
   from `self._save_data.boxes` as before, but instead of each box
   independently creating its own `active_puzzles` entry, look up the
   already-built `pieces` table for that box's `path` and assign it to
   `box.spawned` (same table reference, not a copy) so that if the box is
   still `"ejecting"`, newly-spawned pieces (`JigsawBox:_eject_next`'s
   `self.spawned[#self.spawned + 1] = piece`) land in the same table the
   completion check iterates — mirroring how `box.spawned` and
   `entry.pieces` are already the same table reference in the fresh-game
   path (`_spawn_box()`, lines 213–222).

This makes "does this puzzle have live completion tracking" depend only on
whether it's in `active_puzzles` — never on whether a box object happens to
still be alive — matching the invariant fresh (non-Continue) games already
rely on.

### Tests

Add integration test(s) in `tests/test_jigsaw.lua` (near the existing
resume-adjacent `active_puzzles` tests around lines 1978–2010):

- A puzzle whose box has fully ejected (no box left in `self.boxes`) before
  `to_save()`/reload must still solve and fire completion (`entry.solved`,
  `GameState.solved_count`, shelving) after being correctly arranged
  post-Continue. This is the primary regression test for the reported bug.
- A puzzle saved with a box still `"ejecting"` continues to solve correctly
  after reload (guards against the fix regressing the already-working
  case).
- A puzzle saved while one of its pieces was held by the player
  (`self._save_data.player.held_piece`) still reaches `piece_count` and
  solves once that piece is dropped correctly after reload.
- An old-format save missing the new `active_puzzles` field loads without
  erroring (defaults to no in-progress-puzzle tracking, not a crash).

## What stays the same

- `JigsawSolver.is_assembled()` — untouched; the bug is entirely in what
  gets fed into it, not the check itself.
- The fresh-game (non-Continue) path — `on_enter()`'s `else` branch and
  `_spawn_box()` — untouched; `entry.pieces`/`box.spawned` are already the
  same table reference there and already work correctly.
- `completed_puzzles` (shelved) save/restore — untouched; this bug only
  affects puzzles still in progress at save time.
- `JigsawBox:to_save()`/`from_save()` — untouched; boxes are still saved
  and restored exactly as before, just no longer relied upon as the sole
  source for reconstructing `active_puzzles`.
- Player 2's position/held piece — `GameScene:to_save()` only ever saved
  `self.player` (P1), never `self.player2`; that pre-existing limitation is
  unrelated to this bug and out of scope here.
- Single save slot, save-on-quit-only cadence — unchanged.

## Open questions

None outstanding. Root cause and fix are both fully determined by reading
`game_scene.lua`'s save/restore code and the original save-load design
doc's (incorrect, now-superseded) assumption that `active_puzzles` needs no
save format of its own.
