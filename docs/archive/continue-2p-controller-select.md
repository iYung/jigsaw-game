## Continue 2P Controller-Select Checklist

- [x] Task A — `game/scenes/start_scene.lua` — In `StartScene:_confirm()`'s
      Continue branch (`elseif self.selected == 2 then`), change line 101
      from `GameState.player_count = _clamp_player_count(GameState.player_count)`
      to `GameState.player_count = _clamp_player_count(self.player_count)`,
      so Continue routes to `ControllerSelectScene` based on the live
      "Players: N" toggle (matching the New Game branch at line 90) instead
      of the save file's stored `player_count`.
- [x] Task B — `tests/test_start_scene.lua` — Rewrite Test 21 so it toggles
      `player_count` to `2` (mirroring Test 19's New Game pattern) before
      confirming Continue, rather than relying solely on
      `save.game_state.player_count == 2`. Add a new regression test: save
      has `player_count == 2` but the start-screen toggle is left at its
      default `1` → Continue goes straight to `GameScene` (1P), proving the
      toggle governs, not the save. Verify Test 20 (toggle and save both at
      default `1`) still passes unmodified.
