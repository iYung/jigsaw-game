-- test_anim_sprite.lua
-- Unit tests for lua/core/anim_sprite.lua AnimatedSprite frame cycling.
-- Uses a fake image and spies on love.graphics.draw to inspect quad viewports.

local AnimatedSprite = require("lua/core/anim_sprite")

-- Fake image: 256×64 (4×64px frames)
local function fake_image(w, h)
    return {
        getWidth  = function() return w end,
        getHeight = function() return h end,
    }
end

-- Spy on love.graphics.newQuad to capture the x offset of each quad created.
local captured_quads = {}
local original_newQuad = love.graphics.newQuad
local function with_quad_spy(fn)
    captured_quads = {}
    love.graphics.newQuad = function(x, y, w, h, iw, ih)
        captured_quads[#captured_quads + 1] = { x = x, y = y, w = w, h = h }
        return original_newQuad(x, y, w, h, iw, ih)
    end
    local ok, err = pcall(fn)
    love.graphics.newQuad = original_newQuad
    if not ok then error(err, 0) end
end

-- Spy on love.graphics.draw to confirm it was called.
local draw_calls = 0
local original_draw = love.graphics.draw
local function with_draw_spy(fn)
    draw_calls = 0
    love.graphics.draw = function(...) draw_calls = draw_calls + 1 end
    local ok, err = pcall(fn)
    love.graphics.draw = original_draw
    if not ok then error(err, 0) end
end

-- Test 1: starts on frame 1
do
    local img = fake_image(256, 64)
    local s = AnimatedSprite.new(0, 0, 64, 64, img, 4, 8)
    assert(s.frame == 1, "should start on frame 1")
end
print("PASS: AnimatedSprite starts on frame 1")

-- Test 2: frame does not advance before enough time elapsed (fps=8 → 0.125s per frame)
do
    local img = fake_image(256, 64)
    local s = AnimatedSprite.new(0, 0, 64, 64, img, 4, 8)
    s:update(0.1)  -- less than 0.125s
    assert(s.frame == 1, "frame must not advance before 1/fps seconds")
end
print("PASS: frame does not advance before 1/fps seconds")

-- Test 3: frame advances after exactly 1/fps seconds
do
    local img = fake_image(256, 64)
    local s = AnimatedSprite.new(0, 0, 64, 64, img, 4, 8)
    s:update(0.125)
    assert(s.frame == 2, "frame should advance to 2 after 1/fps seconds")
end
print("PASS: frame advances to 2 after 1/fps seconds")

-- Test 4: multiple frames advance correctly with accumulated time
do
    local img = fake_image(256, 64)
    local s = AnimatedSprite.new(0, 0, 64, 64, img, 4, 8)
    s:update(0.375)  -- 3 × 0.125s
    assert(s.frame == 4, "frame should be 4 after 3 × 1/fps seconds")
end
print("PASS: frame advances by 3 after 3 × 1/fps seconds")

-- Test 5: frame wraps from 4 back to 1
do
    local img = fake_image(256, 64)
    local s = AnimatedSprite.new(0, 0, 64, 64, img, 4, 8)
    s:update(0.5)  -- 4 × 0.125s → wraps back to 1
    assert(s.frame == 1, "frame should wrap back to 1 after all frames elapsed")
end
print("PASS: frame wraps back to 1 after full cycle")

-- Test 6: draw uses the correct quad x-offset for the current frame
do
    local img = fake_image(256, 64)
    local s = AnimatedSprite.new(0, 0, 64, 64, img, 4, 8)
    s:update(0.125)  -- now on frame 2
    with_quad_spy(function()
        with_draw_spy(function()
            s:draw()
        end)
    end)
    assert(#captured_quads == 1, "draw should create exactly one quad")
    assert(captured_quads[1].x == 64, "frame 2 quad x-offset should be 64")
    assert(draw_calls == 1, "draw should call love.graphics.draw once")
end
print("PASS: draw uses correct quad x-offset for the current frame")

-- Test 7: draw is skipped when visible = false
do
    local img = fake_image(256, 64)
    local s = AnimatedSprite.new(0, 0, 64, 64, img, 4, 8)
    s.visible = false
    with_draw_spy(function()
        s:draw()
    end)
    assert(draw_calls == 0, "draw must be skipped when visible is false")
end
print("PASS: draw is skipped when visible = false")

print("ALL TESTS PASSED")
