## Fix Continue Completion Detection Checklist

- [x] Task A — `game/scenes/game_scene.lua` — In `GameScene:to_save()`
      (lines ~396–456), after the existing loop that force-shelves any
      `entry.solved == true` puzzle still mid-fade, build a new
      `active_puzzles` list from the remaining (unsolved)
      `self.active_puzzles` entries (`path`, `tier`, `cols`, `rows`,
      `piece_count` only — no `image`, reloaded via `love.graphics.newImage`
      on restore, same as `completed_puzzles`) and include it in the
      returned save table. Then, in `GameScene:on_enter()`'s save-restore
      branch, replace step (e) (lines ~93–112, which currently derives
      `active_puzzles` entries only from `self._save_data.boxes`) so that
      `self.active_puzzles` is instead rebuilt directly from
      `self._save_data.active_puzzles` (default to `{}` if absent, for
      pre-fix saves — no crash, just no retroactive recovery). For each
      saved entry, build its `pieces` list by scanning `self.pieces` for
      matching `path`, plus `self.player.held_piece` when its `path`
      matches (this must happen after step (b), which restores
      `self.player.held_piece`, and after step (c)/pieces are loaded).
      Then, in the box-rebuild loop (still iterating
      `self._save_data.boxes`), instead of each box independently creating
      its own `active_puzzles` entry, look up the already-built `pieces`
      table for that box's `path` and assign it to `box.spawned` (same
      table reference, not a copy). These two changes are tightly coupled
      (one produces the save field, the other consumes it) — implement and
      verify both together, not as separate tasks.

- [x] Task B — `tests/test_jigsaw.lua` — **Depends on Task A being
      complete** (needs the new `active_puzzles` save field and rebuilt
      restore logic to exist before it can be tested against). Add
      integration test(s) near the existing resume-adjacent
      `active_puzzles` tests (~lines 1978–2010 and 2317–2379):
      - Puzzle whose box fully ejected (no box left in `self.boxes`)
        before `to_save()`/reload must still solve and fire completion
        (`entry.solved`, `GameState.solved_count`, shelving) once correctly
        arranged post-Continue — the primary regression test.
      - Puzzle saved with a box still `"ejecting"` continues to solve
        correctly after reload (guard against regressing the
        already-working case).
      - Puzzle saved while one of its pieces was held by the player
        (`self._save_data.player.held_piece`) still reaches
        `piece_count` and solves once that piece is dropped correctly
        after reload.
      - Old-format save missing the new `active_puzzles` field loads
        without erroring (defaults to no in-progress-puzzle tracking, not
        a crash).
