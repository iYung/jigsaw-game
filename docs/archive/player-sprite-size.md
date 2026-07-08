# Player Sprite Size Checklist

- [x] Task A — `assets/player.png` — Regenerate this PNG at 64x64. Take the existing 32x48
  artwork (peach head, red shirt, blue legs), scale it uniformly by `min(64/32, 64/48) = 1.333`
  to 43x64 (preserve aspect ratio, no distortion), and center it on a transparent 64x64 RGBA
  canvas (~10-11px transparent padding on left/right). Use Python + Pillow. Overwrite
  `assets/player.png` in place. Verify with `file assets/player.png` that the result reports
  "64 x 64".

- [x] Task B — `game/player.lua` — Two independent edits:
  1. Line 12: change `Sprite.new(x, y, 32, 48)` to `Sprite.new(x, y, C.SLOT, C.SLOT)`.
  2. `Player:centre()` (lines 130-132): change the hardcoded `x = self.sprite.x + 16, y =
     self.sprite.y + 24` to `x = self.sprite.x + self.sprite.width / 2, y = self.sprite.y +
     self.sprite.height / 2`.
  `C` (`game/constants.lua`) is already required at the top of this file. Do not touch
  `Player:drop_target()` — its `C.U` offset is sized to a piece, not the player, and is
  unaffected by this change.

- [x] Task C — `game/scenes/game_scene.lua` — Two independent edits:
  1. Line 27: change `Player.new(0, GROUND_Y - 48)` to `Player.new(0, GROUND_Y - C.SLOT)`.
  2. Lines 157-158: change the position clamp from `self.world_w - 32` / `self.world_h - 48` to
     `self.world_w - C.SLOT` / `self.world_h - C.SLOT`.
  `C` (constants) is already required/available in this file — confirm the require exists at the
  top; if not, add `local C = require("game/constants")`.

- [x] Task D — `tests/test_jigsaw.lua` — Update tests that hardcode the old 32x48 player geometry
  so they assert against the *new* 64x64 geometry (centre offset now `+32, +32` instead of
  `+16, +24`), rather than leaving them asserting stale numbers:
  1. Lines ~97-98 and ~119-120: mock `centre` functions currently returning
     `{ x = self.sprite.x + 16, y = self.sprite.y + 24 }` — update to
     `{ x = self.sprite.x + 32, y = self.sprite.y + 32 }` and recompute any dependent
     `expected_x` / `expected_y` values/comments in the same test blocks (~lines 105-106).
  2. Lines ~147-226 (`Player:drop_target()` tests): recompute `player.sprite.x` / `.y` starting
     values and expected `dt.x` / `dt.y` / `dt.snap_x` / `dt.snap_y` results so they reflect the
     new centre offset (`+32, +32`). The snapping formula itself (`C.U` offset, `C.SLOT` rounding)
     is unchanged — only the numbers that flow from the player's centre need updating. Update the
     stale comments at ~lines 186-187 to match.
  3. Lines ~634-641: `Player.new(16, 200)` was chosen so the *old* centre (`+16,+24`) exactly
     matched a piece's centre — pick a new player position so the *new* centre (`+32,+32`) matches
     that same piece centre instead (adjust the `Player.new(...)` call, not the piece's position).
  4. Line ~1241 comment (`player:centre() == (16, 24)`) — update to `(32, 32)` (or whatever the
     actual new sprite position/offset resolves to at that point in the test).
  Run `love . --headless` / the project's test runner (see `tests/test_basics.lua` for how tests
  are invoked) after edits and confirm all tests pass.

- [x] Task E (depends on A, B, C, D) — Run the full test suite and manually sanity-check: load the
  game, confirm the player renders at the same visual size as a puzzle piece/box footprint, spawns
  standing on the ground (not sunken/floating), and stays fully in-bounds when walked to each world
  edge. Fix any regressions found; do not silently patch — if something's wrong, note it before
  moving to Verification.
