## Player Walk Animations Checklist

- [x] Task A — `lua/core/anim_sprite.lua` — Create AnimatedSprite class: spritesheet image, frame_width/frame_count/fps, `_t` accumulator; `update(dt)` advances frames; `draw()` renders current frame via quad; constructor `AnimatedSprite.new(x, y, w, h, image, frame_count, fps)`
- [x] Task B — `assets/player_walk.png` — Create placeholder 4-frame walk spritesheet (256×64): each 64×64 frame is a tinted copy of the existing player.png (slightly different hue per frame to make animation visible during dev), right-facing
- [x] Task C — `game/player.lua` — Add `self.facing` ("right" default), `self.sprite_idle` (existing Sprite+player.png), `self.sprite_walk` (AnimatedSprite+player_walk.png); in `update()` set facing from horizontal input, swap `self.sprite` pointer based on any movement; in `draw()` set `scale_x` from facing before drawing
- [x] Task D — `tests/test_anim_sprite.lua` — Unit tests for AnimatedSprite: frame advances after correct elapsed time, wraps from last frame back to 1, does not advance before enough time elapsed, draw calls correct quad viewport
- [x] Task E — `tests/test_player.lua` — Extend with tests: facing defaults to "right", facing flips to "left" on left input, facing stays "left" after input released, up/down do not change facing, is_moving true while key held and false when released
