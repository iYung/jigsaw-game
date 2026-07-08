# Jigsaw Game

A 2D jigsaw puzzle game built with Love2D.

## Gameplay

- **WASD** — move the player
- **E** — interact: open the piece box, or pick up / drop a jigsaw piece
- **R** — rotate held piece 90°
- **ESC** — quit

The world starts with a gold **box** near the player. Press **E** next to it and the box disappears instantly, while the nine jigsaw pieces (a 3x3 slice of a randomly chosen puzzle image — see `assets/puzzles/`) continue to eject one by one in the background, in shuffled order and with a random initial rotation, into adjacent slots. Dropped pieces snap to the 64px (2U) world grid. While carrying a piece, a faint ghost copy of it is drawn on the ground at the spot it would land if dropped right now, so you can preview the drop location before committing. Once all nine pieces are correctly arranged relative to each other (right rotation, right relative position — anywhere in the world, not just next to the box), the pieces fade out and disappear.

A red **spawn button** sits at the top-centre of the (square, 1280×1280) world, which is rendered as a checkerboard floor alternating between two gray shades per 64px grid cell. Walk up to it and press **E** to spawn a brand-new gold box at a random grid-aligned spot anywhere in the world, letting you generate additional puzzles on demand.

## Structure

```
game/           Game-specific code
  constants.lua   U=32 base unit, SLOT=64 world grid size
  jigsaw_box.lua   JigsawBox entity (infers grid size from the loaded image's pixel dimensions divided by C.SLOT — currently 3x3=9 for the existing 192x192 images, fails fast if a dimension isn't a whole multiple of C.SLOT — then slices into that many quads, shuffles ejection order + initial rotation, timed piece ejection, Manhattan slot search)
  jigsaw_piece.lua JigsawPiece entity (pickup, rotate, drop with grid snap; optional image+quad visual; fade-out "vanishing" state on solve; draw_ghost() faint drop-location preview)
  jigsaw_solver.lua Puzzle-completion check (is_assembled(pieces, expected_count)) — true when exactly expected_count pieces are all unrotated and in correct relative arrangement, regardless of absolute world position; checked per-box (GameScene:active_puzzles) so differently-sized/simultaneous puzzles solve independently
  spawn_button.lua SpawnButton entity — grid-aligned world object; interact() fires an on_press callback (used by GameScene to spawn a new JigsawBox at a random grid position)
  player.lua      Player movement and piece interaction (64x64 sprite, matches piece/grid size)
  scenes/         GameScene
lua/core/       Engine classes — Camera, Drawer, Input, Scene, Sprite (optional quad sub-rectangle drawing), etc.
lua/headless/   Headless test infrastructure (stubs, HeadlessInput, runner)
tests/          Test files — run with: love . --headless
assets/         Images and other assets (assets/puzzles/*.png — 192x192 (3x3) puzzle source images, one picked at random per box; grid size is inferred from each image's pixel size so any C.SLOT-multiple dimensions would work, but only 3x3 images exist today; see scripts/generate_puzzle_images.py)
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
