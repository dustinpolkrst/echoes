local Level = require 'world.level'
local Echo = require 'world.echo'
local Assets = require 'platform.assets'

local gfx = love.graphics
local TILES = Level.TILES
local T = Level.T
local floor, sin, cos, pi, min, max = math.floor, math.sin, math.cos, math.pi, math.min, math.max

local R = { W = 480, H = 270, scale = 2, ox = 0, oy = 0 }

local AMBIENT = { 0.26, 0.25, 0.46 }
local PLATE_COLORS = { { 0.35, 0.95, 1 }, { 1, 0.45, 0.85 }, { 1, 0.85, 0.35 }, { 0.55, 1, 0.5 } }
local MIRROR = { 0.8, 0.5, 1 }
local VEIL = { 1, 0.72, 0.3 }
local BEACON = { 0.6, 1, 0.8 }
-- idle: the alpha while the tile is not active (checkpoints); the light carries its cell for that.
local LIGHTS = {
  torch = { color = { 1, 0.58, 0.25 }, flicker = 3, alpha = 0.92 },
  goal = { color = { 0.55, 1, 0.95 }, breathe = 3, alpha = 0.95 },
  mirror = { color = MIRROR, breathe = 4, alpha = 0.8 },
  veil = { color = VEIL, breathe = 2, alpha = 0.5 },
  checkpoint = { color = BEACON, breathe = 3, alpha = 0.85, idle = 0.18 },
}

local function lightAlpha(spec, l)
  if spec.idle and not l.cell.active then return spec.idle end
  return spec.alpha
end

local function hash(x, y)
  local n = sin(x * 12.9898 + y * 78.233) * 43758.5453
  return n - floor(n)
end

local function clamp(v, lo, hi) return max(lo, min(hi, v)) end
local function lerp(a, b, f) return a + (b - a) * f end

function R.init()
  if Assets.version == 0 then Assets.load() end
  R.game = gfx.newCanvas(R.W, R.H)
  R.game:setFilter('nearest', 'nearest')
  R.lightmap = gfx.newCanvas(R.W, R.H)

  local size = 128
  local data = love.image.newImageData(size, size)
  data:mapPixel(function(x, y)
    local d = math.sqrt((x - size / 2 + 0.5) ^ 2 + (y - size / 2 + 0.5) ^ 2) / (size / 2)
    local v = max(0, 1 - d)
    return 1, 1, 1, v * v
  end)
  R.glowImg = gfx.newImage(data)
  R.glowImg:setFilter('linear', 'linear')

  R.t = 0
end

local function glow(x, y, r, cr, cg, cb, a)
  gfx.setColor(cr, cg, cb, a)
  gfx.draw(R.glowImg, x - r, y - r, 0, 2 * r / 128, 2 * r / 128)
end
R.glow = glow

-- Sprite slots -------------------------------------------------------------

local scratchQuad = gfx.newQuad(0, 0, 1, 1, 1, 1)

-- Draws the slot's sprite and returns true, or returns false when no file exists so the caller
-- runs its procedural drawing. opts: frame, v (0..1 variant pick), flip (+-1), sx, sy, tint, alpha, crop (visible height).
local function drawSlot(name, x, y, o)
  local s = Assets.sprite(name)
  if not s then return false end
  o = o or {}
  local n = #s.quads
  local i = o.frame
  if not i then
    if s.mode == 'variant' then i = floor((o.v or 0) * n) + 1
    elseif s.fps > 0 then i = floor(R.t * s.fps) % n + 1
    else i = 1 end
  end
  local quad = s.quads[min(i, n)]
  if o.crop then
    local qx, qy, qw = quad:getViewport()
    scratchQuad:setViewport(qx, qy, qw, o.crop, s.iw, s.ih)
    quad = scratchQuad
  end
  local c = o.tint
  gfx.setColor(c and c[1] or 1, c and c[2] or 1, c and c[3] or 1, o.alpha or 1)
  gfx.draw(s.image, quad, x, y, 0, (o.sx or 1) * (o.flip or 1), o.sy or 1, s.ox, s.oy)
  return true
end

-- Wraps a tile's procedural draw so a sprite file, when present, takes its place.
local function withSlot(name, procedural, optsFor)
  return function(world, c, x, y, t)
    if not drawSlot(name, x, y, optsFor and optsFor(c)) then procedural(world, c, x, y, t) end
  end
end

-- Tile drawing -------------------------------------------------------------

local function isStone(world, tx, ty)
  local c = world:cell(tx, ty)
  return c and c.kind == 'solid'
end

local function moss(tx, ty, x, y, width, depth)
  for px = 0, width - 1 do
    local h = hash(tx * 16 + px, ty)
    if h > 0.42 then
      local g = hash(px, ty * 7 + tx)
      gfx.setColor(0.18 + g * 0.12, 0.45 + g * 0.2, 0.30 + g * 0.1)
      local d = 1 + floor(h * depth * 1.6)
      gfx.rectangle('fill', x + px, y, 1, min(d, depth))
      if h > 0.78 then
        gfx.setColor(0.32, 0.72, 0.45)
        gfx.rectangle('fill', x + px, y - 1, 1, 1)
      end
    end
  end
end

