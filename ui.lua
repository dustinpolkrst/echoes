local Render = require 'render'
local Menu = require 'menu'

local gfx = love.graphics
local sin, min, max = math.sin, math.min, math.max

local U = { W = 960, H = 540 }

local SIZES = { title = 120, big = 34, menu = 26, mid = 20, small = 15, tiny = 12 }

U.colors = {
  amber = { 1, 0.82, 0.45 },
  cyan = { 0.45, 0.95, 1 },
  white = { 0.92, 0.94, 1 },
  dim = { 0.62, 0.67, 0.88 },
  locked = { 0.4, 0.43, 0.6 },
}
local C = U.colors

local fontScale
-- dpiscale renders glyphs at the real pixel size, so text stays crisp at any window scale.
local function buildFonts(scale)
  local fonts = {}
  for name, size in pairs(SIZES) do fonts[name] = gfx.newFont(size, 'normal', scale) end
  U.fonts = fonts
  fontScale = scale
end

function U.begin()
  local s = Render.scale / 2
  if s ~= fontScale then buildFonts(s) end
  gfx.push()
  gfx.translate(Render.ox, Render.oy)
  gfx.scale(s, s)
end

function U.finish()
  gfx.pop()
end

function U.time()
  return love.timer.getTime()
end

function U.text(str, font, y, color, alpha, x, limit, align)
  gfx.setFont(font)
  alpha = alpha or 1
  local px, w = x or 0, limit or U.W
  align = align or 'center'
  gfx.setColor(0, 0, 0, 0.6 * alpha)
  gfx.printf(str, px + 1.5, y + 1.5, w, align)
  gfx.setColor(color[1], color[2], color[3], alpha)
  gfx.printf(str, px, y, w, align)
end

local GLOW_OFFSETS = { { 0, 0 }, { 3, 0 }, { -3, 0 }, { 0, 3 }, { 0, -3 }, { 6, 6 }, { -6, 6 }, { 6, -6 }, { -6, -6 } }

function U.glowText(str, font, y, color, alpha, glowColor, x, limit)
  gfx.setFont(font)
  local px, w = x or 0, limit or U.W
  gfx.setBlendMode('add')
  for _, o in ipairs(GLOW_OFFSETS) do
    gfx.setColor(glowColor[1], glowColor[2], glowColor[3], 0.07 * alpha)
    gfx.printf(str, px + o[1], y + o[2], w, 'center')
  end
  gfx.setBlendMode('alpha')
  gfx.setColor(0, 0, 0, 0.5 * alpha)
  gfx.printf(str, px + 3, y + 3, w, 'center')
  gfx.setColor(color[1], color[2], color[3], alpha)
  gfx.printf(str, px, y, w, 'center')
end

function U.dim(alpha)
  gfx.setColor(0.02, 0.025, 0.07, alpha)
  gfx.rectangle('fill', 0, 0, U.W, U.H)
end

function U.panel(x, y, w, h, alpha)
  alpha = alpha or 1
  gfx.setColor(0.03, 0.04, 0.1, 0.82 * alpha)
  gfx.rectangle('fill', x, y, w, h, 6, 6)
  gfx.setLineWidth(1)
  gfx.setColor(0.45, 0.9, 1, 0.28 * alpha)
  gfx.rectangle('line', x + 0.5, y + 0.5, w - 1, h - 1, 6, 6)
  gfx.setColor(1, 0.8, 0.45, 0.5 * alpha)
  gfx.rectangle('fill', x + 18, y, w - 36, 2)
end

function U.iris(coverage, cx, cy)
  if coverage <= 0 then return end
  gfx.setColor(0.01, 0.01, 0.03, 1)
  if coverage >= 0.999 then
    gfx.rectangle('fill', -2000, -2000, 5000, 4000)
    return
  end
  local r = (1 - coverage) * 1100
  gfx.stencil(function() gfx.circle('fill', cx, cy, r, 64) end, 'replace', 1)
  gfx.setStencilTest('less', 1)
  gfx.rectangle('fill', -2000, -2000, 5000, 4000)
  gfx.setStencilTest()
  gfx.setColor(1, 0.8, 0.45, 0.35)
  gfx.setLineWidth(2)
  gfx.circle('line', cx, cy, r, 64)
end

