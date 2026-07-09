## Box Spawn Door Animation Checklist

Dependency groups (see notes after each task):
- **Group 1 (parallel, no deps on each other):** Task A, Task B
- **Group 2 (parallel with each other, but each depends on Group 1 items noted below):** Task C, Task E
- **Group 3 (sequential, after Group 2 fully lands):** Task D

- [x] Task A — `game/constants.lua` — Add `BOX_FLY_DURATION = 0.4` to the constants table, alongside the existing `PIECE_FADE_DURATION = 0.5` entry (currently the last field before the closing `}` at line 11). Result:
  ```lua
  return {
      U = U,
      SLOT = SLOT,
      PRIORITY_PIECE = PRIORITY_PIECE,
      PIECE_FADE_DURATION = 0.5,
      BOX_FLY_DURATION = 0.4,
  }
  ```
  No dependencies — can start immediately, independent of every other task. **Task C depends on this task being done first** (it references `C.BOX_FLY_DURATION`), so land this one before or alongside Task C, not after.

- [x] Task B — `game/door.lua` (new file) — Create a visual-only `Door` entity modeled on `game/spawn_button.lua` but with no `interact()`, no `centre()` needed for interaction (it's never queried by `player:update()`), and no state. Exact contents per the design doc:
  ```lua
  local Sprite = require("lua/core/sprite")
  local C = require("game/constants")

  local Door = {}
  Door.__index = Door

  function Door.new(x, y)
      local self = setmetatable({}, Door)
      self.sprite = Sprite.new(x, y, C.SLOT, C.SLOT)
      self.sprite.color = {0.3, 0.35, 0.85, 1}  -- distinct blue-violet, vs. red button / orange box
      return self
  end

  function Door:draw()
      self.sprite:draw()
  end

  return Door
  ```
  No dependencies — can start immediately, independent of every other task. **Task D depends on this file existing** (it instantiates `Door.new` and reads `self.door.sprite.x/y`).

- [x] Task C — `game/jigsaw_box.lua` — Add flight-animation support to `JigsawBox`:
  1. Change `JigsawBox.new(x, y, world_w, world_h)` (line 10) to `JigsawBox.new(x, y, world_w, world_h, spawn_from)`, an optional 5th param.
  2. In the constructor body, after `self.state = "waiting"` (line 34) and after `self.world_w`/`self.world_h` are set (lines 36-37), add: always set `self.target_x, self.target_y = x, y` (so both flying and non-flying boxes expose a consistent "final resting cell", per the design doc). Then, if `spawn_from` is present: set `self.state = "flying"`, `self.spawn_x, self.spawn_y = spawn_from.x, spawn_from.y`, `self.sprite.x, self.sprite.y = self.spawn_x, self.spawn_y`, `self.fly_timer = C.BOX_FLY_DURATION`. If `spawn_from` is absent, behavior is unchanged — box stays in `"waiting"` at `(x, y)` (the sprite is already constructed at `x, y` via `Sprite.new(x, y, ...)` on line 32, so nothing else to do in that branch).
  3. In `JigsawBox:update(dt, pieces)` (line 77), add a `"flying"` branch **before** the existing `if self.state ~= "ejecting" then return end` guard, so it doesn't get skipped:
     ```lua
     function JigsawBox:update(dt, pieces)
         if self.state == "flying" then
             self.fly_timer = self.fly_timer - dt
             local t = 1 - math.max(0, self.fly_timer) / C.BOX_FLY_DURATION
             local eased = 1 - (1 - t) ^ 3  -- ease-out cubic
             self.sprite.x = self.spawn_x + (self.target_x - self.spawn_x) * eased
             self.sprite.y = self.spawn_y + (self.target_y - self.spawn_y) * eased
             if self.fly_timer <= 0 then
                 self.sprite.x, self.sprite.y = self.target_x, self.target_y
                 self.state = "waiting"
             end
             return
         end
         if self.state ~= "ejecting" then return end
         self.spawn_timer = self.spawn_timer - dt
         if self.spawn_timer <= 0 then
             self:_eject_next(pieces)
             self.spawn_timer = 0.3
         end
     end
     ```
  4. Leave `interact()`, `_eject_next()`, `centre()`, `draw()`, and the `"waiting" → "ejecting" → "done"` machinery untouched.

  **Depends on Task A** (`C.BOX_FLY_DURATION` must exist in `game/constants.lua` before this file references it) — do not start until Task A is done. Independent of Task B. **Task D depends on this task's new `JigsawBox.new` signature and `target_x`/`target_y` fields** — do not start Task D until this is done. **Task E (tests) also depends on this task being done.**

- [x] Task D — `game/scenes/game_scene.lua` — Wire the door and flight animation into the scene. Four changes, all in this file:
  1. **Button relocation** (line 78): change `self.spawn_button = SpawnButton.new(WORLD_W / 2, 0, function() self:_spawn_box() end)` to `self.spawn_button = SpawnButton.new(0, 0, function() self:_spawn_box() end)`.
  2. **Door instantiation** in `on_enter`, right after the spawn button setup (after line 79's `self.drawer:add(self.spawn_button, C.PRIORITY_PIECE)`): add
     ```lua
     self.door = Door.new(WORLD_W / 2, 0)
     self.drawer:add(self.door, C.PRIORITY_PIECE)
     ```
     and add `local Door = require("game/door")` to the require block at the top of the file (near line 7, alongside `local SpawnButton = require("game/spawn_button")`). Note: the design doc's sketch shows `Door.new(WORLD_W / 2, 0, function() ... end)` with a 3rd arg, but `Door.new(x, y)` per Task B only takes 2 params and ignores extras — call it with just `(WORLD_W / 2, 0)` to match the actual `Door.new` signature (Door has no `on_press`/`interact`, per "no interact(), no state" in the design doc).
  3. **`_spawn_box()` occupancy check fix + door avoidance** (lines 92-101): change the box-comparison condition on line 94 from `if box.sprite.x == cx and box.sprite.y == cy then` to `if box.target_x == cx and box.target_y == cy then` (compares against the box's destination cell, not its possibly-mid-flight current position). Then add a door-avoidance check alongside the existing button-avoidance check (line 99), mirroring its structure:
     ```lua
     if not occupied and self.spawn_button.sprite.x == cx and self.spawn_button.sprite.y == cy then
         occupied = true
     end
     if not occupied and self.door.sprite.x == cx and self.door.sprite.y == cy then
         occupied = true
     end
     ```
  4. **Pass `spawn_from` into `JigsawBox.new`** (line 104): change `local box = JigsawBox.new(cx, cy, self.world_w, self.world_h)` to
     ```lua
     local box = JigsawBox.new(cx, cy, self.world_w, self.world_h,
         { x = self.door.sprite.x, y = self.door.sprite.y })
     ```
     Leave the `on_enter` initial-box construction at line 60 (`JigsawBox.new(5 * C.SLOT, 3 * C.SLOT, self.world_w, self.world_h)`) **unchanged** — it must keep omitting `spawn_from` so it still spawns directly in `"waiting"` with no flight, per the design doc.

  **Do not start until Task B and Task C are both complete** — this task instantiates `Door.new` (Task B) and calls the new 5-arg `JigsawBox.new` signature while relying on `target_x`/`target_y` existing on every box (Task C). Running this before either lands will not work against the real files.

- [x] Task E — `tests/test_jigsaw.lua` — Extend test coverage for the new flight behavior. This file already has an extensive `JigsawBox` section (starting around line 305) using helpers `new_easy_box(...)` and direct `JigsawBox.new(x, y, world_w, world_h)` calls, and already asserts `box.state == "waiting"` immediately after construction with no `spawn_from` arg (e.g. line 345) — confirm those existing assertions still pass unmodified (they should, since `spawn_from` is optional and defaults to today's behavior), then add new `do ... end` blocks near the existing "JigsawBox.new" tests (after line ~360) covering:
  1. `JigsawBox.new(x, y, world_w, world_h, {x = sx, y = sy})` starts in `state == "flying"`, with `sprite.x == sx`, `sprite.y == sy`, `target_x == x`, `target_y == y`, and `fly_timer == C.BOX_FLY_DURATION`.
  2. A box constructed **without** `spawn_from` still has `target_x == x` and `target_y == y` set (per the design doc: "`self.target_x`/`self.target_y` are always set ... so callers can consistently ask 'where will/does this box end up' regardless of flight state").
  3. Calling `box:update(dt, pieces)` on a flying box with a small `dt` moves `sprite.x`/`sprite.y` partway from `spawn_x/spawn_y` toward `target_x/target_y` (state remains `"flying"`), and calling it with `dt >= C.BOX_FLY_DURATION` (or repeated updates summing to that) lands the sprite exactly on `target_x`/`target_y` and flips `state` to `"waiting"`.
  4. A flying box does not get ejected/interact-able: `box:interact()` while `state == "flying"` should not transition state (the existing `interact()` only checks `if self.state == "waiting"`, so this is a regression-guard test, not a code change).

  **Depends on Task C** (targets the new `spawn_from`/`"flying"`/`target_x`/`target_y` fields added there) — do not start until Task C is done. Independent of Task B and Task D; can run in parallel with Task D once Task C has landed.
