## Fix Music Overlap On Main Menu Checklist

- [x] Task A — `game/scenes/game_scene.lua` — In `GameScene:on_exit()`, stop all bg music tracks in `self._bg_list` via `Sound.stop_music()` before calling `Scene.on_exit(self)`, so bg music doesn't bleed into the main menu when the player returns via the settings overlay.
