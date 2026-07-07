local C = require("game/constants")

local M = {}

function M.is_assembled(pieces, expected_count)
    if #pieces ~= expected_count then return false end

    local ox, oy
    for i, piece in ipairs(pieces) do
        if piece.rotation_step ~= 0 then return false end

        local px = piece.sprite.x / C.SLOT - piece.col
        local py = piece.sprite.y / C.SLOT - piece.row
        if i == 1 then
            ox, oy = px, py
        elseif px ~= ox or py ~= oy then
            return false
        end
    end

    return true
end

return M
