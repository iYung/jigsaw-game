local _visual_test = nil
local _visual_mode = false
do
    local headless, visual, test_file = false, false, nil
    for _, v in ipairs(arg or {}) do
        if     v == "--headless" then headless = true
        elseif v == "--visual"   then visual   = true
        elseif (headless or visual) and not test_file and v:sub(1, 1) ~= "-" then
            test_file = v
        end
    end
    if headless then
        require("lua/headless/stubs")
        require("lua/headless/runner").run(test_file)
        return
    end
    if visual then
        _visual_test = test_file
        _visual_mode = true
    end
end

love.graphics.setDefaultFilter("nearest", "nearest")

local SceneManager  = require("lua/core/scene_manager")
local GameScene     = require("game/scenes/game_scene")
local StartScene    = require("game/scenes/start_scene")
local Save          = require("lua/core/save")
local GameState     = require("game/game_state")
local SettingsState = require("game/settings_state")
local SettingsScene = require("game/scenes/settings_scene")
local Sound         = require("lua/core/sound")

local LOGICAL_W, LOGICAL_H = 1280, 720
local canvas

local SFX_MANIFEST = {
    sfx_dir = "assets/sounds/",
    sfx = {
        "pick_up",
        "put_down",
        "fail",
        "menu_navigate",
        "menu_confirm",
        "puzzle_complete",
        "rotate",
    },
    music = {
        menu = { path = "assets/music/menu.mp3", autoplay = true, looping = true },
        bg1 = { path = "assets/music/background.mp3", autoplay = false, looping = false },
        bg2 = { path = "assets/music/background2.mp3", autoplay = false, looping = false },
        bg3 = { path = "assets/music/background3.mp3", autoplay = false, looping = false },
        bg4 = { path = "assets/music/background4.mp3", autoplay = false, looping = false },
    },
}

local manager
local settings

-- Builds a fresh StartScene wired up so selecting its "Settings" item opens
-- the Settings overlay in opaque mode (no live scene beneath it) -- see
-- docs/design/settings-menu.md's "Start Scene entry point".
local function _new_start_scene()
    return StartScene.new(manager, function() settings:open(true, nil, manager) end)
end

function love.load()
    math.randomseed(os.time())

    love.window.setIcon(love.image.newImageData("assets/images/icon.png"))

    canvas = love.graphics.newCanvas(LOGICAL_W, LOGICAL_H)
    canvas:setFilter("nearest", "nearest")

    manager = SceneManager.new(LOGICAL_W, LOGICAL_H)
    settings = SettingsScene.new()

    Sound.load(SFX_MANIFEST)

    if Save.settings_exists() then
        SettingsState:apply_save(Save.read_settings())
    end
    love.window.setFullscreen(SettingsState.fullscreen)

    manager:switch(_new_start_scene())
end

function love.update(dt)
    Sound.update(dt)
    if settings.is_open then
        -- Pause gameplay input polling entirely while Settings is open.
        settings:update(dt)
    else
        manager:update(dt)
    end
end

function love.draw()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0)
    manager:draw()
    if settings.is_open then
        settings:draw()
    end
    love.graphics.setCanvas()

    local scale = math.min(love.graphics.getWidth() / LOGICAL_W, love.graphics.getHeight() / LOGICAL_H)
    local ox = (love.graphics.getWidth() - LOGICAL_W * scale) / 2
    local oy = (love.graphics.getHeight() - LOGICAL_H * scale) / 2
    love.graphics.draw(canvas, ox, oy, 0, scale, scale)
end

local function _save_current()
    if manager.current and manager.current.to_save then
        Save.write({ game_state = GameState:to_save(), scene = manager.current:to_save() })
    end
end

function love.keypressed(key)
    if settings.is_open then
        if settings:keypressed(key) then return end
    end
    if key == "escape" then
        if settings.is_open then
            settings:close()
        elseif manager.current and manager.current.esc_opens_settings then
            settings:open(false, manager.current, manager)
        elseif manager.current and manager.current.escape_to_menu then
            manager:switch(_new_start_scene())
        else
            love.event.quit()
        end
    end
end

-- No love.gamepadpressed existed anywhere in this repo before this feature
-- (see docs/design/settings-menu.md's "ESC / gamepad Start behavior
-- resolution"). Deliberately ignores which `joystick` fired -- any connected
-- controller's Start button opens/closes Settings (see the design doc's
-- "Multi-controller decision" paragraph).
function love.gamepadpressed(joystick, button)
    if settings.is_open then
        if settings:gamepadpressed(button) then return end
        if button == "start" then settings:close() end
        return
    end
    if button == "start" and manager.current and manager.current.esc_opens_settings then
        settings:open(false, manager.current, manager)
    end
end

function love.quit()
    _save_current()
end

function love.focus(focused)
    Sound.on_focus(focused)
end
