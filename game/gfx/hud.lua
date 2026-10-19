local Echo = require 'world.echo'
local Ui = require 'gfx.ui'
local Model = require 'gfx.hudmodel'

local gfx = love.graphics
local sin, pi = math.sin, math.pi
local STEP = 1 / 60

local Hud = {}

local function ring(x, y, r, frac, width)
  gfx.setLineWidth(width)
  if frac >= 0.999 then
    gfx.circle('line', x, y, r)
  elseif frac > 0.005 then
    gfx.arc('line', 'open', x, y, r, -pi / 2, -pi / 2 + 2 * pi * frac, 32)
  end
end

local CYAN = { 0.45, 0.95, 1 }

local function drawPip(slot, x, y, t)
  gfx.setColor(0.55, 0.7, 1, 0.22)
  ring(x, y, 12, 1, 2)
  if not slot.alive then
    gfx.setColor(0.55, 0.7, 1, 0.12)
    gfx.circle('fill', x, y, 3)
    return
  end
  local flicker = slot.fading and (0.5 + 0.5 * sin(t * 30)) or 1
  local pulse = slot.replaying and (0.8 + 0.2 * sin(t * 8)) or 1
  gfx.setBlendMode('add')
  gfx.setColor(CYAN[1], CYAN[2], CYAN[3], 0.16 * flicker)
  gfx.circle('fill', x, y, 11)
  gfx.setBlendMode('alpha')
  gfx.setColor(CYAN[1], CYAN[2], CYAN[3], 0.95 * flicker * pulse)
  ring(x, y, 12, slot.frac, 3)
  gfx.circle('fill', x, y, 4)
end

local function drawMemory(world, x, y)
  local frac = Model.memory(world)
  local full = frac >= 1
  local w = 78
  local a = full and 0.35 or 0.9
  gfx.setColor(1, 1, 1, 0.1 * a)
  gfx.rectangle('fill', x, y, w, 4, 2, 2)
  gfx.setColor(1, 0.82, 0.45, a)
  gfx.rectangle('fill', x, y, w * frac, 4, 2, 2)
  local f = Ui.fonts.tiny
  local label = full and 'memory 3.0s' or ('memory %.1fs'):format(frac * Echo.FRAMES * STEP)
  Ui.text(label, f, y + 8, Ui.colors.dim, full and 0.5 or 0.9, x, 140, 'left')
end

local function drawPlayerRing(world, camx, camy, t)
  local frac = Model.memory(world)
  local p = world.player
  if frac >= 1 or p.state == 'dead' or p.state == 'cleared' then return end
  local x, y = (p.x + p.w / 2 - camx) * 2, (p.y + p.h / 2 - camy) * 2
  gfx.setColor(1, 0.82, 0.45, 0.12)
  ring(x, y, 24, 1, 2)
  gfx.setColor(1, 0.82, 0.45, 0.55 + 0.1 * sin(t * 6))
  ring(x, y, 24, frac, 2)
end

local BEACON = { 0.6, 1, 0.8 }
local LABEL_LIFE = 1.6

-- "waystone lit" rises and fades over the player for a moment after a checkpoint is touched.
local function drawCheckpointLabel(world, ctx)
  local age = ctx.checkpointT
  if not age or age >= LABEL_LIFE then return end
  local p = world.player
  local a = age < 0.2 and age / 0.2 or 1 - (age - 0.2) / (LABEL_LIFE - 0.2)
  local x = (p.x + p.w / 2 - ctx.camx) * 2
  local y = (p.y - ctx.camy) * 2 - 34 - age * 14
  Ui.text('waystone lit', Ui.fonts.small, y, BEACON, a, x - 100, 200, 'center')
end

-- ctx: index, name, time, deaths, camx, camy, checkpointT (seconds since a waystone lit, or nil)
function Hud.draw(world, ctx)
  local f, t = Ui.fonts, Ui.time()
  drawPlayerRing(world, ctx.camx, ctx.camy, t)
  drawCheckpointLabel(world, ctx)
  Ui.text(('%d  %s'):format(ctx.index, ctx.name), f.small, 14, Ui.colors.amber, 0.75 * (ctx.nameAlpha or 1), 20, 400, 'left')
  Ui.text(Model.clock(ctx.time), f.small, 14, Ui.colors.white, 0.7, -20, Ui.W, 'right')
  local d = ctx.deaths
  Ui.text(d == 0 and 'no deaths' or (d == 1 and '1 death' or d .. ' deaths'), f.tiny, 36, Ui.colors.dim, 0.7, -20, Ui.W, 'right')
  if #world.embers > 0 then
    local lit = world:emberTaken()
    local pop = ctx.emberT and ctx.emberT < 0.4 and 1 + 0.6 * (1 - ctx.emberT / 0.4) or 1
    Ui.ember(28, 58, lit, lit and 0.95 or 0.6, pop)
  end
  local slots = Model.slots(world)
  for k = 1, #slots do drawPip(slots[k], 36 + (k - 1) * 32, Ui.H - 46, t) end
  drawMemory(world, 98, Ui.H - 52)
end

return Hud
