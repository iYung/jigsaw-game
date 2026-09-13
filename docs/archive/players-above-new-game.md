## Players Above New Game Checklist

- [x] Task A — `game/scenes/start_scene.lua` — Reorder `self.items` so Players: 1 is index 1, New Game is index 2, Continue is index 3; update `_toggle_player_count` to write to `self.items[1]`; update the `self.selected == 3` Players branch in `update` to `self.selected == 1`; update `_next_selectable` skip from index 2 to index 3; update `_confirm` indices (New Game: 2, Continue: 3, Settings: 4, Exit: 5); set default `self.selected = 2` in `new()`; in `on_enter` after `_has_save` is set, override `self.selected = 3` when `_has_save` is true
