# Piece Follows Player

## Goal
Make pick-up and put-down feel anchored to the player. Today the piece *does* visually chase the player while carried, but it floats a full grid row above them, and the drop location is computed from that stale, offset carry position instead of the player's actual position — so a dropped piece lands where it was floating, not where the player is standing. Fix the drop-target computation so "put down" clearly happens at the player, not at the piece's last floating spot.

## Affected files
- `game/player.lua` — the interact/drop branch (`Player:update`, lines 34–51)
- `game/jigsaw_piece.lua` — `JigsawPiece:drop()` (lines 28–32) and `JigsawPiece:update()` (lines 34–39)

## What changes

### Root cause (confirmed by reading code + running `love . --headless`, all tests currently pass against this behavior)
- `JigsawPiece:update(player)` (jigsaw_piece.lua:34-39) positions a held piece at `x = player:centre().x - C.U`, `y = player.sprite.y - 2*C.U`. `2*C.U == C.SLOT` (64px) — the piece hovers a full grid row above the player's sprite top, i.e. noticeably above the row the player is actually standing on.
  - Concretely at the player's spawn position (`sprite.y = 208`), the held piece sits at `y = 144`, which snaps to grid row `y = 128`. The row the player's feet/ground contact would naturally align to is `y = 192` (one row lower). That's the visible "disconnect."
- `Player:update`'s drop branch (player.lua:36-37) computes the target slot from `self.held_piece.sprite.x/y` — the piece's own carried position — not from the player's current position.
- Ordering makes this worse by up to one frame: movement is applied (player.lua:29-32), then the drop branch runs (34-51) using the piece's position as of the *previous* frame's `held_piece:update` call (which runs later, at line 90-92, and is skipped this frame once the piece is dropped). So the snap target reflects the player's pre-movement position from the prior tick, layered on top of the above-grid-row offset.
- Net effect: the piece is put down in whatever slot its floating "above head" position happens to snap to — which reads as "put down occurs where the piece is," exactly as reported, rather than at the player.

### Proposed fix
1. In `Player:update`'s drop branch (player.lua:34-51), compute the target x/y from the **player's current position at the moment of interact**, not from `held_piece.sprite.x/y`. Pass that target explicitly into drop, e.g. `held_piece:drop(target_x, target_y)`.
2. Change `JigsawPiece:drop()` (jigsaw_piece.lua:28-32) to accept explicit `(x, y)` to snap, instead of reading `self.sprite.x/y`. (This reverts to a shape close to the pre-036cd8b signature `drop(wx)`, now with both axes.)
3. The "occupied slot" check (player.lua:38-46) must use the same player-derived target coordinates so the occupied check and the actual drop agree.
4. Keep the piece's carried/hover visual (jigsaw_piece.lua:34-39, "float above head") as-is — only the **drop-target calculation** changes to read from the player, not the piece.

## What stays the same
- Pick-up proximity search and nearest-piece logic (player.lua:52-72) — pickup already relocates the piece to the player in the same frame via `held_piece:update`, so no change needed there.
- The visual offset while carried (piece hovers above the player's head) — unchanged, so the piece stays visible and isn't hidden behind the player sprite.
- Rotation logic, grid-snap math (`floor(v/SLOT + 0.5) * SLOT`), one-piece-at-a-time hold constraint.
- `game/jigsaw_box.lua` eject/slot-search logic — unaffected; this fix is scoped to the generic pick-up/drop path in `player.lua` + `jigsaw_piece.lua`, which applies to any grounded piece regardless of whether it came from the box.
- Blocking a drop entirely when the target slot is occupied (piece remains held) — unchanged.

## Open questions — resolved
1. **Drop anchor: use the player's current position directly.** Mirror the existing x-axis carry formula for both axes: `target_x = player:centre().x - C.U`, `target_y = player:centre().y - C.U`, then grid-snap each with `floor(v / C.SLOT + 0.5) * C.SLOT`. This replaces reading `held_piece.sprite.x/y` (the stale, floating carry position) with a value derived straight from the player's live position at the moment of interact. No special feet/ground-contact anchor — just the player's centre point, consistent with how x is already handled.
2. **Hover visual while carried stays unchanged.** `JigsawPiece:update` (jigsaw_piece.lua:34-39) keeps floating the piece one grid row above the player's head. Only the drop-target computation changes.
3. **Occupied-slot behavior unchanged.** A drop onto an occupied slot is still blocked (piece remains held); no fallback slot-search is added.
