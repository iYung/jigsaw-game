## Controller Select Icons Checklist

- [x] Task A — `assets/ui/icon_keyboard.png`, `assets/ui/icon_controller.png` — Generate two new placeholder PNG assets via a throwaway Python + PIL script (write the script anywhere convenient, e.g. `/tmp/gen_icons.py`; do **not** commit the script itself, only the two resulting `.png` files under `assets/ui/`). Follow the existing `assets/ui/panel_normal.png` / `panel_selected.png` precedent (`docs/archive/design/menu-ui-pngs.md`): flat placeholder art, 64x64, RGBA. `icon_keyboard.png` should read as a simple keyboard shape at a glance (e.g. a flat rectangle body with a small grid of lighter squares/dots inside it suggesting keys). `icon_controller.png` should read as a simple generic gamepad shape at a glance (e.g. a flat rounded rectangle/capsule body, no brand-specific button layout — this is the one generic icon used for *every* connected controller regardless of vendor, per the design doc). Keep both images simple flat shapes on a transparent or solid background, consistent with the existing panel PNGs' flat style. No dependency on any other task — can run fully in parallel/isolation. Verify both files exist at `assets/ui/icon_keyboard.png` and `assets/ui/icon_controller.png` when done (Task B assumes these two exact paths exist).

- [x] Task B — `game/scenes/controller_select_scene.lua` — Wire the two new icons into the controller-select screen, replacing the three text-label draws with icon draws. Specifically:
  - After the existing `PANEL_NORMAL`/`PANEL_SELECTED` loads (lines 11-12), add:
    ```lua
    local ICON_KEYBOARD   = love.graphics.newImage("assets/ui/icon_keyboard.png")
    local ICON_CONTROLLER = love.graphics.newImage("assets/ui/icon_controller.png")
    ```
  - In `on_enter()` (lines 46-81): the keyboard source table built at lines 49-57 gets a new `icon = ICON_KEYBOARD` field added alongside its existing `label = "Keyboard"` field. Each gamepad source table built inside the `for i = 1, 2 do` loop (lines 60-80) gets a new `icon = ICON_CONTROLLER` field added alongside its existing `label = "Controller " .. i` field. Leave every existing field (`device`, `label`, `input`) exactly as-is — `label` must stay, since it's still read by `tests/test_controller_select_scene.lua` and by the `_label_for()` helper.
  - Add a small local helper near `_label_for()` (lines 144-154), e.g.:
    ```lua
    local function _source_for(device, sources)
        if not device then
            return nil
        end
        for _, source in ipairs(sources) do
            if devices_equal(source.device, device) then
                return source
            end
        end
        return nil
    end
    ```
    (`_label_for()` can stay as-is for any remaining callers, or be reimplemented in terms of `_source_for` — either is fine, this is a local easily-reversible refactor.)
  - In `draw()` (lines 169-211), replace the three label draws:
    - Player 1 slot (line 182, currently `love.graphics.printf(_label_for(self.p1_device, self._sources), left_x, COLUMN_TOP + 60, COLUMN_W, "center")`): resolve `local p1_source = _source_for(self.p1_device, self._sources)`; if `p1_source` is not nil, draw `p1_source.icon` scaled to a fixed 48x48 size (`icon:getWidth()`/`getHeight()` divisors, matching the existing `PANEL_NORMAL:getWidth()`-style scaling convention at e.g. line 179), centered horizontally in the `left_x`/`COLUMN_W` column at roughly the same vertical position (`COLUMN_TOP + 60`); if `p1_source` is nil, draw nothing (matching today's blank "-" state).
    - Middle "Devices" legend loop (lines 192-194, currently `love.graphics.printf(source.label, mid_x, COLUMN_TOP + 20 + i * 30, COLUMN_W, "center")`): replace with a small icon draw per unclaimed source, scaled to roughly 24x24, centered horizontally in the `mid_x`/`COLUMN_W` column, stacked vertically at the same `COLUMN_TOP + 20 + i * 30` row positions as today's text rows (draw `source.icon`).
    - Player 2 slot (line 201, currently `love.graphics.printf(_label_for(self.p2_device, self._sources), right_x, COLUMN_TOP + 60, COLUMN_W, "center")`): same treatment as Player 1, using `right_x` and `self.p2_device`.
  - Do not touch: the "Player 1"/"Player 2" header `printf`s (lines 181, 199), the "Ready!"/"press Confirm" status `printf`s (lines 184, 203), the "Devices" header `printf` (line 191), the bottom instructions line (lines 206-210), or any panel background draws (`PANEL_NORMAL`/`PANEL_SELECTED`) — these all stay exactly as-is.
  - Assumes Task A has completed and `assets/ui/icon_keyboard.png` / `assets/ui/icon_controller.png` exist on disk (needed for the real, non-headless game to load without erroring; the headless test stub in `lua/headless/stubs.lua` doesn't check file existence so tests can run even if Task A hasn't landed yet, but the real game would break) — no other ordering dependency; this task itself has no code dependency on Task A finishing.

- [x] Task C — `tests/test_controller_select_scene.lua` — Do after Task B. Add a new test block (place it near the existing "Test 1" source-discovery block at lines 63-94, since it's checking the same `on_enter()`-built `_sources` shape) asserting that every source built in `on_enter()` now carries a non-nil `icon` field:
  - With zero joysticks (`with_joysticks({}, function() ... end)`), build a scene, call `scene:on_enter()`, and assert `scene._sources[1].icon ~= nil` (the keyboard source's icon).
  - With one or two fake joysticks (`with_joysticks({ fake_stick() }, ...)` and/or `with_joysticks({ fake_stick(), fake_stick() }, ...)`), assert the corresponding gamepad source(s) (`scene._sources[2].icon`, and `scene._sources[3].icon` for the two-controller case) are also non-nil.
  - Follow this file's existing conventions: use the local `fake_stick()` and `with_joysticks()` helpers already defined at the top of the file (lines 17-36), end each assertion block with a `print("PASS: ...")` line describing what was checked, matching the style of the existing Test 1 blocks (lines 66-94).
  - Do not modify or remove any existing test blocks — this is a pure addition.
