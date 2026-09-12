## No-Overlap Spawn Checklist

- [x] Task A — `game/jigsaw_box.lua` — Add `reserved_cells` parameter to `JigsawBox:update` and pass it through to `_eject_next`. Inside `_eject_next`, prepend the box's own cell (`{x=self.sprite.x, y=self.sprite.y}`) to the received list, then replace the hardcoded `is_reserved = (tx == self.world_w - C.SLOT and ty == 0)` check with a loop over the combined list. Keep all other candidate logic (out-of-bounds, grounded-piece check) unchanged.

- [x] Task B — `game/scenes/game_scene.lua` — In `_spawn_box`, add occupancy checks for grounded pieces in `self.pieces` and held pieces on each player (`self.player.held_piece`, `self.player2` and `self.player2.held_piece` when present), mirroring the existing box-vs-box check. In `GameScene:update`, build a `reserved_cells` table from `self.pile`, `self.wall_tile`, and `self.help_tile` sprite positions and pass it as the third argument to every `box:update(dt, self.pieces, reserved_cells)` call.