local function proceduralSolid(world, c, x, y)
  local tx, ty = c.tx, c.ty
  local h = hash(tx, ty)
  local b = 0.19 + h * 0.05
  gfx.setColor(b, b, b * 1.62)
  gfx.rectangle('fill', x, y, T, T)

  gfx.setColor(0.08, 0.08, 0.18, 0.35)
  gfx.rectangle('fill', x, y + 7, T, 1)
  local joint = (ty % 2 == 0) and 4 or 11
  gfx.rectangle('fill', x + joint, y, 1, 7)
  gfx.rectangle('fill', x + (joint + 7) % 16, y + 8, 1, 8)

  for i = 1, 3 do
    local sx, sy = floor(hash(tx + i, ty) * 15), floor(hash(tx, ty + i * 3) * 15)
    local s = hash(sx, sy)
    if s > 0.5 then gfx.setColor(0.4, 0.4, 0.62, 0.18) else gfx.setColor(0.05, 0.05, 0.14, 0.3) end
    gfx.rectangle('fill', x + sx, y + sy, 1, 1)
  end

  local up, down = isStone(world, tx, ty - 1), isStone(world, tx, ty + 1)
  local left, right = isStone(world, tx - 1, ty), isStone(world, tx + 1, ty)
  if not up then
    gfx.setColor(0.42, 0.42, 0.64)
    gfx.rectangle('fill', x, y, T, 1)
    gfx.setColor(0.31, 0.31, 0.5)
    gfx.rectangle('fill', x, y + 1, T, 1)
  end
  if not left then
    gfx.setColor(0.36, 0.36, 0.56)
    gfx.rectangle('fill', x, y, 1, T)
  end
  if not right then
    gfx.setColor(0.07, 0.07, 0.16)
    gfx.rectangle('fill', x + T - 1, y, 1, T)
  end
  if not down then
    gfx.setColor(0.06, 0.06, 0.15)
    gfx.rectangle('fill', x, y + T - 2, T, 2)
  end
  if not up then moss(tx, ty, x, y + 2, T, 3) end
  if h > 0.86 and up then
    gfx.setColor(0.05, 0.05, 0.14, 0.7)
    gfx.rectangle('fill', x + 5, y + 3, 1, 3)
    gfx.rectangle('fill', x + 6, y + 6, 1, 3)
    gfx.rectangle('fill', x + 7, y + 9, 1, 2)
  end
end

local function proceduralOneway(world, c, x, y)
  local tx, ty = c.tx, c.ty
  gfx.setColor(0.30, 0.30, 0.50)
  gfx.rectangle('fill', x, y, T, 5)
  gfx.setColor(0.45, 0.45, 0.68)
  gfx.rectangle('fill', x, y, T, 1)
  gfx.setColor(0.10, 0.10, 0.22)
  gfx.rectangle('fill', x, y + 4, T, 1)
  gfx.setColor(0.2, 0.2, 0.36)
  gfx.rectangle('fill', x + 3, y + 5, 2, 2)
  gfx.rectangle('fill', x + 11, y + 5, 2, 2)
  moss(tx, ty, x, y + 1, T, 2)
end

local function proceduralSpike(world, c, x, y)
  for i = 0, 2 do
    local bx = x + 1 + i * 5
    gfx.setColor(0.62, 0.42, 0.62)
    gfx.polygon('fill', bx, y + 16, bx + 2.5, y + 7, bx + 2.5, y + 16)
    gfx.setColor(1, 0.78, 0.88)
    gfx.polygon('fill', bx + 2.5, y + 7, bx + 5, y + 16, bx + 2.5, y + 16)
  end
  gfx.setColor(0.12, 0.12, 0.24)
  gfx.rectangle('fill', x, y + 14, T, 2)
end

local function proceduralTorch(world, c, x, y, t)
  local cx = x + T / 2
  local anchor
  for k = 1, 12 do
    if isStone(world, c.tx, c.ty - k) then anchor = k break end
  end
  gfx.setColor(0.25, 0.24, 0.34)
  if anchor then
    for yy = y - (anchor - 1) * T, y + 4, 3 do
      gfx.rectangle('fill', cx - 0.5 + ((yy / 3) % 2), yy, 1, 2)
    end
  end
  gfx.setColor(0.22, 0.2, 0.3)
  gfx.rectangle('fill', cx - 3, y + 5, 6, 6)
  gfx.setColor(0.4, 0.34, 0.4)
  gfx.rectangle('fill', cx - 3, y + 5, 6, 1)
  gfx.rectangle('fill', cx - 3, y + 10, 6, 1)
  local fl = sin(t * 11 + c.tx * 3.1) * 0.6 + sin(t * 17.3 + c.ty) * 0.4
  gfx.setColor(1, 0.55, 0.15)
  gfx.polygon('fill', cx - 2, y + 10, cx - 1.5, y + 7, cx + fl * 0.8, y + 3 - fl, cx + 1.5, y + 7, cx + 2, y + 10)
  gfx.setColor(1, 0.9, 0.5)
  gfx.polygon('fill', cx - 1, y + 10, cx + fl * 0.4, y + 6, cx + 1, y + 10)
end

