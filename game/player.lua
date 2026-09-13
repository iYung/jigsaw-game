local Sprite = require("lua/core/sprite")
local Input  = require("lua/core/input")
local Sound  = require("lua/core/sound")
local C      = require("game/constants")

local SPEED = 200

local Player = {}
Player.__index = Player

-- Build an Input instance for a given device descriptor:
--   nil                              -> default merged keyboard + first-two-gamepads
--   { type = "keyboard" }            -> keyboard only, no gamepad opts
--   { type = "gamepad", index = N }  -> gamepad-only, scoped to controller N
function Player.build_input(device)
    if device == nil then
        return Input.new({
            up           = { "w" },
            down         = { "s" },
            left         = { "a" },
            right        = { "d" },
            interact     = { "e" },
            rotate_piece = { "r" },
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
    elseif device.type == "keyboard" then
        return Input.new({
            up           = { "w" },
            down         = { "s" },
            left         = { "a" },
            right        = { "d" },
            interact     = { "e" },
            rotate_piece = { "r" },
        }, nil)
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
    self.held_piece   = nil
    self.hud_hints    = {}
    self._hover_pos   = nil
    return self
end

function Player:update(dt, pieces, boxes, pile, drawer, wall_tile, frozen, help_tile)
    -- Always run first, unconditionally: _pressed/_down in lua/core/input.lua
    -- are edge-triggered, so skipping this while frozen would desync edge
    -- detection for whenever the player unfreezes.
    self.input:update()

    -- Compute contextual HUD hints for this frame.
    do
        local dev    = self.input:last_device()
        local ikey   = dev == "gamepad" and "[A]" or "[E]"
        local rkey   = dev == "gamepad" and "[X]" or "[R]"
        local centre = self:centre()
        if frozen then
            self.hud_hints  = {}
            self._hover_pos = nil
        elseif self.held_piece ~= nil then
            local drop_target = self:drop_target()
            local drop_blocked = false
            if pieces then
                for _, p in ipairs(pieces) do
                    if p ~= self.held_piece and p.state == "grounded"
                       and p.sprite.x == drop_target.snap_x and p.sprite.y == drop_target.snap_y then
                        drop_blocked = true
                        break
                    end
                end
            end
            if drop_blocked then
                self.hud_hints = { rkey .. " Rotate" }
            else
                self.hud_hints = { ikey .. " Drop", rkey .. " Rotate" }
            end
            self._hover_pos = nil
        else
            -- Find the nearest interactable within range, tracking its grid
            -- position so the hover highlight and the HUD hint point at the
            -- same object.
            local best_dist = 1.5 * C.U
            local best_x, best_y = nil, nil
            local function try(cx, cy, sx, sy)
                local dx = cx - centre.x
                local dy = cy - centre.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist <= best_dist then
                    best_dist = dist
                    best_x = sx
                    best_y = sy
                end
            end
            if pieces then
                for _, piece in ipairs(pieces) do
                    if piece.state == "grounded" then
                        local pc = piece:centre()
                        try(pc.x, pc.y, piece.sprite.x, piece.sprite.y)
                    end
                end
            end
            if boxes then
                for _, b in ipairs(boxes) do
                    if b.state == "waiting" then
                        local bc = b:centre()
                        try(bc.x, bc.y, b.sprite.x, b.sprite.y)
                    end
                end
            end
            for _, tile in ipairs({ pile, wall_tile, help_tile }) do
                if tile ~= nil then
                    local tc = tile:centre()
                    try(tc.x, tc.y, tc.x - C.U, tc.y - C.U)
                end
            end
            if best_x ~= nil then
                self.hud_hints  = { ikey .. " Pick up" }
                self._hover_pos = { x = best_x, y = best_y }
            else
                self.hud_hints  = {}
                self._hover_pos = nil
            end
        end
    end

    if frozen then
        -- Frozen is driven by already being in wall view, so the wall tile
        -- itself must stay interactable here -- otherwise there'd be no way
        -- back out. Everything else (movement, piece/box/pile) stays
        -- blocked; this mirrors the not-frozen wall_tile check below but
        -- can't share code with it, since only one of the two branches ever
        -- runs per frame (never both, so wall_tile:interact() can't
        -- double-fire on the same press).
        if self.input:pressed("interact") and self.held_piece == nil then
            local centre = self:centre()
            if wall_tile ~= nil then
                local wc = wall_tile:centre()
                local dx = wc.x - centre.x
                local dy = wc.y - centre.y
                if math.sqrt(dx * dx + dy * dy) <= 1.5 * C.U then
                    wall_tile:interact()
                end
            end
            if help_tile ~= nil then
                local hc = help_tile:centre()
                local dx = hc.x - centre.x
                local dy = hc.y - centre.y
                if math.sqrt(dx * dx + dy * dy) <= 1.5 * C.U then
                    help_tile:interact()
                end
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
                Sound.play("put_down")
            else
                Sound.play("fail")
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
                Sound.play("pick_up")
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
            if self.held_piece == nil and help_tile ~= nil then
                local hc = help_tile:centre()
                local dx = hc.x - centre.x
                local dy = hc.y - centre.y
                if math.sqrt(dx * dx + dy * dy) <= 1.5 * C.U then
                    help_tile:interact()
                end
            end
        end
    end

    if self.input:pressed("rotate_piece") then
        if self.held_piece ~= nil then
            self.held_piece:rotate()
            Sound.play("rotate")
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

function Player:movement_dir()
    local dx = 0
    local dy = 0
    if self.input:is_down("left")  then dx = dx - 1 end
    if self.input:is_down("right") then dx = dx + 1 end
    if self.input:is_down("up")    then dy = dy - 1 end
    if self.input:is_down("down")  then dy = dy + 1 end
    return {dx = dx, dy = dy}
end

function Player:draw()
    if self.held_piece ~= nil then
        local drop_target = self:drop_target()
        self.held_piece:draw_ghost(drop_target.snap_x, drop_target.snap_y)
    else
        local hx, hy
        if self._hover_pos then
            hx = self._hover_pos.x
            hy = self._hover_pos.y
        else
            local drop_target = self:drop_target()
            hx = drop_target.snap_x
            hy = drop_target.snap_y
        end
        love.graphics.setColor(1, 1, 1, 0.25)
        love.graphics.rectangle("fill", hx, hy, C.SLOT, C.SLOT)
        love.graphics.setColor(1, 1, 1, 1)
    end
    self.sprite:draw()
    if self.held_piece ~= nil then
        self.held_piece:draw()
    end
end

return Player
