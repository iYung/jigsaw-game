local PuzzleCatalog = {}

local TIERS = {"easy", "med", "hard"}

local cached_list

-- Scans assets/puzzles/<tier>/ for each hardcoded tier folder and returns one
-- flat array of "assets/puzzles/<tier>/<filename>" path strings across all
-- tiers combined. Memoized: the scan runs at most once per process.
function PuzzleCatalog.list()
    if cached_list then
        return cached_list
    end

    local list = {}
    for _, tier in ipairs(TIERS) do
        local dir = "assets/puzzles/" .. tier
        local items = love.filesystem.getDirectoryItems(dir)
        for _, name in ipairs(items) do
            if name:sub(-4) == ".png" then
                list[#list + 1] = dir .. "/" .. name
            end
        end
    end

    cached_list = list
    return cached_list
end

return PuzzleCatalog
