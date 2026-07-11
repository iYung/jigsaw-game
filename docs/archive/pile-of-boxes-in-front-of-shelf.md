## Pile Of Boxes In Front Of Shelf Checklist

- [x] Task A — `game/constants.lua` — Add a new `PRIORITY_SHELF = 4` local (below `PRIORITY_PIECE = 5`), with a one-line comment explaining it's for shelved/completed-puzzle entries, styled like the existing `PRIORITY_PIECE`/`PRIORITY_BOX_FLYING` comments. Export it in the returned table as `PRIORITY_SHELF = PRIORITY_SHELF`.
- [x] Task B — `game/scenes/game_scene.lua:136` — Change `self.drawer:add(shelved, C.PRIORITY_PIECE)` (save-data restore branch of `on_enter()`) to `self.drawer:add(shelved, C.PRIORITY_SHELF)`.
- [x] Task C — `game/scenes/game_scene.lua:390` — Change `self.drawer:add(shelved, C.PRIORITY_PIECE)` (in `GameScene:_shelve()`) to `self.drawer:add(shelved, C.PRIORITY_SHELF)`.
