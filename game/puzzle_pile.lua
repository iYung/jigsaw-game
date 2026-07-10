local Sprite = require("lua/core/sprite")
local C = require("game/constants")
local GameState = require("game/game_state")
local PuzzleCatalog = require("game/puzzle_catalog")
local Shader = require("lua/core/shader")

-- Visual-only, no interact() -- same role game/door.lua used to play as a
-- grid-aligned world object marking where new boxes fly in from, but drawn
-- as a stack of small boxes (one per puzzle still left to see this session)
-- instead of one flat tile.
local PuzzlePile = {}
PuzzlePile.__index = PuzzlePile

-- Same rounded-corner mask used by jigsaw pieces (jigsaw_piece.lua) and the
-- trophy shelf, so stacked boxes visually match the real box/piece style.
-- Loaded once at module scope, same lifetime as piece_shader in
-- jigsaw_piece.lua; "size" is constant since every stacked box is drawn at
-- PILE_BOX_SIZE, and "uv_rect" is the full unit square since every box
-- draws the same 1x1 pixel image below, not a sub-quad of a shared atlas.
local box_shader = Shader.load("assets/shaders/rounded_corners.frag")
box_shader:send("size", {C.PILE_BOX_SIZE, C.PILE_BOX_SIZE})
box_shader:send("uv_rect", {0, 0, 1, 1})

-- A solid-color love.graphics.rectangle() draw does not vary its fragment
-- texture_coords across the shape the way an actual textured image draw
-- does, so the corner shader (which derives pixel_pos from texture_coords)
-- would see a constant UV for every fragment and mask out the whole box.
-- Every other user of this shader (pieces, shelf) draws a real image for
-- exactly this reason -- so stacked boxes draw a scaled 1x1 white pixel
-- image instead of a raw rectangle fill, tinted by setColor same as before.
local pixel_data = love.image.newImageData(1, 1)
pixel_data:setPixel(0, 0, 1, 1, 1, 1)
local white_pixel = love.graphics.newImage(pixel_data)

function PuzzlePile.new(x, y)
    local self = setmetatable({}, PuzzlePile)
    -- Base footprint sprite: same role the door's sprite played for
    -- occupancy checks in game_scene.lua's _spawn_box (blocks this grid
    -- cell from being picked as a new box's resting cell). Invisible --
    -- the stack itself is drawn in :draw(), not via Sprite:draw().
    self.sprite = Sprite.new(x, y, C.SLOT, C.SLOT)
    self.sprite.visible = false
    return self
end

-- Fully derived from GameState + PuzzleCatalog on every call -- no
-- stored/cached count on the pile itself, so it can never drift out of
-- sync with the pool JigsawBox.new actually draws from. Updates for free
-- the instant GameState:mark_seen runs inside JigsawBox.new, whether
-- that's from the initial on_enter box or a button-triggered spawn.
function PuzzlePile:count()
    return GameState:remaining_puzzle_count(PuzzleCatalog.list_by_tier())
end

-- World position the top box in the stack currently occupies -- this is
-- where a newly-spawned box's flight animation should originate from.
-- Floors n at 1 so this always returns a sane point even at count() == 0
-- (defensive only -- _spawn_box never actually reaches the animation-origin
-- call when the pool is empty, since JigsawBox.new returns nil first).
function PuzzlePile:top_position()
    local n = math.max(self:count(), 1)
    return {
        x = self.sprite.x,
        y = self.sprite.y - (n - 1) * C.PILE_BOX_STACK_OFFSET,
    }
end

function PuzzlePile:draw()
    local n = self:count()
    -- Same orange JigsawBox uses for its own sprite (jigsaw_box.lua:33), so
    -- the stacked boxes read visually as "boxes," just smaller and stacked.
    love.graphics.setColor(1, 0.75, 0.2, 1)
    love.graphics.setShader(box_shader)
    local inset = (C.SLOT - C.PILE_BOX_SIZE) / 2
    for i = 1, n do
        local by = self.sprite.y - (i - 1) * C.PILE_BOX_STACK_OFFSET
        love.graphics.draw(white_pixel, self.sprite.x + inset, by + inset, 0, C.PILE_BOX_SIZE, C.PILE_BOX_SIZE)
    end
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
end

return PuzzlePile
