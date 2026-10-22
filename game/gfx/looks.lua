local Style = require 'gfx.style'

local gfx = love.graphics
local Echo = require 'world.echo'
local floor, sin, min, max, pi = math.floor, math.sin, math.min, math.max, math.pi
local T = 16
local GW, GH = 480, 270
local UIW, UIH = 960, 540

local PLATE = Style.plates

local function hash(x, y)
  local n = sin(x * 12.9898 + y * 78.233) * 43758.5453
  return n - floor(n)
end

local function rgb(c, a)
  gfx.setColor(c[1], c[2], c[3], a or 1)
end

local function air(world, tx, ty)
  local n = world:cell(tx, ty)
  return not (n and n.kind == 'solid')
end

local function edges(world, c, x, y, hi, lo)
  local tx, ty = c.tx, c.ty
  if air(world, tx, ty - 1) then
    rgb(hi)
    gfx.rectangle('fill', x, y, T, 1)
  end
  if air(world, tx, ty + 1) then
    rgb(lo)
    gfx.rectangle('fill', x, y + T - 1, T, 1)
  end
  if air(world, tx - 1, ty) then
    rgb(hi)
    gfx.rectangle('fill', x, y, 1, T)
  end
  if air(world, tx + 1, ty) then
    rgb(lo)
    gfx.rectangle('fill', x + T - 1, y, 1, T)
  end
end

local function spikes(x, y, dark, light)
  for i = 0, 2 do
    local bx = x + 1 + i * 5
    rgb(dark)
    gfx.polygon('fill', bx, y + 16, bx + 2.5, y + 7, bx + 2.5, y + 16)
    rgb(light)
    gfx.polygon('fill', bx + 2.5, y + 7, bx + 5, y + 16, bx + 2.5, y + 16)
  end
end

local function bounds(cells, open)
  local x0, y0, x1, y1 = math.huge, math.huge, 0, 0
  for _, c in ipairs(cells) do
    x0, y0 = min(x0, c.tx * T), min(y0, c.ty * T)
    x1, y1 = max(x1, (c.tx + 1) * T), max(y1, (c.ty + 1) * T)
  end
  local wide = x1 - x0 > y1 - y0
  local span = wide and (x1 - x0) or (y1 - y0)
  local vis = floor(span * (1 - open) + 0.5)
  return x0, y0, x1, y1, wide, vis, PLATE[cells[1].idx]
end

local function image(w, h, fn)
  local data = love.image.newImageData(w, h)
  data:mapPixel(fn)
  local img = gfx.newImage(data)
  img:setFilter('nearest', 'nearest')
  return img
end

local function blit(img, ox, oy, s)
  gfx.setBlendMode('alpha')
  gfx.setColor(1, 1, 1, 1)
  gfx.draw(img, ox, oy, 0, s, s)
  gfx.setLineWidth(1)
end

local function atFeet(p)
  gfx.push()
  gfx.translate(floor(p.x + p.w / 2 + 0.5), floor(p.y + p.h + 0.5))
  gfx.scale(p.sx, p.sy)
end

local function person(fill, a, facing, mark)
  rgb(fill, a)
  gfx.polygon('fill', -4, -1, -3, -11, 0, -13, 3, -11, 4, -1)
  gfx.circle('fill', facing * 0.5, -12, 3.2, 10)
  if mark then
    rgb(mark, a)
    gfx.rectangle('fill', facing > 0 and 1 or -2, -13, 1, 2)
  end
end

local function halo(x, y, r, col, a)
  local glow = Style.glow
  if glow then
    glow(x, y, r, col[1], col[2], col[3], a)
  else
    rgb(col, a * 0.35)
    gfx.circle('fill', x, y, r, 16)
  end
end

local function seal(cx, cy, r, col, a, hole)
  rgb(col, a)
  gfx.circle('fill', cx, cy, r, 14)
  if hole then
    rgb(hole, a)
    gfx.circle('fill', cx, cy, r * 0.45, 10)
  end
end

local function flame(cx, top, col, hot, a)
  local fl = sin(Style.t * 14 + cx) * 0.8
  rgb(col, a)
  gfx.polygon('fill', cx - 3, top + 8, cx + fl, top - 2, cx + 3, top + 8)
  rgb(hot, a)
  gfx.polygon('fill', cx - 1.5, top + 8, cx + fl * 0.5, top + 2, cx + 1.5, top + 8)
end

local function plateBody(x, y, c, base, ink)
  local drop = c.pressed and 2 or 0
  rgb(base)
  gfx.rectangle('fill', x + 1, y + 11, T - 2, 5)
  local col = PLATE[c.idx]
  rgb(col, c.pressed and 1 or 0.92)
  if ink then
    gfx.circle('fill', x + T / 2, y + 7 + drop, c.pressed and 3 or 5, 12)
    rgb(base)
    gfx.circle('fill', x + T / 2, y + 7 + drop, c.pressed and 1.2 or 2.2, 8)
  else
    gfx.rectangle('fill', x + 2, y + 12 + drop, T - 4, 3)
  end
end

local function doorPaint(cells, open, body, stripeW)
  local x0, y0, x1, y1, wide, vis, col = bounds(cells, open)
  local span = wide and (y1 - y0) or (x1 - x0)
  rgb(body)
  if wide then
    gfx.rectangle('fill', x0, y0, 3, span)
    if vis > 0 then
      gfx.rectangle('fill', x0, y0 + 2, vis, span - 4)
      rgb(col)
      gfx.rectangle('fill', x0, y0 + (span - stripeW) / 2, vis, stripeW)
      gfx.rectangle('fill', x0 + vis - 2, y0 + 2, 2, span - 4)
    end
  else
    gfx.rectangle('fill', x0, y0, span, 3)
    if vis > 0 then
      gfx.rectangle('fill', x0 + 2, y0, span - 4, vis)
      rgb(col)
      gfx.rectangle('fill', x0 + (span - stripeW) / 2, y0, stripeW, vis)
      gfx.rectangle('fill', x0 + 2, y0 + vis - 2, span - 4, 2)
    end
  end
  if open > 0.05 then
    rgb(col, 0.85)
    if wide then gfx.rectangle('fill', x0, y0 + (span - stripeW) / 2, x1 - x0, stripeW)
    else gfx.rectangle('fill', x0 + (span - stripeW) / 2, y0, stripeW, 3) end
  end