local function proceduralGoal(world, c, x, y, t)
  local cx, cy = x + T / 2, y + T / 2
  gfx.setColor(0.55, 0.95, 0.9, 0.9)
  gfx.setLineStyle('rough')
  gfx.setLineWidth(1)
  for i = 0, 2 do
    local r = 7 - i * 2 + sin(t * 3 + i) * 0.8
    gfx.setColor(0.6 + i * 0.15, 1, 0.95, 0.9 - i * 0.2)
    gfx.ellipse('line', cx, cy, r * 0.8, r + 1)
  end
  gfx.setColor(1, 1, 1, 0.9)
  gfx.rectangle('fill', floor(cx), floor(cy + sin(t * 4) * 2), 1, 1)
  for i = 1, 4 do
    local a = t * 1.5 + i * pi / 2
    gfx.setColor(0.8, 1, 0.95, 0.8)
    gfx.rectangle('fill', floor(cx + cos(a) * 9), floor(cy + sin(a) * 11), 1, 1)
  end
end

local function proceduralPlate(world, c, x, y)
  local col = PLATE_COLORS[c.idx]
  local drop = c.pressed and 2 or 0
  gfx.setColor(0.12, 0.12, 0.24)
  gfx.rectangle('fill', x + 1, y + 11, T - 2, 5)
  gfx.setColor(col[1] * 0.55, col[2] * 0.55, col[3] * 0.55)
  gfx.rectangle('fill', x + 2, y + 12 + drop, T - 4, 4 - drop)
  gfx.setColor(col[1], col[2], col[3], c.pressed and 1 or 0.8)
  gfx.rectangle('fill', x + 3, y + 12 + drop, T - 6, 1)
end

local function proceduralMirror(world, c, x, y, t)
  local cx = x + T / 2
  gfx.setColor(0.16, 0.14, 0.26)
  gfx.rectangle('fill', x + 2, y + 13, T - 4, 3)
  gfx.setColor(0.3, 0.26, 0.42)
  gfx.rectangle('fill', x + 3, y + 13, T - 6, 1)
  gfx.setColor(0.2, 0.16, 0.32)
  gfx.rectangle('fill', cx - 4, y - 6, 8, 19)
  local pulse = 0.7 + 0.3 * sin(t * 4 + c.tx)
  gfx.setColor(MIRROR[1] * 0.5, MIRROR[2] * 0.4, MIRROR[3] * 0.7, 0.9)
  gfx.rectangle('fill', cx - 3, y - 5, 6, 17)
  gfx.setColor(MIRROR[1], MIRROR[2], MIRROR[3], pulse)
  gfx.rectangle('fill', cx - 2, y - 4, 4, 15)
  gfx.setColor(1, 0.92, 1, 0.9)
  local sweep = floor((t * 9 + c.tx * 2) % 17)
  gfx.rectangle('fill', cx - 2, y - 4 + sweep, 4, 1)
  gfx.setColor(1, 1, 1, 0.8)
  gfx.rectangle('fill', cx - 1, y - 2, 1, 11)
  gfx.setColor(MIRROR[1], MIRROR[2], MIRROR[3], 0.55)
  gfx.rectangle('fill', cx - 7, y - 7, 1, 1)
  gfx.rectangle('fill', cx + 6, y - 7, 1, 1)
  gfx.rectangle('fill', cx - 6, y + 8, 1, 1)
  gfx.rectangle('fill', cx + 5, y + 8, 1, 1)
end

local function proceduralVeil(world, c, x, y, t)
  gfx.setColor(VEIL[1], VEIL[2], VEIL[3], 0.2)
  gfx.rectangle('fill', x, y, T, T)
  for k = 0, 3 do
    local px = x + 2 + k * 4
    for yy = 0, T - 1 do
      local wave = sin(t * 5 + yy * 0.5 + k * 1.7 + c.tx) * 1.2
      local a = 0.45 + 0.3 * sin(t * 7 + k + yy * 0.3)
      gfx.setColor(VEIL[1], VEIL[2] + 0.15, VEIL[3] + 0.3, a)
      gfx.rectangle('fill', floor(px + wave + 0.5), y + yy, 1, 1)
    end
  end
  local spark = floor((t * 13 + c.tx * 5 + c.ty * 3) % T)
  gfx.setColor(1, 0.97, 0.85, 0.9)
  gfx.rectangle('fill', x + floor(hash(c.tx, c.ty + spark) * (T - 1)), y + spark, 1, 1)
end

