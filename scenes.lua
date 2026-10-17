local Level = require 'level'
local Levels = require 'levels'
local Player = require 'player'
local Render = require 'render'
local Particles = require 'particles'
local Sfx = require 'sfx'
local Input = require 'input'

local gfx = love.graphics
local floor, sin, pi, min, max = math.floor, math.sin, math.pi, math.min, math.max
local DT = Level.DT
local T = Level.T

local S = {}
local current
local run = { deaths = 0, time = 0 }

local COLORS = {
  amber = { 1, 0.82, 0.45 },
  cyan = { 0.45, 0.95, 1 },
  white = { 0.92, 0.94, 1 },
}

S.readInput = Input.read

-- Replaced by --shot so a scripted run can drive the same scenes; receives the live world.
S.inputSource = function() return Input.read() end

local function clock(seconds)
  local m = floor(seconds / 60)
  return ('%d:%04.1f'):format(m, seconds - m * 60)
end

-- Camera -------------------------------------------------------------------

local cam = { x = 0, y = 0 }
local LOOKAHEAD = 30

local function camTarget(world)
  local p = world.player
  local tx = p.x + p.w / 2 - Render.W / 2 + p.facing * LOOKAHEAD
  local ty = p.y + p.h / 2 - Render.H / 2 - 8
  local maxX, maxY = world.W * T - Render.W, world.H * T - Render.H
  tx = maxX <= 0 and maxX / 2 or max(0, min(maxX, tx))
  ty = maxY <= 0 and maxY / 2 or max(0, min(maxY, ty))
  return tx, ty
end

local function followCamera(world, snap)
  local tx, ty = camTarget(world)
  if snap then
    cam.x, cam.y = tx, ty
  else
    local k = 1 - math.exp(-6 * DT)
    cam.x = cam.x + (tx - cam.x) * k
    cam.y = cam.y + (ty - cam.y) * k
  end
end

-- Event reactions ----------------------------------------------------------

local shake = 0

local DUST = { 0.55, 0.55, 0.8 }
local function react(world, ev)
  local x, y = ev.x, ev.y
  if ev.name == 'jump' then
    Sfx.play('jump')
    Particles.burst(x, y, 6, { dir = -pi / 2, spread = pi * 0.9, speed = 30, life = 0.35, grav = 60, color = DUST })
  elseif ev.name == 'land' then
    Sfx.play('land', 0.9 + min(0.3, ev.v / 1500))
    Particles.burst(x, y, 4 + floor(ev.v / 60), { dir = -pi / 2, spread = pi * 0.95, speed = 45, life = 0.4, grav = 80, color = DUST })
  elseif ev.name == 'death' then
    Sfx.play('death')
    Input.rumble(0.6, 0.25)
    run.deaths = run.deaths + 1
    shake = 5
    Particles.burst(x, y, 34, { speed = 110, life = 0.8, grav = 120, drag = 1.2, color = { 1, 0.7, 0.25 }, glow = true, size = 2 })
    Particles.burst(x, y, 16, { speed = 60, life = 1.0, grav = -10, color = { 1, 0.95, 0.7 }, glow = true })
  elseif ev.name == 'cast' then
    Sfx.play('cast')
    Input.rumble(0.25, 0.12)
    Particles.burst(x, y, 26, { speed = 70, life = 0.7, drag = 2, color = { 0.4, 0.95, 1 }, glow = true })
  elseif ev.name == 'plate' then
    Sfx.play('plate', ev.v and 1 or 0.8)
    Particles.burst(x, y - 2, 6, { dir = -pi / 2, spread = pi, speed = 40, life = 0.4, grav = 80, color = { 0.6, 0.95, 1 }, glow = true })
  elseif ev.name == 'door' then
    Sfx.play('door', ev.v and 1 or 0.85)
    Particles.burst(x, y, 12, { dir = pi / 2, spread = pi, speed = 25, life = 0.7, grav = 40, color = DUST, jitter = 8 })
  elseif ev.name == 'goal' then
    Sfx.play('goal')
    Particles.burst(x, y, 30, { speed = 90, life = 1.0, drag = 1.5, color = { 0.7, 1, 0.95 }, glow = true })
  end
end

local function ambientParticles(world)
  local rand = love.math.random
  for _, e in ipairs(world.echoes) do
    if rand() < 0.2 then
      Particles.burst(e.x + e.w / 2 + (rand() - 0.5) * 6, e.y + 8, 1, { dir = -pi / 2, spread = 0.6, speed = 14, life = 0.7, color = { 0.4, 0.95, 1 }, glow = true })
    end
  end
  for _, l in ipairs(world.lights) do
    if rand() < 0.06 then
      Particles.burst(l.x, l.y - 2, 1, { dir = -pi / 2, spread = 0.8, speed = 18, life = 0.9, color = { 1, 0.6, 0.2 }, glow = true })
    end
  end
