# Continue Should Respect the 2P Toggle Before Entering the Game

## Goal

Selecting "Continue" with the "Players: 2" toggle set on the start screen
currently skips `ControllerSelectScene` and drops straight into `GameScene`,
because the Continue branch derives 2-player-ness from the save file's
persisted `player_count` field instead of the live "Players: N" toggle the
player just set. New Game already does the right thing (it uses the live
toggle). Continue should behave the same way: whenever the toggle reads
"Players: 2" (and a second controller is present), Continue routes through
`ControllerSelectScene` before `GameScene`, exactly like New Game does.

## Affected files

- `game/scenes/start_scene.lua` — `StartScene:_confirm()`, Continue branch
  (`elseif self.selected == 2 then ... end`, lines ~96–106).
- `tests/test_start_scene.lua` — Continue/2P tests (Test 20, Test 21).

## What changes

- `start_scene.lua` line 101: `GameState.player_count =
  _clamp_player_count(GameState.player_count)` becomes
  `GameState.player_count = _clamp_player_count(self.player_count)` —
  mirroring line 90's New Game branch. After `GameState:apply_save(data
  .game_state)` restores everything else from the save (puzzle progress,
  piece positions, etc.), the live start-screen toggle — not the save's
  stored `player_count` — decides whether `ControllerSelectScene` is shown
  and whether `GameScene` gets a second player.
- Rationale for using the toggle as the sole source of truth: `StartScene`
  is freshly constructed (never reused) both on initial boot and on every
  ESC-to-menu return, per `main.lua`'s `love.load()` and `love.keypressed()`
  handlers, so `self.player_count` always resets to `1` and reflects an
  explicit, current choice — it's never stale. New Game already trusts it
  exclusively; Continue should too, for consistency.
- `tests/test_start_scene.lua`:
  - Test 20 (Continue, save's `player_count == 1`, toggle left at default
    `1`) — unaffected, stays green.
  - Test 21 currently asserts Continue routes to `ControllerSelectScene`
    solely because `save.game_state.player_count == 2`, with the toggle
    left at its default (`1`). That assertion encodes the bug and must be
    rewritten to toggle `player_count` to `2` before confirming (mirroring
    Test 19's New Game pattern), so it asserts the *correct* trigger.
  - New test: save has `player_count == 2` but the toggle is left at `1` →
    Continue goes straight to `GameScene` (1P), proving the toggle — not
    the save — governs the routing decision.

## What stays the same

- `GameState:apply_save` still restores every other field from the save
  exactly as before — this change only touches which value seeds
  `GameState.player_count` after that restore.
- New Game branch (`start_scene.lua` lines 87–95): untouched, already
  correct.
- `ControllerSelectScene` and `GameScene`: untouched — both already accept
  an existing player count and `data.scene`/save payload correctly.
- 1-player Continue (the common case, toggle left at its default of `1`):
  unchanged behavior — no controller-select detour before this fix, none
  after.
- `_clamp_player_count`'s no-controller-connected safety clamp: unchanged,
  still applies to whatever value it's given.

## Open questions

None outstanding — resolved: `self.player_count` is confirmed to reset to
`1` on every `StartScene` construction (never reused across sessions), so
it always reflects an explicit, current player choice rather than stale
state from a previous save. That makes it the correct single source of
truth for both New Game and Continue, consistent with New Game's existing
behavior.
