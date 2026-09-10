## Goal

Fix the help-button overlay so that green/red shading never renders on top of a tile the player is currently holding.

## Affected files

- `game/scenes/game_scene.lua`

## What changes

### Root cause

`GameScene:_draw_help_overlay()` is called **after** `drawer:draw()` in `GameScene:draw()`. The drawer renders in ascending priority order:

| Priority | Content |
|----------|---------|
| -1 | background |
| 0 | floor |
| 4 | completed-puzzle shelf entries |
| 5 | pieces, boxes, wall tile, help tile, pile |
| 10 | player sprite + held piece |

Because the overlay is painted after the entire drawer finishes, it lands on top of the player and the held piece. When the held piece sits over a green-shaded grounded piece, the green rectangle covers the held piece.

### Fix

Register a pseudo-drawable (a plain Lua table with a `draw` method) in the drawer at **priority 9** — above grounded pieces but below the player. This drawable calls `_draw_help_overlay()` when `help_mode` is true. The explicit `_draw_help_overlay()` calls in `GameScene:draw()` (and the surrounding `camera:attach/detach` block added for the single-player path) are then removed.

Result:
- Grounded-piece overlays are drawn at priority 9 → player and held piece (priority 10) render on top.
- In the two-player path, `drawer:draw()` is called once per camera already, so the overlay drawable is included in each camera's pass automatically — no extra code needed.
- `_draw_help_overlay()` itself is unchanged.

### Priority for the overlay drawable

Priority 9 is chosen because:
- It must be > 5 so the overlay is above grounded pieces (otherwise it would be drawn under them).
- It must be < 10 so the overlay is below the player/held piece.

## What stays the same

- `_draw_help_overlay()` logic — which pieces get highlighted and how the color is chosen — is untouched.
- `help_mode` toggling via the help tile.
- All two-player split-screen drawing paths.
- The held piece is still included in `all_pieces` inside `_draw_help_overlay()`, so it receives an overlay too; because that overlay is now drawn at priority 9 it will be covered by the held piece's own sprite at priority 10, giving correct z-ordering.

## Open questions

None — the fix is localized to three lines removed and ~six lines added in `game_scene.lua`.
