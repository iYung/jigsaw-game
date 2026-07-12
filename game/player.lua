local Sprite        = require("lua/core/sprite")
local Input         = require("lua/core/input")
local C             = require("game/constants")
local SettingsState = require("game/settings_state")

local SPEED = 200

local Player = {}
Player.__index = Player

-- Build an Input instance for a given device descriptor:
--   nil                              -> default merged keyboard + first-two-gamepads
--   { type = "keyboard" }            -> keyboard only, no gamepad opts
--   { type = "gamepad", index = N }  -> gamepad-only, scoped to controller N
function Player.build_input(device)
    if device == nil then
        local key_map = SettingsState:key_map()
        local inp = Input.new({
            up           = key_map.up,
            down         = key_map.down,
            left         = key_map.left,
            right        = key_map.right,
            interact     = key_map.interact,
            rotate_piece = key_map.rotate_piece,
        }, {
            gamepad_buttons = {
                up           = { "dpup" },
                down         = { "dpdown" },
                left         = { "dpleft" },
                right        = { "dpright" },
                interact     = { "a" },
                rotate_piece = { "x" },
            },
            use_left_stick = true,
            joystick_scope = "first_two",
        })
        inp._keyboard_rebindable = true
        return inp
    elseif device.type == "keyboard" then
        local key_map = SettingsState:key_map()
        local inp = Input.new({
            up           = key_map.up,
            down         = key_map.down,
            left         = key_map.left,
            right        = key_map.right,
            interact     = key_map.interact,
            rotate_piece = key_map.rotate_piece,
        }, nil)
        inp._keyboard_rebindable = true
        return inp
    elseif device.type == "gamepad" then
        return Input.new({
            up           = {},
            down         = {},
            left         = {},
            right        = {},
            interact     = {},
            rotate_piece = {},
        }, {
            gamepad_buttons = {
                up           = { "dpup" },
                down         = { "dpdown" },
                left         = { "dpleft" },
                right        = { "dpright" },
                interact     = { "a" },
                rotate_piece = { "x" },
            },
            use_left_stick = true,
            joystick_scope = device.index,
        })
    end
end

function Player.new(x, y, input)
    local self        = setmetatable({}, Player)
    self.sprite       = Sprite.new(x, y, C.SLOT, C.SLOT)
    self.sprite.image = love.graphics.newImage("assets/player.png")
    self.input        = input or Player.build_input()
    self.held_piece = nil
    return self
end

