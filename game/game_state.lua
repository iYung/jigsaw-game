-- In-memory, per-tier "seen" set. Session-only: lives only for the
-- process's lifetime, same lifetime pattern as PuzzleCatalog's cached_list.
-- to_save()/apply_save() below exist for the save/load feature, mirroring
-- ../wip's GameState pattern -- everything else about this module (a
-- session-lifetime singleton, no other persistence) stays the same.
local GameState = {}
GameState.__index = GameState

-- Cap on simultaneously active puzzles in the world; see can_start_puzzle.
GameState.MAX_ACTIVE_PUZZLES = 3

-- Number of a tier's puzzles that must be solved before the next tier
-- unlocks; see is_tier_unlocked.
GameState.UNLOCK_THRESHOLD = 3

function GameState.new()
    local self = setmetatable({}, GameState)
    self.seen = {easy = {}, med = {}, hard = {}}
    self.solved_count = 0
    self.active_count = 0
    self.solved_by_tier = {easy = 0, med = 0, hard = 0}
    return self
end

-- Marks `path` as seen under `tier`.
function GameState:mark_seen(tier, path)
    self.seen[tier][path] = true
end

-- Returns true/false for whether `path` has been marked seen under `tier`.
function GameState:is_seen(tier, path)
    return self.seen[tier][path] == true
end

-- Given the tier's full path array (e.g. one value from
-- PuzzleCatalog.list_by_tier()), returns a new array containing only the
-- entries not yet marked seen for that tier. Does not mutate the input.
function GameState:unseen_paths(tier, all_paths_for_tier)
    local result = {}
    for _, path in ipairs(all_paths_for_tier) do
        if not self:is_seen(tier, path) then
            result[#result + 1] = path
        end
    end
    return result
end

-- Returns true iff every path in all_paths_for_tier has been seen for that
-- tier. An empty all_paths_for_tier is vacuously exhausted.
function GameState:is_tier_exhausted(tier, all_paths_for_tier)
    return #self:unseen_paths(tier, all_paths_for_tier) == 0
end

-- Given a table shaped like PuzzleCatalog.list_by_tier() (e.g.
-- {easy = {...paths}, med = {...paths}, hard = {...paths}}), returns the
-- count of puzzle images not yet spawned this session, summed across every
-- tier in by_tier -- including tiers that are currently locked. This
-- deliberately does not check is_tier_unlocked: a locked tier's paths are
-- never marked seen while locked, since mark_seen is only called for paths
-- drawn from an unlocked tier's pool (see game/jigsaw_box.lua), so counting
-- a locked tier's unseen paths here causes no double-counting and no
-- discontinuity in the total when that tier later unlocks.
function GameState:remaining_puzzle_count(by_tier)
    local total = 0
    for tier, paths in pairs(by_tier) do
        total = total + #self:unseen_paths(tier, paths)
    end
    return total
end

-- Called once per box spawned into the world (opened or not); caller is
-- responsible for calling this exactly once per spawn.
function GameState:puzzle_started()
    self.active_count = self.active_count + 1
end

-- Called exactly once per puzzle, the instant its arrangement is first
-- detected as correct (not when its pieces finish fading).
function GameState:puzzle_solved(tier)
    self.solved_count = self.solved_count + 1
    self.active_count = self.active_count - 1
    self.solved_by_tier[tier] = self.solved_by_tier[tier] + 1
end

-- Returns true iff another puzzle can be started without exceeding the cap.
function GameState:can_start_puzzle()
    return self.active_count < GameState.MAX_ACTIVE_PUZZLES
end

-- Returns true iff `tier`'s puzzles are available for selection. "easy" is
-- always unlocked; "med" unlocks once UNLOCK_THRESHOLD "easy" puzzles have
-- been solved; "hard" unlocks once UNLOCK_THRESHOLD "med" puzzles have.
function GameState:is_tier_unlocked(tier)
    if tier == "easy" then
        return true
    elseif tier == "med" then
        return self.solved_by_tier.easy >= GameState.UNLOCK_THRESHOLD
    elseif tier == "hard" then
        return self.solved_by_tier.med >= GameState.UNLOCK_THRESHOLD
    end
end

-- Clears all seen-state back to empty. Nothing in game-runtime code calls
-- this; it exists purely so tests can isolate scenarios that would
-- otherwise share this process-lifetime instance.
function GameState:reset()
    self.seen = {easy = {}, med = {}, hard = {}}
    self.solved_count = 0
    self.active_count = 0
    self.solved_by_tier = {easy = 0, med = 0, hard = 0}
end

-- Returns a plain snapshot table of this singleton's persistable fields,
-- suitable for handing to lua/core/save.lua's serializer. Shallow: seen/
-- solved_by_tier are the same table references as the live singleton, not
-- deep copies (the serializer is what produces an independent, disk-safe
-- copy).
function GameState:to_save()
    return {
        version = 1,
        seen = self.seen,
        solved_count = self.solved_count,
        active_count = self.active_count,
        solved_by_tier = self.solved_by_tier,
    }
end

-- Restores previously-saved fields onto this singleton, mutating it in
-- place (assigning into self.seen etc.) rather than replacing self itself,
-- since every other module holds a reference to this exact singleton table
-- via require("game/game_state") -- replacing self would leave those
-- references stale. Falls back to a fresh reset() if data is missing or
-- from an incompatible version.
function GameState:apply_save(data)
    if not data or data.version ~= 1 then
        self:reset()
        return
    end
    self.seen = data.seen
    self.solved_count = data.solved_count
    self.active_count = data.active_count
    self.solved_by_tier = data.solved_by_tier
end

-- Module returns a singleton instance (not the class table) so existing
-- callers keep a single shared state object for the process lifetime, same
-- as before, just shaped like a class instance instead of free functions.
return GameState.new()