end

-- Shared world stepping ------------------------------------------------------

local function stepWorld(world, input)
  Level.step(world, input)
  for _, ev in ipairs(world.events) do react(world, ev) end
  ambientParticles(world)
  Particles.update(DT)
  Render.update(world, DT)
  shake = shake * 0.88
end

local function drawScene(world)
  Render.beginFrame()
  local sx, sy = 0, 0
  if shake > 0.3 then
    sx, sy = love.math.random() * shake - shake / 2, love.math.random() * shake - shake / 2
  end
  local camx, camy = floor(cam.x + sx + 0.5), floor(cam.y + sy + 0.5)
  Render.drawBackground(camx, camy, Render.t)
  gfx.push()
  gfx.translate(-camx, -camy)
  Render.drawWorld(world)
  Particles.draw()
  gfx.pop()
  Render.drawLighting(world, camx, camy)
  Render.drawGlows(world, camx, camy)
  Render.drawMotes(camx, camy, Render.t)
end

-- Title / ending backdrop ----------------------------------------------------

local ambient = {}

local HALL = {
  '########################################',
  '#......................................#',
  '#......................................#',
  '#......................................#',
  '#......................................#',
  '#...t..........t..........t.........t..#',
  '#......................................#',
  '#......................................#',
  '#......................................#',
  '#...........##..................##.....#',
  '#..........####................####....#',
  '#.P.......######..............######...#',
  '########################################',
  '########################################',
}

local function loadAmbient()
  ambient.world = Level.new({ name = 'hall', map = HALL })
  Render.buildLevel(ambient.world)
  ambient.frame = 0
  Particles.clear()
  followCamera(ambient.world, true)
end

-- Walks back and forth, hopping and leaving echoes so the menus show the mechanic.
local function demoInput(f)
  local phase = f % 600
  local going = phase < 300
  return {
    right = going and phase > 10 and phase < 290,
    left = not going and phase < 590,
    jump = (phase % 100 > 40 and phase % 100 < 58),
    cast = phase == 200 or phase == 500,
  }
end

local function stepAmbient()
  ambient.frame = ambient.frame + 1
  stepWorld(ambient.world, demoInput(ambient.frame))
  local p = ambient.world.player
  if p.y > 400 or p.state == 'dead' then loadAmbient() end
  followCamera(ambient.world)
end

local function glowText(str, font, y, color, alpha, glowColor)
  gfx.setFont(font)
  local w = gfx.getWidth()
  gfx.setBlendMode('add')
  for _, o in ipairs({ { 0, 0 }, { 3, 0 }, { -3, 0 }, { 0, 3 }, { 0, -3 }, { 6, 6 }, { -6, 6 }, { 6, -6 }, { -6, -6 } }) do
    gfx.setColor(glowColor[1], glowColor[2], glowColor[3], 0.07 * alpha)
    gfx.printf(str, o[1], y + o[2], w, 'center')
  end
  gfx.setBlendMode('alpha')
  gfx.setColor(0, 0, 0, 0.5 * alpha)
  gfx.printf(str, 3, y + 3, w, 'center')
  gfx.setColor(color[1], color[2], color[3], alpha)
  gfx.printf(str, 0, y, w, 'center')
end

-- Title ----------------------------------------------------------------------

S.title = {}

function S.title.enter()
  loadAmbient()
  S.title.t = 0
end

function S.title.update()
  S.title.t = S.title.t + DT
  stepAmbient()
end

function S.title.draw()
  drawScene(ambient.world)
end

function S.title.drawUI()
  local t = S.title.t
  local f = Render.fonts
  local pulse = 0.85 + 0.15 * sin(t * 2)
  gfx.setFont(f.title)
  local w = gfx.getWidth()
  for i = 3, 1, -1 do
    gfx.setColor(0.35, 0.9, 1, 0.1 * pulse * (4 - i) / 3)
    gfx.printf('ECHOES', -i * 14, 54, w, 'center')
  end
  glowText('ECHOES', f.title, 54, { 1, 0.88, 0.55 }, 1, { 1, 0.6, 0.2 })
  Render.text('a small light remembers where it has been', f.mid, 200, COLORS.cyan, 0.8)
  if (t * 1.6) % 1 < 0.7 then
    Render.text(Input.confirmLabel(), f.big, 400, COLORS.white, 1)
  end
  Render.text(Input.confirmKeys(), f.small, 450, { 0.6, 0.65, 0.85 }, 0.8)
end

function S.title.action(action)
  if action == 'confirm' then
    run.deaths, run.time = 0, 0
    S.go('playing', 1)
  end
end

-- Playing --------------------------------------------------------------------

local playing = {}
S.playing = playing

local function loadLevel()
  playing.world = Level.new(Levels[playing.index])
  Render.buildLevel(playing.world)
  Particles.clear()
  followCamera(playing.world, true)
  playing.t = 0
