local M = {}

local list = {}
local rand = love.math.random

function M.clear()
  list = {}
end

-- opts: speed, spread (radians around dir), dir, life, grav, size, color {r,g,b}, glow
function M.burst(x, y, n, opts)
  local speed = opts.speed or 40
  local dir = opts.dir or 0
  local spread = opts.spread or math.pi * 2
  local life = opts.life or 0.5
  local c = opts.color or { 1, 1, 1 }
  for _ = 1, n do
    local a = dir + (rand() - 0.5) * spread
    local s = speed * (0.4 + rand() * 0.8)
    list[#list + 1] = {
      x = x + (rand() - 0.5) * (opts.jitter or 0), y = y,
      vx = math.cos(a) * s, vy = math.sin(a) * s,
      life = life * (0.6 + rand() * 0.6), max = life,
      grav = opts.grav or 0, drag = opts.drag or 0,
      size = opts.size or 1, r = c[1], g = c[2], b = c[3], glow = opts.glow,
    }
  end
end

function M.update(dt)
  for i = #list, 1, -1 do
    local p = list[i]
    p.life = p.life - dt
    if p.life <= 0 then
      list[i] = list[#list]
      list[#list] = nil
    else
      p.vy = p.vy + p.grav * dt
      local k = math.max(0, 1 - p.drag * dt)
      p.vx, p.vy = p.vx * k, p.vy * k
      p.x = p.x + p.vx * dt
      p.y = p.y + p.vy * dt
    end
  end
end

function M.draw()
  local gfx = love.graphics
  for _, p in ipairs(list) do
    local a = math.min(1, p.life / p.max * 1.5)
    gfx.setBlendMode(p.glow and 'add' or 'alpha')
    gfx.setColor(p.r, p.g, p.b, a)
    local s = p.size
    gfx.rectangle('fill', math.floor(p.x - s / 2 + 0.5), math.floor(p.y - s / 2 + 0.5), s, s)
  end
  gfx.setBlendMode('alpha')
end

return M
