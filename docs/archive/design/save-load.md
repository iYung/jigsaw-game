# Save / Load

## Goal

Persist game progress across sessions, mirroring the pattern already proven in `../wip` (`lua/core/save.lua` + `GameState.to_save/from_save` + a Continue button on the start screen). On quit, write out: puzzle-progress bookkeeping (seen/solved counts, tier unlocks), every loose piece and box currently out in the world, and every completed (shelved) puzzle. On Continue, reconstruct the world exactly as it was left.

## Affected files

- `lua/core/save.lua` — **new**. Generic Lua-table serializer + `Save.exists()/write()/read()`, ported near-verbatim from `wip/lua/core/save.lua`.
- `conf.lua` — set `t.identity` so the save directory doesn't collide with other LÖVE games.
- `game/game_state.lua` — add `to_save()` / `apply_save(data)` to the singleton.
- `game/jigsaw_box.lua` — store the puzzle image `path` on `self` (currently a local var); add save/restore helpers for a box's remaining spawn queue.
- `game/jigsaw_piece.lua` — store `path`/`row`/`col` on `self` (currently only `image`+`quad`, which aren't serializable) so a piece can be rebuilt from data.
- `game/scenes/game_scene.lua` — add `:to_save()` and accept optional saved data in construction to restore boxes, loose pieces, completed puzzles, shelf layout, and player position/held piece.
- `game/scenes/start_scene.lua` — add a "Continue" item; dim/disable it when no save exists.
- `main.lua` — wire `love.quit()` to save when the current scene is a `GameScene`; require `lua/core/save`.
- Tests: new `tests/test_save.lua`; extend `tests/test_game_state.lua`, `tests/test_jigsaw.lua`, `tests/test_start_scene.lua`.

## What changes

### New `lua/core/save.lua`
Hand-rolled serializer (numbers/booleans/strings/flat-or-nested tables, int or string keys) plus:
```lua
Save.exists()        -- love.filesystem.getInfo("save.dat") ~= nil
Save.write(data)      -- love.filesystem.write("save.dat", "return " .. serialize(data))
Save.read()           -- load()/loadstring() the file back into a table, nil on missing/corrupt
```
No settings file (this game has no settings menu) — just the one `save.dat`.

### `conf.lua`
Add `t.identity = "jigsaw_game"` so LÖVE doesn't share a save folder with every other unnamed LÖVE game on the machine.

### `game/game_state.lua`
```lua
function GameState:to_save()
    return {
        version = 1,
        seen = self.seen,                    -- {easy={[path]=true,...}, med=..., hard=...}
        solved_count = self.solved_count,
        active_count = self.active_count,
        solved_by_tier = self.solved_by_tier,
    }
end

function GameState:apply_save(data)          -- mutates the singleton in place
    self.seen = data.seen
    self.solved_count = data.solved_count
    self.active_count = data.active_count
    self.solved_by_tier = data.solved_by_tier
end
```
Mutates in place (rather than returning a new instance) because every module `require`s the same singleton — replacing it would leave stale references. On version mismatch or missing save, fall back to `self:reset()`.

### `game/jigsaw_box.lua`
- Store `self.path = path` at construction (currently only used locally to load the image).
- Add `JigsawBox:to_save()` returning: `path`, `tier`, simplified `state` (`"flying"` collapses to `"waiting"` since mid-flight position is purely cosmetic), `target_x`/`target_y`, and the remaining `pieces_to_spawn` as a list of `{row, col}` (path/image are shared per-box, no need to repeat per piece).
- Add `JigsawBox.from_save(data, world_w, world_h)` reconstructing a box at `state = "waiting"` (or `"ejecting"` with `spawn_timer = 0.3` if it had one in progress) with its remaining queue intact, without re-marking `GameState.seen` (it's already marked) and without re-shuffling the queue (it's already shuffled).

### `game/jigsaw_piece.lua`
- Store `self.path` alongside `self.row`/`self.col` when constructed from a box's `visual` spec, so a piece can be serialized as `{path, row, col, rotation_step, x, y}` and rebuilt by re-deriving `image`/`quad` from `path` (`love.graphics.newImage(path)`, then a quad from `row/col * C.SLOT` and the image's own dimensions — same math `jigsaw_box.lua` already does).
- Only `state == "grounded"` pieces are saved. A piece mid-`"vanishing"` fade at save time is finished immediately (its puzzle gets shelved, skipping the last fraction of a second of fade) rather than serializing transient fade state.
- A `"held"` piece (rare — only true if the player quits mid-carry) is saved as the player's `held_piece` descriptor and restored back into `player.held_piece`, not auto-dropped.

### `game/scenes/game_scene.lua`
- `GameScene.new(save_data)` — `save_data` optional (nil ⇒ today's fresh-game behavior, unchanged, so no existing caller/test breaks).
- New `GameScene:to_save()` gathers: `player = {x, y, held_piece}`, `pieces` (grounded only), `boxes` (via `JigsawBox:to_save()`), `completed_puzzles` (`path, x, y, cols, rows` — shader dropped, recreated on load), and the shelf-layout cursor (`shelf_row_x`, `shelf_row_bottom`, `shelf_row_max_height`) so newly-completed puzzles keep appending in the right place instead of overlapping restored ones.
- On restore: rebuild `active_puzzles` bookkeeping entries from the restored boxes' `spawned` pieces (this table is fully derived today — `game_scene.lua:76-84` — so it needs no separate save format of its own).
- `GameState:puzzle_started()`/`is_tier_unlocked()` etc. are not re-invoked during restore (the counts are already baked into the restored `GameState`).

### `game/scenes/start_scene.lua`
Add "Continue" as the 2nd menu item (`New Game`, `Continue`, `Exit Game`):
- `on_enter()`: `self._has_save = Save.exists()`; skip Continue in up/down navigation when false (same skip-logic pattern as `wip`'s `_next_selectable`); draw it dimmed.
- Confirm New Game: `Save.exists()` and delete `save.dat` if present (fresh start shouldn't leave a stale save around from a previous run — actually simpler and equally safe: just let the next quit overwrite it; no explicit delete needed since New Game always writes a fresh `save.dat` at quit time), `GameState:reset()`, switch to `GameScene.new()`.
- Confirm Continue: no-op if `not self._has_save`; else `Save.read()` → `GameState:apply_save(data)` → `GameScene.new(data)`.

### `main.lua`
```lua
function love.quit()
    if manager.current and manager.current.to_save then
        Save.write({ game_state = GameState:to_save(), scene = manager.current:to_save() })
    end
end
```
Guarded by duck-typing `manager.current.to_save` (only `GameScene` has it) — mirrors `wip`'s `current.game_state` guard, adapted since this game has no per-scene `game_state` field, just the one scene class worth saving.

## What stays the same

- No periodic autosave — save only fires in `love.quit()`, matching `../wip` (no settings-menu "Save" button here, since this game has no settings menu).
- Single save slot (`save.dat`), no multi-slot support.
- `GameScene.new()` with no args still produces exactly today's fresh-game world.
- Visual/animation-only state (fly arcs, spawn timers, fade progress, shader objects, `pieces_in_drawer` bookkeeping) is never serialized — it's cosmetic or trivially rebuilt.
- Existing tests that construct `GameScene.new()`/`JigsawBox.new()`/`JigsawPiece.new()` with today's signatures keep working unchanged.

## Open questions

None — resolved. Mid-vanish pieces at save time collapse straight to "shelved" (confirmed).
