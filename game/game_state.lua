-- In-memory, per-tier "seen" set. Session-only: lives only for the
-- process's lifetime, same lifetime pattern as PuzzleCatalog's cached_list.
-- Nothing here touches disk (no to_save/from_save, unlike ../wip's
-- GameState -- persistence is explicitly out of scope).
local GameState = {}
GameState.__index = GameState

function GameState.new()
    local self = setmetatable({}, GameState)
    self.seen = {easy = {}, med = {}, hard = {}}
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

-- Clears all seen-state back to empty. Nothing in game-runtime code calls
-- this; it exists purely so tests can isolate scenarios that would
-- otherwise share this process-lifetime instance.
function GameState:reset()
    self.seen = {easy = {}, med = {}, hard = {}}
end

-- Module returns a singleton instance (not the class table) so existing
-- callers keep a single shared state object for the process lifetime, same
-- as before, just shaped like a class instance instead of free functions.
return GameState.new()