end

local function cairn(x, y, stone, crystal, lit, t, tx, outline)
  local cx = x + T / 2
  rgb(stone)
  gfx.rectangle('fill', cx - 6, y + 11, 12, 5)
  gfx.rectangle('fill', cx - 4, y + 6, 8, 5)
  gfx.rectangle('fill', cx - 3, y + 1, 6, 5)
  if outline then
    rgb(outline, 0.9)
    gfx.rectangle('line', cx - 6.5, y + 0.5, 13, 16)
  end
  local pulse = lit and (0.75 + 0.25 * sin(t * 5 + tx)) or 0.7
  rgb(crystal, pulse)
  gfx.rectangle('fill', cx - 2, y - 3, 4, 8)
  if lit then
    rgb({ 1, 1, 1 }, 0.9)
    gfx.rectangle('fill', cx - 1, y - 1, 1, 3)
  end
end

local function emberGem(x, y, t, tx, ty, outer, inner)
  local cx, cy = x + T / 2, y + T / 2 + sin(t * 3 + tx) * 1.5
  local fl = sin(t * 17 + ty) * 0.8
  rgb(outer, 0.95)
  gfx.polygon('fill', cx, cy - 6 - fl, cx + 4, cy, cx, cy + 4, cx - 4, cy)
  rgb(inner)
  gfx.polygon('fill', cx, cy - 3 - fl, cx + 2, cy + 0.5, cx, cy + 2.5, cx - 2, cy + 0.5)
end

local function torchCup(world, c, x, y, t, iron, flameCol, hot)
  local cx = x + T / 2
  rgb(iron)
  gfx.rectangle('fill', cx - 0.5, y - 8, 1, 12)
  gfx.rectangle('fill', cx - 3, y + 5, 6, 5)
  flame(cx, y + 1, flameCol, hot, 1)
end

local function goalMark(x, y, t, ring, core)
  local cx, cy = x + T / 2, y + T / 2
  gfx.setLineWidth(1)
  for i = 0, 2 do
    rgb(ring, 0.85 - i * 0.2)
    local r = 7 - i * 2 + sin(t * 3 + i) * 0.6
    gfx.ellipse('line', cx, cy, r * 0.8, r + 1)
  end
  rgb(core)
  gfx.rectangle('fill', floor(cx), floor(cy + sin(t * 4) * 2), 1, 1)
  gfx.setLineWidth(1)
end

local function mirrorGlass(x, y, t, tx, frame, glass)
  local cx = x + T / 2
  rgb(frame)
  gfx.rectangle('fill', cx - 4, y - 6, 8, 20)
  gfx.rectangle('fill', x + 2, y + 13, T - 4, 3)
  local pulse = 0.65 + 0.35 * sin(t * 4 + tx)
  rgb(glass, pulse)
  gfx.rectangle('fill', cx - 2, y - 4, 4, 15)
  rgb({ 1, 1, 1 }, 0.75)
  local sweep = floor((t * 9 + tx * 2) % 15)
  gfx.rectangle('fill', cx - 2, y - 4 + sweep, 4, 1)
end

local function veilLines(x, y, t, tx, col)
  for k = 0, 3 do
    local px = x + 2 + k * 4
    for yy = 0, T - 1, 2 do
      local wave = sin(t * 5 + yy * 0.5 + k + tx) * 1.1
      rgb(col, 0.35 + 0.4 * sin(t * 7 + k + yy))
      gfx.rectangle('fill', floor(px + wave + 0.5), y + yy, 1, 2)
    end
  end
end

local function crumbleBlock(world, c, x, y, t, fill, hi, crack)
  if c.gone then
    rgb(crack, 0.35 + (c.regrow < 0.6 and (0.6 - c.regrow) * 0.5 or 0))
    gfx.rectangle('line', x + 2, y + 2, T - 4, T - 4)
    return
  end
  local shake = c.crack and floor(sin(t * 60 + c.tx) * 1.5 + 0.5) or 0
  x = x + shake
  rgb(fill)
  gfx.rectangle('fill', x, y, T, T)
  edges(world, c, x, y, hi, fill)
  rgb(crack, c.crack and (0.5 + 0.5 * sin(t * 40)) or 0.7)
  gfx.rectangle('fill', x + 4, y + 4, 8, 1)
  gfx.rectangle('fill', x + 7, y + 4, 1, 8)
  gfx.rectangle('fill', x + 3, y + 10, 6, 1)
end

local function parallax(camx, period, par, fn)
  local k0 = floor(camx * par / period) - 1
  for k = k0, k0 + floor(GW / period) + 3 do
    fn(k, k * period - camx * par)
  end
end

local function ruled(color, step, a)
  rgb(color, a)
  for y = 0, GH, step do gfx.rectangle('fill', 0, y, GW, 1) end
end

local function ghostAnchor(e, frame)
  return floor(frame.x + e.w / 2 + 0.5), floor(frame.y + 0.5)
end

local function textAt(str, font, y, color, alpha, x, limit, align)
  gfx.setFont(font)
  gfx.setColor(color[1], color[2], color[3], alpha or 1)
  gfx.printf(str, x or 0, y, limit or UIW, align or 'center')
end

