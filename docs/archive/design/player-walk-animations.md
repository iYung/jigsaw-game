## Goal

Add walk animations and left/right directionality to the player character. When the player moves horizontally, the sprite flips to face the direction of travel. While any movement key is held, a walk animation plays; when the player stops, the sprite returns to the idle pose.

## Affected files

- `lua/core/anim_sprite.lua` — new: AnimatedSprite class (spritesheet frame cycling)
- `game/player.lua` — track `facing` and `is_moving`; switch between idle/walk sprites; flip on horizontal direction
- `assets/player_walk.png` — new: 4-frame horizontal walk spritesheet, 256×64 (4 × 64px frames, right-facing)
- `tests/test_anim_sprite.lua` — new: unit tests for AnimatedSprite frame advancement
- `tests/test_player.lua` — extend: tests for facing direction and animation state switching

## What changes

### New `lua/core/anim_sprite.lua` — AnimatedSprite

A thin subclass/companion to `Sprite` that adds spritesheet frame cycling.

Fields:
- `image` — spritesheet texture
- `frame_width`, `frame_height` — pixel size of one frame
- `frame_count` — total number of frames in the strip
- `fps` — playback rate (default 8)
- `frame` — current frame index (1-based)
- `_t` — accumulated time since last frame advance
- All `Sprite` fields (`x`, `y`, `width`, `height`, `scale_x`, `scale_y`, `visible`, `color`)

`AnimatedSprite:update(dt)` — advances `_t`; when `_t >= 1/fps`, increments frame (wraps), resets `_t`.

`AnimatedSprite:draw()` — computes a `love.graphics.newQuad` from the current frame index and delegates to the same draw logic as `Sprite` (using `self.quad`).

`AnimatedSprite.new(x, y, w, h, image, frame_count, fps)` — constructor.

### Changes to `game/player.lua`

New state fields on the Player:
- `self.facing` — `"right"` (default) or `"left"`, tracks the last horizontal input direction
- `self.is_moving` — `true` while any directional key is held this frame

Two sprite variants stored on the player (not via SpriteSet to keep complexity low):
- `self.sprite_idle` — the existing `Sprite` with `assets/player.png` (64×64, static)
- `self.sprite_walk` — an `AnimatedSprite` with `assets/player_walk.png` (4 frames, 256×64)
- `self.sprite` — pointer to whichever is active; reassigned in `update()` based on `is_moving`

Direction logic in `update()`:
- If `left` is down, set `self.facing = "left"` (set `scale_x = -1` on draw)
- If `right` is down, set `self.facing = "right"` (set `scale_x = 1` on draw)
- Up/down do **not** change `self.facing`
- If any directional key is down, `self.is_moving = true` and `self.sprite = self.sprite_walk`
- If no directional key is down, `self.is_moving = false` and `self.sprite = self.sprite_idle`

In `Player:draw()` — set `self.sprite.scale_x = (self.facing == "left" and -1 or 1)` before calling `self.sprite:draw()`.

Sync position: when switching active sprite, copy `x`/`y` from the old to the new sprite. Both sprites share the same logical position via `self.sprite.x`/`self.sprite.y`; the x/y swap is a single field copy, not a full object replace.

### New asset `assets/player_walk.png`

A 256×64 RGBA PNG, right-facing, 4 frames side by side. Each frame is 64×64 pixels matching the current player tile size. (Placeholder: 4 recolored copies of the existing player.png. Real art can replace it without code changes.)

## What stays the same

- Player movement speed (`SPEED = 200`) and all physics — no changes
- Held piece logic, interact/rotate handling — untouched
- Camera tracking uses `Player:centre()` — unchanged, still computed from `self.sprite.x/y`
- The `SpriteSet` class is **not** used here (would add indirection for two states; direct pointer swap is simpler)
- `Sprite` base class — unchanged; `AnimatedSprite` is a separate new class
- All existing player tests remain valid; new tests are additive

## Open questions

None — design is self-contained. The placeholder asset can ship with the feature; the user can replace it with real pixel art at any time.
