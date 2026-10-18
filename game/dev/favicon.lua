local Render = require 'gfx.render'

local Favicon = {}

local SIZE = 20
local SCALES = { 2, 9 }

-- Draws the player with the game's own procedural art on a transparent
-- SIZE x SIZE canvas and saves nearest-neighbour upscales for the dev blog.
function Favicon.run()
  Render.t = 0.35
  local canvas = love.graphics.newCanvas(SIZE, SIZE)
  canvas:setFilter('nearest', 'nearest')
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)
  Render.drawPlayer({ x = SIZE / 2 - 5, y = SIZE - 13, w = 10, h = 12, sx = 1, sy = 1, facing = 1, vx = 0, vy = 0, state = 'ground' })
  love.graphics.setCanvas()
  local base = canvas:newImageData()
  for _, k in ipairs(SCALES) do
    local out = love.image.newImageData(SIZE * k, SIZE * k)
    out:mapPixel(function(x, y) return base:getPixel(math.floor(x / k), math.floor(y / k)) end)
    local name = ('favicon-%d.png'):format(SIZE * k)
    out:encode('png', name)
    print('FAVICON ' .. love.filesystem.getSaveDirectory() .. '/' .. name)
  end
  io.stdout:flush()
  return true
end

return Favicon
