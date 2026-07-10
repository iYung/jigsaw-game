# Escape Saves and Returns to Start Menu

## Goal

Today, pressing Escape always calls `love.event.quit()` unconditionally, from any scene (`main.lua:64-65`). The user wants Escape pressed while in the game world to instead save progress and return to the start menu (mirroring the "Continue" flow, without fully exiting the app), while Escape at the start menu keeps quitting the app as it does today.

## Affected files

- `main.lua` — the only file that needs to change. `love.keypressed` currently hard-codes `love.event.quit()`; `love.quit()` already has the exact save-writing logic to reuse.

## What changes

`main.lua`'s `love.keypressed` branches on whether the current scene is a `GameScene` (duck-typed via `.to_save`, the same check `love.quit()` already uses):

```lua
local function _save_current()
    if manager.current and manager.current.to_save then
        Save.write({ game_state = GameState:to_save(), scene = manager.current:to_save() })
    end
end

function love.keypressed(key)
    if key == "escape" then
        if manager.current and manager.current.to_save then
            _save_current()
            manager:switch(StartScene.new(manager))
        else
            love.event.quit()
        end
    end
end

function love.quit()
    _save_current()
end
```

- In `GameScene`: Escape saves (via the same `{game_state, scene}` shape `love.quit()` already writes) and calls `manager:switch(StartScene.new(manager))`. `SceneManager:switch` already calls `on_enter()` on the new scene, which re-reads `Save.exists()` — so the start menu's Continue button is immediately available (and already-dimmed-if-not) right after returning, no extra wiring needed.
- In `StartScene` (or any future non-`GameScene` scene): Escape keeps today's behavior, `love.event.quit()`.
- `love.quit()` itself is simplified to just call the same extracted `_save_current()` helper — no behavior change, just deduplication (quitting via the OS window-close button or Alt+F4 still saves exactly as before).

## What stays the same

- Save format/shape, single-slot `save.dat`, save-on-quit-or-escape-from-game only — no periodic autosave.
- Escape from the start menu still fully quits the app (there's nowhere "further back" to go).
- `GameScene`/`StartScene` construction signatures are unchanged — this is purely a `main.lua`-level orchestration change, consistent with how `main.lua` already owns all scene-switching in `love.load()`.
- No dedicated test coverage is possible for this, same limitation Task H (the original `love.quit()` wiring) already had: `--headless` mode (`lua/headless/runner.lua`) never defines `love.keypressed`/`love.quit()` at all, since `main.lua`'s headless branch returns before reaching them. This is an existing, pre-existing gap in the test infra, not something this change should try to fix.

## Open questions

None — small, single-file change with no ambiguity.
