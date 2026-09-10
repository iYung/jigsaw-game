-- test_jigsaw_box.lua
-- Unit test for game/jigsaw_box.lua's JigsawBox:_eject_next: verifies it
-- plays the "poof" sound effect every time a piece is ejected from a box
-- (docs/checklists/poof-sound-on-piece-emerge.md Task E). Spies on Sound.play
-- by monkey-patching the shared lua/core/sound module singleton -- require()
-- caches modules, so this is the same table jigsaw_box.lua's own
-- `local Sound = require(...)` holds a reference to. Mirrors the
-- spy-and-restore pattern from tests/test_player.lua's Test 4.
--
-- _eject_next is driven directly against a minimal fake box (rather than a
-- full JigsawBox.new(...)) to avoid pulling in PuzzleCatalog/GameState/image
-- loading -- per the checklist, only the fields _eject_next actually reads
-- (pieces_to_spawn, sprite, world_w, world_h, spawned) are populated.

local JigsawBox = require("game/jigsaw_box")
local Sound = require("lua/core/sound")

local function with_sound_play_spy(fn)
    local original = Sound.play
    local played = {}
    Sound.play = function(name) played[#played + 1] = name end
    local ok, err = pcall(fn, played)
    Sound.play = original
    if not ok then
        error(err, 0)
    end
end

local function played_contains(played, name)
    for _, n in ipairs(played) do
        if n == name then return true end
    end
    return false
end

-- Builds a minimal fake JigsawBox with `count` pending piece specs, wired up
-- with just the fields JigsawBox:_eject_next reads.
local function fake_box(count)
    local fake = setmetatable({}, JigsawBox)
    fake.pieces_to_spawn = {}
    for i = 1, count do
        fake.pieces_to_spawn[i] = { row = 0, col = i - 1, path = "fake.png" }
    end
    fake.sprite = { x = 0, y = 0 }
    fake.world_w = 1280
    fake.world_h = 720
    fake.spawned = {}
    return fake
end

-- Test: a single _eject_next call plays "poof" and moves a piece into both
-- `pieces` and `self.spawned`.
with_sound_play_spy(function(played)
    local box = fake_box(1)
    local pieces = {}

    JigsawBox._eject_next(box, pieces)

    assert(#pieces == 1, "_eject_next should push one piece into `pieces`")
    assert(#box.spawned == 1, "_eject_next should push one piece into self.spawned")
    assert(played_contains(played, "poof"),
        "_eject_next: ejecting a piece should call Sound.play('poof')")
end)
print("PASS: JigsawBox:_eject_next plays 'poof' sound when a piece is ejected")

-- Test: "poof" plays on every eject, not just the first.
with_sound_play_spy(function(played)
    local box = fake_box(2)
    local pieces = {}

    JigsawBox._eject_next(box, pieces)
    JigsawBox._eject_next(box, pieces)

    local poof_count = 0
    for _, n in ipairs(played) do
        if n == "poof" then poof_count = poof_count + 1 end
    end
    assert(poof_count == 2, "_eject_next: each eject should call Sound.play('poof') once, got " .. poof_count)
end)
print("PASS: JigsawBox:_eject_next plays 'poof' sound on every eject")

print("ALL TESTS PASSED")
