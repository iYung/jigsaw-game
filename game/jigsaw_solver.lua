local C = require("game/constants")

local M = {}

function M.rotate_cell(row, col, k)
    k = k % 4
    if k == 0 then
        return col, row
    elseif k == 1 then
        return -row, col
    elseif k == 2 then
        return -col, -row
    else
        return row, -col
    end
end

function M.is_assembled(pieces, expected_count)
    if #pieces ~= expected_count then return false end

    local k = pieces[1].rotation_step
    local ox, oy
    for i, piece in ipairs(pieces) do
        if piece.rotation_step ~= k then return false end

        local gx, gy = M.rotate_cell(piece.row, piece.col, k)
        local px = piece.sprite.x / C.SLOT - gx
        local py = piece.sprite.y / C.SLOT - gy
        if i == 1 then
            ox, oy = px, py
        elseif px ~= ox or py ~= oy then
            return false
        end
    end

    return true
end

return M
