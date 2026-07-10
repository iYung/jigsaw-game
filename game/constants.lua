local U = 32
local SLOT = 2 * U

-- Drawer priority for grounded jigsaw pieces and the jigsaw box.
local PRIORITY_PIECE = 5

-- World-space size and offset of the scrolling background image, sized to
-- cover the camera's worst-case overreach past the floor edges (1280 + 2*608
-- x 640 + 2*328), top-left positioned so the floor rect sits centered inside it.
local BG_W = 2496
local BG_H = 1296
local BG_OFFSET_X = -608
local BG_OFFSET_Y = -328

return {
    U = U,
    SLOT = SLOT,
    PRIORITY_PIECE = PRIORITY_PIECE,
    BG_W = BG_W,
    BG_H = BG_H,
    BG_OFFSET_X = BG_OFFSET_X,
    BG_OFFSET_Y = BG_OFFSET_Y,
    PIECE_FADE_DURATION = 0.5,
    BOX_FLY_DURATION = 1.0,
    BOX_FLY_ARC_HEIGHT = 1.5 * SLOT,
    PILE_BOX_SIZE = SLOT,
    PILE_BOX_STACK_OFFSET = SLOT,
}
