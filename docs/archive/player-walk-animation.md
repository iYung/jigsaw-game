## Player Walk Animation Checklist

- [x] Task A — `assets/player_idle.png`, `assets/player_walk.png` — copy both files from `/root/wip/assets/images/player_idle.png` and `/root/wip/assets/images/player_walk.png` into `assets/`

- [x] Task B — `lua/core/spriteset.lua` — add `self.color = {1, 1, 1, 1}` to `SpriteSet.new()` and forward it to the active sprite inside `SpriteSet:draw()` (just before calling `s:draw()`)

- [x] Task C — `game/player.lua` — replace single Sprite with a SpriteSet + Timer walk animation: require SpriteSet and Timer; in Player.new create idle/walk Sprites from the new PNGs (sized C.SLOT × C.SLOT), add them to a SpriteSet starting on "idle"; add `_anim_timer = Timer.new(0.15)` and `_anim_frame = "idle"`; in update() detect movement, tick the timer and flip between "idle"/"walk" when moving, snap to "idle" when still
