## Held Item Draw Priority Checklist

Design: `docs/design/held-item-draw-priority.md`

- [x] Task A — `lua/core/drawer.lua` — Add `Drawer:remove(sprite)`: iterate `self.layers`, and when
      an entry's `.sprite == sprite`, `table.remove(self.layers, i)` and return. No-op (no error) if
      the sprite isn't found. Leave `add`/`draw`/`clear` untouched. No dependencies on other tasks.

- [x] Task B — `game/constants.lua` — Add `PRIORITY_PIECE = 5` to the returned table (alongside `U`
      and `SLOT`), documenting it as the draw priority for grounded pieces and the box. No
      dependencies on other tasks.

- [x] Task C — `game/player.lua` — Depends on Task A and Task B.
      - Change `Player:update(dt, pieces, box)` to `Player:update(dt, pieces, box, drawer)`.
      - In the pick-up branch (where `nearest:pick_up()` / `self.held_piece = nearest` currently is):
        after picking `nearest`, remove it from the `pieces` array (find its index via `ipairs` and
        `table.remove`), and if `drawer` was passed, call `drawer:remove(nearest)`. Then set
        `self.held_piece = nearest` as before.
      - In the drop branch (where `self.held_piece:drop(target_x, target_y)` currently is): after the
        drop call, re-insert the piece into `pieces` (`pieces[#pieces + 1] = self.held_piece`) and,
        if `drawer` was passed, call `drawer:add(self.held_piece, C.PRIORITY_PIECE)` (`C` is already
        required at the top of this file). Then clear `self.held_piece = nil` as before.
      - Update `Player:draw()` to draw `self.sprite`, then, if `self.held_piece ~= nil`, draw
        `self.held_piece` directly right after.
      - Guard all `drawer` usage with `if drawer then ... end` so existing calls to `Player:update`
        without a 4th argument (e.g. in tests) keep working unchanged.

- [x] Task D — `game/scenes/game_scene.lua` — Depends on Task B and Task C.
      - Replace the literal `5` priorities for the box (`self.drawer:add(self.box, 5)`) and for newly
        discovered pieces (`self.drawer:add(piece, 5)`) with `C.PRIORITY_PIECE`.
      - Change the call `self.player:update(dt, self.pieces, self.box)` to
        `self.player:update(dt, self.pieces, self.box, self.drawer)`.

- [x] Task E — `tests/test_jigsaw.lua` — Depends on Tasks A–D. Add test coverage (follow the existing
      `do ... end` block + `assert` + `print("PASS: ...")` style in this file):
      - `Drawer:remove` removes the matching entry and leaves others intact; no-ops when the sprite
        isn't present.
      - Picking up a piece (via `Player:update` with a real `Drawer` and a `pieces` array containing
        the piece) removes it from both the `pieces` array and the `Drawer`'s internal layers.
      - Dropping a held piece re-inserts it into `pieces` and re-adds it to the `Drawer` with
        `C.PRIORITY_PIECE`.
      - `Player:draw()` draws the player's own sprite and, when a piece is held, draws that piece's
        sprite too (e.g. assert no error / spy that both sprites' `:draw()` are invoked).

### Task dependency order
Tasks A and B have no dependencies and can run in parallel. Task C depends on A and B. Task D
depends on B and C. Task E depends on A, B, C, and D. Run in order: {A, B} in parallel → C → D → E.
