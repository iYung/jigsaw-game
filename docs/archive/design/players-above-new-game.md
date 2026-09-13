# Players Above New Game

## Goal

Move the "Players: N" menu item above "New Game" in the start scene, and make the initial cursor selection context-aware (New Game by default, Continue when a save exists).

## Affected files

- `game/scenes/start_scene.lua` — only file that needs to change

## What changes

### Menu item order

Current order:
1. New Game
2. Continue
3. Players: 1
4. Settings
5. Exit Game

New order:
1. Players: 1
2. New Game
3. Continue
4. Settings
5. Exit Game

### Hardcoded item indices

Every place that references a specific index must update:

| Location | Old index | New index | Meaning |
|---|---|---|---|
| `self.items` table | 3 | 1 | Players label |
| `_toggle_player_count` | `self.items[3]` | `self.items[1]` | update label |
| `_next_selectable` | skip index 2 | skip index 3 | skip Continue when no save |
| `_confirm` selected == 1 | New Game | index 2 |
| `_confirm` selected == 2 | Continue | index 3 |
| `_confirm` selected == 4 | Settings | index 4 (unchanged) |
| `_confirm` selected == 5 | Exit | index 5 (unchanged) |
| `update` — Players branch | `self.selected == 3` | `self.selected == 1` |

### Default selection (new behaviour)

Currently `self.selected = 1` is fixed in `StartScene.new`. After the change:

- Set `self.selected = 2` (New Game) unconditionally in `new()`.
- In `on_enter`, after `_has_save` is known, override: if `_has_save` then `self.selected = 3` (Continue).

This mirrors the cursor to the most useful action: Continue when a save exists, New Game otherwise.

## What stays the same

- `_next_selectable` logic structure — only the skipped index number changes (2 → 3).
- All sound effects, draw logic, item count, and input bindings are unchanged.
- No other files are affected.

## Open questions

None — fully resolved before writing this doc.
