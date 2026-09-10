local AnimatedSprite = {}
AnimatedSprite.__index = AnimatedSprite

function AnimatedSprite.new(x, y, w, h, image, frame_count, fps)
    local self       = setmetatable({}, AnimatedSprite)
    self.x           = x or 0
    self.y           = y or 0
    self.width       = w or 32
    self.height      = h or 32
    self.scale_x     = 1
    self.scale_y     = 1
    self.visible     = true
    self.color       = {1, 1, 1, 1}
    self.image       = image
    self.frame_count = frame_count or 1
    self.fps         = fps or 8
    self.frame       = 1
    self._t          = 0
    return self
end

function AnimatedSprite:update(dt)
    self._t = self._t + dt
    local frame_dur = 1 / self.fps
    while self._t >= frame_dur do
        self._t = self._t - frame_dur
        self.frame = self.frame % self.frame_count + 1
    end
end

function AnimatedSprite:draw()
    if not self.visible then return end
    if not self.image then return end
    local iw = self.image:getWidth()
    local ih = self.image:getHeight()
    local fw = iw / self.frame_count
    local quad = love.graphics.newQuad((self.frame - 1) * fw, 0, fw, ih, iw, ih)
    local sx = self.width / fw * self.scale_x
    local sy = self.height / ih * self.scale_y
    love.graphics.setColor(self.color)
    -- pivot at sprite centre so scale_x=-1 flips around centre
    local cx = self.x + self.width / 2
    local cy = self.y + self.height / 2
    love.graphics.draw(self.image, quad, cx, cy, 0, sx, sy, fw / 2, ih / 2)
    love.graphics.setColor(1, 1, 1, 1)
end

return AnimatedSprite
