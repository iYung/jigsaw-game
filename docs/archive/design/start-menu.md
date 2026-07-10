# Start Menu

## Goal
Add a start menu scene that appears before gameplay begins, matching the pattern `../wip` uses (a `StartScene` shown first, `SceneManager` switches into gameplay on confirm). For now, only two options: **New Game** and **Exit Game** — no Continue/Settings/save-file handling, since jigsaw-game has no persistence (`game/game_state.lua` is explicitly session-only, no `to_save`/`from_save`).

## Affected files
- `game/scenes/start_scene.lua` — **new**: `StartScene`, a `Scene` subclass showing the two menu items
- `main.lua` — switch to `StartScene.new(manager)` on load instead of `GameScene.new()` directly
- `tests/test_start_scene.lua` — **new**: covers navigation wrap, confirm actions
- `README.md` — document the start menu under Gameplay/Structure

## What changes

### `StartScene` (`game/scenes/start_scene.lua`)
A `Scene` subclass (`Scene.new(1280, 720)`), following the existing `game_scene.lua` pattern of building its `on_enter` content from plain-color rectangles and `love.graphics.print`/`printf` — jigsaw-game has no menu art or sound assets (unlike `../wip`'s `start_bg.png`/`menu_btn.png`/`Sound` module), so this stays purely code-drawn, consistent with the floor/box/pile's existing style.

State:
- `self.items = {"New Game", "Exit Game"}`
- `self.selected` — 1-indexed, starts at `1`
- `self.input` — own `lua/core/input.lua` instance (matches `player.lua`'s per-owner pattern, not a shared global like `../wip`), mapped `{ up = {"w","up"}, down = {"s","down"}, confirm = {"e","return"} }`
- `self.manager` — the `SceneManager` passed in, used to switch to `GameScene.new()` on "New Game"

Behavior:
- `update(dt)`: calls `self.input:update()`; `pressed("up")`/`pressed("down")` move `self.selected` by ±1, wrapping (`((selected - 2 + delta) % #items) + 1` style, matching `../wip`'s `_next_selectable` wraparound); `pressed("confirm")` calls `self:_confirm()`
- `_confirm()`: if `selected == 1` → `self.manager:switch(GameScene.new())`; if `selected == 2` → `love.event.quit()`
- Mouse support: `mousemoved(x, y)` updates `self.selected` if the cursor is over an item's rect (scaled/offset the same way `main.lua` already letterboxes the canvas — reuse the existing scale math, or expose a screen→logical helper); `mousepressed(x, y, button)` with `button == 1` calls `self:_confirm()` if the click lands on the currently-hoverable item. Requires `main.lua` to forward `love.mousemoved`/`love.mousepressed` to `manager.current` the same way `love.keypressed` already exists for ESC-to-quit.
- `draw()`: title text centered near the top (e.g. "Jigsaw"), two items stacked and centered, each drawn as a rectangle (existing solid-color style, e.g. gray fill `{0.35,0.35,0.35,1}` normal / lighter `{0.55,0.55,0.55,1}` selected) with the label text centered inside; selected item visually distinguished by the fill color (no image swap needed, matching the file's no-art-asset constraint)

### `main.lua`
- `require("game/scenes/start_scene")` alongside `GameScene`
- `love.load()`: `manager:switch(StartScene.new(manager))` instead of `manager:switch(GameScene.new())` — `StartScene` needs the manager reference to switch into `GameScene` on confirm
- Add `love.mousemoved`/`love.mousepressed` handlers that forward to `manager.current` if it defines them (mirrors the existing `love.keypressed` ESC-to-quit handler's shape — a thin top-level function delegating into the active scene)

## What stays the same
- `GameScene` itself — untested, unchanged; `StartScene` only ever constructs a fresh `GameScene.new()`, same as what `love.load()` does today
- `SceneManager`'s fade transition — reused as-is; switching from `StartScene` to `GameScene` fades exactly like any other scene switch
- ESC-still-quits-immediately behavior in `main.lua`'s `love.keypressed` — untouched; ESC works as a global quit from any scene, start menu included
- No persistence, no Continue option, no Settings — explicitly out of scope per the user's "just new game and exit game for now"
- `lua/core/input.lua` — reused unmodified, same as `player.lua` already does

## Open questions
None — resolved before writing this doc:
- Navigation/confirm keys: **W/S (or arrows) + E** — matches jigsaw-game's existing WASD-move/E-interact convention, plus mouse hover+click as a supplement
- Visual style: **plain code-drawn rectangles + text**, no custom art/sound — matches the project's existing minimalist style and avoids inventing assets that don't exist yet
