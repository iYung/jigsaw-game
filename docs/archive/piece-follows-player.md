## Piece Follows Player Checklist

> **Not parallelizable.** Task A changes `JigsawPiece:drop()`'s signature and Task A's
> partner change in `player.lua` is the only call site — they must land together in one
> commit/session. Splitting them across independent agents would leave the repo in a
> broken intermediate state (either a call site passing no args to a function that now
> requires them, or a signature change with no caller update). Task A below is therefore
> written as a single combined task for one agent. Task B (tests) depends on Task A being
> complete first and must run after it, not in parallel.

- [x] Task A — `game/jigsaw_piece.lua` + `game/player.lua` — Fix the drop-target computation to derive from the player's live position instead of the held piece's floating carry position. Do both edits together, in this order:
  1. In `game/jigsaw_piece.lua`, change `JigsawPiece:drop()` (lines 28–32) to accept explicit `x, y` parameters and snap those instead of reading `self.sprite.x`/`self.sprite.y`:
     ```lua
     function JigsawPiece:drop(x, y)
         self.sprite.x = math.floor(x / C.SLOT + 0.5) * C.SLOT
         self.sprite.y = math.floor(y / C.SLOT + 0.5) * C.SLOT
         self.state = "grounded"
     end
     ```
     Leave `JigsawPiece:update()` (lines 34–39, the carried hover visual) completely unchanged — the design doc explicitly keeps the "float one grid row above the player's head while held" behavior as-is.
  2. In `game/player.lua`'s interact/drop branch (`Player:update`, lines 34–51), replace the snap-source computation so it reads from the player's current position rather than `self.held_piece.sprite.x/y`, mirroring the existing x-axis carry formula (`player:centre().x - C.U`) onto both axes:
     ```lua
     if self.input:pressed("interact") then
         if self.held_piece ~= nil then
             local centre = self:centre()
             local target_x = centre.x - C.U
             local target_y = centre.y - C.U
             local snap_x = math.floor(target_x / C.SLOT + 0.5) * C.SLOT
             local snap_y = math.floor(target_y / C.SLOT + 0.5) * C.SLOT
             local occupied = false
             if pieces then
                 for _, p in ipairs(pieces) do
                     if p ~= self.held_piece and p.state == "grounded"
                        and p.sprite.x == snap_x and p.sprite.y == snap_y then
                         occupied = true
                         break
                     end
                 end
             end
             if not occupied then
                 self.held_piece:drop(target_x, target_y)
                 self.held_piece = nil
             end
         else
             ...
     ```
     Note `target_x`/`target_y` (pre-snap) are passed to `drop()`, which does its own snapping internally — this keeps `drop()` the single source of truth for the snap math, same as today. The occupied check uses `snap_x`/`snap_y` (post-snap) exactly as before, just computed from the player instead of the piece.
  3. Confirm no other call sites of `JigsawPiece:drop()` exist (e.g. `game/jigsaw_box.lua`) that would break with the new required-args signature; update any found to pass explicit coordinates consistent with their own context.

- [x] Task B — `tests/test_jigsaw.lua` — Update/add tests to cover the fixed behavior. Depends on Task A being complete (run after, not in parallel):
  1. Update the two existing `drop()` tests (lines 68–93, "drop() grid snap" and "drop at exact slot boundary") to call `p:drop(x, y)` with explicit arguments instead of setting `p.sprite.x`/`p.sprite.y` before calling `p:drop()` — e.g. `p:drop(555, 200)` should still assert `p.sprite.x == 576` and `p.sprite.y == 192`; `p:drop(384, 128)` should still assert it stays at `384, 128`.
  2. Add a new test requiring `game/player.lua` and `lua/headless/input.lua` (the existing `HeadlessInput` scriptable input stub used for headless tests — see `lua/headless/input.lua` and its use via `lua/headless/runner.lua`) that: creates a `Player` via `Player.new(x, y)`, then replaces `player.input` with a fresh `HeadlessInput.new()` instance so presses can be scripted directly (no real keyboard needed), gives the player a `held_piece` (a grounded `JigsawPiece` that's been `pick_up()`'d and assigned to `player.held_piece`), positions the player's `sprite.x/y` at a specific location, calls `player.input:press("interact")` then `player:update(dt, pieces)` (with `dt` small enough that movement keys — none held — don't matter), and asserts the piece's `sprite.x`/`sprite.y` after the call land on the grid slot matching the *player's* position (via `player:centre().x - C.U` / `player:centre().y - C.U`, snapped) — not on the piece's pre-drop floating position. Include a case where the player's sprite has moved since the piece was picked up, to prove the drop follows the player's current position rather than a stale one.
  3. Update the "overlap check (via player logic)" test (lines 133–159) — it currently duplicates the occupied-slot logic inline using `pieceB.sprite.x/y` as the snap source, which no longer matches how `player.lua` computes it post-fix. Rewrite it to go through the real `Player`/`player.lua` occupied-check code path (same `HeadlessInput`-based harness as B.2): place a grounded `pieceA` at a known slot, position the player (via `player.sprite.x/y`) so that slot is exactly where the player would drop `pieceB`, script an "interact" press and call `player:update(dt, pieces)` with `pieces = { pieceA, pieceB }`, and assert the drop is blocked (`pieceB.state` stays `"held"`, `player.held_piece == pieceB`, `pieceA`'s slot is undisturbed) — occupied-slot-blocks-drop must still work with the new player-derived coordinate source.
  4. Run `love . --headless` (or however this repo's test runner is invoked — check `README.md`/existing scripts) and confirm `ALL TESTS PASSED` still prints, with no regressions in the unrelated `jigsaw_box` tests below.