local function textShadow(str, font, y, color, alpha, x, limit, align, shadow)
  gfx.setFont(font)
  alpha = alpha or 1
  local px, w = x or 0, limit or UIW
  gfx.setColor(shadow[1], shadow[2], shadow[3], (shadow[4] or 0.6) * alpha)
  gfx.printf(str, px + 1, y + 1, w, align or 'center')
  gfx.setColor(color[1], color[2], color[3], alpha)
  gfx.printf(str, px, y, w, align or 'center')
end

local function irisOf(fill, ring)
  return function(coverage, cx, cy)
    if coverage <= 0 then return end
    rgb(fill, 1)
    if coverage >= 0.999 then
      gfx.rectangle('fill', -2000, -2000, 5000, 4000)
      return
    end
    local r = (1 - coverage) * 1100
    gfx.stencil(function() gfx.circle('fill', cx, cy, r, 64) end, 'replace', 1)
    gfx.setStencilTest('less', 1)
    gfx.rectangle('fill', -2000, -2000, 5000, 4000)
    gfx.setStencilTest()
    rgb(ring, 0.8)
    gfx.setLineWidth(2)
    gfx.circle('line', cx, cy, r, 64)
    gfx.setLineWidth(1)
  end
end

local function dimOf(col, scale)
  return function(alpha)
    rgb(col, alpha * scale)
    gfx.rectangle('fill', 0, 0, UIW, UIH)
  end
end

local function footerOf(chip, key, label)
  return function(hints, y, Ui)
    local font = Ui.fonts.small
    y = y or 496
    gfx.setFont(font)
    local gap, padX = 26, 8
    local widths, total = {}, 0
    for i, h in ipairs(hints) do
      local kw = font:getWidth(h[1]) + padX * 2
      widths[i] = { kw = kw, lw = font:getWidth(h[2]) }
      total = total + kw + 8 + widths[i].lw + (i > 1 and gap or 0)
    end
    local x = (UIW - total) / 2
    local fh = font:getHeight()
    for i, h in ipairs(hints) do
      local wd = widths[i]
      rgb(chip, 0.9)
      gfx.rectangle('line', x + 0.5, y - 1.5, wd.kw - 1, fh + 3)
      rgb(key, 1)
      gfx.print(h[1], x + padX, y)
      rgb(label, 0.95)
      gfx.print(h[2], x + wd.kw + 8, y)
      x = x + wd.kw + 8 + wd.lw + gap
    end
    gfx.setLineWidth(1)
  end
end

local function emberOf(hot, core)
  return function(x, y, lit, alpha, size)
    local k = size or 1
    local pts = { x, y - 7 * k, x + 5 * k, y, x, y + 5 * k, x - 5 * k, y }
    if lit then
      rgb(hot, alpha)
      gfx.polygon('fill', pts)
      rgb(core, alpha)
      gfx.polygon('fill', x, y - 3 * k, x + 2.5 * k, y + 0.5 * k, x, y + 3 * k, x - 2.5 * k, y + 0.5 * k)
    else
      gfx.setLineWidth(1.5)
      rgb(hot, (alpha or 1) * 0.55)
      gfx.polygon('line', pts)
      gfx.setLineWidth(1)
    end
  end
end

local function memoryLabel(frac)
  local full = frac >= 1
  local text = full and 'memory 3.0s' or ('memory %.1fs'):format(frac * Echo.FRAMES * (1 / 60))
  return text, full
end

local function drawHud(world, ctx, theme)
  local Ui = require 'gfx.ui'
  local Model = require 'gfx.hudmodel'
  local f, t = Ui.fonts, Ui.time()
  local frac = Model.memory(world)
  local p = world.player
  if frac < 1 and p.state ~= 'dead' and p.state ~= 'cleared' then
    local x = (p.x + p.w / 2 - ctx.camx) * 2
    local y = (p.y + p.h / 2 - ctx.camy) * 2
    rgb(theme.accent, 0.18)
    gfx.circle('line', x, y, 24)
    rgb(theme.accent, 0.7)
    gfx.arc('line', 'open', x, y, 24, -pi / 2, -pi / 2 + 2 * pi * frac, 32)
  end
  if theme.chip then
    rgb(theme.chip, 0.94)
    gfx.rectangle('fill', UIW - 148, 6, 136, 46)
  end
  local name = ('%d  %s'):format(ctx.index, ctx.name)
  Ui.text(name, f.small, 14, theme.ink, 0.9 * (ctx.nameAlpha or 1), 20, 420, 'left')
  Ui.text(Model.clock(ctx.time), f.small, 14, theme.ink, 0.95, -24, UIW, 'right')
  local d = ctx.deaths
  local deaths = d == 0 and 'no deaths' or (d == 1 and '1 death' or d .. ' deaths')
  Ui.text(deaths, f.tiny, 36, theme.dim, 0.9, -24, UIW, 'right')
  if #world.embers > 0 then
    local lit = world:emberTaken()
    Ui.ember(28, 58, lit, lit and 0.95 or 0.7, 1)
  end
  local slots = Model.slots(world)
  for k = 1, #slots do
    local slot = slots[k]
    local x, y = 36 + (k - 1) * 32, UIH - 46
    local live = slot.alive and (slot.fading and (0.55 + 0.45 * sin(t * 30)) or 1) or 0.35
    rgb(theme.accent, 0.9 * live)
    if theme.pip == 'square' then
      gfx.rectangle('line', x - 8, y - 8, 16, 16)
      if slot.alive then gfx.rectangle('fill', x - 3, y - 3, 6, 6) end
    else
      gfx.circle('line', x, y, 8)
      if slot.alive then gfx.circle('fill', x, y, 3) end
    end
    if slot.alive and slot.frac > 0.02 then
      rgb(theme.hot, live)
      gfx.arc('line', 'open', x, y, 8, -pi / 2, -pi / 2 + 2 * pi * slot.frac, 24)
    end
  end
  local label, full = memoryLabel(frac)
  local bx, by, bw = 98, UIH - 52, 92
  if theme.chip then
    rgb(theme.chip, 0.94)
    gfx.rectangle('fill', bx - 4, by + 6, 176, 22)
  end
  if theme.meter == 'film' then
    rgb(theme.dim, 0.9)
    gfx.rectangle('line', bx - 4, by - 3, bw + 8, 10)
    for i = 0, 7 do
      gfx.rectangle('fill', bx - 2, by - 6 + (i % 2) * 12, 4, 2)
    end
    rgb(theme.hot, full and 0.45 or 1)
    gfx.rectangle('fill', bx, by, bw * frac, 4)
  elseif theme.meter == 'box' then
    rgb(theme.accent, 0.9)
    gfx.rectangle('line', bx, by, bw, 6)
    gfx.rectangle('fill', bx, by, bw * frac, 6)
  else
    rgb(theme.dim, 0.7)
    gfx.rectangle('fill', bx, by + 2, bw, 1)
    rgb(theme.hot, full and 0.45 or 1)
    gfx.rectangle('fill', bx, by + 1, bw * frac, 3)
  end
  Ui.text(label, f.tiny, by + 8, theme.dim, full and 0.55 or 0.95, bx, 220, 'left')
  gfx.setLineWidth(1)
