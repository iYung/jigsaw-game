# Held Item Draw Priority

## Goal
When the player is carrying a jigsaw piece, that piece must always render above every other
sprite in the scene (player, box, ground, other grounded pieces) — it should never be visually
occluded. Today, draw order is decided by a static `priority` number assigned once when a sprite
is registered with the `Drawer` (`lua/core/drawer.lua:10-13`). Grounded pieces and the held piece
share the same priority (`5`), which is lower than the player's (`10`), so a held piece can currently
render behind the player.

The deeper issue: a picked-up piece today stays in `GameScene.pieces` (the world/game-state list)
for its entire lifetime, with only `piece.state` ("grounded" vs "held") distinguishing it. The piece
is simultaneously "in the world" and "carried" — that ambiguity is what makes draw order (and
occupancy/pick-up checks) awkward.

## Reference pattern (sibling project)
The sibling `wip` project keeps a carried item purely as player state: `Player.held_item`
(`/root/wip/lua/game/player.lua:24`) is the *only* place a carried item lives — it's never a member
of any scene-level items list while held. `Player:draw()` draws its own sprite, then unconditionally
draws `self.held_item` right after (`/root/wip/lua/game/player.lua:112-123`), so it always paints on
top, purely from call order. This design adopts the same ownership model: a piece belongs to either
game state (`GameScene.pieces` + the scene's `Drawer`) or player state (`Player.held_piece`), never
both.

## Affected files
- `lua/core/drawer.lua` — add `Drawer:remove(sprite)`, which removes the matching entry from
  `self.layers`. (`add`/`draw`/`clear` unchanged.)
- `game/constants.lua` — add `C.PRIORITY_PIECE = 5`, replacing the literal `5` used for grounded
  pieces in `game_scene.lua`, so the same named value is reused when a dropped piece re-enters the
  `Drawer`.
- `game/player.lua`:
  - `Player:update(dt, pieces, box, drawer)` gains a `drawer` parameter.
  - On pick-up: remove the piece from the shared `pieces` array (game state) and from `drawer`
    (`drawer:remove(piece)`), then assign it to `self.held_piece` (player state). The piece now
    exists in exactly one place.
  - On drop: re-insert the piece into `pieces` and re-add it to `drawer` at `C.PRIORITY_PIECE`,
    then clear `self.held_piece`.
  - `Player:draw()` draws `self.sprite`, then, if `self.held_piece` is set, draws it directly —
    matching the wip pattern. No priority juggling needed for the held case since it's no longer a
    `Drawer` entry at all while held.
- `game/scenes/game_scene.lua` — pass `self.drawer` into `self.player:update(...)`; use
  `C.PRIORITY_PIECE` instead of the literal `5` when first registering newly-spawned grounded pieces.
- `game/jigsaw_piece.lua` — no changes. `JigsawPiece:draw()` keeps drawing its sprite unconditionally;
  it no longer needs to know or care whether it's held, since that's now determined by which
  container (world list vs player field) holds it.
- `tests/test_jigsaw.lua` — add coverage:
  - Picking up a piece removes it from the scene's `pieces` array and from the `Drawer`'s layers.
  - Dropping a piece re-inserts it into `pieces` and re-adds it to the `Drawer` at `C.PRIORITY_PIECE`.
  - `Player:draw()` draws the held piece's sprite after the player's own sprite.
  - `Drawer:remove` removes the right entry and no-ops if the sprite isn't present.

## What changes
- A carried piece is removed from `GameScene.pieces` and the scene's `Drawer` at pick-up time, and
  restored to both at drop time — ownership genuinely transfers between game state and player state
  rather than being tracked by a `state` flag on an object that stays in both places at once.
- `Player:draw()` takes over drawing the held piece directly, guaranteeing it paints after (on top
  of) the player.
- The existing `p ~= self.held_piece` guard in the occupancy-check loop (`game/player.lua`) and the
  `p.state == "grounded"` filters become redundant once held pieces can no longer appear in `pieces`
  at all — safe to simplify, though not required for correctness.

## What stays the same
- `piece.state` ("grounded"/"held") is unchanged and still drives `JigsawPiece:update`'s
  follow-the-player positioning and rotation.
- `Drawer:add()` / `Drawer:draw()` behavior for the player, box, and ground is unchanged.
- The held piece's on-screen *position* (above the player's head) is unchanged.

## Open questions
None — resolved before writing this doc. Rejected: (1) a dynamic per-sprite priority accessor,
(2) an always-on-top priority constant with the piece still living in `GameScene.pieces` while held,
(3) a `JigsawPiece:draw()` no-op guard based on state. Chosen: the piece is fully removed from game
state (`pieces` array + `Drawer`) at pick-up and fully restored at drop, with `Player:draw()`
explicitly drawing the held piece — mirroring the wip project's `Player.held_item` ownership model.
