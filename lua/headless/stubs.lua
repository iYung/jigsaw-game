-- lua/headless/stubs.lua
-- Installs no-op replacements into the `love` global before any game module
-- loads. Required when running with --headless (love.graphics is nil).

local noop = function() end

-- Stub image returned by any love.graphics.new*() call. Dimensions match the
-- real puzzle assets under assets/puzzles/<tier>/*.png so that JigsawBox.new's
-- fixed-cell-size grid inference (game/jigsaw_box.lua) sees whole-number
-- rows/cols under headless tests just like it does with the real images.
-- Path-aware: love.graphics.newImage(path) forwards `path` here via the
-- catch-all __index below, so the reported size varies by tier folder
-- (/med/ -> 256x256, /hard/ -> 320x320, /final_puzzle/ -> 448x448). Any
-- other call (e.g. newQuad, or newImage with no/other path) falls through
-- to the 192x192 default.
local function make_stub_image(path)
  local width, height = 192, 192
  if type(path) == "string" then
    if path:find("/med/", 1, true) then
      width, height = 256, 256
    elseif path:find("/hard/", 1, true) then
      width, height = 320, 320
    elseif path:find("/final_puzzle/", 1, true) then
      width, height = 448, 448
    end
  end
  return {
    getWidth      = function() return width end,
    getHeight     = function() return height end,
    getDimensions = function() return width, height end,
    setFilter     = noop,
  }
end

-- Build the graphics stub table with explicit stubs first, then a catch-all
-- __index metatable that returns a no-op (or a new*-style factory) for any
-- unknown key.
local graphics_stub = {}

-- Explicit stubs ---------------------------------------------------------
graphics_stub.setDefaultFilter = noop
graphics_stub.setCanvas        = noop
graphics_stub.setColor         = noop
graphics_stub.setShader        = noop
graphics_stub.newShader        = function(path) return { send = noop } end
graphics_stub.setBlendMode     = noop
graphics_stub.setFilter        = noop
graphics_stub.setScissor       = noop
graphics_stub.draw             = noop
graphics_stub.rectangle        = noop
graphics_stub.print            = noop
graphics_stub.printf           = noop
graphics_stub.push             = noop
graphics_stub.pop              = noop
graphics_stub.translate        = noop
graphics_stub.scale            = noop
graphics_stub.clear            = noop
graphics_stub.getFont          = function() return {} end

-- Global screen dimension query (not the stub-image version).
graphics_stub.getDimensions = function() return 1280, 720 end
graphics_stub.getWidth      = function() return 1280 end
graphics_stub.getHeight     = function() return 720 end

-- Catch-all: any unknown key returns a no-op, except new* returns a factory.
setmetatable(graphics_stub, {
  __index = function(_, key)
    if type(key) == "string" and key:sub(1, 3) == "new" then
      return make_stub_image
    end
    return noop
  end,
})

-- Install stubs into the love global ------------------------------------
love.graphics = graphics_stub

love.keyboard = love.keyboard or {}
love.keyboard.isDown = function() return false end

love.window = love.window or {}
love.window.getFullscreen = function() return false end
love.window.setFullscreen = function() end

love.filesystem = love.filesystem or {}
love.filesystem.getInfo = function() return nil end

love.joystick = love.joystick or {}
love.joystick.getJoysticks = function() return {} end

love.audio = love.audio or {}

-- Stub source object returned by newSource.
local function make_stub_source()
  local src = {}
  src.clone      = function() return make_stub_source() end
  src.setLooping = noop
  src.setVolume  = noop
  src.setPitch   = noop
  src.play       = noop
  src.stop       = noop
  src.isPlaying  = function() return false end
  return src
end

love.audio.newSource  = function(path, type) return make_stub_source() end
love.audio.play       = noop
