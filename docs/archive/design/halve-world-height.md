## Goal
The player-facing complaint is "the world is too tall." Today the playable world is a perfect
square, `20 x 20` cells (1280 x 1280px), set in `GameScene:on_enter()`:

```lua
-- game/scenes/game_scene.lua:20-21
local WORLD_W = 20 * C.SLOT  -- 1280px
local WORLD_H = WORLD_W
```

(`C.SLOT = 64`, `game/constants.lua:2`.) The window is 1280x720 (`conf.lua:10-11`), so a
1280px-tall world requires roughly 1.8x the viewport's vertical scrolling to see top-to-bottom,
while the width matches the viewport exactly and needs no horizontal scrolling at all. This
feature halves the number of vertical cells — `20 rows -> 10 rows` — so the world becomes
`20 x 10` cells (1280 x 640px). Cell size (`C.SLOT`) is unchanged; width is unchanged; only the
row count (and therefore world height in pixels) is cut in half, per the literal request ("halve
the number of cells for height").

## Affected files
- **`game/scenes/game_scene.lua:20-21`** — the only place `WORLD_H` is defined. Change:
  ```lua
  local WORLD_W = 20 * C.SLOT  -- 1280px
  local WORLD_H = 10 * C.SLOT  -- 640px
  ```
  `WORLD_W` is untouched. Everything else that depends on world height (`self.world_h`,
  `game_scene.lua:24`) reads this same local, so no other line in this file needs to change:
  - The checkerboard floor loop (`game_scene.lua:34`, `rows = WORLD_H / C.SLOT`) already derives
    row count from `WORLD_H`, so it will draw 10 rows instead of 20 automatically.
  - `_spawn_box`'s random cell picker (`game_scene.lua:86`, `rows = self.world_h / C.SLOT`)
    already derives from `self.world_h`, so box placement automatically confines to the shorter
    world.
  - The player's vertical clamp (`game_scene.lua:216`,
    `math.min(self.player.sprite.y, self.world_h - C.SLOT)`) already reads `self.world_h`.
  - `JigsawBox.new(x, y, world_w, world_h)` (`game/jigsaw_box.lua:10,36-37`) and its
    out-of-bounds check for piece ejection (`jigsaw_box.lua:111`,
    `ty < 0 or ty >= self.world_h`) already take `world_h` as a parameter passed straight through
    from `self.world_h` at the two call sites (`game_scene.lua:60,104`), so no change needed there
    either.
- **`tests/test_jigsaw.lua:1886-1912`** — the "checkerboard floor" test block currently hardcodes
  the old square-world assumption from the prior halving (see `docs/archive/design/
  checkerboard-floor.md`):
  ```lua
  -- tests/test_jigsaw.lua:1893-1896
  assert(gs.world_w == 20 * C.SLOT, ...)
  assert(gs.world_h == 20 * C.SLOT, ...)   -- must become 10 * C.SLOT
  ```
  This assertion must be updated to `gs.world_h == 10 * C.SLOT`; `gs.world_w == 20 * C.SLOT`
  stays as-is. This is the only existing test that encodes the specific world dimensions — I
  grepped the whole `tests/` tree for `world_h`/`world_w`/`WORLD_H`/`WORLD_W` and confirmed no
  other test hardcodes a concrete height value:
  - `tests/test_jigsaw.lua:460-472` builds its own local `world_w, world_h = 4 * C.SLOT, 4 *
    C.SLOT` for an isolated `JigsawBox` unit test — independent of the real constants, no change
    needed.
  - `tests/test_jigsaw.lua:1793-1796` asserts box placement is within `[0, gs.world_w -
    C.SLOT]`/`[0, gs.world_h - C.SLOT]` generically (reads the live fields, not a literal) — no
    change needed.
  - `tests/test_jigsaw.lua:1712` is a comment/assertion about `world_w` (row-wrapping of the
    trophy shelf) — unaffected since `world_w` doesn't change.

## What changes
- `WORLD_H` in `game_scene.lua` goes from `20 * C.SLOT` (1280px) to `10 * C.SLOT` (640px). The
  world's aspect ratio changes from a `20x20` (1:1) square to a `20x10` (2:1) rectangle.