local function proceduralCrumble(world, c, x, y, t)
  if c.gone then
    local soon = c.regrow < 0.6 and (0.6 - c.regrow) / 0.6 or 0
    gfx.setColor(0.6, 0.48, 0.3, 0.22 + soon * 0.5)
    gfx.setLineStyle('rough')
    gfx.setLineWidth(1)
    gfx.rectangle('line', x + 1.5, y + 1.5, T - 3, T - 3)
    for k = 0, 2 do
      gfx.rectangle('fill', x + 3 + k * 5, y + 7, 2, 1)
    end
    return
  end
  local shake = c.crack and floor(sin(t * 60 + c.tx) * 1.5 + 0.5) or 0
  x = x + shake
  gfx.setColor(0.36, 0.28, 0.2)
  gfx.rectangle('fill', x, y, T, T)
  gfx.setColor(0.52, 0.42, 0.28)
  gfx.rectangle('fill', x, y, T, 2)
  gfx.setColor(0.18, 0.13, 0.1)
  gfx.rectangle('fill', x, y + T - 2, T, 2)
  gfx.rectangle('fill', x + T - 1, y, 1, T)
  local hot = c.crack and (0.6 + 0.4 * sin(t * 40)) or 0
  gfx.setColor(0.14 + hot * 0.8, 0.1 + hot * 0.6, 0.08 + hot * 0.3)
  gfx.rectangle('fill', x + 7, y + 2, 1, 4)
  gfx.rectangle('fill', x + 8, y + 5, 1, 3)
  gfx.rectangle('fill', x + 6, y + 7, 2, 1)
  gfx.rectangle('fill', x + 5, y + 8, 1, 4)
  gfx.rectangle('fill', x + 9, y + 8, 1, 2)
  gfx.rectangle('fill', x + 10, y + 10, 2, 1)
  gfx.rectangle('fill', x + 12, y + 11, 1, 4)
  gfx.rectangle('fill', x + 2, y + 10, 1, 1)
  gfx.rectangle('fill', x + 3, y + 11, 2, 1)
  gfx.setColor(0.62, 0.5, 0.34, 0.7)
  gfx.rectangle('fill', x + 2, y + 3, 3, 1)
  gfx.rectangle('fill', x + 11, y + 4, 2, 1)
  gfx.rectangle('fill', x + 3, y + 13, 1, 1)
end

-- A waystone: a cairn of three stones with a crystal set in the top one. Dark until touched, then it burns.
local function proceduralCheckpoint(world, c, x, y, t)
  local cx = x + T / 2
  gfx.setColor(0.14, 0.13, 0.24)
  gfx.rectangle('fill', cx - 6, y + 11, 12, 5)
  gfx.setColor(0.2, 0.18, 0.32)
  gfx.rectangle('fill', cx - 5, y + 11, 10, 1)
  gfx.rectangle('fill', cx - 4, y + 6, 8, 5)
  gfx.setColor(0.27, 0.25, 0.4)
  gfx.rectangle('fill', cx - 3, y + 6, 6, 1)
  gfx.rectangle('fill', cx - 3, y + 2, 6, 4)
  gfx.setColor(0.34, 0.32, 0.48)
  gfx.rectangle('fill', cx - 2, y + 2, 4, 1)
  if c.active then
    local pulse = 0.75 + 0.25 * sin(t * 5 + c.tx)
    gfx.setColor(BEACON[1], BEACON[2], BEACON[3], pulse)
    gfx.rectangle('fill', cx - 1, y - 1, 2, 7)
    gfx.rectangle('fill', cx - 2, y + 1, 4, 3)
    gfx.setColor(1, 1, 1, 0.9)
    gfx.rectangle('fill', cx - 1, y + 1, 1, 2)
    local spark = floor((t * 7 + c.tx) % 4)
    gfx.setColor(BEACON[1], BEACON[2], BEACON[3], 0.6)
    gfx.rectangle('fill', cx - 4 + (spark % 2) * 7, y - 3 + floor(spark / 2) * 2, 1, 1)
  else
    gfx.setColor(0.3, 0.42, 0.4, 0.9)
    gfx.rectangle('fill', cx - 1, y, 2, 6)
    gfx.setColor(0.45, 0.6, 0.55, 0.7)
    gfx.rectangle('fill', cx - 1, y + 1, 1, 2)
  end
end

local function variantOf(c) return { v = hash(c.tx, c.ty) } end

TILES.solid.draw = withSlot('solid', proceduralSolid, variantOf)
TILES.oneway.draw = withSlot('oneway', proceduralOneway, variantOf)
TILES.spike.draw = withSlot('spike', proceduralSpike)
TILES.torch.draw = withSlot('torch', proceduralTorch)
TILES.goal.draw = withSlot('goal', proceduralGoal)
TILES.plate.draw = withSlot('plate', proceduralPlate, function(c)
  return { frame = c.pressed and 2 or 1, tint = PLATE_COLORS[c.idx] }
end)
TILES.mirror.draw = withSlot('mirror', proceduralMirror)
TILES.veil.draw = withSlot('veil', proceduralVeil)
TILES.crumble.draw = withSlot('crumble', proceduralCrumble, function(c)
  return { frame = c.gone and 3 or c.crack and 2 or 1 }
end)
TILES.checkpoint.draw = withSlot('checkpoint', proceduralCheckpoint, function(c)
  return { frame = c.active and 2 or 1 }
end)