end

local function strokeLine(pts, col, width, pool)
  if #pts < 2 then return end
  gfx.setLineStyle('rough')
  gfx.setLineWidth(width)
  rgb(col, 0.9)
  local v = {}
  for i = 1, #pts do
    v[#v + 1] = pts[i].x
    v[#v + 1] = pts[i].y
  end
  gfx.line(v)
  gfx.setLineWidth(1)
  gfx.setLineStyle('smooth')
  if pool then
    local last = pts[#pts]
    rgb(col, 1)
    gfx.circle('fill', last.x, last.y, pool, 10)
  end
end

local INK = { 0.102, 0.071, 0.047 }
local INK2 = { 0.227, 0.165, 0.118 }
local PAPER = { 0.953, 0.902, 0.769 }
local PAPER2 = { 0.894, 0.824, 0.682 }
local VERM = { 0.824, 0.227, 0.157 }
local VERM2 = { 1, 0.353, 0.235 }
local INDIGO = { 0.165, 0.180, 0.525 }

local FIELD = { 0.165, 0.173, 0.188 }
local CUT = { 0.039, 0.043, 0.051 }
local BONE = { 0.957, 0.937, 0.894 }
local BONEDIM = { 0.655, 0.643, 0.612 }
local LAMP = { 1, 0.694, 0.353 }
local GHOSTW = { 0.949, 0.984, 1 }
local GHOSTM = { 0.941, 0.831, 1 }

local CREAM = { 0.965, 0.906, 0.816 }
local SEPIA = { 0.478, 0.416, 0.345 }
local SEPIA2 = { 0.659, 0.580, 0.486 }
local UMBER = { 0.243, 0.204, 0.173 }
local MOUNT = { 0.141, 0.110, 0.086 }
local BURNT = { 0.769, 0.318, 0.165 }
local AFTER_R = { 1, 0.231, 0.306 }
local AFTER_C = { 0.227, 0.831, 1 }

local function inkEcho(mirrored)
  local col = mirrored and INDIGO or VERM
  local hot = mirrored and { 0.55, 0.62, 1 } or VERM2
  return {
    tint = col, body = col, core = hot, flame = hot, eyes = INK, edge = hot,
    glow = hot,
  }
end

local function photoSplit(dx, r, g, b, a, x, y)
  gfx.setBlendMode('add')
  gfx.setColor(r, g, b, a)
  gfx.circle('fill', x + dx, y, 5.2, 12)
  gfx.setBlendMode('alpha')
end

local looks = {}

looks.ink = function()
  local fiber = image(GW, GH, function(x, y)
    local n = hash(x + 2, y + 9)
    if n > 0.93 then return 0.15, 0.08, 0.05, 0.22 end
    return 0, 0, 0, 0
  end)
  local echo = { [false] = inkEcho(false), [true] = inkEcho(true) }
  return {
    font = 'assets/fonts/IMFeENrm28P.ttf',
    fonts = {
      small = 'assets/fonts/BarlowCondensed-Regular.ttf',
      tiny = 'assets/fonts/BarlowCondensed-Regular.ttf',
      num = 'assets/fonts/BarlowCondensed-Regular.ttf',
    },
    sizes = { title = 64, big = 32, menu = 26, mid = 20, small = 20, tiny = 16, num = 32 },
    colors = {
      amber = VERM, white = INK, dim = { 0.353, 0.275, 0.212 },
      cyan = INDIGO, locked = { 0.541, 0.467, 0.392 },
    },
    flatLight = true,
    echoCopies = 1,
    echoGlowR = 28,
    playerGlowR = 14,
    noPropGlow = true,
    dust = INK2,
    castColor = VERM,
    castMirror = INDIGO,
    torchSpark = VERM2,
    echo = echo,
    card = {
      fill = { 0.973, 0.941, 0.855 }, fillA = 0.94, lockedA = 0.8, radius = 0,
      line = { INK[1], INK[2], INK[3], 0.75 }, sel = { VERM[1], VERM[2], VERM[3], 1 },
    },
    background = function(camx, camy, t)
      rgb(PAPER)
      gfx.rectangle('fill', 0, 0, GW, GH)
      ruled(INK2, 14, 0.08)
      gfx.setLineWidth(1)
      parallax(camx, 170, 0.1, function(k, x)
        local h = 50 + hash(k, 3) * 80
        local top = 250 - h - camy * 0.05
        rgb(INK, 0.28)
        gfx.rectangle('fill', x, top, 2, h)
        gfx.arc('line', 'open', x + 36, top, 34, pi, pi + pi * (0.4 + hash(k, 5) * 0.6))
      end)
      parallax(camx, 54, 0.32, function(k, x)
        local len = 24 + hash(k, 4) * 70
        rgb(INK, 0.4)
        local sway = sin(t * 0.8 + k) * 3
        gfx.rectangle('fill', floor(x + sway), 0, 1, len)
      end)
      gfx.setLineWidth(1)
    end,
    motes = function(camx, camy, t)
      for i = 1, 18 do
        local x = (hash(i, 2) * 520 - camx * 0.2 + t * 4) % 520 - 20
        local y = (hash(i, 4) * 300 - camy * 0.1 + sin(t + i) * 6) % 300
        rgb(INK, 0.15 + hash(i, 6) * 0.2)
        gfx.rectangle('fill', floor(x), floor(y), 2, 1)
      end
    end,
    tiles = {
      solid = function(world, c, x, y)
        local h = hash(c.tx, c.ty)
        rgb({ 0.20 + h * 0.04, 0.13, 0.09 })
        gfx.rectangle('fill', x, y, T, T)
        rgb(PAPER, 0.20)
        for i = 2, T - 2, 4 do
          if hash(c.tx + i, c.ty) > 0.15 then gfx.rectangle('fill', x + 1, y + i, T - 2, 1) end
        end
        edges(world, c, x, y, PAPER2, INK)
      end,
      oneway = function(world, c, x, y)
        rgb(INK)
        gfx.rectangle('fill', x, y + 1, T, 2)
        gfx.rectangle('fill', x + 2, y + 5, 3, 1)
        gfx.rectangle('fill', x + 11, y + 5, 3, 1)
      end,
      spike = function(world, c, x, y) spikes(x, y, INK, PAPER2) end,
      torch = function(world, c, x, y, t) torchCup(world, c, x, y, t, INK, VERM, VERM2) end,
      goal = function(world, c, x, y, t) goalMark(x, y, t, INK, VERM) end,
      plate = function(world, c, x, y) plateBody(x, y, c, INK, true) end,
      mirror = function(world, c, x, y, t) mirrorGlass(x, y, t, c.tx, INK, INDIGO) end,
      veil = function(world, c, x, y, t) veilLines(x, y, t, c.tx, INDIGO) end,
      crumble = function(world, c, x, y, t) crumbleBlock(world, c, x, y, t, INK2, PAPER2, VERM) end,
      checkpoint = function(world, c, x, y, t)
        cairn(x, y, INK2, VERM, c.active, t, c.tx, PAPER)
      end,
      ember = function(world, c, x, y, t)
        if c.taken then return end
        emberGem(x, y, t, c.tx, c.ty, VERM, VERM2)
      end,
    },
    door = function(cells, open) doorPaint(cells, open, INK, 4) end,
    player = function(p, alpha)
      atFeet(p)
      person(INK, alpha, p.facing, PAPER)
      flame(0, -16, VERM, VERM2, alpha)
      gfx.pop()
    end,
    ghost = function(e, frame, alpha)
      local col = e.mirrored and INDIGO or VERM
      local hot = e.mirrored and { 0.55, 0.62, 1 } or VERM2
      local cx, top = ghostAnchor(e, frame)
      seal(cx, top + 7, 7, col, 0.92 * alpha, PAPER)
      rgb(hot, alpha)
      gfx.circle('fill', cx, top + 7, 1.6, 8)
    end,
    stroke = function(pts, pal) strokeLine(pts, pal.edge, 3, 3.2) end,
    post = function(ox, oy, s) blit(fiber, ox, oy, s) end,
    wordmark = function(Ui, t)
      local f = Ui.fonts
      local y = 72
      textAt('ECHOES', f.title, y, INK, 1)
      rgb(VERM, 0.95)
      gfx.rectangle('fill', UIW / 2 - 78, y + f.title:getHeight() + 2, 156, 3)
      textAt('a small light remembers where it has been', f.mid, 186, INK2, 0.9)
    end,
    text = function(str, font, y, color, alpha, x, limit, align)
      textAt(str, font, y, color, alpha, x, limit, align)
    end,
    glowText = function(str, font, y, color, alpha, glow, x, limit)
      textAt(str, font, y, color, alpha, x, limit, 'center')
      rgb(VERM, 0.9 * (alpha or 1))
      local w, box = 72, limit or UIW
      gfx.rectangle('fill', (x or 0) + (box - w) / 2, y + font:getHeight() + 3, w, 2)
    end,
    panel = function(x, y, w, h, alpha)
      alpha = alpha or 1
      rgb(INK, 0.18 * alpha)
      gfx.rectangle('fill', x + 5, y + 5, w, h)
      rgb(PAPER, 0.96 * alpha)
      gfx.rectangle('fill', x, y, w, h)
      rgb(INK, 0.92 * alpha)
      gfx.setLineWidth(2)
      gfx.rectangle('line', x + 1, y + 1, w - 2, h - 2)
      gfx.setLineWidth(1)
      gfx.rectangle('line', x + 6, y + 6, w - 12, h - 12)
    end,
    cursor = function(left, ry, w, rh)
      local cy = ry + (rh - 4) / 2
      rgb(VERM, 1)
      gfx.rectangle('fill', left + 12, cy - 3, 6, 6)
    end,
    dim = dimOf(PAPER, 0.55),
    iris = irisOf(PAPER, VERM),
    footer = footerOf(INK, VERM, INK),
    emberIcon = emberOf(VERM, VERM2),
    hud = function(world, ctx)
      drawHud(world, ctx, {
        ink = INK, dim = INK2, accent = VERM, hot = VERM2, pip = 'circle', meter = 'rule', chip = PAPER,
      })
    end,
  }
end

looks.cut = function()
  local echo = {
    [false] = {
      tint = GHOSTW, body = GHOSTW, core = { 1, 1, 1 }, flame = GHOSTW, eyes = CUT,
      edge = { 1, 1, 1 }, glow = { 0.75, 0.95, 1 },
    },
    [true] = {
      tint = GHOSTM, body = GHOSTM, core = { 1, 1, 1 }, flame = GHOSTM, eyes = CUT,
      edge = { 1, 0.95, 1 }, glow = { 0.85, 0.55, 1 },
    },
  }
  return {
    font = 'assets/fonts/BarlowCondensed-Regular.ttf',
    fonts = { title = 'assets/fonts/BebasNeue-Regular.ttf' },
    sizes = { title = 104, big = 36, menu = 30, mid = 22, small = 18, tiny = 15, num = 36 },
    colors = {
      amber = LAMP, white = BONE, dim = BONEDIM, cyan = GHOSTW, locked = { 0.431, 0.447, 0.471 },
    },
    flatLight = true,
    echoCopies = 3,
    echoGlowR = 46,
    playerGlowR = 18,
    noPropGlow = true,
    dust = BONE,
    castColor = GHOSTW,
    castMirror = GHOSTM,
    torchSpark = BONE,
    echo = echo,
    card = {
      fill = { 0.06, 0.065, 0.075 }, fillA = 0.92, lockedA = 0.78, radius = 0,
      line = { BONE[1], BONE[2], BONE[3], 0.85 }, sel = { LAMP[1], LAMP[2], LAMP[3], 1 },
    },
    background = function(camx, camy)
      rgb(FIELD)
      gfx.rectangle('fill', 0, 0, GW, GH)
      parallax(camx, 140, 0.08, function(k, x)
        local h = 40 + hash(k, 2) * 90
        rgb({ 0.09, 0.095, 0.105 })
        gfx.rectangle('fill', x, 270 - h, 90 + hash(k, 8) * 40, h + 20)
      end)
      parallax(camx, 200, 0.16, function(k, x)
        local top = 150 + hash(k, 3) * 40 - camy * 0.04
        rgb(CUT)
        gfx.rectangle('fill', x, top, 14, 140)
        gfx.rectangle('fill', x + 70, top + 16, 14, 130)
        gfx.rectangle('fill', x, top, 84, 10)
      end)
    end,
    motes = false,
    tiles = {
      solid = function(world, c, x, y)
        rgb(CUT)
        gfx.rectangle('fill', x, y, T, T)
        edges(world, c, x, y, BONE, BONE)
      end,
      oneway = function(world, c, x, y)
        rgb(BONE)
        gfx.rectangle('fill', x, y, T, 2)
        gfx.rectangle('fill', x + 4, y + 2, 2, 3)
        gfx.rectangle('fill', x + 10, y + 2, 2, 3)
      end,
      spike = function(world, c, x, y) spikes(x, y, BONE, { 1, 1, 1 }) end,
      torch = function(world, c, x, y, t) torchCup(world, c, x, y, t, CUT, BONE, LAMP) end,
      goal = function(world, c, x, y, t) goalMark(x, y, t, BONE, LAMP) end,
      plate = function(world, c, x, y) plateBody(x, y, c, BONE, false) end,
      mirror = function(world, c, x, y, t) mirrorGlass(x, y, t, c.tx, BONE, GHOSTM) end,
      veil = function(world, c, x, y, t) veilLines(x, y, t, c.tx, BONE) end,
      crumble = function(world, c, x, y, t) crumbleBlock(world, c, x, y, t, CUT, BONE, LAMP) end,
      checkpoint = function(world, c, x, y, t) cairn(x, y, CUT, BONE, c.active, t, c.tx, BONE) end,
      ember = function(world, c, x, y, t)
        if c.taken then return end
        emberGem(x, y, t, c.tx, c.ty, LAMP, { 1, 0.95, 0.8 })
      end,
    },
    door = function(cells, open) doorPaint(cells, open, CUT, 6) end,
    player = function(p, alpha)
      atFeet(p)
      local dir = p.facing
      rgb(BONE, alpha)
      gfx.rectangle('fill', -3, -14, 6, 13)
      gfx.rectangle('fill', -2, -18, 4, 5)
      rgb(LAMP, alpha)
      gfx.rectangle('fill', -1, -16, 2, 3)
      rgb(CUT, alpha)
      gfx.rectangle('fill', dir > 0 and 1 or -2, -17, 1, 2)
      gfx.pop()
    end,
    ghost = function(e, frame, alpha)
      local col = e.mirrored and GHOSTM or GHOSTW
      local cx, top = ghostAnchor(e, frame)
      local cy = top + 6
      halo(cx, cy, 20, col, 0.9 * alpha)
      rgb({ 1, 1, 1 }, alpha)
      gfx.circle('fill', cx, cy, 6.5, 16)
      rgb(CUT, alpha)
      local dir = frame.facing or 1
      gfx.rectangle('fill', cx + dir * 1.5 - 1, cy - 1, 1, 2)
    end,
    stroke = function(pts, pal)
      rgb({ 1, 1, 1 }, 0.95)
      for i = 1, #pts do
        local p = pts[i]
        gfx.rectangle('fill', p.x - 2, p.y - 1, 4, 2)
      end
    end,
    wordmark = function(Ui, t)
      local f = Ui.fonts
      textAt('ECHOES', f.title, 30, BONE, 1)
      rgb(LAMP, 1)
      gfx.rectangle('fill', UIW / 2 - 36, 30 + f.title:getHeight() + 4, 72, 3)
      textAt('a small light remembers where it has been', f.mid, 184, BONEDIM, 0.95)
    end,
    text = function(str, font, y, color, alpha, x, limit, align)
      textAt(str, font, y, color, alpha, x, limit, align)
    end,
    glowText = function(str, font, y, color, alpha, glow, x, limit)
      textAt(str, font, y, color, alpha, x, limit, 'center')
    end,
    panel = function(x, y, w, h, alpha)
      alpha = alpha or 1
      rgb(CUT, 0.94 * alpha)
      gfx.rectangle('fill', x, y, w, h)
      rgb(BONE, 0.95 * alpha)
      gfx.setLineWidth(1)
      gfx.rectangle('line', x + 0.5, y + 0.5, w - 1, h - 1)
      gfx.rectangle('fill', x, y, 14, 2)
      gfx.rectangle('fill', x, y, 2, 14)
      gfx.rectangle('fill', x + w - 14, y + h - 2, 14, 2)
      gfx.rectangle('fill', x + w - 2, y + h - 14, 2, 14)
    end,
    cursor = function(left, ry, w, rh)
      rgb(LAMP, 1)
      gfx.rectangle('fill', left, ry + rh - 7, w, 2)
      gfx.rectangle('fill', left, ry + 8, 3, rh - 16)
    end,
    dim = dimOf({ 0.02, 0.02, 0.025 }, 1),
    iris = irisOf(CUT, BONE),
    footer = footerOf(BONE, LAMP, BONE),
    emberIcon = emberOf(LAMP, { 1, 0.95, 0.85 }),
    hud = function(world, ctx)
      drawHud(world, ctx, { ink = BONE, dim = BONEDIM, accent = GHOSTW, hot = LAMP, pip = 'square', meter = 'box' })
    end,
  }
end

looks.photo = function()
  local grade = image(GW, GH, function(x, y)
    local u, v = x / (GW - 1) - 0.5, y / (GH - 1) - 0.5
    local d = u * u * 1.15 + v * v * 1.8
    local vig = max(0, min(1, (d - 0.2) / 0.5))
    local n = hash(x, y)
    if n > 0.97 and vig < 0.2 then return 0.95, 0.9, 0.78, 0.1 end
    return 0.08, 0.05, 0.03, vig * 0.4
  end)
  local function echo(mirrored)
    local glow = mirrored and AFTER_R or AFTER_C
    return {
      tint = glow, body = glow, core = glow, flame = CREAM, eyes = MOUNT,
      edge = glow, glow = glow,
    }
  end
  return {
    font = 'assets/fonts/CourierPrime-Regular.ttf',
    sizes = { title = 64, big = 28, menu = 22, mid = 18, small = 16, tiny = 14, num = 28 },
    colors = {
      amber = BURNT, white = MOUNT, dim = { 0.361, 0.298, 0.235 },
      cyan = { 0.12, 0.45, 0.55 }, locked = { 0.541, 0.478, 0.416 },
    },
    ambient = { 0.82, 0.72, 0.58 },
    echoCopies = 2,
    echoGlowR = 36,
    playerGlowR = 22,
    dust = UMBER,
    castColor = AFTER_C,
    castMirror = AFTER_R,
    torchSpark = { 1, 0.62, 0.32 },
    lights = {
      torch = { color = { 1, 0.62, 0.32 }, flicker = 3, alpha = 0.55 },
      goal = { color = { 0.95, 0.75, 0.4 }, breathe = 3, alpha = 0.45 },
      mirror = { color = AFTER_C, breathe = 4, alpha = 0.35 },
      veil = { color = AFTER_C, breathe = 2, alpha = 0.28 },
      checkpoint = { color = { 1, 0.7, 0.35 }, breathe = 3, alpha = 0.55, idle = 0.1 },
      ember = { color = { 1, 0.5, 0.18 }, breathe = 7, alpha = 0.6 },
    },
    echo = { [false] = echo(false), [true] = echo(true) },
    card = {
      fill = { 0.965, 0.922, 0.847 }, fillA = 0.94, lockedA = 0.82, radius = 0,
      line = { MOUNT[1], MOUNT[2], MOUNT[3], 0.8 }, sel = { BURNT[1], BURNT[2], BURNT[3], 1 },
    },
    background = function(camx, camy)
      for i = 0, 26 do
        local f = i / 26
        gfx.setColor(0.90 - f * 0.32, 0.80 - f * 0.34, 0.65 - f * 0.30)
        gfx.rectangle('fill', 0, i * 10, GW, 10)
      end
      parallax(camx, 150, 0.1, function(k, x)
        local h = 60 + hash(k, 3) * 70
        local top = 240 - h
        rgb(SEPIA2, 0.45)
        gfx.rectangle('fill', x, top, 16, h)
        gfx.rectangle('fill', x + 64, top + 12, 16, h)
        gfx.arc('fill', x + 40, top + 8, 36, pi, 0)
      end)
    end,
    motes = function(camx, camy, t)
      for i = 1, 28 do
        local x = (hash(i, 2) * 540 - camx * 0.25 + t * 3) % 540 - 20
        local y = (hash(i, 4) * 320 - t * 2 + sin(t * 0.5 + i) * 8) % 320
        rgb(UMBER, 0.12 + hash(i, 6) * 0.18)
        gfx.rectangle('fill', floor(x), floor(y), 1, 1)
      end
    end,
    tiles = {
      solid = function(world, c, x, y)
        local h = hash(c.tx, c.ty)
        rgb({ 0.45 + h * 0.05, 0.38 + h * 0.04, 0.31 })
        gfx.rectangle('fill', x, y, T, T)
        if h > 0.72 then
          rgb(UMBER, 0.35)
          gfx.rectangle('fill', x + floor(h * 12), y + 4, 2, 1)
          gfx.rectangle('fill', x + 3, y + floor(h * 10), 1, 2)
        end
        edges(world, c, x, y, SEPIA2, UMBER)
      end,
      oneway = function(world, c, x, y)
        rgb(SEPIA2)
        gfx.rectangle('fill', x, y, T, 4)
        rgb(UMBER)
        gfx.rectangle('fill', x, y + 3, T, 1)
      end,
      spike = function(world, c, x, y) spikes(x, y, UMBER, { 0.55, 0.32, 0.24 }) end,
      torch = function(world, c, x, y, t) torchCup(world, c, x, y, t, UMBER, { 1, 0.55, 0.2 }, { 1, 0.85, 0.45 }) end,
      goal = function(world, c, x, y, t) goalMark(x, y, t, BURNT, { 1, 0.9, 0.6 }) end,
      plate = function(world, c, x, y) plateBody(x, y, c, UMBER, false) end,
      mirror = function(world, c, x, y, t) mirrorGlass(x, y, t, c.tx, UMBER, AFTER_C) end,
      veil = function(world, c, x, y, t) veilLines(x, y, t, c.tx, AFTER_C) end,
      crumble = function(world, c, x, y, t) crumbleBlock(world, c, x, y, t, SEPIA, SEPIA2, BURNT) end,
      checkpoint = function(world, c, x, y, t)
        cairn(x, y, UMBER, { 1, 0.72, 0.35 }, c.active, t, c.tx, CREAM)
      end,
      ember = function(world, c, x, y, t)
        if c.taken then return end
        emberGem(x, y, t, c.tx, c.ty, { 1, 0.45, 0.12 }, { 1, 0.85, 0.45 })
      end,
    },
    door = function(cells, open) doorPaint(cells, open, UMBER, 4) end,
    player = function(p, alpha)
      atFeet(p)
      person({ 0.55, 0.28, 0.12 }, alpha, p.facing, CREAM)
      flame(0, -16, { 1, 0.45, 0.1 }, { 1, 0.9, 0.5 }, alpha)
      gfx.pop()
    end,
    ghost = function(e, frame, alpha)
      local cx, top = ghostAnchor(e, frame)
      local cy = top + 7
      local shift = e.mirrored and -3 or 3
      photoSplit(-shift, 1, 0.15, 0.22, 0.75 * alpha, cx, cy)
      photoSplit(shift, 0.15, 0.75, 1, 0.75 * alpha, cx, cy)
      rgb(CREAM, 0.95 * alpha)
      gfx.circle('fill', cx, cy, 4.2, 12)
      rgb(MOUNT, alpha)
      local dir = frame.facing or 1
      gfx.rectangle('fill', cx + dir - 2, cy - 1, 1, 2)
      gfx.rectangle('fill', cx + dir + 1, cy - 1, 1, 2)
    end,
    stroke = function(pts)
      for i = 1, #pts do
        local p = pts[i]
        photoSplit(-2, 1, 0.2, 0.25, 0.8 * p.a, p.x, p.y)
        photoSplit(2, 0.2, 0.8, 1, 0.8 * p.a, p.x, p.y)
      end
    end,
    post = function(ox, oy, s) blit(grade, ox, oy, s) end,
    wordmark = function(Ui, t)
      local f = Ui.fonts
      local y = 46
      gfx.setFont(f.title)
      gfx.setBlendMode('add')
      gfx.setColor(AFTER_R[1], AFTER_R[2], AFTER_R[3], 0.55)
      gfx.printf('ECHOES', -6, y, UIW, 'center')
      gfx.setColor(AFTER_C[1], AFTER_C[2], AFTER_C[3], 0.55)
      gfx.printf('ECHOES', 6, y, UIW, 'center')
      gfx.setBlendMode('alpha')
      textAt('ECHOES', f.title, y, MOUNT, 1)
      textAt('a small light remembers where it has been', f.mid, 184, UMBER, 0.9)
    end,
    text = function(str, font, y, color, alpha, x, limit, align)
      textShadow(str, font, y, color, alpha, x, limit, align, { 1, 0.95, 0.88, 0.35 })
    end,
    glowText = function(str, font, y, color, alpha, glow, x, limit)
      gfx.setFont(font)
      local px, w, a = x or 0, limit or UIW, alpha or 1
      gfx.setBlendMode('add')
      gfx.setColor(AFTER_R[1], AFTER_R[2], AFTER_R[3], 0.4 * a)
      gfx.printf(str, px - 4, y, w, 'center')
      gfx.setColor(AFTER_C[1], AFTER_C[2], AFTER_C[3], 0.4 * a)
      gfx.printf(str, px + 4, y, w, 'center')
      gfx.setBlendMode('alpha')
      textAt(str, font, y, color, a, px, w, 'center')
    end,
    panel = function(x, y, w, h, alpha)
      alpha = alpha or 1
      rgb(MOUNT, 0.12 * alpha)
      gfx.rectangle('fill', x + 4, y + 4, w, h)
      rgb(CREAM, 0.94 * alpha)
      gfx.rectangle('fill', x, y, w, h)
      rgb(MOUNT, 0.8 * alpha)
      gfx.setLineWidth(1)
      gfx.rectangle('line', x + 5.5, y + 5.5, w - 11, h - 11)
    end,
    cursor = function(left, ry, w, rh)
      local cy = ry + (rh - 4) / 2
      rgb(BURNT, 1)
      gfx.polygon('fill', left + 10, cy - 5, left + 18, cy, left + 10, cy + 5)
    end,
    dim = dimOf(CREAM, 0.5),
    iris = irisOf(UMBER, CREAM),
    footer = footerOf(MOUNT, BURNT, MOUNT),
    emberIcon = emberOf({ 1, 0.45, 0.12 }, { 1, 0.85, 0.5 }),
    hud = function(world, ctx)
      drawHud(world, ctx, {
        ink = MOUNT, dim = UMBER, accent = AFTER_C, hot = BURNT, pip = 'circle', meter = 'film', chip = CREAM,
      })
    end,
  }
end

local M = {}

function M.get(id)
  return looks[id]()
end

return M
