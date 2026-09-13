local Scene      = require("lua/core/scene")
local Sprite     = require("lua/core/sprite")
local Shader     = require("lua/core/shader")
local Camera     = require("lua/core/camera")
local Sound      = require("lua/core/sound")
local Player     = require("game/player")
local C          = require("game/constants")
local JigsawBox  = require("game/jigsaw_box")
local JigsawPiece = require("game/jigsaw_piece")
local JigsawSolver = require("game/jigsaw_solver")
local PuzzlePile = require("game/puzzle_pile")
local WallViewTile = require("game/wall_view_tile")
local HelpTile   = require("game/help_tile")
local GameState  = require("game/game_state")

-- Logical/virtual resolution the whole game renders at before letterboxing
-- (see main.lua) -- needed here to compute a zoom level that fits the
-- completed-puzzles wall's bounding box on screen.
local LOGICAL_W = 1280
local LOGICAL_H = 720

local GameScene = {}
GameScene.__index = GameScene

function GameScene.new(save_data, input_assignments)
    local self = Scene.new(1280, 720)
    setmetatable(self, GameScene)
    self._save_data = save_data
    self._input_assignments = input_assignments
    -- Read by main.lua's ESC/gamepad-Start handling (see docs/design/
    -- settings-menu.md's "ESC / gamepad Start behavior resolution") to
    -- decide whether ESC/Start opens the Settings overlay instead of the
    -- old save-and-return-to-menu behavior.
    self.esc_opens_settings = true
    self._bg_list = { "bg1", "bg2", "bg3", "bg4" }
    self._bg_index = math.random(4)
    return self
end

