## Goal

Give both players a walk animation that alternates between an idle and a walk
sprite frame while the player is moving, matching the mechanism used in
`../wip/lua/game/player.lua`.

## Affected files

- `game/player.lua` — core animation changes
- `lua/core/spriteset.lua` — add `color` field so `sprite.color` still works
- `game/scenes/game_scene.lua` — no changes needed (sprite.color still works
  via SpriteSet)
- `assets/player_idle.png` — new (copied from `../wip`)
- `assets/player_walk.png` — new (copied from `../wip`)

## What changes

### 1. Two image assets added

Copy `player_idle.png` and `player_walk.png` from `../wip/assets/images/` into
`assets/`. These are 120×240 pixel-art character sprites. The existing Sprite
render path scales images to the sprite's declared width/height, so they will
render at `C.SLOT × C.SLOT` (64×64) in-game just like the current `player.png`.
The existing `assets/player.png` is kept as-is (no longer used by Player, but
kept in case other code references it).

### 2. `lua/core/spriteset.lua` — add `color` passthrough

Add `self.color = {1, 1, 1, 1}` to `SpriteSet.new()` and forward it to the
active sprite inside `SpriteSet:draw()`. This preserves the existing
`player.sprite.color = {...}` interface used in `game_scene.lua` line 220
without any changes to that file.

### 3. `game/player.lua` — SpriteSet + Timer animation

- Require `SpriteSet` and `Timer` (both already exist under `lua/core/`).
- In `Player.new`: create two `Sprite` objects (`idle` and `walk`) loaded from
  the new PNGs; add them to a `SpriteSet`; replace the old single `Sprite`
  assignment. Start with `"idle"` active.
- Add `self._anim_timer = Timer.new(0.15)` and `self._anim_frame = "idle"`.
- In `Player:update()`: detect whether any directional key is held (`moving`
  flag). If moving, tick the timer and flip between `"idle"` and `"walk"` on
  each tick; if not moving, snap back to `"idle"`. Call `self.sprite:set(...)`
  accordingly.
- `self.sprite` becomes a `SpriteSet`, but its `.x`, `.y`, `.width`, `.height`
  fields are unchanged in shape (SpriteSet exposes `x`/`y` directly and
  proxies `width`/`height` from the active sprite), so all game_scene.lua
  accesses (`sprite.x`, `sprite.y` clamps, save/restore, player2 initial
  position) continue to work with zero changes.

### No held-piece variants

The wip project has `idle_held`/`walk_held` frames. The jigsaw game uses the
same idle/walk frames regardless of whether the player holds a piece — the
floating piece sprite above the player's head already communicates the held
state visually.

## What stays the same

- `Player.new(x, y, input)` signature and behavior
- `player.sprite.x`, `player.sprite.y` as readable/writable position fields
- `player.sprite.color` writable (now via SpriteSet's new `color` field)
- `player:centre()` implementation and return shape
- `player:update()` and `player:draw()` external signatures
- All test assertions in `tests/test_player.lua` (none access sprite internals
  or animation state directly)

## Open questions

None — scope is clear. Proceed to Phase 2.
