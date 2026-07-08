# Player Sprite Size

## Goal
The player is already a real PNG sprite (`assets/player.png`, loaded at `game/player.lua:13`),
but it's sized **32x48** (`Sprite.new(x, y, 32, 48)`, `game/player.lua:12`) while puzzle pieces are
**64x64** (`C.SLOT x C.SLOT`, `game/jigsaw_piece.lua:11`, `C.SLOT = 2 * C.U = 64` in
`game/constants.lua:1-2`). The two don't share a footprint today, which is visually inconsistent
and means the player doesn't occupy one grid cell the way a piece does.

This feature resizes the player sprite to `C.SLOT x C.SLOT` (64x64) — the same size as a puzzle
piece — and regenerates `assets/player.png` at 64x64 so the artwork isn't distorted by non-uniform
stretching.

## Affected files
- `assets/player.png` — currently a 32x48 pixel-art figure (peach head, red shirt, blue legs).
  Regenerated as a 64x64 PNG: the existing artwork is scaled by the uniform factor
  `min(64/32, 64/48) = 1.333` (64/48, the tighter constraint) to **43x64**, preserving its original
  proportions, then centered on a transparent 64x64 canvas (~10-11px transparent padding on each
  side). This avoids the alternative of just changing `Sprite.new`'s width/height and letting
  `Sprite:draw`'s existing rescale (`lua/core/sprite.lua:40-46`) stretch the 32x48 source
  non-uniformly (2x horizontally, 1.33x vertically) into a squashed-looking 64x64 image.
- `game/player.lua`:
  - Line 12: `Sprite.new(x, y, 32, 48)` → `Sprite.new(x, y, C.SLOT, C.SLOT)`.
  - Lines 130-132, `Player:centre()`: currently hardcodes `+16, +24` (half of the old 32x48).
    Changed to `self.sprite.width / 2, self.sprite.height / 2` so it derives from the sprite's
    actual size instead of a second magic-number copy of it.
- `game/scenes/game_scene.lua`:
  - Line 27: `Player.new(0, GROUND_Y - 48)` → `Player.new(0, GROUND_Y - C.SLOT)` (spawn sits on the
    ground using the new sprite height).
  - Lines 157-158: position clamp `self.world_w - 32` / `self.world_h - 48` →
    `self.world_w - C.SLOT` / `self.world_h - C.SLOT`.
- `tests/test_jigsaw.lua` — several tests hardcode the old 32x48 geometry and will need their
  expected values updated to match the new 64x64 size (not just left alone, since they'd otherwise
  assert the *old* wrong numbers):
  - Lines 97-98, 119-120: mock `centre` functions using `+16, +24` — update to match new centre math.
  - Lines 105-106, 147-158, 186-226: `Player:drop_target()` tests — the drop-target math itself
    (`C.U` offset, `C.SLOT` snapping) doesn't change, but comments/expected coordinates derived from
    the old centre offset need recomputation.
  - Lines 634-641: sets `Player.new(16, 200)` specifically so the old centre (`+16,+24`) lines up
    with a piece's centre — needs a new player position so the new centre (`+32,+32`) still lines up.
  - Line 1241 comment (`player:centre() == (16, 24)`) — update to reflect new offsets.

## What stays the same
- `assets/puzzles/*.png` and piece-cutting logic (`game/jigsaw_box.lua`) are untouched — piece size
  is already `C.SLOT` and isn't changing.
- `Player:drop_target()`'s use of `C.U` as the offset from the player's centre to a piece's top-left
  (`game/player.lua:135-142`) is unchanged — that offset is sized to a *piece* (half of `C.SLOT`),
  not to the player, so it stays correct regardless of player sprite size.
- Movement speed (`SPEED = 200`, `game/player.lua:5`) and input handling are unchanged — this is a
  visual/footprint change only, not a gameplay-speed change.
- `Sprite` (`lua/core/sprite.lua`) itself is unchanged — it already supports arbitrary width/height
  independent of the source image's pixel dimensions; the player continues to use that as its normal
  draw path.

## Open questions
None outstanding. Sizing target (`C.SLOT x C.SLOT`, matching pieces exactly) is unambiguous per the
request. The art-regeneration approach (uniform scale + letterbox, rather than stretching the
existing PNG non-uniformly) is a non-blocking image-quality call made in this doc, matching how
prior design docs in this project (e.g. checkerboard floor colors) made similar non-blocking calls
directly rather than stopping to ask.
