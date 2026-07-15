# Rotate Sound Effect

## Goal

Play a sound effect whenever a player rotates a held jigsaw piece, matching the
existing feedback pattern already used for pick-up and put-down actions.

## Affected files

- `main.lua` — `SFX_MANIFEST.sfx` list (line ~39-46)
- `game/player.lua` — rotate input handling (line ~203-207)
- `assets/sounds/rotate.wav` — new asset (temporary placeholder, see below)
- `assets/sounds/attribution.txt` — note the placeholder source

## What changes

- Add `"rotate"` to the `sfx` array in `SFX_MANIFEST` (`main.lua`), so it's
  preloaded via `Sound.load` at startup alongside the other SFX.
- In `Player:update` (`game/player.lua:203-207`), call `Sound.play("rotate")`
  immediately after `self.held_piece:rotate()` is invoked, only when
  `self.held_piece` is not nil (i.e. only when an actual rotate happens, not
  on every keypress if nothing is held).
- Add `assets/sounds/rotate.wav` as a **temporary placeholder**: a copy of an
  existing SFX file (`menu_navigate.wav`) renamed to `rotate.wav`, so the
  feature is fully wired end-to-end. This is a stand-in until a proper rotate
  sound is sourced and swapped in later — noted in `attribution.txt`.

## What stays the same

- `Sound.lua` module itself (`Sound.load` / `Sound.play`) — no changes needed,
  it's a generic manifest-driven loader.
- Rotation logic in `JigsawPiece:rotate()` (`game/jigsaw_piece.lua:26-29`) —
  untouched, purely visual/state rotation.
- Input bindings for `rotate_piece` (`"r"` key / `"x"` gamepad) — untouched.
- SFX volume control in Settings — the new sound automatically inherits it
  since it goes through the same `Sound.play` path.

## Open questions

None outstanding — asset sourcing was resolved: reuse an existing SFX file as
a temporary placeholder for `rotate.wav` rather than blocking on sourcing a
new asset from freesound.org.
