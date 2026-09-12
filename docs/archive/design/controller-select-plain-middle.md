## Goal
Remove the colored (selected/highlighted) panel from the middle "Devices" column on the controller select screen. All three columns should use the same plain panel style.

## Affected files
- `game/scenes/controller_select_scene.lua`

## What changes
- The middle column's `love.graphics.draw` call (line 215) uses `PANEL_SELECTED` — change it to `PANEL_NORMAL`.
- The `PANEL_SELECTED` image asset is no longer referenced in this file. If it's only used here, the `local PANEL_SELECTED = ...` load at the top can also be removed.

## What stays the same
- Layout, logic, labels, and icon rendering are unchanged.
- P1 and P2 columns remain identical to their current state.
- `PANEL_SELECTED` asset file itself stays on disk (may be used elsewhere).

## Open questions
None — the change is unambiguous.