-- Doors span several cells, so each door piece is drawn as one slab rather than per tile.
local function drawDoor(cells, open)
  local col = PLATE_COLORS[cells[1].idx]
  local x0, y0, x1, y1 = math.huge, math.huge, 0, 0
  for _, c in ipairs(cells) do
    x0, y0 = min(x0, c.tx * T), min(y0, c.ty * T)
    x1, y1 = max(x1, (c.tx + 1) * T), max(y1, (c.ty + 1) * T)
  end
  local hatch = x1 - x0 > y1 - y0
  local span = hatch and x1 - x0 or y1 - y0
  local vis = floor(span * (1 - open) + 0.5)
  if Assets.sprite('door') then
    for _, c in ipairs(cells) do
      local along = hatch and c.tx * T - x0 or c.ty * T - y0
      local visible = clamp(vis - along, 0, T)
      if hatch and visible >= T or not hatch and visible > 0 then
        drawSlot('door', c.tx * T, c.ty * T, { crop = hatch and T or visible, tint = col })
      end
    end
    return
  end
  local pulse = 0.65 + 0.35 * sin(R.t * 3 + cells[1].idx)
  if hatch then
    local h = y1 - y0
    gfx.setColor(0.09, 0.09, 0.2)
    gfx.rectangle('fill', x0, y0, 3, h)
    if vis > 0 then
      gfx.setColor(0.26, 0.23, 0.36)
      gfx.rectangle('fill', x0, y0 + 1, vis, h - 2)
      gfx.setColor(0.36, 0.33, 0.5)
      gfx.rectangle('fill', x0, y0 + 1, vis, 1)
      gfx.setColor(0.13, 0.11, 0.22)
      gfx.rectangle('fill', x0, y1 - 2, vis, 1)
      for xx = x0 + 8, x0 + vis - 2, T do
        gfx.rectangle('fill', xx, y0 + 1, 1, h - 2)
      end
      gfx.setColor(col[1], col[2], col[3], pulse)
      gfx.rectangle('fill', x0 + 4, y0 + 7, max(0, vis - 8), 2)
      gfx.rectangle('fill', x0 + floor(vis / 2) - 1, y0 + 4, 2, 8)
      gfx.setColor(col[1], col[2], col[3])
      gfx.rectangle('fill', x0 + vis - 2, y0 + 1, 2, h - 2)
    end
    if open > 0 then
      gfx.setColor(col[1], col[2], col[3], 0.22 * open)
      gfx.rectangle('fill', x0, y0 + 1, x1 - x0, 1)
      gfx.rectangle('fill', x0, y1 - 2, x1 - x0, 1)
    end
    return
  end
  gfx.setColor(0.09, 0.09, 0.2)
  gfx.rectangle('fill', x0, y0, T, 3)
  if vis > 0 then
    gfx.setColor(0.26, 0.23, 0.36)
    gfx.rectangle('fill', x0 + 1, y0, T - 2, vis)
    gfx.setColor(0.36, 0.33, 0.5)
    gfx.rectangle('fill', x0 + 1, y0, 1, vis)
    gfx.setColor(0.13, 0.11, 0.22)
    gfx.rectangle('fill', x0 + T - 2, y0, 1, vis)
    for yy = y0 + 8, y0 + vis - 2, T do
      gfx.rectangle('fill', x0 + 1, yy, T - 2, 1)
    end
    gfx.setColor(col[1], col[2], col[3], pulse)
    gfx.rectangle('fill', x0 + 7, y0 + 4, 2, max(0, vis - 8))
    gfx.rectangle('fill', x0 + 4, y0 + floor(vis / 2) - 1, 8, 2)
    gfx.setColor(col[1], col[2], col[3])
    gfx.rectangle('fill', x0 + 1, y0 + vis - 2, T - 2, 2)
  end
  if open > 0 then
    gfx.setColor(col[1], col[2], col[3], 0.22 * open)
    gfx.rectangle('fill', x0 + 1, y0, 1, y1 - y0)
    gfx.rectangle('fill', x0 + T - 2, y0, 1, y1 - y0)
    gfx.setColor(col[1], col[2], col[3], 0.8 * open)
    gfx.rectangle('fill', x0 + 6, y0 + 3, 4, 2)
  end
end

-- Level layer --------------------------------------------------------------

local function bake(world)
  local canvas = gfx.newCanvas(world.W * T, world.H * T)
  canvas:setFilter('nearest', 'nearest')
  gfx.push('all')
  gfx.setCanvas(canvas)
  gfx.clear(0, 0, 0, 0)
  gfx.origin()
  for ty = 0, world.H - 1 do
    for tx = 0, world.W - 1 do
      local c = world.cells[ty][tx]
      if c and TILES[c.kind].static then
        TILES[c.kind].draw(world, c, tx * T, ty * T, 0)
      end
    end
  end
  gfx.pop()
  return canvas
end

-- A letter can mark several separate doors that share a plate. Each 4-connected run of its cells is one piece,
-- listed in map order so every run draws them in the same order.
local NEIGHBOURS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

