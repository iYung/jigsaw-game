## Jigsaw Basic Pickup Checklist

- [x] Task A — `game/constants.lua` — Create new file exporting `U = 32` and `SLOT = 2 * U` (64)

- [x] Task B — `lua/core/sprite.lua` — Add `rotation` field (default `0`, radians) to `Sprite.new`; in `Sprite:draw()` translate to the sprite's center, apply `love.graphics.rotate(self.rotation)`, then draw offset back by half-width/half-height so rotation is around the center

- [x] Task C — `game/jigsaw_piece.lua` — Create new JigsawPiece entity: wraps a `2U×2U` Sprite with a solid color; fields `rotation_step` (0–3), `state` (`"grounded"` or `"held"`); methods `rotate()`, `pick_up()`, `drop(wx, wy)` (snaps x to nearest SLOT, y to `ground_y - piece_height`), `update(player)` (when held, position piece centered above player head), `draw()`

- [x] Task D — `game/player.lua` — Add `interact` and `rotate_piece` key bindings (`E` and `R`); add `held_piece` field (nil when not holding); on `interact` press: if `held_piece` is nil pick up nearest grounded piece within `1.5*U` of player center, else drop it; on `rotate_piece` press: if holding a piece call `held_piece:rotate()`; expose `centre()` (already exists) for pickup range checks

- [x] Task E — `game/scenes/game_scene.lua` — Replace the coins demo with a `WORLD_W = 2560` ground spanning the full world; spawn 3 JigsawPieces at grid-aligned x positions `384`, `1280`, `2112` resting on the ground (`y = 156`); pass pieces to player each update for pickup logic; clamp player x to `[0, WORLD_W - player_width]`; add all pieces to the drawer; require `game/constants` and `game/jigsaw_piece`