function GameScene:on_enter()
    Sound.stop_music("menu")
    local bg_already_playing = false
    for _, name in ipairs(self._bg_list) do
        if Sound.is_music_playing(name) then
            bg_already_playing = true
            break
        end
    end
    if not bg_already_playing then
        Sound.fade_music(self._bg_list[self._bg_index], 1, 2)
    end

    local WORLD_W = 20 * C.SLOT  -- 1280px
    local WORLD_H = 10 * C.SLOT  -- 640px

    self.world_w = WORLD_W
    self.world_h = WORLD_H

    local GROUND_Y = 4 * C.SLOT  -- 256, grid-aligned so pieces rest at 3*SLOT=192

    self.player = Player.new(0, GROUND_Y - C.SLOT, self._input_assignments and self._input_assignments.p1)
    self.drawer:add(self.player, 10)

    local scene = self
    self.background = {
        image = love.graphics.newImage("assets/backgrounds/world_bg.png"),
        draw = function(self)
            local fill_top = scene.shelf_row_bottom and (scene.shelf_row_bottom - LOGICAL_H) or C.BG_OFFSET_Y
            fill_top = math.min(fill_top, C.BG_OFFSET_Y)
            local pad = 10000
            love.graphics.setColor(C.BG_WALL_COLOR[1], C.BG_WALL_COLOR[2], C.BG_WALL_COLOR[3])
            love.graphics.rectangle("fill", C.BG_OFFSET_X - pad, fill_top - pad, C.BG_W + 2 * pad, (C.BG_OFFSET_Y + C.BG_H + pad) - (fill_top - pad))
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(self.image, C.BG_OFFSET_X, C.BG_OFFSET_Y)
        end,
    }
    self.drawer:add(self.background, -1)

    self.floor = {
        image = love.graphics.newImage("assets/backgrounds/floor.png"),
        draw = function(self)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(self.image, 0, 0)
        end,
    }
    self.drawer:add(self.floor, 0)

    self.pieces = {}
    self.pieces_in_drawer = {}
    self.active_puzzles = {}
    self.completed_puzzles = {}

    if self._save_data then
        -- (a) restore player position
        self.player.sprite.x, self.player.sprite.y = self._save_data.player.x, self._save_data.player.y

        -- (b) restore held piece, if any
        if self._save_data.player.held_piece then
            self.player.held_piece = JigsawPiece.from_save(self._save_data.player.held_piece)
            self.player.held_piece:pick_up()
        end

        -- (c) rebuild loose grounded pieces (lazily added to the drawer by
        -- update()'s existing loop, same as any other piece)
        for _, piece_data in ipairs(self._save_data.pieces) do
            self.pieces[#self.pieces + 1] = JigsawPiece.from_save(piece_data)
        end

        -- (e) rebuild self.active_puzzles directly from the saved field
        -- (defaults to {} for pre-fix saves, which had no such field -- no
        -- crash, just no retroactive recovery of their in-progress
        -- puzzles). Must run after (b), which restores
        -- self.player.held_piece, and after (c), which populates
        -- self.pieces -- each saved entry's pieces list is built by
        -- scanning self.pieces for matching path, plus held_piece when it
        -- matches too (a held piece is never in self.pieces, so without
        -- this it would never be picked up here). Keep the per-path pieces
        -- tables around so the box-rebuild loop below can wire the same
        -- table reference into box.spawned.
        self.active_puzzles = {}
        local active_pieces_by_path = {}
        for _, entry_data in ipairs(self._save_data.active_puzzles or {}) do
            local matched = {}
            for _, p in ipairs(self.pieces) do
                if p.path == entry_data.path then
                    matched[#matched + 1] = p
                end
            end
            if self.player.held_piece and self.player.held_piece.path == entry_data.path then
                matched[#matched + 1] = self.player.held_piece
            end
            active_pieces_by_path[entry_data.path] = matched
            self.active_puzzles[#self.active_puzzles + 1] = {
                pieces = matched,
                piece_count = entry_data.piece_count,
                solved = false,
                image = love.graphics.newImage(entry_data.path),
                cols = entry_data.cols,
                rows = entry_data.rows,
                tier = entry_data.tier,
                path = entry_data.path,
            }
        end

        -- (d) rebuild boxes, explicitly added to the drawer (unlike pieces,
        -- boxes are not lazily added by update())
        self.boxes = {}
        for _, box_data in ipairs(self._save_data.boxes) do
            local box = JigsawBox.from_save(box_data, self.world_w, self.world_h)
            self.boxes[#self.boxes + 1] = box
            self.drawer:add(box, C.PRIORITY_PIECE)

            -- Reuse the same pieces table built in (e) above for this
            -- box's path -- not a copy -- so that if the box is still
            -- "ejecting", newly-spawned pieces (JigsawBox:_eject_next's
            -- self.spawned[#self.spawned + 1] = piece) land in the same
            -- table the completion check in update() iterates. Falls back
            -- to the empty table JigsawBox.from_save() already gave it
            -- (rather than nil) for a pre-fix save with boxes but no
            -- matching active_puzzles entry, so ejection still has a table
            -- to append to instead of crashing.
            box.spawned = active_pieces_by_path[box.path] or box.spawned
        end

        -- (f) rebuild shelved/completed puzzles
        for _, entry_data in ipairs(self._save_data.completed_puzzles) do
            local image = love.graphics.newImage(entry_data.path)
            local entry_shader = Shader.load("assets/shaders/rounded_corners.frag")
            entry_shader:send("size", {entry_data.cols * C.SLOT, entry_data.rows * C.SLOT})
            entry_shader:send("uv_rect", {0, 0, 1, 1})

            local shelved = {
                image = image,
                x = entry_data.x,
                y = entry_data.y,
                cols = entry_data.cols,
                rows = entry_data.rows,
                shader = entry_shader,
                path = entry_data.path,
                draw = function(self)
                    love.graphics.setShader(self.shader)
                    love.graphics.draw(self.image, self.x, self.y)
                    love.graphics.setShader()
                end,
            }
            self.completed_puzzles[#self.completed_puzzles + 1] = shelved
            self.drawer:add(shelved, C.PRIORITY_SHELF)
        end

        -- (g) restore the shelf cursor
        self.shelf_row_x, self.shelf_row_bottom, self.shelf_row_max_height =
            self._save_data.shelf_row_x, self._save_data.shelf_row_bottom, self._save_data.shelf_row_max_height
    else
        self.shelf_row_x = 0
        self.shelf_row_bottom = -C.SLOT
        self.shelf_row_max_height = 0

        local box = nil
        if GameState:can_start_puzzle() then
            box = JigsawBox.new(5 * C.SLOT, 3 * C.SLOT, self.world_w, self.world_h)
        end
        self.boxes = {}
        if box then
            self.boxes[#self.boxes + 1] = box
            self.drawer:add(box, C.PRIORITY_PIECE)
            self.active_puzzles[#self.active_puzzles + 1] = {
                pieces = box.spawned,
                piece_count = box.piece_count,
                solved = false,
                image = box.image,
                cols = box.cols,
                rows = box.rows,
                tier = box.tier,
                path = box.path,
            }
            GameState:puzzle_started()
        end
    end

    if GameState.player_count == 2 then
        self.player2 = Player.new(self.player.sprite.x + C.SLOT, self.player.sprite.y,
            self._input_assignments and self._input_assignments.p2)
        -- Same sprite image as Player 1 -- tint it so the two are visually
        -- distinguishable in the world instead of looking identical. Warm
        -- orange/gold rather than blue, since assets/player.png already has
        -- a blue accent color that a blue tint would wash out.
        self.player2.sprite.color = { 1, 0.7, 0.25, 1 }
        self.drawer:add(self.player2, 10)
        self.camera._w = 640
        self.camera2 = Camera.new(0, 0, 640, 720, 640, 0)
    end

    self.pile = PuzzlePile.new(WORLD_W / 2, 0, function() self:_spawn_box() end)
    self.drawer:add(self.pile, C.PRIORITY_PIECE)

    -- Wall-view toggle tile, top-right corner of the floor (y = 0 is the
    -- floor's top edge, where the shelf's baseline starts -- see
    -- docs/design/wall-view-tile.md). Each player's view/frozen state is
    -- independent (2P split-screen), so in 2P mode each gets their own
    -- WallViewTile instance at the same cell, bound to their own toggle --
    -- only wall_tile is added to the drawer, since wall_tile2 would render
    -- an identical rectangle on top of it.
    self.wall_tile = WallViewTile.new(WORLD_W - C.SLOT, 0, function() self:_toggle_wall_view("p1") end)
    self.drawer:add(self.wall_tile, C.PRIORITY_PIECE)

    self.help_tile = HelpTile.new(0, WORLD_H - C.SLOT, function() self:_toggle_help() end)
    self.drawer:add(self.help_tile, C.PRIORITY_PIECE)
    self.help_mode = false
    self.help_overlay_drawable = { draw = function() if self.help_mode then self:_draw_help_overlay() end end }
    self.drawer:add(self.help_overlay_drawable, 9)

    self._hud_panel = love.graphics.newImage("assets/ui/panel_normal.png")
    self._hud_font  = love.graphics.newFont(12)

    self.view1 = "play"
    self.wall_pan1 = nil
    if GameState.player_count == 2 then
        self.wall_tile2 = WallViewTile.new(WORLD_W - C.SLOT, 0, function() self:_toggle_wall_view("p2") end)
        self.view2 = "play"
        self.wall_pan2 = nil
    end
end

function GameScene:_spawn_box()
    if not GameState:can_start_puzzle() then return end

    local cols = self.world_w / C.SLOT
    local rows = self.world_h / C.SLOT

    for _ = 1, 50 do
        local cx = math.random(0, cols - 1) * C.SLOT
        local cy = math.random(0, rows - 1) * C.SLOT

        local occupied = false
        for _, box in ipairs(self.boxes) do
            if box.target_x == cx and box.target_y == cy then
                occupied = true
                break
            end
        end
        if not occupied and self.pile.sprite.x == cx and self.pile.sprite.y == cy then
            occupied = true
        end
        if not occupied and self.wall_tile.sprite.x == cx and self.wall_tile.sprite.y == cy then
            occupied = true
        end
        if not occupied and self.help_tile.sprite.x == cx and self.help_tile.sprite.y == cy then
            occupied = true
        end
        if not occupied then
            for _, piece in ipairs(self.pieces) do
                if piece.state == "grounded" and piece.sprite.x == cx and piece.sprite.y == cy then
                    occupied = true
                    break
                end
            end
        end
        if not occupied and self.player.held_piece then
            local hp = self.player.held_piece
            local snap_x = math.floor(hp.sprite.x / C.SLOT + 0.5) * C.SLOT
            local snap_y = math.floor(hp.sprite.y / C.SLOT + 0.5) * C.SLOT
            if snap_x == cx and snap_y == cy then
                occupied = true
            end
        end
        if not occupied and self.player2 and self.player2.held_piece then
            local hp = self.player2.held_piece
            local snap_x = math.floor(hp.sprite.x / C.SLOT + 0.5) * C.SLOT
            local snap_y = math.floor(hp.sprite.y / C.SLOT + 0.5) * C.SLOT
            if snap_x == cx and snap_y == cy then
                occupied = true
            end
        end

        if not occupied then
            local box = JigsawBox.new(cx, cy, self.world_w, self.world_h,
                self.pile:top_position())
            if not box then return end
            self.boxes[#self.boxes + 1] = box
            self.drawer:add(box, C.PRIORITY_BOX_FLYING)
            self.active_puzzles[#self.active_puzzles + 1] = {
                pieces = box.spawned,
                piece_count = box.piece_count,
                solved = false,
                image = box.image,
                cols = box.cols,
                rows = box.rows,
                tier = box.tier,
                path = box.path,
            }
            GameState:puzzle_started()
            return
        end
    end
end

function GameScene:update(dt)
    if not Sound.is_music_playing(self._bg_list[self._bg_index]) then
        self._bg_index = (self._bg_index % #self._bg_list) + 1
        Sound.fade_music(self._bg_list[self._bg_index], 1, 2)
    end

    local reserved_cells = {
        {x = self.pile.sprite.x,      y = self.pile.sprite.y},
        {x = self.wall_tile.sprite.x, y = self.wall_tile.sprite.y},
        {x = self.help_tile.sprite.x, y = self.help_tile.sprite.y},
    }
    for _, box in ipairs(self.boxes) do
        local was_flying = box.state == "flying"
        box:update(dt, self.pieces, reserved_cells)
        if was_flying and box.state ~= "flying" then
            self.drawer:set_priority(box, C.PRIORITY_PIECE)
        end
    end

    for _, piece in ipairs(self.pieces) do
        if not self.pieces_in_drawer[piece] then
            self.drawer:add(piece, C.PRIORITY_PIECE)
            self.pieces_in_drawer[piece] = true
        end
    end

    for i = #self.boxes, 1, -1 do
        local box = self.boxes[i]
        if box.state == "done" then
            box.sprite.visible = false
            table.remove(self.boxes, i)
        end
    end

    self.player:update(dt, self.pieces, self.boxes, self.pile, self.drawer,
        self.wall_tile, self.view1 == "wall", self.help_tile)
    if self.player2 then
        self.player2:update(dt, self.pieces, self.boxes, self.pile, self.drawer,
            self.wall_tile2, self.view2 == "wall", self.help_tile)
    end

    for _, entry in ipairs(self.active_puzzles) do
        if not entry.solved and JigsawSolver.is_assembled(entry.pieces, entry.piece_count) then
            entry.solved = true
            Sound.play("puzzle_complete")
            GameState:puzzle_solved(entry.tier)
            for _, piece in ipairs(entry.pieces) do
                piece:start_celebrate(entry.cols)
            end
        end
    end

    for i = #self.pieces, 1, -1 do
        local piece = self.pieces[i]
        if piece.state == "celebrating" then
            piece:update_celebrate(dt)
        elseif piece.state == "vanishing" then
            local finished = piece:update_fade(dt)
            if finished then
                table.remove(self.pieces, i)
                self.drawer:remove(piece)
                self.pieces_in_drawer[piece] = nil
            end
        end
    end

    for i = #self.active_puzzles, 1, -1 do
        local entry = self.active_puzzles[i]
        if entry.solved then
            local all_faded = true
            for _, piece in ipairs(entry.pieces) do
                if piece.sprite.color[4] ~= 0 then
                    all_faded = false
                    break
                end
            end
            if all_faded then
                if entry.image and entry.cols and entry.rows then
                    self:_shelve(entry)
                end

                table.remove(self.active_puzzles, i)
            end
        end
    end

    self.player.sprite.x = math.max(0, math.min(self.player.sprite.x, self.world_w - C.SLOT))
    self.player.sprite.y = math.max(0, math.min(self.player.sprite.y, self.world_h - C.SLOT))

    if self.player2 then
        self.player2.sprite.x = math.max(0, math.min(self.player2.sprite.x, self.world_w - C.SLOT))
        self.player2.sprite.y = math.max(0, math.min(self.player2.sprite.y, self.world_h - C.SLOT))
    end

    if self.view1 == "wall" then
        local dir = self.player:movement_dir()
        local pan_min_x, pan_max_x, pan_min_y, pan_max_y = self:_wall_pan_bounds()
        self.wall_pan1.x = math.max(pan_min_x, math.min(pan_max_x, self.wall_pan1.x + dir.dx * C.WALL_VIEW_PAN_SPEED * dt))
        self.wall_pan1.y = math.max(pan_min_y, math.min(pan_max_y, self.wall_pan1.y + dir.dy * C.WALL_VIEW_PAN_SPEED * dt))
        self.camera:follow({x = self.wall_pan1.x, y = self.wall_pan1.y, zoom = C.WALL_VIEW_ZOOM}, 0.85)
    else
        local c = self.player:centre()
        self.camera:follow({x = c.x, y = c.y, zoom = 1.0}, 0.85)
    end
    if self.camera2 then
        if self.view2 == "wall" then
            local dir2 = self.player2:movement_dir()
            local pan_min_x, pan_max_x, pan_min_y, pan_max_y = self:_wall_pan_bounds()
            self.wall_pan2.x = math.max(pan_min_x, math.min(pan_max_x, self.wall_pan2.x + dir2.dx * C.WALL_VIEW_PAN_SPEED * dt))
            self.wall_pan2.y = math.max(pan_min_y, math.min(pan_max_y, self.wall_pan2.y + dir2.dy * C.WALL_VIEW_PAN_SPEED * dt))
            self.camera2:follow({x = self.wall_pan2.x, y = self.wall_pan2.y, zoom = C.WALL_VIEW_ZOOM}, 0.85)
        else
            local c2 = self.player2:centre()
            self.camera2:follow({x = c2.x, y = c2.y, zoom = 1.0}, 0.85)
        end
    end
end

function GameScene:_toggle_help()
    self.help_mode = not self.help_mode
    self.help_tile.active = self.help_mode
end

-- Draws a coloured overlay on each piece to show connection validity.
-- Green = ≥1 correct same-puzzle neighbor, 0 incorrect.
-- Red   = ≥1 incorrect same-puzzle neighbor.
-- Called from within an active camera transform.
function GameScene:_draw_help_overlay()
    local all_pieces = {}
    for _, p in ipairs(self.pieces) do
        all_pieces[#all_pieces + 1] = p
    end
    if self.player.held_piece then
        all_pieces[#all_pieces + 1] = self.player.held_piece
    end
    if self.player2 and self.player2.held_piece then
        all_pieces[#all_pieces + 1] = self.player2.held_piece
    end

    for _, piece in ipairs(all_pieces) do
        if piece.path then
            local correct = 0
            local incorrect = 0
            local k = piece.rotation_step
            local gx_a, gy_a = JigsawSolver.rotate_cell(piece.row, piece.col, k)
            local ox_a = piece.sprite.x / C.SLOT - gx_a
            local oy_a = piece.sprite.y / C.SLOT - gy_a

            for _, other in ipairs(all_pieces) do
                if other ~= piece and other.path == piece.path then
                    local dx = math.abs(other.sprite.x - piece.sprite.x)
                    local dy = math.abs(other.sprite.y - piece.sprite.y)
                    local adjacent = (dx == C.SLOT and dy == 0) or (dx == 0 and dy == C.SLOT)
                    if adjacent then
                        if other.rotation_step == k then
                            local gx_b, gy_b = JigsawSolver.rotate_cell(other.row, other.col, k)
                            local ox_b = other.sprite.x / C.SLOT - gx_b
                            local oy_b = other.sprite.y / C.SLOT - gy_b
                            if ox_b == ox_a and oy_b == oy_a then
                                correct = correct + 1
                            else
                                incorrect = incorrect + 1
                            end
                        else
                            incorrect = incorrect + 1
                        end
                    end
                end
            end

            if correct >= 1 and incorrect == 0 then
                love.graphics.setColor(0.2, 0.9, 0.2, 0.45)
                love.graphics.rectangle("fill", piece.sprite.x, piece.sprite.y, C.SLOT, C.SLOT)
            elseif incorrect >= 1 then
                love.graphics.setColor(0.9, 0.2, 0.2, 0.45)
                love.graphics.rectangle("fill", piece.sprite.x, piece.sprite.y, C.SLOT, C.SLOT)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Returns pan clamp bounds [min_x, max_x, min_y, max_y] for wall view,
-- derived from the bounding box of all completed puzzles plus a half-screen
-- margin. Falls back to world bounds when the shelf is empty.
function GameScene:_wall_pan_bounds()
    if #self.completed_puzzles == 0 then
        return 0, self.world_w, 0, self.world_h
    end
    local min_x, min_y = math.huge, math.huge
    local max_x, max_y = -math.huge, -math.huge
    for _, entry in ipairs(self.completed_puzzles) do
        local w = entry.cols * C.SLOT
        local h = entry.rows * C.SLOT
        min_x = math.min(min_x, entry.x)
        min_y = math.min(min_y, entry.y)
        max_x = math.max(max_x, entry.x + w)
        max_y = math.max(max_y, entry.y + h)
    end
    local hw = LOGICAL_W / 2
    local hh = LOGICAL_H / 2
    return min_x - hw, max_x + hw, min_y - hh, max_y + hh
end

-- Flips the given player's ("p1"/"p2") view between "play" and "wall".
-- Entering "wall" computes a target camera center/zoom that fits the full
-- Returns a camera target {x, y, zoom} that frames the full bounding box of
-- self.completed_puzzles, or nil when the shelf is empty.
function GameScene:_compute_wall_target()
    if #self.completed_puzzles == 0 then return nil end

    local min_x, min_y = math.huge, math.huge
    local max_x, max_y = -math.huge, -math.huge
    for _, entry in ipairs(self.completed_puzzles) do
        local w = entry.cols * C.SLOT
        local h = entry.rows * C.SLOT
        min_x = math.min(min_x, entry.x)
        min_y = math.min(min_y, entry.y)
        max_x = math.max(max_x, entry.x + w)
        max_y = math.max(max_y, entry.y + h)
    end

    local bbox_w = max_x - min_x
    local bbox_h = max_y - min_y
    local zoom = math.min(1.0, 0.9 * math.min(LOGICAL_W / bbox_w, LOGICAL_H / bbox_h))
    return {
        x = (min_x + max_x) / 2,
        y = (min_y + max_y) / 2,
        zoom = zoom,
    }
end

-- Flips the given player's ("p1"/"p2") view between "play" and "wall".
-- Entering "wall" seeds wall_pan1/wall_pan2 from the bounding-box centre of
-- completed_puzzles, or the player's own centre when the shelf is empty.
-- While in wall view, movement controls pan the camera at C.WALL_VIEW_PAN_SPEED;
-- zoom is fixed at C.WALL_VIEW_ZOOM (see docs/design/wall-view-pan.md).
function GameScene:_toggle_wall_view(which)
    local view_key = (which == "p2") and "view2" or "view1"
    local pan_key  = (which == "p2") and "wall_pan2" or "wall_pan1"

    if self[view_key] == "wall" then
        self[view_key] = "play"
        return
    end

    local t = self:_compute_wall_target()
    if t then
        self[pan_key] = {x = t.x, y = t.y}
    else
        local player = (which == "p2") and self.player2 or self.player
        local c = player:centre()
        self[pan_key] = {x = c.x, y = c.y}
    end
    self[view_key] = "wall"
end

function GameScene:draw()
    if self.camera2 == nil then
        Scene.draw(self)
    else
        love.graphics.setScissor(0, 0, 640, 720)
        self.camera:attach()
        self.drawer:draw()
        self.camera:detach()

        love.graphics.setScissor(640, 0, 640, 720)
        self.camera2:attach()
        self.drawer:draw()
        self.camera2:detach()

        love.graphics.setScissor()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.line(640, 0, 640, 720)
    end

    self:_draw_hud(self.player, 0)
    if self.player2 then
        self:_draw_hud(self.player2, 640)
    end
end

function GameScene:_draw_hud(player, x_offset)
    local hints = player.hud_hints
    if not hints or #hints == 0 then return end

    local font = self._hud_font
    local prev_font = love.graphics.getFont()
    love.graphics.setFont(font)

    local PAD    = 8
    local LINE_H = font:getHeight() + 4

    local max_w = 0
    for _, hint in ipairs(hints) do
        local lw = font:getWidth(hint)
        if lw > max_w then max_w = lw end
    end

    local box_w = max_w + PAD * 2
    local box_h = #hints * LINE_H + PAD * 2 - 4
    local margin = 12
    local box_x = x_offset + margin
    local box_y = 720 - margin - box_h

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self._hud_panel, box_x, box_y, 0,
        box_w / self._hud_panel:getWidth(),
        box_h / self._hud_panel:getHeight())

    love.graphics.setColor(0.1, 0.1, 0.1, 1)
    for i, hint in ipairs(hints) do
        love.graphics.print(hint, box_x + PAD, box_y + PAD + (i - 1) * LINE_H)
    end

    love.graphics.setFont(prev_font)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Forwards to Scene:on_exit() (clears self.drawer) -- GameScene doesn't chain
-- its metatable to Scene, so without this override, SceneManager:switch's
-- `self._prev:on_exit()` call fails outright once something can actually
-- switch away from a live GameScene (previously only possible by quitting
-- the whole app, which never went through SceneManager).
function GameScene:on_exit()
    for _, name in ipairs(self._bg_list) do
        Sound.stop_music(name)
    end
    Scene.on_exit(self)
end

-- Moves a fully-faded (or, per GameScene:to_save(), forcibly-collapsed)
-- solved active_puzzles entry onto the completed-puzzles shelf: computes its
-- shelf position (wrapping to a new row if needed), builds the shelved
-- draw-able, appends it to self.completed_puzzles, adds it to the drawer,
-- and advances the shelf-row cursor. Does NOT remove `entry` from
-- self.active_puzzles -- callers are responsible for that.
function GameScene:_shelve(entry)
    local width = entry.cols * C.SLOT
    local height = entry.rows * C.SLOT

    -- Wrap to a new row once the current row's cumulative
    -- width would exceed the world width. Never wrap an
    -- empty row, even if a single puzzle is wider than the
    -- world, to avoid an infinite-wrap loop.
    if self.shelf_row_x > 0 and self.shelf_row_x + width > self.world_w then
        self.shelf_row_bottom = self.shelf_row_bottom - self.shelf_row_max_height - C.SLOT
        self.shelf_row_x = 0
        self.shelf_row_max_height = 0
    end

    local x = self.shelf_row_x
    local y = self.shelf_row_bottom - height

    local entry_shader = Shader.load("assets/shaders/rounded_corners.frag")
    entry_shader:send("size", {width, height})
    entry_shader:send("uv_rect", {0, 0, 1, 1})

    local shelved = {
        image = entry.image,
        x = x,
        y = y,
        cols = entry.cols,
        rows = entry.rows,
        shader = entry_shader,
        path = entry.path,
        draw = function(self)
            love.graphics.setShader(self.shader)
            love.graphics.draw(self.image, self.x, self.y)
            love.graphics.setShader()
        end,
    }
    self.completed_puzzles[#self.completed_puzzles + 1] = shelved
    self.drawer:add(shelved, C.PRIORITY_SHELF)

    self.shelf_row_x = self.shelf_row_x + width + C.SLOT
    self.shelf_row_max_height = math.max(self.shelf_row_max_height, height)
end

function GameScene:to_save()
    -- Per the design doc's confirmed "collapse to shelved" behavior: any
    -- active_puzzles entry that was already detected solved (GameState's
    -- solved_count already counts it) but whose pieces are still mid-fade
    -- must be shelved right now, exactly as if its fade had finished this
    -- instant -- otherwise it would silently vanish from the save entirely
    -- while still being counted as solved.
    local shelved_paths = {}
    for _, entry in ipairs(self.active_puzzles) do
        if entry.solved then
            self:_shelve(entry)
            shelved_paths[entry.path] = true
        end
    end

    -- Any box whose puzzle was just shelved above must not be saved as if
    -- it were still active -- same as it would be removed on the next real
    -- update() tick once its pieces finished fading.
    for i = #self.boxes, 1, -1 do
        if shelved_paths[self.boxes[i].path] then
            table.remove(self.boxes, i)
        end
    end

    local pieces = {}
    for _, piece in ipairs(self.pieces) do
        if piece.state == "grounded" then
            pieces[#pieces + 1] = piece:to_save()
        end
    end

    local boxes = {}
    for _, box in ipairs(self.boxes) do
        boxes[#boxes + 1] = box:to_save()
    end

    local completed_puzzles = {}
    for _, shelved in ipairs(self.completed_puzzles) do
        completed_puzzles[#completed_puzzles + 1] = {
            path = shelved.path,
            x = shelved.x,
            y = shelved.y,
            cols = shelved.cols,
            rows = shelved.rows,
        }
    end

    -- Puzzles still in progress must be saved explicitly -- their
    -- completion tracking can't be re-derived from self.boxes alone on
    -- restore, since a box is removed the moment its last piece ejects,
    -- well before the puzzle is actually solved. Image isn't saved -- like
    -- completed_puzzles above, it's reloaded from `path` via
    -- love.graphics.newImage on restore.
    local active_puzzles = {}
    for _, entry in ipairs(self.active_puzzles) do
        if not entry.solved then
            active_puzzles[#active_puzzles + 1] = {
                path = entry.path,
                tier = entry.tier,
                cols = entry.cols,
                rows = entry.rows,
                piece_count = entry.piece_count,
            }
        end
    end

    return {
        player = {
            x = self.player.sprite.x,
            y = self.player.sprite.y,
            held_piece = (self.player.held_piece and self.player.held_piece:to_save() or nil),
        },
        pieces = pieces,
        boxes = boxes,
        completed_puzzles = completed_puzzles,
        active_puzzles = active_puzzles,
        shelf_row_x = self.shelf_row_x,
        shelf_row_bottom = self.shelf_row_bottom,
        shelf_row_max_height = self.shelf_row_max_height,
    }
end

return GameScene
