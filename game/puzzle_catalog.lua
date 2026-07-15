local PuzzleCatalog = {}

local TIERS = {"easy", "med", "hard", "final_puzzle"}

local cached_list
local cached_by_tier

-- Scans assets/puzzles/<tier>/ for each hardcoded tier folder once, building
-- both the flat list and the per-tier table in a single pass. Memoized: the
-- scan runs at most once per process, regardless of which public function
-- (list() or list_by_tier()) triggers it first.
local function scan()
    if cached_list then
        return
    end

    local list = {}
    local by_tier = {}
    for _, tier in ipairs(TIERS) do
        local dir = "assets/puzzles/" .. tier
        local items = love.filesystem.getDirectoryItems(dir)
        local tier_list = {}
        for _, name in ipairs(items) do
            if name:sub(-4) == ".png" then
                local path = dir .. "/" .. name
                list[#list + 1] = path
                tier_list[#tier_list + 1] = path
            end
        end
        by_tier[tier] = tier_list
    end

    cached_list = list
    cached_by_tier = by_tier
end

-- Returns one flat array of "assets/puzzles/<tier>/<filename>" path strings
-- across all tiers combined. Memoized: the scan runs at most once per process.
function PuzzleCatalog.list()
    scan()
    return cached_list
end

-- Returns {easy = {...paths}, med = {...paths}, hard = {...paths}}, each an
-- array of "assets/puzzles/<tier>/<filename>" path strings for that tier
-- only. Memoized: shares the same underlying scan as list().
function PuzzleCatalog.list_by_tier()
    scan()
    return cached_by_tier
end

return PuzzleCatalog