function Player:update(dt, pieces, boxes, pile, drawer, wall_tile, frozen)
    -- Always run first, unconditionally: _pressed/_down in lua/core/input.lua
    -- are edge-triggered, so skipping this while frozen would desync edge
    -- detection for whenever the player unfreezes.
    self.input:update()
    if frozen then
        -- Frozen is driven by already being in wall view, so the wall tile
        -- itself must stay interactable here -- otherwise there'd be no way
        -- back out. Everything else (movement, piece/box/pile) stays
        -- blocked; this mirrors the not-frozen wall_tile check below but
        -- can't share code with it, since only one of the two branches ever
        -- runs per frame (never both, so wall_tile:interact() can't
        -- double-fire on the same press).
        if self.input:pressed("interact") and self.held_piece == nil and wall_tile ~= nil then
            local centre = self:centre()
            local wc = wall_tile:centre()
            local dx = wc.x - centre.x
            local dy = wc.y - centre.y
            if math.sqrt(dx * dx + dy * dy) <= 1.5 * C.U then
                wall_tile:interact()
            end
        end
        return
    end
    local s = self.sprite
    if self.input:is_down("left")  then s.x = s.x - SPEED * dt end
    if self.input:is_down("right") then s.x = s.x + SPEED * dt end
    if self.input:is_down("up")    then s.y = s.y - SPEED * dt end
    if self.input:is_down("down")  then s.y = s.y + SPEED * dt end

    if self.input:pressed("interact") then
        if self.held_piece ~= nil then
            local drop_target = self:drop_target()
            local occupied = false
            if pieces then
                for _, p in ipairs(pieces) do
                    if p ~= self.held_piece and p.state == "grounded"
                       and p.sprite.x == drop_target.snap_x and p.sprite.y == drop_target.snap_y then
                        occupied = true
                        break
                    end
                end
            end
            if not occupied then
                self.held_piece:drop(drop_target.x, drop_target.y)
                pieces[#pieces + 1] = self.held_piece
                if drawer then
                    drawer:add(self.held_piece, C.PRIORITY_PIECE)
                end
                self.held_piece = nil
            end
        else
            local centre = self:centre()
            local nearest, nearest_dist = nil, math.huge
            if pieces then
                for _, piece in ipairs(pieces) do
                    if piece.state == "grounded" then
                        local pc = piece:centre()
                        local dx = pc.x - centre.x
                        local dy = pc.y - centre.y
                        local dist = math.sqrt(dx * dx + dy * dy)
                        if dist < nearest_dist then
                            nearest_dist = dist
                            nearest = piece
                        end
                    end
                end
            end
            if nearest and nearest_dist <= 1.5 * C.U then
                nearest:pick_up()
                for i, piece in ipairs(pieces) do
                    if piece == nearest then
                        table.remove(pieces, i)
                        break
                    end
                end
                if drawer then
                    drawer:remove(nearest)
                end
                self.held_piece = nearest
            end
            local box_interacted = false
            if self.held_piece == nil then
                local nearest_box, nearest_box_dist = nil, math.huge
                if boxes then
                    for _, b in ipairs(boxes) do
                        if b.state == "waiting" then
                            local bc = b:centre()
                            local dx = bc.x - centre.x
                            local dy = bc.y - centre.y
                            local dist = math.sqrt(dx * dx + dy * dy)
                            if dist < nearest_box_dist then
                                nearest_box_dist = dist
                                nearest_box = b
                            end
                        end
                    end
                end
                if nearest_box and nearest_box_dist <= 1.5 * C.U then
                    nearest_box:interact()
                    box_interacted = true
                end
            end
            if self.held_piece == nil and not box_interacted and pile ~= nil then
                local bc = pile:centre()
                local dx = bc.x - centre.x
                local dy = bc.y - centre.y
                if math.sqrt(dx * dx + dy * dy) <= 1.5 * C.U then
                    pile:interact()
                end
            end
            if self.held_piece == nil and wall_tile ~= nil then
                local wc = wall_tile:centre()
                local dx = wc.x - centre.x
                local dy = wc.y - centre.y
                if math.sqrt(dx * dx + dy * dy) <= 1.5 * C.U then
                    wall_tile:interact()
                end
            end
        end
    end

    if self.input:pressed("rotate_piece") then
        if self.held_piece ~= nil then
            self.held_piece:rotate()
        end
    end

    if self.held_piece ~= nil then
        self.held_piece:update(self)
    end
end

-- Centre point used for camera tracking
function Player:centre()
    return { x = self.sprite.x + self.sprite.width / 2, y = self.sprite.y + self.sprite.height / 2 }
end

-- Where a held piece would land (grid-snapped) if dropped right now
function Player:drop_target()
    local centre = self:centre()
    local target_x = centre.x - C.U
    local target_y = centre.y - C.U
    local snap_x = math.floor(target_x / C.SLOT + 0.5) * C.SLOT
    local snap_y = math.floor(target_y / C.SLOT + 0.5) * C.SLOT
    return { x = target_x, y = target_y, snap_x = snap_x, snap_y = snap_y }
end

function Player:draw()
    if self.held_piece ~= nil then
        local drop_target = self:drop_target()
        self.held_piece:draw_ghost(drop_target.snap_x, drop_target.snap_y)
    else
        local drop_target = self:drop_target()
        love.graphics.setColor(1, 1, 1, 0.25)
        love.graphics.rectangle("fill", drop_target.snap_x, drop_target.snap_y, C.SLOT, C.SLOT)
        love.graphics.setColor(1, 1, 1, 1)
    end
    self.sprite:draw()
    if self.held_piece ~= nil then
        self.held_piece:draw()
    end
end

return Player