end

function playing.enter(index)
  playing.index = index
  shake = 0
  loadLevel()
end

function playing.update()
  local world = playing.world
  stepWorld(world, S.inputSource(world))
  playing.t = playing.t + DT
  local p = world.player
  if p.state ~= 'cleared' then run.time = run.time + DT end
  followCamera(world)
  if p.state == 'dead' and p.stateT >= Player.DEATH_DELAY then
    loadLevel()
  elseif p.state == 'cleared' and p.stateT >= 1.1 then
    S.go('levelclear', playing.index)
  end
end

function playing.draw()
  drawScene(playing.world)
end

function playing.drawUI()
  local world, f = playing.world, Render.fonts
  local t = playing.t
  local a = t < 2.8 and 1 or max(0, 1 - (t - 2.8) / 1.4)
  if a > 0 then
    glowText(('%d. %s'):format(playing.index, world.name), f.big, 36, COLORS.amber, a, { 1, 0.6, 0.2 })
    Render.text(Input.hint(world.hint), f.mid, 86, COLORS.white, a)
  end
  gfx.setFont(f.small)
  gfx.setColor(0.7, 0.75, 0.95, 0.6)
  gfx.printf(('deaths %d    %s'):format(run.deaths, clock(run.time)), -16, 12, gfx.getWidth(), 'right')
  local p = world.player
  if p.state == 'cleared' then
    gfx.setColor(1, 1, 1, min(0.6, p.stateT * 0.7))
    gfx.rectangle('fill', 0, 0, gfx.getDimensions())
  end
end

function playing.action(action)
  if action == 'restart' then loadLevel() end
end

-- Level clear ----------------------------------------------------------------

S.levelclear = {}

function S.levelclear.enter(index)
  S.levelclear.index = index
  S.levelclear.t = 0
end

function S.levelclear.update()
  local lc = S.levelclear
  lc.t = lc.t + DT
  Render.update(playing.world, DT)
  Particles.update(DT)
  if lc.t >= 2.2 then S.levelclear.advance() end
end

function S.levelclear.advance()
  local nextIndex = S.levelclear.index + 1
  if nextIndex > #Levels then
    S.go('ending')
  else
    S.go('playing', nextIndex)
  end
end

function S.levelclear.draw()
  drawScene(playing.world)
end

function S.levelclear.drawUI()
  local lc, f = S.levelclear, Render.fonts
  local a = min(1, lc.t * 2)
  gfx.setColor(0.03, 0.03, 0.1, 0.55 * a)
  gfx.rectangle('fill', 0, 0, gfx.getDimensions())
  glowText('echo kept', f.big, 190, COLORS.cyan, a, { 0.3, 0.9, 1 })
  Render.text(('deaths %d    time %s'):format(run.deaths, clock(run.time)), f.mid, 250, COLORS.white, a)
  if sin(lc.t * 5) > -0.2 then Render.text(Input.confirmLabel(), f.small, 310, { 0.7, 0.75, 0.95 }, a) end
end

function S.levelclear.action(action)
  if action == 'confirm' and S.levelclear.t > 0.5 then S.levelclear.advance() end
end

-- Ending ---------------------------------------------------------------------

S.ending = {}

function S.ending.enter()
  loadAmbient()
  S.ending.t = 0
end

function S.ending.update()
  S.ending.t = S.ending.t + DT
  stepAmbient()
end

function S.ending.draw()
  drawScene(ambient.world)
end

function S.ending.drawUI()
  local e, f = S.ending, Render.fonts
  local a = min(1, e.t * 0.8)
  gfx.setColor(0.03, 0.03, 0.1, 0.5)
  gfx.rectangle('fill', 0, 120, gfx.getWidth(), 300)
  glowText('YOU FOUND THE WAY OUT', f.big, 140, COLORS.amber, a, { 1, 0.6, 0.2 })
  Render.text(('deaths  %d'):format(run.deaths), f.mid, 230, COLORS.white, a)
  Render.text(('time  %s'):format(clock(run.time)), f.mid, 265, COLORS.white, a)
  Render.text('the echoes fade, the light remains', f.small, 320, COLORS.cyan, a * 0.8)
  if e.t > 1.2 and sin(e.t * 3) > -0.3 then Render.text(Input.confirmLabel(), f.mid, 370, COLORS.white, 1) end
end

function S.ending.action(action)
  if action == 'confirm' and S.ending.t > 1.2 then S.go('title') end
end

-- Dispatch -------------------------------------------------------------------

function S.go(name, ...)
  S.name = name
  current = S[name]
  if current.enter then current.enter(...) end
end

function S.update()
  current.update()
end

function S.draw()
  current.draw()
  Render.present()
  if current.drawUI then current.drawUI() end
end

function S.action(action)
  if current.action then current.action(action) end
end

return S
