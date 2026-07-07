local Sprite = {}
Sprite.__index = Sprite

function Sprite.new(x, y, w, h)
    local self    = setmetatable({}, Sprite)
    self.x        = x or 0
    self.y        = y or 0
    self.width    = w or 32
    self.height   = h or 32
    self.scale_x  = 1
    self.scale_y  = 1
    self.rotation = 0
    self.visible  = true
    self.color    = {1, 1, 1, 1}
    self.shader   = nil
    self.image    = nil
    self.quad     = nil
    return self
end

function Sprite:draw()
    if not self.visible then return end
    love.graphics.push()
    love.graphics.translate(self.x + self.width / 2, self.y + self.height / 2)
    love.graphics.rotate(self.rotation)
    love.graphics.scale(self.scale_x, self.scale_y)
    if self.shader then love.graphics.setShader(self.shader) end
    love.graphics.setColor(self.color)
    if self.image then
        if self.quad then
            local qw, qh
            if self.quad.getViewport then
                local _, _, vw, vh = self.quad:getViewport()
                qw, qh = vw, vh
            elseif self.quad.getWidth and self.quad.getHeight then
                qw, qh = self.quad:getWidth(), self.quad:getHeight()
            else
                qw, qh = self.image:getWidth(), self.image:getHeight()
            end
            local sx = self.width  / qw
            local sy = self.height / qh
            love.graphics.draw(self.image, self.quad, -self.width / 2, -self.height / 2, 0, sx, sy)
        else
            local sx = self.width  / self.image:getWidth()
            local sy = self.height / self.image:getHeight()
            love.graphics.draw(self.image, -self.width / 2, -self.height / 2, 0, sx, sy)
        end
    else
        love.graphics.rectangle("fill", -self.width / 2, -self.height / 2, self.width, self.height)
    end
    if self.shader then love.graphics.setShader() end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.pop()
end

function Sprite:update(dt) end

return Sprite
