## Goal

Fix the bug where background game music (bg1–bg4) and main-menu music play simultaneously after the player selects "New Game" and then "Main Menu" from the in-game settings overlay.

## Affected files

- `game/scenes/game_scene.lua` — `GameScene:on_exit()`

## What changes

`GameScene:on_exit()` currently only calls `Scene.on_exit(self)` (which clears the drawer). It does **not** stop the background music tracks it started in `on_enter()`.

The fix: iterate over `self._bg_list` and call `Sound.stop_music()` for each track before clearing the drawer. This mirrors how `GameScene:on_enter()` calls `Sound.stop_music("menu")` to clean up the music the *previous* scene started.

```lua
function GameScene:on_exit()
    for _, name in ipairs(self._bg_list) do
        Sound.stop_music(name)
    end
    Scene.on_exit(self)
end
```

## What stays the same

- `StartScene:on_enter()` is unchanged — its existing guard (`if not Sound.is_music_playing("menu")`) already handles re-entry from settings/controller-select safely.
- `SceneManager` is unchanged — no changes to the fade lifecycle.
- `Sound` module API is unchanged — `Sound.stop_music` already exists.
- No changes to `SettingsScene`, `ControllerSelectScene`, or any other scene.

## Open questions

None. The cause and fix are unambiguous.
