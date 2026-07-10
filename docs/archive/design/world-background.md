# World Background

## Goal
Add a background that fills the screen no matter where the camera ends up while the player roams the floor — today `love.graphics.clear(0, 0, 0)` (`main.lua:51`) leaves flat black visible in the ~608px (left/right) and ~328px (top/bottom) of overreach beyond the 1280x640 floor, since the camera follows the player with no bounds clamp.

## Affected files
- `assets/backgrounds/world_bg.png` — **new**: placeholder background image, 2496 x 1296 px
- `game/scenes/game_scene.lua` — `on_enter` (~line 21-85): create a background entity and add it to `self.drawer` at a priority below the floor's `0` so it draws first, underneath everything else
- `game/constants.lua` — optionally add background dimensions/offset as named constants (kept in one place instead of magic numbers in `game_scene.lua`)

## What changes

### Sizing derivation (verified against current code, unchanged from earlier analysis)
- Logical canvas: 1280x720 (`main.lua:28`), letterboxed to the real window — background only needs to cover the logical canvas.
- World/floor bounds: `WORLD_W = 1280`, `WORLD_H = 640` (`game_scene.lua:22-23`, `SLOT = 64` from `game/constants.lua:2`).
- Player position is clamped to `[0, WORLD_W-SLOT] x [0, WORLD_H-SLOT]` (`game_scene.lua:233-234`).
- Camera follows the player's centre with an exponential lerp (`Camera:follow`, `lua/core/camera.lua:26-31`) and is **never clamped** — confirmed no other code touches `camera.x`/`camera.y`. So camera.x ranges over the same interval as the player's centre: `[32, 1248]`, camera.y over `[32, 608]`.
- `Camera:attach()` (`lua/core/camera.lua:14-19`) translates by half the viewport (640, 360) then by `-camera.x/-camera.y`, at a fixed `zoom = 1.0` (confirmed: nothing else in the codebase reads or writes `.zoom`). Viewport half-extents are therefore a constant 640 x 360.
- Worst-case visible world-space rect: x in `[-608, 1888]`, y in `[-328, 968]` — i.e. 608px of overreach past the floor's left/right edges, 328px past its top/bottom edges.
- Required background size: **2496 x 1296 px** (`1280 + 2*608`, `640 + 2*328`), positioned in world space with its top-left corner at **(-608, -328)** so the floor rect `(0,0)-(1280,640)` sits centered inside it.

### Background entity (`game_scene.lua`)
A plain drawer entry, following the same pattern as `self.floor` (`game_scene.lua:33-50`):
```lua
self.background = {
    image = love.graphics.newImage("assets/backgrounds/world_bg.png"),
    draw = function(self)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.image, -608, -328)
    end,
}
self.drawer:add(self.background, -1)
```
- Added with priority `-1` (below the floor's `0`) so `Drawer:draw()` (`lua/core/drawer.lua:24-28`, ascending priority sort) draws it first.
- Added inside `Scene:draw()`'s `camera:attach()/detach()` block (`lua/core/scene.lua:16-20`) — same as the floor — so it pans with the world instead of sitting fixed in screen space.
- Loaded once in `on_enter`, same lifecycle as the floor; no per-frame cost beyond one `draw()` call.

### Placeholder art
No art pipeline or established visual theme exists yet — every current entity (floor, door, spawn button, player-adjacent UI) is a flat-colored rectangle; the only real bitmap art in the repo is `assets/player.png` and the puzzle thumbnails. To keep this change unblocked on art production, the initial `world_bg.png` will be a simple flat/soft-gradient placeholder (e.g. a muted solid color a shade darker than the floor tiles), generated as part of implementation. Swapping in real art later is a drop-in file replacement — no code changes needed.

## What stays the same
- Floor rendering, grid, player movement/clamping, camera follow behavior and lerp factor
- Drawer/Scene/Camera architecture and draw ordering conventions
- Logical canvas size and letterbox scaling in `main.lua`
- No zoom support is introduced; if zoom is added later, the background size/position will need revisiting (out of scope here)

## Open questions
None — resolved by judgment before writing this doc (Auto Mode: proceeding rather than blocking on confirmation; flagging assumptions here for review):
- **Static vs. tiled art**: single static 2496x1296 image, not a repeated/tiled texture — simplest to implement and matches the codebase's current preference for simple, direct rendering over generalized systems.
- **Scrolls with camera vs. fixed screen-space**: scrolls with the world (drawn between `camera:attach()`/`detach()`, same as the floor) — this is what the sizing math assumes, and a fixed screen-space image would defeat the purpose (edges of the floor would visibly slide over a static backdrop).
- **Art style**: no existing theme to match (everything today is flat-colored placeholder rectangles) — background will likewise be a simple placeholder color/gradient, easily replaced later.
- **Asset source**: no art pipeline exists; a placeholder PNG will be generated as part of this feature rather than waiting on external art, at `assets/backgrounds/world_bg.png`.