- The one existing test that hardcodes the old height (`tests/test_jigsaw.lua:1893-1896`) must be
  updated to expect `10 * C.SLOT` for `world_h` (its `world_w` assertion is unchanged).
- The floor checkerboard, box/piece random-spawn range, and the player's vertical movement clamp
  all shrink to match automatically, since they all derive from `self.world_h`/`WORLD_H` rather
  than a second hardcoded constant.

## What stays the same
- `C.SLOT` (64px cell size) is unchanged — cells are not resized, only fewer of them exist
  vertically. Pieces, the player sprite, and box sprites are all still `C.SLOT x C.SLOT`.
- `WORLD_W` (20 cols, 1280px) is unchanged — only height is halved, per the request.
- `GROUND_Y` in `game_scene.lua:26` (`4 * C.SLOT` = 256px, used only to position the player's
  spawn point) and the initial box's spawn position (`game_scene.lua:60`, `y = 3 * C.SLOT` =
  192px) both comfortably fit inside the new 640px-tall (10-row) world — no change needed.
- No puzzle image is tall enough to be affected: `assets/puzzles/easy/*.png` are 192px (3x3 =
  3 rows), `assets/puzzles/med/*.png` are 256px (4x4 = 4 rows), `assets/puzzles/hard/*.png` are
  320px (5x5 = 5 rows) — all verified via `file`. The largest (320px) is well under the new 640px
  world height, so `JigsawBox`'s piece-ejection out-of-bounds check
  (`game/jigsaw_box.lua:111`) still has ample vertical room to place every piece of every tier,
  including "hard" (the tallest grid), unlocked per `docs/archive/design/
  progressive-difficulty-unlock.md`.
- No save/persistence system exists to worry about compatibility with (`game/game_state.lua:1-4`
  explicitly documents it as in-memory/session-only, "Nothing here touches disk"), so there's no
  save-migration concern.
- The trophy shelf for completed puzzles (`game_scene.lua:167-213`) stacks entries *above* the
  world at negative y (`self.shelf_row_bottom` starts at `-C.SLOT` and decreases), entirely
  independent of `world_h` — unaffected by this change.
- `lua/core/camera.lua` is unchanged: it has no world-bounds clamping today (it only lerps toward
  the player's centre), so no camera code needs to change for this feature to work at all.

## Open questions
1. **Interpretation of "halve the number of cells for height."** I read this literally: cut the
   row count in half (20 -> 10) while keeping `C.SLOT` fixed, so the world becomes physically
   shorter (1280x640 instead of 1280x1280) rather than keeping the same pixel height with fewer,
   larger cells. Recommendation: proceed with row-count halving as specified above. Please confirm
   this is the intended reading, not "double the cell size so the same 20 rows cover half the
   pixel height" (which would *not* reduce the number of cells).
2. **Width untouched.** The request only mentions height, so I'm leaving `WORLD_W` at
   `20 * C.SLOT` (1280px), turning the world from a 1:1 square into a 2:1 wide rectangle.
   Recommendation: proceed as-is. Flag if a different final aspect ratio was intended.
3. **Camera/viewport mismatch below the new world height.** The window is 720px tall
   (`conf.lua:11`) but the new world is only 640px tall, and `lua/core/camera.lua` never clamps
   the camera to world bounds — it just lerps toward the player. Once the world is shorter than
   the viewport, a player standing anywhere near vertical center will show a static ~80px band of
   empty (undrawn) space above and/or below the floor, since nothing in the camera code prevents
   the view from extending past the world edges. This already happens today at the world's left
   edge in a milder way (world width 1280 == viewport width 1280, so it's not visible
   horizontally, but nothing stops it structurally). Recommendation: treat this as acceptable/
   out-of-scope for this change — a shorter world *is* the requested fix for "too tall," and no
   camera-clamping code exists today to extend. Flag if the empty margin should instead be
   addressed (e.g. clamping the camera to the world's vertical extent, or reducing the window/
   viewport height to match).
