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
    return self
end

function GameScene:on_enter()
    local WORLD_W = 20 * C.SLOT  -- 1280px
    local WORLD_H = 10 * C.SLOT  -- 640px

    self.world_w = WORLD_W
    self.world_h = WORLD_H

    local GROUND_Y = 4 * C.SLOT  -- 256, grid-aligned so pieces rest at 3*SLOT=192

    self.player = Player.new(0, GROUND_Y - C.SLOT, self._input_assignments and self._input_assignments.p1)
    self.drawer:add(self.player, 10)

    self.background = {
        image = love.graphics.newImage("assets/backgrounds/world_bg.png"),
        draw = function(self)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(self.image, C.BG_OFFSET_X, C.BG_OFFSET_Y)
        end,
    }
    self.drawer:add(self.background, -1)

    self.floor = {
        draw = function()
            local cols = WORLD_W / C.SLOT
            local rows = WORLD_H / C.SLOT
            for row = 0, rows - 1 do
                for col = 0, cols - 1 do
                    if (row + col) % 2 == 0 then
                        love.graphics.setColor(0.55, 0.55, 0.55, 1)
                    else
                        love.graphics.setColor(0.45, 0.45, 0.45, 1)
                    end
                    love.graphics.rectangle("fill", col * C.SLOT, row * C.SLOT, C.SLOT, C.SLOT)
                end
            end
            love.graphics.setColor(1, 1, 1, 1)
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

    self.view1 = "play"
    self.wall_target1 = nil
    if GameState.player_count == 2 then
        self.wall_tile2 = WallViewTile.new(WORLD_W - C.SLOT, 0, function() self:_toggle_wall_view("p2") end)
        self.view2 = "play"
        self.wall_target2 = nil
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
    for _, box in ipairs(self.boxes) do
        local was_flying = box.state == "flying"
        box:update(dt, self.pieces)
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
        self.wall_tile, self.view1 == "wall")
    if self.player2 then
        self.player2:update(dt, self.pieces, self.boxes, self.pile, self.drawer,
            self.wall_tile2, self.view2 == "wall")
    end

    for _, entry in ipairs(self.active_puzzles) do
        if not entry.solved and JigsawSolver.is_assembled(entry.pieces, entry.piece_count) then
            entry.solved = true
            Sound.play("puzzle_complete")
            GameState:puzzle_solved(entry.tier)
            for _, piece in ipairs(entry.pieces) do
                piece:start_vanish()
            end
        end
    end

    for i = #self.pieces, 1, -1 do
        local piece = self.pieces[i]
        if piece.state == "vanishing" then
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
        self.camera:follow(self.wall_target1, 0.85)
    else
        local c = self.player:centre()
        self.camera:follow({x = c.x, y = c.y, zoom = 1.0}, 0.85)
    end
    if self.camera2 then
        if self.view2 == "wall" then
            self.camera2:follow(self.wall_target2, 0.85)
        else
            local c2 = self.player2:centre()
            self.camera2:follow({x = c2.x, y = c2.y, zoom = 1.0}, 0.85)
        end
    end
end

-- Flips the given player's ("p1"/"p2") view between "play" and "wall".
-- Entering "wall" computes a target camera center/zoom that fits the full
-- bounding box of self.completed_puzzles on screen (see
-- docs/design/wall-view-tile.md); a no-op if nothing has been shelved yet,
-- since there's no bounding box to fit.
function GameScene:_toggle_wall_view(which)
    local view_key = (which == "p2") and "view2" or "view1"
    local target_key = (which == "p2") and "wall_target2" or "wall_target1"

    if self[view_key] == "wall" then
        self[view_key] = "play"
        return
    end

    if #self.completed_puzzles == 0 then
        return
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

    local bbox_w = max_x - min_x
    local bbox_h = max_y - min_y
    local zoom = math.min(1.0, 0.9 * math.min(LOGICAL_W / bbox_w, LOGICAL_H / bbox_h))

    self[target_key] = {
        x = (min_x + max_x) / 2,
        y = (min_y + max_y) / 2,
        zoom = zoom,
    }
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

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("WASD: move   E: pick up / drop   R: rotate   ESC / Start: settings", 16, 16)
    local c = self.player:centre()
    love.graphics.print(string.format("player (%.0f, %.0f)", c.x, c.y), 16, 36)
    if self.camera2 then
        local c2 = self.player2:centre()
        love.graphics.print(string.format("player (%.0f, %.0f)", c2.x, c2.y), 656, 36)
    end
end

-- Forwards to Scene:on_exit() (clears self.drawer) -- GameScene doesn't chain
-- its metatable to Scene, so without this override, SceneManager:switch's
-- `self._prev:on_exit()` call fails outright once something can actually
-- switch away from a live GameScene (previously only possible by quitting
-- the whole app, which never went through SceneManager).
function GameScene:on_exit()
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