function U.scissor(x, y, w, h)
  local s = Render.scale / 2
  gfx.setScissor(Render.ox + x * s, Render.oy + y * s, w * s, h * s)
end

local function triangle(x, y, size, dir)
  gfx.polygon('fill', x, y - size, x + dir * size * 1.4, y, x, y + size)
end

function U.menu(m, cx, y, o)
  o = o or {}
  local f = U.fonts
  local font = o.font or f.menu
  local rh, w = o.rowHeight or 44, o.width or 420
  local left, right = cx - w / 2, cx + w / 2
  local twoCol = false
  for _, item in ipairs(m.items) do
    if item.value then twoCol = true end
  end
  local pulse = 0.5 + 0.5 * sin(U.time() * 4)
  for i, item in ipairs(m.items) do
    local ry = y + (i - 1) * rh
    local sel = i == m.index
    local ty = ry + (rh - 4 - font:getHeight()) / 2
    local color = sel and C.amber or C.dim
    local a = sel and 1 or 0.78
    if sel then
      gfx.setColor(1, 0.75, 0.35, 0.09 + 0.05 * pulse)
      gfx.rectangle('fill', left, ry, w, rh - 4, 4, 4)
      gfx.setColor(1, 0.8, 0.45, 0.9)
      gfx.rectangle('fill', left, ry + 4, 3, rh - 12)
      gfx.setColor(C.amber[1], C.amber[2], C.amber[3], 0.9)
      triangle(left + 16, ry + (rh - 4) / 2, 5, 1)
    end
    if twoCol then
      U.text(Menu.label(m, i), font, ty, color, a, left + 34, w, 'left')
      if item.value then
        local text = item.value()
        local vx = right - 16
        gfx.setFont(font)
        local tw = font:getWidth(text)
        if item.meter then
          local frac, bw = max(0, min(1, item.meter())), 110
          local bx = vx - 84 - bw
          local by = ry + (rh - 4) / 2 - 3
          gfx.setColor(1, 1, 1, 0.12)
          gfx.rectangle('fill', bx, by, bw, 6, 3, 3)
          gfx.setColor(sel and 1 or 0.7, sel and 0.8 or 0.7, sel and 0.45 or 0.85, 0.95)
          gfx.rectangle('fill', bx, by, bw * frac, 6, 3, 3)
          tw = 0
          U.text(text, font, ty, color, a, vx - 80, 80, 'right')
        else
          local vc = (text == 'On') and C.cyan or color
          U.text(text, font, ty, vc, a, vx - 200, 200, 'right')
        end
        if sel and item.adjust then
          local cy = ry + (rh - 4) / 2
          gfx.setColor(C.amber[1], C.amber[2], C.amber[3], 0.8)
          local lx = item.meter and (vx - 84 - 110 - 14) or (vx - tw - 14)
          triangle(lx, cy, 4, -1)
          triangle(right - 4, cy, 4, 1)
        end
      end
    else
      U.text(Menu.label(m, i), font, ty, color, a, left, w, 'center')
    end
  end
end

-- hints: { {key, label}, ... } centred along the bottom edge.
function U.footer(hints, y)
  local font = U.fonts.small
  y = y or 496
  gfx.setFont(font)
  local gap, padX = 26, 8
  local widths, total = {}, 0
  for i, h in ipairs(hints) do
    local kw = font:getWidth(h[1]) + padX * 2
    widths[i] = { kw = kw, lw = font:getWidth(h[2]) }
    total = total + kw + 8 + widths[i].lw + (i > 1 and gap or 0)
  end
  local x = (U.W - total) / 2
  local fh = font:getHeight()
  for i, h in ipairs(hints) do
    local wd = widths[i]
    gfx.setColor(1, 0.82, 0.45, 0.16)
    gfx.rectangle('fill', x, y - 2, wd.kw, fh + 4, 4, 4)
    gfx.setColor(1, 0.82, 0.45, 0.6)
    gfx.rectangle('line', x + 0.5, y - 1.5, wd.kw - 1, fh + 3, 4, 4)
    gfx.setColor(1, 0.9, 0.65, 1)
    gfx.print(h[1], x + padX, y)
    gfx.setColor(C.dim[1], C.dim[2], C.dim[3], 0.95)
    gfx.print(h[2], x + wd.kw + 8, y)
    x = x + wd.kw + 8 + wd.lw + gap
  end
end

return U