local function doorPieces(world)
  local pieces, seen = {}, {}
  for ty = 0, world.H - 1 do
    for tx = 0, world.W - 1 do
      local c = world.cells[ty][tx]
      if c and c.kind == 'door' and not seen[c] then
        local cells, stack = {}, { c }
        seen[c] = true
        while #stack > 0 do
          local d = table.remove(stack)
          cells[#cells + 1] = d
          for _, n in ipairs(NEIGHBOURS) do
            local row = world.cells[d.ty + n[2]]
            local e = row and row[d.tx + n[1]]
            if e and e.kind == 'door' and e.id == c.id and not seen[e] then
              seen[e] = true
              stack[#stack + 1] = e
            end
          end
        end
        table.sort(cells, function(a, b) return a.ty < b.ty or a.ty == b.ty and a.tx < b.tx end)
        pieces[#pieces + 1] = { id = c.id, cells = cells }
      end
    end
  end
  return pieces
end

local viewsByWorld = setmetatable({}, { __mode = 'k' })

local function view(world)
  local v = viewsByWorld[world]
  if not v then
    v = { doors = {}, pieces = doorPieces(world) }
    viewsByWorld[world] = v
  end
  return v
end

local function layer(world)
  local v = view(world)
  if v.version ~= Assets.version then
    v.canvas, v.version = bake(world), Assets.version
  end
  return v.canvas
end

function R.update(world, dt)
  R.t = R.t + dt
  local doors = view(world).doors
  for id, open in pairs(world.doorOpen) do
    local target = open and 1 or 0
    local cur = doors[id] or 0
    doors[id] = cur + clamp(target - cur, -dt * 3, dt * 3)
  end
end

-- Backgrounds --------------------------------------------------------------

local function bgGradient()
  local bands = 27
  for i = 0, bands - 1 do
    local f = i / (bands - 1)
    gfx.setColor(lerp(0.05, 0.12, f), lerp(0.045, 0.09, f), lerp(0.13, 0.26, f))
    gfx.rectangle('fill', 0, i * 10, R.W, 10)
  end
end

local function drawArches(camx, camy)
  local period, par = 150, 0.12
  local k0 = floor(camx * par / period) - 1
  gfx.setLineStyle('rough')
  for k = k0, k0 + floor(R.W / period) + 3 do
    local h = hash(k, 3)
    local x = k * period - camx * par
    local baseY = 262 - camy * 0.08
    local pillarH = 70 + h * 70
    local top = baseY - pillarH
    local span = 78
    gfx.setColor(0.12, 0.11, 0.25)
    gfx.rectangle('fill', x, top, 12, pillarH)
    gfx.rectangle('fill', x - 2, top, 16, 4)
    if hash(k, 9) > 0.25 then
      gfx.rectangle('fill', x + span, top + 10, 12, pillarH - 10)
      gfx.rectangle('fill', x + span - 2, top + 10, 16, 4)
    end
    gfx.setColor(0.14, 0.13, 0.29)
    gfx.setLineWidth(7)
    local cx = x + 6 + span / 2
    local sweep = hash(k, 5) > 0.35 and pi or pi * (0.35 + hash(k, 6) * 0.4)
    gfx.arc('line', 'open', cx, top, span / 2, pi, pi + sweep)
    gfx.setColor(0.09, 0.085, 0.2)
    gfx.rectangle('fill', x - 4, baseY - 6, span + 20, 40)
  end
  gfx.setLineWidth(1)
end

local function drawHangings(camx, camy, t)
  local spacing, par = 47, 0.35
  local k0 = floor(camx * par / spacing) - 1
  for k = k0, k0 + floor(R.W / spacing) + 3 do
    local h = hash(k, 17)
    local x = k * spacing + h * 20 - camx * par
    local len = 30 + hash(k, 4) * 90
    local y0 = -camy * par - 4
    local vine = hash(k, 8) > 0.5
    for j = 0, floor(len / 5) do
      local sway = sin(t * 0.9 + k + j * 0.18) * j * 0.12
      if vine then
        gfx.setColor(0.10, 0.27, 0.24)
        gfx.rectangle('fill', floor(x + sway + sin(j * 0.9 + k) * 2), floor(y0 + j * 5), 1, 5)
        if j % 3 == 1 then
          gfx.setColor(0.13, 0.36, 0.30)
          gfx.rectangle('fill', floor(x + sway + (j % 2 == 0 and 2 or -3)), floor(y0 + j * 5), 2, 1)
        end
      else
        gfx.setColor(0.2, 0.2, 0.35)
        gfx.rectangle('fill', floor(x + sway), floor(y0 + j * 5), j % 2 == 0 and 3 or 1, 4)
      end
    end
  end
end

-- Tiles the image horizontally at its slot's parallax. Returns false when the slot has no file.
local function drawBgSlot(name, camx, camy)
  local s = Assets.sprite(name)
  if not s then return false end
  local y = s.valign == 'bottom' and R.H - s.h or 0
  y = floor(y - camy * s.vpar)
  local x = -floor(camx * s.par) % s.w - s.w
  while x < R.W do
    drawSlot(name, x, y)
    x = x + s.w
  end
  return true
end

function R.drawBackground(camx, camy, t)
  gfx.setBlendMode('alpha')
  if not drawBgSlot('bg_far', camx, camy) then bgGradient() end
  if not drawBgSlot('bg_mid', camx, camy) then drawArches(camx, camy) end
  if not drawBgSlot('bg_near', camx, camy) then drawHangings(camx, camy, t) end
end

function R.drawMotes(camx, camy, t)
  gfx.setBlendMode('add')
  for i = 1, 46 do
    local depth = 1.15 + hash(i, 1) * 0.5
    local x = (hash(i, 2) * 560 - camx * depth + t * (3 + hash(i, 3) * 6)) % 560 - 40
    local y = (hash(i, 4) * 330 - camy * depth - t * (2 + hash(i, 5) * 3) + sin(t * 0.6 + i) * 8) % 330 - 30
    local a = 0.12 + hash(i, 6) * 0.3
    gfx.setColor(0.65, 0.75, 1, a)
    local s = hash(i, 7) > 0.8 and 2 or 1
    gfx.rectangle('fill', floor(x), floor(y), s, s)
  end
  gfx.setBlendMode('alpha')
end

-- Actors -------------------------------------------------------------------

function R.drawPlayer(p, alpha)
  if p.state == 'dead' then return end
  alpha = alpha or 1
  local t = R.t
  gfx.push()
  gfx.translate(floor(p.x + p.w / 2 + 0.5), floor(p.y + p.h + 0.5))
  gfx.scale(p.sx, p.sy)
  if drawSlot('player', 0, 0, { flip = p.facing, alpha = alpha }) then
    gfx.pop()
    return
  end
  local lean = clamp(-p.vx * 0.045, -4, 4)
  local rise = clamp(p.vy * 0.012, -3, 3)
  local fl = sin(t * 14) * 0.7 + sin(t * 23) * 0.5
  local tip = -17 - fl + rise
  gfx.setColor(1, 0.5, 0.1, alpha * 0.95)
  gfx.polygon('fill', -3, -9, -2, -13, lean * 0.6, tip, 2, -13, 3, -9)
  gfx.setColor(1, 0.85, 0.4, alpha)
  gfx.polygon('fill', -1.5, -9, lean * 0.4, tip + 4, 1.5, -9)
  gfx.setColor(1, 0.6, 0.12, alpha)
  gfx.circle('fill', 0, -6, 5.5, 14)
  gfx.setColor(1, 0.8, 0.32, alpha)
  gfx.circle('fill', 0, -6, 4, 12)
  gfx.setColor(1, 0.96, 0.78, alpha)
  gfx.circle('fill', -1, -7, 2, 8)
  gfx.setColor(0.28, 0.1, 0.04, alpha)
  local ex = p.facing * 1.5
  gfx.rectangle('fill', floor(-2.5 + ex), -8, 1, 2)
  gfx.rectangle('fill', floor(1.5 + ex), -8, 1, 2)
  gfx.pop()
end

local ECHO_PALETTE = {
  [false] = { tint = { 0.55, 0.95, 1 }, body = { 0.3, 0.85, 1 }, core = { 0.6, 0.97, 1 }, flame = { 0.45, 0.95, 1 },
    eyes = { 0.1, 0.35, 0.45 }, edge = { 0.8, 1, 1 }, glow = { 0.3, 0.85, 1 } },
  [true] = { tint = { 0.9, 0.6, 1 }, body = { 0.75, 0.4, 1 }, core = { 0.95, 0.75, 1 }, flame = { 0.85, 0.5, 1 },
    eyes = { 0.3, 0.1, 0.45 }, edge = { 1, 0.9, 1 }, glow = { 0.8, 0.45, 1 } },
}

local function paint(c, a)
  gfx.setColor(c[1], c[2], c[3], a)
end

local function drawGhost(e, frame, alpha)
  local pal = ECHO_PALETTE[e.mirrored]
  local cx, top = floor(frame.x + e.w / 2 + 0.5), floor(frame.y + 0.5)
  if drawSlot('echo', cx, top + e.h, { flip = frame.facing, tint = pal.tint, alpha = alpha * 0.85 }) then return end
  paint(pal.body, alpha * 0.55)
  gfx.circle('fill', cx, top + 7, 5.5, 14)
  paint(pal.core, alpha * 0.7)
  gfx.circle('fill', cx - 1, top + 6, 2.5, 8)
  local fl = sin(R.t * 12 + e.frames[1].x) * 0.8
  paint(pal.flame, alpha * 0.8)
  gfx.polygon('fill', cx - 2, top + 3, cx + fl, top - 2, cx + 2, top + 3)
  paint(pal.eyes, alpha * 0.8)
  gfx.rectangle('fill', cx + frame.facing * 1.5 - 2, top + 5, 1, 2)
  gfx.rectangle('fill', cx + frame.facing * 1.5 + 1, top + 5, 1, 2)
end

function R.drawEcho(e)
  local alpha = 1
  if e.lingerT > Echo.LINGER then
    alpha = clamp(1 - (e.lingerT - Echo.LINGER) / Echo.FADE, 0, 1)
  elseif Echo.LINGER - e.lingerT < 1 then
    alpha = 0.65 + 0.35 * sin(R.t * 30)
  end
  for k = 4, 1, -1 do
    local f = e.frames[max(1, e.i - k * 4)]
    if f.x ~= e.x or f.y ~= e.y then
      drawGhost(e, f, alpha * (0.34 - k * 0.06))
    end
  end
  drawGhost(e, e, alpha)
  if e:isSolid() then
    local pal = ECHO_PALETTE[e.mirrored]
    local cx, top = floor(e.x + e.w / 2 + 0.5), floor(e.y + 0.5)
    paint(pal.edge, alpha * 0.9)
    gfx.rectangle('fill', cx - 6, top, 12, 1)
    paint(pal.body, alpha * 0.35)
    gfx.rectangle('fill', cx - 6, top + 1, 12, 1)
  end
end

function R.drawWorld(world)
  local t = R.t
  gfx.setColor(1, 1, 1)
  gfx.draw(layer(world), 0, 0)
  local v = view(world)
  for _, p in ipairs(v.pieces) do drawDoor(p.cells, v.doors[p.id] or 0) end
  for ty = 0, world.H - 1 do
    for tx = 0, world.W - 1 do
      local c = world.cells[ty][tx]
      local tile = c and TILES[c.kind]
      if tile and tile.draw and not tile.static then tile.draw(world, c, tx * T, ty * T, t) end
    end
  end
  for _, e in ipairs(world.echoes) do R.drawEcho(e) end
  local p = world.player
  R.drawPlayer(p, p.state == 'cleared' and max(0, 1 - p.stateT * 1.1) or 1)
end

-- Lighting -----------------------------------------------------------------

-- The lightmap starts dark and light discs are added into it; multiplying it over the
-- scene is equivalent to a darkness layer with soft holes cut out.
function R.drawLighting(world, camx, camy, extra)
  local t = R.t
  gfx.push('all')
  gfx.setCanvas(R.lightmap)
  gfx.origin()
  gfx.translate(-camx, -camy)
  gfx.clear(AMBIENT[1], AMBIENT[2], AMBIENT[3], 1)
  gfx.setBlendMode('add')

  local p = world.player
  if p.state ~= 'dead' then
    local k = p.state == 'cleared' and max(0, 1 - p.stateT) or 1
    glow(p.x + p.w / 2, p.y + 6, 104 + sin(t * 9) * 2, 1, 0.78, 0.46, k)
  end
  for _, e in ipairs(world.echoes) do
    local a = e.lingerT > Echo.LINGER and clamp(1 - (e.lingerT - Echo.LINGER) / Echo.FADE, 0, 1) or 1
    local g = ECHO_PALETTE[e.mirrored].glow
    glow(e.x + e.w / 2, e.y + 6, 52, g[1], g[2], g[3], 0.9 * a)
  end
  for _, l in ipairs(world.lights) do
    local spec = LIGHTS[l.kind]
    local r = l.r
    if spec.flicker then
      r = r + (sin(t * 11 + l.x) * 0.5 + sin(t * 17 + l.y) * 0.5) * spec.flicker
    else
      r = r + sin(t * 2 + l.x * 0.1) * spec.breathe
    end
    glow(l.x, l.y, r, spec.color[1], spec.color[2], spec.color[3], lightAlpha(spec, l))
  end
  local v = view(world)
  for _, p in ipairs(v.pieces) do
    local cells, open = p.cells, v.doors[p.id] or 0
    if open < 0.95 then
      local col = PLATE_COLORS[cells[1].idx]
      local c = cells[floor(#cells / 2) + 1]
      glow(c.tx * T + T / 2, c.ty * T + T / 2, 34, col[1], col[2], col[3], 0.55 * (1 - open))
    end
  end
  for _, c in ipairs(world.plates) do
    local col = PLATE_COLORS[c.idx]
    glow(c.tx * T + T / 2, c.ty * T + 14, c.pressed and 40 or 24, col[1], col[2], col[3], c.pressed and 0.8 or 0.5)
  end
  if extra then extra(glow) end
  gfx.pop()

  gfx.push('all')
  gfx.origin()
  gfx.setBlendMode('multiply', 'premultiplied')
  gfx.setColor(1, 1, 1, 1)
  gfx.draw(R.lightmap)
  gfx.pop()
end

function R.drawGlows(world, camx, camy)
  gfx.push('all')
  gfx.translate(-camx, -camy)
  gfx.setBlendMode('add')
  local p = world.player
  if p.state ~= 'dead' then
    local k = p.state == 'cleared' and max(0, 1 - p.stateT) or 1
    glow(p.x + p.w / 2, p.y + 6, 24, 1, 0.7, 0.3, 0.55 * k)
  end
  for _, e in ipairs(world.echoes) do
    local g = ECHO_PALETTE[e.mirrored].glow
    glow(e.x + e.w / 2, e.y + 6, 20, g[1], g[2], g[3], 0.5)
  end
  for _, l in ipairs(world.lights) do
    local spec = LIGHTS[l.kind]
    local lift = spec.flicker and 4 or 0
    glow(l.x, l.y - lift, spec.flicker and 16 or 24, spec.color[1], spec.color[2], spec.color[3], 0.65 * lightAlpha(spec, l))
  end
  gfx.pop()
end

-- Frame plumbing -----------------------------------------------------------

function R.beginFrame()
  gfx.setCanvas(R.game)
  gfx.clear(0, 0, 0, 1)
  gfx.origin()
end

function R.present(target)
  gfx.setCanvas(target)
  gfx.origin()
  gfx.setBlendMode('alpha')
  local ww, wh = gfx.getDimensions()
  local s = min(ww / R.W, wh / R.H)
  if s >= 1 then s = floor(s) end
  R.scale = s
  R.ox, R.oy = floor((ww - R.W * s) / 2), floor((wh - R.H * s) / 2)
  gfx.clear(0, 0, 0, 1)
  gfx.setColor(1, 1, 1, 1)
  gfx.draw(R.game, R.ox, R.oy, 0, s, s)
end

return R
