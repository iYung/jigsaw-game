# Jigsaw Game

A 2D jigsaw puzzle game built with Love2D.

## Gameplay

The game boots into a **start menu** — **New Game**, **Continue**, **Players: 1/2**, and **Exit Game**. Navigate with **W/S** or the arrow keys, confirm with **E** or Enter. Choosing New Game fades into a fresh world; Continue (dimmed/disabled until a save exists) restores the world exactly as it was left. The **Players** row toggles between 1 and 2 with **A/D** or the left/right arrow keys (or Enter/E, or a gamepad's D-pad/A) while it's highlighted, and the chosen count is stored on `GameState.player_count` when New Game starts (or restored from a save on Continue). With 1 player, confirming New Game or Continue goes straight into the world exactly as before. With 2 players, confirming instead goes to a **controller-select screen** first: three devices are available — Keyboard, and Controller 1/2 for whichever gamepads are connected — and each device independently claims Player 1 by pressing left or Player 2 by pressing right (a device already claimed by the other player is rejected until that claim changes); Escape here returns to the start menu without saving. Once both players have claimed a distinct device, confirming spawns two characters in the world, Player 2 one grid cell to the right of Player 1, each driven exclusively by whichever device it claimed — no other device can move or act as that player. Progress — loose pieces, boxes, completed puzzles, and puzzle-tracking state — is saved automatically on quit, single-slot, no periodic autosave.

- **WASD** — move the player
- **E** — interact: open the piece box, or pick up / drop a jigsaw piece
- **R** — rotate held piece 90°
- **ESC** — in-game, saves and returns to the start menu; at the start menu, quits

A gamepad also works throughout, first two connected controllers only: **D-pad or left stick** to move/navigate, **A** to interact/confirm, **X** to rotate a held piece. The start menu is fully controller-navigable too.

The world starts with a gold **box** near the player. Press **E** next to it and the box disappears instantly, while the jigsaw pieces (a grid slice of a puzzle image — see `assets/puzzles/`, picked uniformly at random from whichever images haven't been shown yet this session) continue to eject one by one in the background, in shuffled order and with a random initial rotation, into adjacent slots. Dropped pieces snap to the 64px (2U) world grid. While carrying a piece, a faint ghost copy of it is drawn on the ground at the spot it would land if dropped right now, so you can preview the drop location before committing. When not carrying a piece, the grid cell the player is currently standing over is highlighted with a faint white fill instead, so the same drop-target feedback is visible at all times. Once all pieces are correctly arranged relative to each other (one shared rotation across every piece — upright, 90°, 180°, or 270° — and right relative position under that rotation, anywhere in the world, not just next to the box), the pieces fade out and disappear.

The (1280×640) world is rendered as a checkerboard floor alternating between two gray shades per 64px grid cell, over a scrolling placeholder background image (`assets/backgrounds/world_bg.png`) drawn beneath the floor and panning with the world as the camera follows the player. A **puzzle pile** sits at the top-centre of the world: a stack of small orange boxes, one per puzzle image not yet spawned this session (summed across all tiers, including locked ones), shrinking by one each time a new box is spawned. Walk up to it and press **E** to spawn a brand-new gold box, letting you generate additional puzzles on demand. Each new box flies from the current top of the pile to its randomly-chosen, grid-aligned resting cell before settling into its normal interactable state. Each puzzle image only appears once per session (tracked separately per easy/med/hard difficulty); once every image in every unlocked tier has been seen, new boxes stop appearing and the pile becomes a silent no-op. Difficulty tiers unlock progressively: `easy` is always available, `med` unlocks once 3 `easy` puzzles have been solved this session, and `hard` unlocks once 3 `med` puzzles have been solved — a locked tier's images never get picked, no matter how many are unseen. At most 3 puzzles can be active in the world at once (opened or not); the pile is a silent no-op at the cap, and a slot frees up the instant a puzzle is solved. The number of puzzles solved this session is also tracked, though not yet shown anywhere in the UI. Once a solved puzzle's pieces finish fading out, its fully-assembled image is permanently displayed at actual size on a "trophy shelf" above the top edge of the world, accumulating left-to-right in solve order for the rest of the session, wrapping to a new row once a row's cumulative width would exceed the world width — visible by walking toward the top of the world; purely decorative, with no collision or pickup. Shelf images render with softly rounded corners (a GLSL shader, `assets/shaders/rounded_corners.frag`), applied once and permanently — individual pieces render with plain square corners throughout.

## Structure

```
game/           Game-specific code
  constants.lua   U=32 base unit, SLOT=64 world grid size, PIECE_FADE_DURATION/BOX_FLY_DURATION animation timings
  puzzle_pile.lua Puzzle pile entity — grid-aligned world object; interact()/centre() own the spawn interaction, firing an on_press callback (used by GameScene to spawn a new JigsawBox); renders a stack of small orange boxes, one per puzzle image not yet spawned this session (all tiers, including locked); exposes count() and top_position(), used by game_scene.lua's spawn logic to size the stack and originate the flight animation of newly-spawned boxes
  jigsaw_box.lua   JigsawBox entity (JigsawBox.new pools the unseen (per GameState) paths across all *unlocked* tiers (GameState:is_tier_unlocked) from PuzzleCatalog.list_by_tier(), picks one uniformly at random — a tier with more unseen images remaining is proportionally more likely, not an even pick-a-tier-first step — marks it seen, records the chosen tier on `self.tier`, and returns `nil` instead of constructing a box once every unlocked tier's pool is exhausted; infers grid size from the loaded image's pixel dimensions divided by C.SLOT — 3x3=9 for easy's 192x192 images, 4x4=16 for med's 256x256, 5x5=25 for hard's 320x320 — fails fast if a dimension isn't a whole multiple of C.SLOT — then slices into that many quads, shuffles ejection order + initial rotation, timed piece ejection, Manhattan slot search; optional 5th `spawn_from` arg to `.new` starts the box in a "flying" state that eases from `spawn_from` to its `(x, y)` target cell over `C.BOX_FLY_DURATION` before settling into "waiting" — `target_x`/`target_y` are always set regardless of flight state; a box spawned without `spawn_from`, e.g. the initial on_enter box, starts directly in "waiting" as before)
  puzzle_catalog.lua PuzzleCatalog.list() / .list_by_tier() — scans assets/puzzles/easy/, med/, hard/ via love.filesystem.getDirectoryItems once per process (memoized, single shared scan powers both accessors); list() returns one flat array of image path strings across all three tiers, list_by_tier() returns {easy = {...}, med = {...}, hard = {...}} grouped per tier
  game_state.lua  GameState — a class (.new()/metatable, shaped like ../wip's GameState/SettingsState) whose module export is a singleton instance holding an in-memory, per-tier "seen" set (session-only, resets on process restart, mirrors PuzzleCatalog's memoization lifetime); to_save()/apply_save(data) snapshot/restore the singleton's persistable fields for the save/load feature (mutates in place — every module holds the same singleton reference); instance methods mark_seen/is_seen/unseen_paths/is_tier_exhausted/reset(), used by jigsaw_box.lua to enforce "no puzzle repeats within a session, tracked per difficulty tier". Also tracks solved_count, active_count, and per-tier solved_by_tier = {easy, med, hard} (all reset alongside `seen`), with puzzle_started()/puzzle_solved(tier)/can_start_puzzle() and a GameState.MAX_ACTIVE_PUZZLES = 3 constant, used by game_scene.lua to cap the world at 3 simultaneously active puzzles and count solves per tier. GameState:is_tier_unlocked(tier) plus GameState.UNLOCK_THRESHOLD = 3 gate `med`/`hard` behind solving 3 puzzles of the prior tier (`easy` is always unlocked); jigsaw_box.lua consults this to keep locked tiers out of the selection pool. Also holds player_count (1 or 2, default 1, reset alongside the other fields), set from the start menu's "Players: N" toggle and round-tripped through to_save()/apply_save() (defaults to 1 if a save predates this field) — read by game_scene.lua's on_enter to decide whether to construct a second Player, and by controller_select_scene.lua's routing in start_scene.lua
  jigsaw_piece.lua JigsawPiece entity (pickup, rotate, drop with grid snap; optional image+quad visual; fade-out "vanishing" state on solve; draw_ghost() faint drop-location preview; pieces render with square corners — no shader — throughout their lifetime)
  jigsaw_solver.lua Puzzle-completion check (is_assembled(pieces, expected_count)) — true when exactly expected_count pieces all share one rotation_step (0-3) and are in correct relative arrangement under that rotation, regardless of absolute world position; checked per-box (GameScene:active_puzzles) so differently-sized/simultaneous puzzles solve independently
  player.lua      Player movement and piece interaction (64x64 sprite, matches piece/grid size); Player.new(x, y, input) takes an optional pre-built lua/core/input.lua `Input` instance in place of the default merged keyboard + first-two-gamepads input, and the module also exports Player.build_input(device) — given nil, `{type="keyboard"}`, or `{type="gamepad", index=N}`, returns the matching Input (default merged, keyboard-only with no gamepad opts, or gamepad-only scoped to exactly controller N via lua/core/input.lua's numeric joystick_scope) — used by controller_select_scene.lua to give each claimed device its own exclusive Input and by game_scene.lua to wire those into Player 1/2
  scenes/         GameScene, StartScene, ControllerSelectScene
    start_scene.lua Start menu shown on launch — "New Game"/"Continue"/"Players: N"/"Exit Game", drawn as plain solid-color rectangles + text (no art/sound assets, unlike ../wip's start screen); owns its own lua/core/input.lua instance (W/S or arrows to navigate, E or Enter to confirm, wrapping between the four items, skipping Continue when no save exists); Exit Game calls love.event.quit(); the "Players: N" row toggles self.player_count between 1 and 2 via left/right (A/D or arrow keys, gamepad D-pad) or confirm while it's selected — shown as "< Players: N >" when highlighted — and is written to GameState.player_count when New Game is confirmed (or restored from a save on Continue). With player_count 1, New Game switches the SceneManager to a fresh GameScene and Continue reads lua/core/save.lua's save.dat and restores GameState + GameScene (dimmed/disabled with no save present), same as always; with player_count 2, both instead switch to a ControllerSelectScene (fresh for New Game, threading the save's scene data through for Continue) so each player can claim their own input device before the world loads
    controller_select_scene.lua Two-player device-claim screen shown between the start menu and GameScene whenever player_count == 2; on_enter() builds one Input source per available device — Keyboard always, plus Controller 1/2 for whichever gamepads are connected via love.joystick.getJoysticks(), mirroring the first-two-controllers convention used elsewhere — each mapping left/right/confirm. Each frame, whichever device presses left claims Player 1 and whichever presses right claims Player 2 (a device already claimed by the other player is rejected until that claim changes); confirming, once both players have a distinct claim, builds each player's full gameplay Input via player.lua's Player.build_input(device) and switches to GameScene.new(save_data, {p1 = ..., p2 = ...}). Sets self.escape_to_menu = true so main.lua's Escape handler returns to the start menu instead of trying to save (this scene has nothing to save yet)
lua/core/       Engine classes — Camera, Drawer, Input, Scene, Sprite (optional quad sub-rectangle drawing), save.lua (Save.exists()/write()/read() — single-slot save.dat, written by main.lua's love.quit() whenever the current scene is a GameScene), etc.
lua/headless/   Headless test infrastructure (stubs, HeadlessInput, runner)
tests/          Test files — run with: love . --headless
assets/         Images and other assets (assets/backgrounds/world_bg.png — placeholder background image, drawn beneath the checkerboard floor and scrolling with the world; sized 2496x1296px (game/constants.lua's BG_W/BG_H) to cover the camera's worst-case overreach past the floor edges, positioned at world-space offset (-608,-328) (BG_OFFSET_X/BG_OFFSET_Y) so the 1280x640 floor sits centered inside it; assets/shaders/rounded_corners.frag — GLSL shader giving trophy-shelf images rounded corners at a fixed ~8px radius (jigsaw pieces render with square corners and do not use this shader); assets/puzzles/easy|med|hard/*.png — puzzle source images grouped into per-difficulty subfolders, discovered at launch by game/puzzle_catalog.lua; each box picks uniformly at random from whichever images haven't been shown yet this session (game/game_state.lua) among *unlocked* tiers — a tier stops contributing candidates once all its images have been seen, `med`/`hard` don't contribute any candidates at all until unlocked (3 solves of the prior tier), and box spawning stops once every unlocked tier is exhausted; grid size is inferred from each image's pixel size, so any C.SLOT-multiple dimensions work — 192x192 (3x3) in easy/, 256x256 (4x4) in med/, 320x320 (5x5) in hard/ today)
conf.lua        Window config; suppresses graphics/audio modules under --headless
main.lua        Entry point — canvas rendering with letterboxing, pixel-art filter
```

See [`core/lua/README.md`](core/lua/README.md) for API docs on each engine class.

## Running

```bash
love .                  # normal window
love . --headless       # run tests and exit
```

## Web build

```bash
npm install
bash scripts/build_web.sh   # outputs to web/
```

`APP_TITLE` env var overrides the browser tab title (default: `"Love Exemplar"`).

The web build's on-screen controls include a ⌨/🎮 toggle that switches
between touch-keyboard buttons and a simulated gamepad (a fake
`navigator.getGamepads()` device driven by the on-screen D-pad/A/X buttons).
This lets you smoke-test controller support in any browser without a
physical controller plugged in.

## CI / Cloudflare Pages

Two GitHub Actions workflows are included:

- **`ci.yml`** — runs `love . --headless` on every push and PR
- **`web.yml`** — builds the web output and deploys to Cloudflare Pages

To activate the web deploy, see [`docs/setup-cloudflare.md`](docs/setup-cloudflare.md). In short, set these in your GitHub repository settings:

| Type | Name | Value |
|------|------|-------|
| Secret | `CLOUDFLARE_API_TOKEN` | your Cloudflare API token |
| Secret | `CLOUDFLARE_ACCOUNT_ID` | your Cloudflare account ID |
| Variable | `CLOUDFLARE_PROJECT_NAME` | your Cloudflare Pages project name |
| Variable | `APP_TITLE` | browser tab title (optional) |

PR previews are deployed automatically and linked in a PR comment. Production deploys on push to `master`.

## Architecture notes

- **Fixed logical resolution** — game renders to a `1280×720` canvas; `main.lua` scales it to the window with letterboxing. Works with any window size.
- **Scene transitions** — `SceneManager` fades through black (0.3 s) between scene switches.
- **Headless tests** — `lua/headless/stubs.lua` installs no-op love API replacements so test files run without a window. `HeadlessInput` lets tests script action presses frame-by-frame. See `tests/test_basics.lua` for a minimal example.
