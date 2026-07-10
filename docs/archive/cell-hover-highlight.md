# Cell Hover Highlight Checklist

Design doc: `docs/design/cell-hover-highlight.md`

- [x] Task A — `game/player.lua` — In `Player:draw()` (currently lines 144-153),
      add a branch for the `self.held_piece == nil` case: draw a
      semi-transparent white fill rectangle over the grid cell the player
      currently occupies. Use `self:drop_target()` (unchanged, lines 135-142)
      to get `snap_x`/`snap_y` — do not add new snapping math, the existing
      function already answers "what grid cell is the player's centre over"
      regardless of held-piece state. Drawing sequence:
      `love.graphics.setColor(1, 1, 1, 0.25)`, then
      `love.graphics.rectangle("fill", snap_x, snap_y, C.SLOT, C.SLOT)`, then
      `love.graphics.setColor(1, 1, 1, 1)` to restore state (`C` is already
      required at the top of the file). Draw this in the same "before
      `self.sprite:draw()`" slot the ghost preview currently occupies, so the
      overall structure becomes: if held, draw ghost; else draw cell
      highlight; then draw player sprite; then draw held piece if any.
      No changes to `drop_target()` itself, no bounds/occupancy checks, no
      mouse/input changes.

- [x] Task B — `tests/test_jigsaw.lua` — Add tests near the existing
      `Player:draw()` draw-order test (around lines 1099-1134) and
      `drop_target()` tests (lines 217-246), using the same headless
      love-stub pattern that captures `love.graphics.rectangle`/`setColor`
      calls into a list. Cover:
      1. When `player.held_piece == nil`, `Player:draw()` issues a
         `setColor(1, 1, 1, 0.25)` call followed by a
         `rectangle("fill", snap_x, snap_y, C.SLOT, C.SLOT)` call (using the
         same snap values `drop_target()` would return for the player's
         current position), and color is restored to `(1, 1, 1, 1)`
         afterward.
      2. When `player.held_piece ~= nil`, no such highlight rectangle is
         drawn (only the existing ghost-preview/held-piece draw calls
         appear) — i.e. the two states are mutually exclusive.
      This task depends on Task A being complete (it asserts against the
      real implementation), so it must run after Task A, not in parallel.
