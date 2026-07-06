# Jigsaw Basic Pickup

## Goal
Establish the first playable loop of the jigsaw game: a world larger than the camera, a player who walks under floating jigsaw pieces, picks them up, rotates them, and drops them. Introduce a shared base unit (`U = 32px`) and a world grid of `2U = 64px` slots that pieces snap to when resting on the ground.

## Affected files
- `game/constants.lua` — **new**: exports `U = 32`
- `lua/core/sprite.lua` — add `rotation` field (radians) and draw around sprite center
- `game/jigsaw_piece.lua` — **new**: JigsawPiece entity with position, color, rotation state, and grounded/held state
- `game/player.lua` — add pickup/drop input (`E`), hold a piece reference
- `game/scenes/game_scene.lua` — replace coins demo with 3 jigsaw pieces spread across a wide world; clamp player to world bounds

## What changes

### Base unit and world grid
`game/constants.lua` exports `U = 32` and `SLOT = 2 * U` (= 64px). The world is laid out on a `SLOT`-sized grid — piece spawn positions and drop positions always align to this grid. The player moves freely with no grid constraint.

### Sprite rotation
`Sprite` gains a `rotation` field (radians, default `0`). When drawing, the sprite translates to its center, rotates, then draws the rect/image. `x, y` remains the top-left corner; rotation is visual only, around the sprite's own center.

### JigsawPiece
A new entity `game/jigsaw_piece.lua` wraps its own Sprite (`2U × 2U = 64×64`, i.e. one SLOT square). Each piece has:
- A distinct solid color (no image file; Sprite draws a filled rect when `image = nil`)
- `rotation_step`: integer 0–3, where each step is 90°. Rendered as `rotation_step * (math.pi / 2)` radians.
- State: `"grounded"` (resting on the world grid) or `"held"` (follows player freely)

JigsawPiece exposes:
- `piece:update(player)` — if held, positions piece above player's head
- `piece:draw()` — delegates to its Sprite
- `piece:rotate()` — increments `rotation_step` by 1 (mod 4)
- `piece:pick_up()` — transitions to `"held"`
- `piece:drop(wx, wy)` — snaps `(wx, wy)` to nearest SLOT boundary, transitions to `"grounded"`

### Grid snapping on drop
When a piece is dropped, its position is snapped to the nearest 2U grid slot:
```
snapped_x = math.floor(wx / SLOT + 0.5) * SLOT
snapped_y = ground_y - piece_height   -- always sits on the ground
```
While held, the piece follows the player with no snapping.

### Pickup interaction
Player gains an `E` key binding for `interact`. On `interact` press:
- If not holding a piece: pick up the nearest grounded piece within `1.5 * U` of the player's center.
- If holding a piece: drop it — piece snaps to the nearest grid slot on the ground beneath the player.

While holding a piece, pressing `R` calls `held_piece:rotate()`.

Held piece position each frame: centered above the player's head — `x = player_center.x - U`, `y = player.sprite.y - 2*U`.

### World and camera
World width: `2 * 1280 = 2560px` (2 screens). Ground sprite spans the full world width.

Three pieces spawn at grid-aligned x positions: `384` (= 6 × SLOT), `1280` (= 20 × SLOT), `2112` (= 33 × SLOT). All rest on the ground: `y = ground_y - piece_height = 220 - 64 = 156`.

Player x is clamped to `[0, world_width - player_width]` each update. Camera already follows player center.

## What stays the same
- Camera lerp-follow logic
- WASD movement and speed
- Drawer / Scene / SceneManager architecture
- Sprite draw path for non-rotated sprites (rotation=0 is a no-op)
- Ground as a plain Sprite with a green color

## Open questions
None — all resolved before writing this doc.
- Base unit: **32px**
- World grid slot: **2U = 64px**
- Rotation style: **90° snapped, R key**
- Piece appearance: **solid-color filled rectangles, no image files**
- Pickup key: **E**
- Pieces while grounded: **snap to 2U grid**
- Pieces while held: **free movement with player**
