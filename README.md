# Jigsaw Game

A 2D jigsaw puzzle game built with Love2D.

## Gameplay

- **WASD** — move the player
- **E** — interact: open the piece box, or pick up / drop a jigsaw piece
- **R** — rotate held piece 90°
- **ESC** — quit

The world starts with a gold **box** near the player. Press **E** next to it to eject the nine jigsaw pieces (a 3x3 slice of `assets/puzzles/gradient_3x3.png`) one by one, in shuffled order and with a random initial rotation, into adjacent slots. The box disappears once all pieces are out. Dropped pieces snap to the 64px (2U) world grid.

## Structure

```
game/           Game-specific code
  constants.lua   U=32 base unit, SLOT=64 world grid size
  jigsaw_box.lua   JigsawBox entity (loads/slices the puzzle image into 9 quads, shuffles ejection order + initial rotation, timed piece ejection, Manhattan slot search)
  jigsaw_piece.lua JigsawPiece entity (pickup, rotate, drop with grid snap; optional image+quad visual)
  player.lua      Player movement and piece interaction
  scenes/         GameScene
lua/core/       Engine classes — Camera, Drawer, Input, Scene, Sprite (optional quad sub-rectangle drawing), etc.
lua/headless/   Headless test infrastructure (stubs, HeadlessInput, runner)
tests/          Test files — run with: love . --headless
assets/         Images and other assets (assets/puzzles/gradient_3x3.png — 3x3 puzzle source image; see scripts/generate_puzzle_gradient.py)
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
