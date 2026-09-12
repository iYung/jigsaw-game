# No-Overlap Spawn

## Goal

Two spawn paths currently allow game objects to occupy the same cell:

1. `_spawn_box()` in `game/scenes/game_scene.lua` picks a random cell for a new JigsawBox but never checks existing grounded pieces, so a box can land on top of a piece.
2. `_eject_next()` in `game/jigsaw_box.lua` places ejected pieces by spiraling outward from the box, but only excludes the wall_tile cell via a hardcoded coordinate. The pile, help_tile, and the box's own cell are not excluded, so a piece can land on any of them.

Neither overlap is wanted. This feature fixes both.

## Affected files

- `game/jigsaw_box.lua` — `_eject_next` receives an expanded exclusion set
- `game/scenes/game_scene.lua` — `_spawn_box` gains a piece-occupancy check; the call site for `_eject_next` passes tile positions

## What changes

### `_spawn_box` in `game_scene.lua`

Add a scan over `self.pieces` to the occupancy check, the same way the box-vs-box check works:

```lua
for _, piece in ipairs(self.pieces) do
    if piece.state == "grounded" and piece.sprite.x == cx and piece.sprite.y == cy then
        occupied = true
        break
    end
end
```

Also check the held piece of each player, since a held piece is not in `self.pieces`.

### `_eject_next` in `jigsaw_box.lua`

Replace the hardcoded `is_reserved` check with a dynamic exclusion set passed in from the caller. The set is a list of `{x, y}` pairs representing cells that must never receive a piece:

- The box's own cell (`self.sprite.x, self.sprite.y`)
- Each tile's cell: pile, wall_tile, help_tile (passed in as a list)

The caller (`game_scene.lua`) builds this list and passes it through `box:update()` → `box:_eject_next()`.

Signature change to `JigsawBox:update`:
```lua
function JigsawBox:update(dt, pieces, reserved_cells)
```

`reserved_cells` is a plain array of `{x=…, y=…}` tables. `_eject_next` checks each candidate against this list in addition to grounded pieces.

The call sites in `game_scene.lua` build the list once per `update` call from the fixed tile sprites and the box's own sprite position:

```lua
local reserved = {
    {x = self.pile.sprite.x,      y = self.pile.sprite.y},
    {x = self.wall_tile.sprite.x, y = self.wall_tile.sprite.y},
    {x = self.help_tile.sprite.x, y = self.help_tile.sprite.y},
}
box:update(dt, self.pieces, reserved)
```

The box adds its own cell to this list inside `_eject_next` before the candidate loop.

## What stays the same

- The spiral search algorithm in `_eject_next` is unchanged.
- Box spawning logic, fly animation, and ejection timing are unchanged.
- No new types or modules. No save-format changes.
- The "piece can't land on another grounded piece" check in `_eject_next` stays exactly as is.

## Open questions

None — resolved before writing this doc:
- `_eject_next` excludes the box's own cell. ✓
- The hardcoded wall_tile coordinate is replaced with a dynamic set. ✓
