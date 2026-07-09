local U = 32
local SLOT = 2 * U

-- Drawer priority for grounded jigsaw pieces and the jigsaw box.
local PRIORITY_PIECE = 5

return {
    U = U,
    SLOT = SLOT,
    PRIORITY_PIECE = PRIORITY_PIECE,
    PIECE_FADE_DURATION = 0.5,
    BOX_FLY_DURATION = 1.0,
    BOX_FLY_ARC_HEIGHT = 1.5 * SLOT,
}
