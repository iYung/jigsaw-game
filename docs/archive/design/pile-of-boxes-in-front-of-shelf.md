## Goal

Make the pile of boxes (`self.pile`, a `PuzzlePile` instance created in
`GameScene:on_enter()`, `game/scenes/game_scene.lua:182`) always draw visually
in front of — i.e. never occluded by — the completed-puzzles shelf (the
`shelved` draw-ables in `self.completed_puzzles`, built by
`GameScene:_shelve()` at `game/scenes/game_scene.lua:354-394` and restored in
the save-data branch of `on_enter()` at lines 114-137), regardless of how many
puzzles have been completed or the order in which entities were added to the
scene this session.

## Affected files

- `game/scenes/game_scene.lua`
  - Line 136: `self.drawer:add(shelved, C.PRIORITY_PIECE)` — shelved entry restored from save data
  - Line 183: `self.drawer:add(self.pile, C.PRIORITY_PIECE)` — the pile
  - Line 390: `self.drawer:add(shelved, C.PRIORITY_PIECE)` — shelved entry created live via `:_shelve()`
- `game/constants.lua` — where `PRIORITY_PIECE = 5` (line 5) and `PRIORITY_BOX_FLYING = 20` (line 9) are defined; a new priority constant would live here
- `lua/core/drawer.lua` — the layering mechanism itself (context only; not expected to change)

## Root cause

The scene uses a flat priority-sort `Drawer` (`lua/core/drawer.lua`), not a
y-sort/depth system. `Drawer:add`/`:set_priority` do `table.sort(self.layers,
function(a, b) return a.priority < b.priority end)` (drawer.lua:12, 28) — a
strict `<` comparator, which for **equal priorities never guarantees relative
order**, and Lua's `table.sort` is not a stable sort.

Right now both the pile and every shelved/completed-puzzle entry are added at
the exact same priority, `C.PRIORITY_PIECE = 5`:
- pile: `game_scene.lua:183`
- each shelved entry: `game_scene.lua:136` (restored from save) and `:390` (shelved live via `_shelve()`)

Grounded jigsaw pieces and non-flying `JigsawBox` instances also share this
same priority value. Because the pile and shelf entries tie at priority 5,
whichever of the two ends up later in the sorted `layers` array after any
given `table.sort` call is unspecified — it can flip depending on insertion
order and how many other priority-5 entries (pieces, boxes, other shelved
puzzles) have been added/removed/re-sorted in between. That non-determinism is
why the pile isn't reliably drawn in front of the shelf: they're tied, not
ordered.

Spatially this is real, not theoretical: shelved images are positioned in
`_shelve()` at `y = shelf_row_bottom - height`, which only ever grows more
negative (rows wrap upward via `shelf_row_bottom = shelf_row_bottom -
shelf_row_max_height - C.SLOT`, line 363) and whose `x` cycles across the
full world width (0 to `world_w`, wrapping per row). The pile's stack of small
boxes is drawn at `self.sprite.y - (i - 1) * C.PILE_BOX_STACK_OFFSET`
(`puzzle_pile.lua:65`), i.e. it also grows upward on screen as more puzzles
remain in the pool. With enough completed puzzles, a shelf row's `x` can land
under the pile's fixed column (`WORLD_W / 2`, set at `game_scene.lua:182`),
so the two can genuinely overlap on screen — and today, which one wins is a
coin flip.

## What changes

Introduce a strict priority separation between the pile and the shelf so
their relative order is deterministic instead of tied. Concretely: add one
new named priority constant in `game/constants.lua` and use it for one side
of this pair, so the pile's effective priority is always numerically greater
than every shelved entry's:

- Shelved entries stop using `C.PRIORITY_PIECE` and instead use a new,
  lower constant (e.g. `C.PRIORITY_SHELF`, given a value below `5`), applied
  at both call sites that add a shelved draw-able (`game_scene.lua:136` and
  `:390` — both must change together, since the same shape of entry is built
  in both places).
- The pile keeps its existing `C.PRIORITY_PIECE` priority, unchanged.

This is a targeted fix: only the shelf's priority number moves. It does not
touch the y-sort question (there isn't one), the shelf's row-wrapping layout
math in `_shelve()`, the pile's own draw logic (`puzzle_pile.lua:58-69`), or
any other entity's priority (`floor`=0, `background`=-1, `player`=10,
`PRIORITY_BOX_FLYING`=20 all stay as-is).

## What stays the same

- The `Drawer` mechanism itself (`lua/core/drawer.lua`) — still a flat
  priority-sorted list, no y-sort/depth-sort system introduced.
- Grounded `JigsawPiece`s and non-flying `JigsawBox`es keep `C.PRIORITY_PIECE`
  — their ordering relative to each other and to the pile is untouched by
  this change (the pile and boxes/pieces are not the subject of this
  request, and boxes are already prevented from spawning on the pile's grid
  cell — see the occupancy check in `GameScene:_spawn_box`, lines 196-205 —
  so no new overlap is introduced there).
- `PRIORITY_BOX_FLYING = 20` and its use for the pile-to-slot flight
  animation (`game_scene.lua:212`, `:234`).
- The shelf's row/column layout math in `_shelve()` — only its draw
  priority constant changes, not where it's positioned in world space.
- Save/load format (`to_save()` / the save-data restore branch) — priority is
  a runtime-only `Drawer` concept, not part of saved data.

## Decisions

1. **Shelf is demoted, pile is unchanged.** Add `C.PRIORITY_SHELF = 4` and use
   it for shelved entries (`game_scene.lua:136` and `:390`). The pile keeps
   `C.PRIORITY_PIECE = 5`, unchanged.
2. **Constant style matches the existing convention.** `C.PRIORITY_SHELF` is a
   bare integer constant with a one-line explanatory comment, same as
   `PRIORITY_PIECE`/`PRIORITY_BOX_FLYING`. No new layer-naming convention is
   introduced.
