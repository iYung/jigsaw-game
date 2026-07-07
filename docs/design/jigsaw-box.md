# Jigsaw Box

## Goal
Replace the three pre-spawned pieces in the world with a single interactable **box**. When the player presses `E` near the box, it ejects the three pieces one by one into the nearest empty ground slots around it (timed, ~0.2 s between each). Once all pieces are ejected the box disappears.

## Affected files
- `game/jigsaw_box.lua` — **new**: Box entity with a spawn queue, timer, and occupied-slot awareness
- `game/scenes/game_scene.lua` — remove pre-spawned pieces; add one Box near player start; wire box into update/draw; move pieces list management into the box
- `game/player.lua` — extend interact logic to also check for a nearby box (no piece held, no piece nearby → try box)

## What changes

### JigsawBox entity (`game/jigsaw_box.lua`)
A new entity wrapping a `Sprite` (`SLOT × SLOT`, gold/orange color so it reads differently from pieces).

State machine:
- `"waiting"` — sitting in the world, ready to be triggered
- `"ejecting"` — popping pieces out one by one
- `"done"` — all pieces ejected; box should be removed from the scene

Fields:
- `self.sprite` — `Sprite` at its world position
- `self.pieces_to_spawn` — ordered list of piece specs `{color}` (3 entries)
- `self.spawn_timer` — countdown to next piece eject (reset to `0.3 s` after each piece)
- `self.spawned_pieces` — pieces already spawned (so their slots are treated as occupied)
- `self.state` — `"waiting" | "ejecting" | "done"`

Key methods:
- `box:interact(pieces)` — transitions `"waiting"` → `"ejecting"`, sets timer to 0 (fires immediately)
- `box:update(dt, pieces)` — when `"ejecting"`, ticks the timer; on expiry, calls `box:_eject_next(pieces)`
- `box:_eject_next(pieces)` — finds the nearest empty ground slot to the box center (expanding outward), creates a `JigsawPiece` there, appends it to `pieces`; if queue is empty after this, transitions to `"done"`
- `box:centre()` — returns box center `{x, y}` (used for interaction distance)

#### Slot search order
Starting from the box's own grid slot, search candidate slots by Manhattan distance, expanding outward. A slot is **empty** if no other piece (including already-spawned pieces) occupies it. All slots are valid — this is a top-down 2D game with no floor axis. Candidates are sorted ascending by Manhattan distance; ties broken left-to-right. The first empty candidate wins.

Concretely, search slots at Manhattan distance 1 first (left, right, up, down), then distance 2, etc., until 3 empty slots are found total (one per piece ejected).

### Scene changes (`game/scenes/game_scene.lua`)
- Remove the 3 hardcoded `JigsawPiece` entries from `on_enter`
- Create one `JigsawBox` near player start
- `self.pieces` starts as `{}` (empty); pieces are added dynamically as the box ejects them
- Each frame, after the box update, newly created pieces are added to the drawer
- When `box.state == "done"`, remove the box sprite from the drawer (or simply stop drawing it)
- Pass `self.box` to `player:update(dt, self.pieces, self.box)` so the player can interact with it

### Player changes (`game/player.lua`)
Extend the `interact` branch (when not holding a piece):
1. First check for a nearby grounded piece (unchanged).
2. If no piece found **and** a box is provided **and** `box.state == "waiting"` **and** the player is within `1.5 * U` of the box center → call `box:interact(pieces)`.

Signature change: `player:update(dt, pieces, box)` — `box` may be `nil` once it's done.

## What stays the same
- Pickup, drop, and rotate logic for pieces
- World width, ground position, camera follow
- Grid snapping on drop
- Drawer / Scene / SceneManager architecture
- JigsawPiece itself is unchanged

## Open questions
None — all resolved before writing this doc.
- Spawn style: **timed, 0.3 s between pieces**
- First piece fires: **immediately on interact (timer starts at 0)**
- Spawn placement: **adjacent slots, greedy, expanding Manhattan distance — all slots valid (top-down game, no floor axis)**
- Box placement: **near player start**
- Box color: **gold/orange `{1, 0.75, 0.2, 1}`**
- Box disappears: **when `state == "done"` — removed from drawer in game_scene**
- Piece colors: **same 3 as before `{red, blue, green}`**
