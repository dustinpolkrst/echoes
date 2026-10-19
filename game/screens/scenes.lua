local Level = require 'world.level'
local Levels = require 'content.levels'
local Player = require 'world.player'
local Timeline = require 'world.timeline'
local Render = require 'gfx.render'
local Particles = require 'gfx.particles'
local Sfx = require 'platform.sfx'
local Input = require 'platform.input'
local Save = require 'platform.save'
local Progress = require 'screens.progress'
local Menu = require 'screens.menu'
local Trans = require 'screens.transition'
local Ui = require 'gfx.ui'
local Hud = require 'gfx.hud'
local Assets = require 'platform.assets'

local gfx = love.graphics
local floor, sin, pi, min, max = math.floor, math.sin, math.pi, math.min, math.max
local DT = Level.DT
local T = Level.T
local C = Ui.colors

local S = {}
local current

S.readInput = Input.read

-- Replaced by --shot so a scripted run can drive the same scenes; receives the live world.
S.inputSource = function() return Input.read() end

local clock = require('gfx.hudmodel').clock


S.store = Save.open({ read = function() return nil end, write = function() return true end })

local function data() return S.store.data end
local function persist() Save.persist(S.store) end

local function totalEmbers()
  local n = 0
  for _, def in ipairs(Levels) do
    if Progress.hasEmber(def) then n = n + 1 end
  end
  return n
end

function S.applySettings()
  local s = data().settings
  love.audio.setVolume(s.master)
  Sfx.volume = s.sfx
  if love.window.getFullscreen() ~= s.fullscreen then love.window.setFullscreen(s.fullscreen, 'desktop') end
end

function S.init(store)
  S.store = store
  S.applySettings()
end


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

local function followCamera(stage, snap)
  local cam = stage.cam
  local tx, ty = camTarget(stage.world)
  if snap then
    cam.x, cam.y = tx, ty
  else
    local k = 1 - math.exp(-6 * DT)
    cam.x = cam.x + (tx - cam.x) * k
    cam.y = cam.y + (ty - cam.y) * k
  end
end


local stats = { deaths = 0 }

local DUST = { 0.55, 0.55, 0.8 }
local function react(stage, ev)
  local x, y = ev.x, ev.y
  local function burst(n, opts) Particles.burst(stage.particles, x, y, n, opts) end
  if ev.name == 'jump' then
    Sfx.play('jump')
    burst(6, { dir = -pi / 2, spread = pi * 0.9, speed = 30, life = 0.35, grav = 60, color = DUST })
  elseif ev.name == 'land' then
    Sfx.play('land', 0.9 + min(0.3, ev.v / 1500))
    burst(4 + floor(ev.v / 60), { dir = -pi / 2, spread = pi * 0.95, speed = 45, life = 0.4, grav = 80, color = DUST })
  elseif ev.name == 'death' then
    Sfx.play('death')
    Input.rumble(0.6, 0.25)
    stats.deaths = stats.deaths + 1
    stage.shake = data().settings.shake and 5 or 0
    burst(34, { speed = 110, life = 0.8, grav = 120, drag = 1.2, color = { 1, 0.7, 0.25 }, glow = true, size = 2 })
    burst(16, { speed = 60, life = 1.0, grav = -10, color = { 1, 0.95, 0.7 }, glow = true })
  elseif ev.name == 'cast' then
    Sfx.play('cast', ev.v and 0.8 or 1)
    Input.rumble(0.25, 0.12)
    burst(26, { speed = 70, life = 0.7, drag = 2, color = ev.v and { 0.85, 0.5, 1 } or { 0.4, 0.95, 1 }, glow = true })
  elseif ev.name == 'crumble' then
    Sfx.play('crumble', ev.v and 1 or 1.4)
    burst(ev.v and 14 or 5, { dir = pi / 2, spread = pi * 0.8, speed = 40, life = 0.6, grav = 160, color = { 0.55, 0.42, 0.28 } })
  elseif ev.name == 'plate' then
    Sfx.play('plate', ev.v and 1 or 0.8)
    Particles.burst(stage.particles, x, y - 2, 6, { dir = -pi / 2, spread = pi, speed = 40, life = 0.4, grav = 80, color = { 0.6, 0.95, 1 }, glow = true })
  elseif ev.name == 'door' then
    Sfx.play('door', ev.v and 1 or 0.85)
    burst(12, { dir = pi / 2, spread = pi, speed = 25, life = 0.7, grav = 40, color = DUST, jitter = 8 })
  elseif ev.name == 'goal' then
    Sfx.play('goal')
    burst(30, { speed = 90, life = 1.0, drag = 1.5, color = { 0.7, 1, 0.95 }, glow = true })
  elseif ev.name == 'ember' then
    Sfx.play('ember', ev.v and 1.25 or 1)
    Input.rumble(0.2, 0.15)
    stage.emberT = 0
    burst(30, { speed = 80, life = 0.9, drag = 1.6, grav = -30, color = { 1, 0.7, 0.25 }, glow = true })
  elseif ev.name == 'checkpoint' then
    Sfx.play('checkpoint')
    Input.rumble(0.15, 0.1)
    stage.checkpointT = 0
    burst(22, { dir = -pi / 2, spread = pi * 0.7, speed = 55, life = 0.9, grav = -20, drag = 1.5, color = { 0.6, 1, 0.8 }, glow = true })
  end
end

local function ambientParticles(stage)
  local rand = love.math.random
  local world = stage.world
  for _, e in ipairs(world.echoes) do
    if rand() < 0.2 then
      Particles.burst(stage.particles, e.x + e.w / 2 + (rand() - 0.5) * 6, e.y + 8, 1, { dir = -pi / 2, spread = 0.6, speed = 14, life = 0.7, color = { 0.4, 0.95, 1 }, glow = true })
    end
  end
  for _, l in ipairs(world.lights) do
    if rand() < 0.06 then
      Particles.burst(stage.particles, l.x, l.y - 2, 1, { dir = -pi / 2, spread = 0.8, speed = 18, life = 0.9, color = { 1, 0.6, 0.2 }, glow = true })
    end
  end
end


local function setStage(stage, world)
  stage.world, stage.cam, stage.particles, stage.shake, stage.checkpointT, stage.emberT = world, {}, Particles.new(), 0, nil, nil
  followCamera(stage, true)
end

local function stepStage(stage, input)
  local world = stage.world
  Level.step(world, input)
  for _, ev in ipairs(world.events) do react(stage, ev) end
  ambientParticles(stage)
  Particles.update(stage.particles, DT)
  Render.update(world, DT)
  stage.shake = stage.shake * 0.88
  if stage.checkpointT then stage.checkpointT = stage.checkpointT + DT end
  if stage.emberT then stage.emberT = stage.emberT + DT end
end

local function drawScene(stage)
  local world, cam, shake = stage.world, stage.cam, stage.shake
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
  Particles.draw(stage.particles)
  gfx.pop()
  Render.drawLighting(world, camx, camy)
  Render.drawGlows(world, camx, camy)
  Render.drawMotes(camx, camy, Render.t)
end


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
  setStage(ambient, Level.new({ name = 'hall', map = HALL }))
  ambient.frame = 0
end

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
  stepStage(ambient, demoInput(ambient.frame))
  local p = ambient.world.player
  if p.y > 400 or p.state == 'dead' then loadAmbient() end
  followCamera(ambient)
end

local function ambientScene(scene)
  scene.update = stepAmbient
  scene.draw = function() drawScene(ambient) end
end


local function feedback(event)
  if event == 'move' then Sfx.play('plate', 1.6)
  elseif event == 'select' then Sfx.play('cast', 1.3)
  elseif event == 'adjust' then Sfx.play('plate', 1.25)
  elseif event == 'back' then Sfx.play('land', 0.8)
  elseif event == 'denied' then Sfx.play('land', 0.55) end
end

local function menuActions(getMenu)
  local t = {}
  for _, a in ipairs({ 'up', 'down', 'left', 'right', 'confirm' }) do
    t[a] = function() feedback(Menu.handle(getMenu(), a)) end
  end
  return t
end

local function withBack(actions, fn)
  actions.back = function() feedback('back') fn() end
  return actions
end

function S.go(name, ...)
  if current and current.leave then current.leave() end
  Input.requireRelease()
  S.name = name
  current = S[name]
  if current.enter then current.enter(...) end
end

function S.to(name, ...)
  local args = { n = select('#', ...), ... }
  return Trans.start(function() S.go(name, unpack(args, 1, args.n)) end)
end

local function startLevel(index)
  stats = { deaths = 0 }
  S.to('playing', index)
end

local function hints(...)
  local n = Input.names()
  local out = {}
  for _, h in ipairs({ ... }) do out[#out + 1] = { n[h[1]], h[2] } end
  return out
end

local function heading(text, y)
  Ui.glowText(text, Ui.fonts.big, y or 36, C.amber, 1, { 1, 0.6, 0.2 })
end


S.title = {}

function S.title.enter()
  loadAmbient()
  local d = data()
  local self = S.title
  self.t = 0
  local resumeAt = Progress.furthest(d, #Levels)
  self.resumeAt = Progress.started(d) and resumeAt or nil
  self.menu = Menu.new({
    { label = self.resumeAt and 'Continue' or 'Play', action = function() startLevel(resumeAt) end },
    { label = 'Level select', action = function() S.select.returnTo = { 'title' } S.to('select', resumeAt) end },
    { label = 'Settings', action = function() S.settings.returnTo = { 'title' } S.to('settings') end },
    { label = 'Quit', confirm = 'Really quit?', action = function() love.event.quit() end },
  })
end

ambientScene(S.title)

function S.title.update()
  S.title.t = S.title.t + DT
  stepAmbient()
end

function S.title.drawUI()
  local t, f = S.title.t, Ui.fonts
  local pulse = 0.85 + 0.15 * sin(t * 2)
  gfx.setFont(f.title)
  for i = 3, 1, -1 do
    gfx.setColor(0.35, 0.9, 1, 0.1 * pulse * (4 - i) / 3)
    gfx.printf('ECHOES', -i * 14, 40, Ui.W, 'center')
  end
  Ui.glowText('ECHOES', f.title, 40, { 1, 0.88, 0.55 }, 1, { 1, 0.6, 0.2 })
  Ui.text('a small light remembers where it has been', f.mid, 184, C.cyan, 0.8)
  Ui.panel(Ui.W / 2 - 190, 236, 380, 218, 0.9)
  Ui.menu(S.title.menu, Ui.W / 2, 250, { rowHeight = 46, width = 320 })
  if S.title.resumeAt then
    local l = Levels[S.title.resumeAt]
    Ui.text(('resume at %d, %s'):format(S.title.resumeAt, l.name), f.tiny, 434, C.dim, 0.8)
  end
  local found = Save.embers(data())
  if found > 0 then
    local label = ('%d of %d embers'):format(found, totalEmbers())
    local w = f.tiny:getWidth(label)
    Ui.ember(Ui.W / 2 - w / 2 - 12, 472, true, 0.9, 0.8)
    Ui.text(label, f.tiny, 465, C.amber, 0.8)
  end
  Ui.footer(hints({ 'move', 'Move' }, { 'confirm', 'Select' }))
end

S.title.actions = menuActions(function() return S.title.menu end)


local playing = {}
S.playing = playing

-- Death and R retry from the last waystone and keep the clock running; the pause menu's Restart level
-- starts the level over with a fresh clock.
local function loadAttempt(fromCheckpoint)
  local checkpoint = fromCheckpoint and playing.world and playing.world.respawn or nil
  local banked = checkpoint and playing.world:emberTaken()
  setStage(playing, Level.new(Levels[playing.index], { checkpoint = checkpoint }))
  if banked then
    for _, c in ipairs(playing.world.embers) do c.taken = true end
  end
  playing.timeline = Timeline.new(playing.world)
  playing.rewindT = 0
  if not checkpoint then
    playing.t = 0
    playing.attemptT = 0
  end
end

local function playerFocus()
  local p, cam = playing.world.player, playing.cam
  return (p.x + p.w / 2 - cam.x) * 2, (p.y + p.h / 2 - cam.y) * 2
end

function playing.enter(index)
  playing.index = index
  loadAttempt()
end

-- Holding rewind runs the world backwards, faster the longer it is held. The clock keeps running.
local REWIND_SPEEDS = { { 0, 1 }, { 1.2, 2 }, { 2.5, 4 } }
local DEATH_WAIT = Player.DEATH_DELAY + 0.6

local function rewind(world)
  local speed = 1
  for _, s in ipairs(REWIND_SPEEDS) do
    if playing.rewindT >= s[1] then speed = s[2] end
  end
  local moved = false
  for _ = 1, speed do
    moved = Timeline.back(playing.timeline, world) or moved
  end
  if moved and floor(playing.rewindT * 60) % 5 == 0 then Sfx.play('rewind', 0.9 + 0.1 * speed) end
  playing.rewindT = playing.rewindT + DT
  Particles.update(playing.particles, DT)
  Render.update(world, DT)
  return moved
end

function playing.update()
  local world = playing.world
  local input = S.inputSource(world)
  local p = world.player
  playing.rewinding = input.rewind and p.state ~= 'cleared' and rewind(world)
  if not playing.rewinding then
    playing.rewindT = 0
    stepStage(playing, input)
    Timeline.push(playing.timeline, world)
  end
  playing.t = playing.t + DT
  p = world.player
  if p.state ~= 'cleared' then playing.attemptT = playing.attemptT + DT end
  followCamera(playing)
  if p.state == 'dead' and p.stateT >= DEATH_WAIT and not input.rewind then
    local cx, cy = playerFocus()
    Trans.start(function() loadAttempt(true) end, cx, cy)
  elseif p.state == 'cleared' and p.stateT >= 1.1 then
    local cx, cy = playerFocus()
    Trans.start(function() S.go('levelclear', playing.index, playing.attemptT, world:emberTaken()) end, cx, cy)
  end
end

function playing.draw()
  drawScene(playing)
end

local function drawRewind()
  local t = playing.rewindT
  gfx.setBlendMode('add')
  gfx.setColor(0.25, 0.45, 0.9, 0.1)
  gfx.rectangle('fill', 0, 0, Ui.W, Ui.H)
  gfx.setColor(0.5, 0.8, 1, 0.05)
  for y = floor(t * 240) % 6, Ui.H, 6 do gfx.rectangle('fill', 0, y, Ui.W, 2) end
  gfx.setBlendMode('alpha')
  local x, y = Ui.W / 2 - 22, 70
  gfx.setColor(0.75, 0.92, 1, 0.85 + 0.15 * sin(t * 12))
  gfx.polygon('fill', x + 20, y, x + 20, y + 24, x, y + 12)
  gfx.polygon('fill', x + 44, y, x + 44, y + 24, x + 24, y + 12)
  local left = Timeline.seconds(playing.timeline)
  Ui.text(('%.1fs'):format(left), Ui.fonts.tiny, y + 32, C.white, 0.7)
end

function playing.drawUI()
  local world, f = playing.world, Ui.fonts
  local t = playing.t
  local a = t < 2.8 and 1 or max(0, 1 - (t - 2.8) / 1.4)
  if a > 0 then
    Ui.glowText(('%d. %s'):format(playing.index, world.name), f.big, 60, C.amber, a, { 1, 0.6, 0.2 })
    Ui.text(Input.hint(world.hint), f.mid, 110, C.white, a)
  end
  Hud.draw(world, {
    index = playing.index, name = world.name, time = playing.attemptT, deaths = stats.deaths,
    camx = playing.cam.x, camy = playing.cam.y, nameAlpha = 1 - a, checkpointT = playing.checkpointT,
    emberT = playing.emberT,
  })
  local p = world.player
  if playing.rewinding then
    drawRewind()
  elseif p.state == 'dead' and p.stateT > 0.25 then
    local a = min(1, (p.stateT - 0.25) * 4)
    local n = Input.names()
    Ui.text(('Hold %s to rewind     %s to retry'):format(n.rewind, n.restart), f.mid, Ui.H / 2 + 40, C.white, a)
  end
  if p.state == 'cleared' then
    gfx.setColor(1, 1, 1, min(0.6, p.stateT * 0.7))
    gfx.rectangle('fill', 0, 0, Ui.W, Ui.H)
  end
end

local function cleared() return playing.world.player.state == 'cleared' end

playing.actions = {
  restart = function()
    if cleared() then return end
    local cx, cy = playerFocus()
    Trans.start(function() loadAttempt(true) end, cx, cy)
  end,
  pause = function()
    if not cleared() then S.go('pause', 'playing') end
  end,
}

-- Pause: an overlay that keeps drawing the scene beneath it and never steps it ---------

local pause = {}
S.pause = pause

local BLUR = { { -3, 0 }, { 3, 0 }, { 0, -3 }, { 0, 3 } }

-- Nothing beneath the pause steps, so its frame, blur and dim are composed once into `still`.
local still, stillVersion

local function frozen()
  local w, h = gfx.getDimensions()
  return still and still:getWidth() == w and still:getHeight() == h and stillVersion == Assets.version
end

local function freeze()
  if frozen() then return end
  still, stillVersion = gfx.newCanvas(gfx.getDimensions()), Assets.version
  gfx.push('all')
  Render.present(still)
  Ui.begin()
  gfx.setColor(1, 1, 1, 0.28)
  for _, o in ipairs(BLUR) do gfx.draw(Render.game, o[1], o[2], 0, 2, 2) end
  Ui.dim(0.58)
  Ui.finish()
  gfx.pop()
end

function pause.leave()
  still = nil
end

local function resume()
  pause.leave()
  S.name = pause.under
  current = S[pause.under]
end

function pause.enter(under)
  pause.under = under
  pause.menu = Menu.new({
    { label = 'Resume', action = resume },
    { label = 'Restart level', action = function()
      Trans.start(function() loadAttempt(false) resume() end)
    end },
    { label = 'Level select', action = function()
      S.select.returnTo = { 'pause', 'playing' }
      S.to('select', playing.index)
    end },
    { label = 'Settings', action = function()
      S.settings.returnTo = { 'pause', 'playing' }
      S.to('settings')
    end },
    { label = 'Quit game', confirm = 'Really quit?', action = function() love.event.quit() end },
  })
end

function pause.update() end

function pause.draw()
  if not frozen() then S[pause.under].draw() end
end

function pause.drawUI()
  freeze()
  gfx.push('all')
  gfx.origin()
  gfx.setColor(1, 1, 1, 1)
  gfx.draw(still)
  gfx.pop()
  local f = Ui.fonts
  Ui.panel(Ui.W / 2 - 230, 96, 460, 342)
  heading('PAUSED', 114)
  Ui.text(('%d. %s'):format(playing.index, playing.world.name), f.small, 160, C.dim, 0.9)
  Ui.menu(pause.menu, Ui.W / 2, 196, { rowHeight = 46, width = 380 })
  Ui.footer(hints({ 'move', 'Move' }, { 'confirm', 'Select' }, { 'pause', 'Resume' }))
end

pause.actions = withBack(menuActions(function() return pause.menu end), resume)
pause.actions.pause = resume


local select_ = {}
S.select = select_
select_.returnTo = { 'title' }

local CARD_W, CARD_H, CARD_GAP = 172, 84, 10
local ROW_H, LABEL_H = CARD_H + 14, 28
local AREA_TOP, AREA_BOTTOM = 92, 488

function select_.enter(index)
  select_.sel = index or 1
  select_.rows = Progress.rows(Progress.acts(Levels))
  select_.scroll = nil
  loadAmbient()
end

local function rowTops(rows)
  local tops, y = {}, 0
  for i, row in ipairs(rows) do
    tops[i] = y
    y = y + ROW_H + (row.label and LABEL_H or 0)
  end
  return tops, y
end

local function selectedRow(rows, sel)
  for r, row in ipairs(rows) do
    for _, i in ipairs(row.indices) do
      if i == sel then return r end
    end
  end
  return 1
end

function select_.update()
  stepAmbient()
  local rows = select_.rows
  local tops, total = rowTops(rows)
  local r = selectedRow(rows, select_.sel)
  local viewH = AREA_BOTTOM - AREA_TOP
  local bottom = tops[r] + ROW_H + (rows[r].label and LABEL_H or 0)
  local target = max(0, min(max(0, total - viewH), bottom - viewH))
  if not select_.scroll then select_.scroll = target end
  select_.scroll = select_.scroll + (target - select_.scroll) * (1 - math.exp(-14 * DT))
end

select_.draw = function() drawScene(ambient) end

local function drawCheck(x, y, a)
  gfx.setLineWidth(2.5)
  gfx.setColor(C.cyan[1], C.cyan[2], C.cyan[3], a)
  gfx.line(x - 6, y, x - 2, y + 5, x + 7, y - 6)
end

local function drawLock(x, y, a)
  gfx.setColor(C.locked[1], C.locked[2], C.locked[3], a)
  gfx.rectangle('fill', x - 6, y - 1, 12, 9, 2, 2)
  gfx.setLineWidth(2)
  gfx.arc('line', 'open', x, y - 1, 4.5, pi, 2 * pi, 12)
end

local function drawCard(i, x, y, selected, pulse)
  local d = data()
  local rec = d.levels[i] or {}
  local open = Progress.unlocked(d, i)
  local done = Progress.done(d, i)
  local f = Ui.fonts
  gfx.setColor(0.03, 0.04, 0.1, open and 0.85 or 0.7)
  gfx.rectangle('fill', x, y, CARD_W, CARD_H, 6, 6)
  if selected then
    gfx.setColor(1, 0.75, 0.35, 0.1 + 0.06 * pulse)
    gfx.rectangle('fill', x, y, CARD_W, CARD_H, 6, 6)
    gfx.setLineWidth(2)
    gfx.setColor(1, 0.82, 0.45, 0.75 + 0.25 * pulse)
  else
    gfx.setLineWidth(1)
    if done then gfx.setColor(C.cyan[1], C.cyan[2], C.cyan[3], 0.45)
    elseif open then gfx.setColor(1, 0.82, 0.45, 0.3)
    else gfx.setColor(C.locked[1], C.locked[2], C.locked[3], 0.3) end
  end
  gfx.rectangle('line', x + 0.5, y + 0.5, CARD_W - 1, CARD_H - 1, 6, 6)
  local numColor = open and (done and C.cyan or C.amber) or C.locked
  Ui.text(tostring(i), f.big, y + (CARD_H - f.big:getHeight()) / 2, numColor, open and 1 or 0.7, x + 10, 44, 'center')
  local tx = x + 60
  if open then
    local name = Levels[i].name
    if f.small:getWidth(name) <= CARD_W - 64 then
      Ui.text(name, f.small, y + 12, C.white, 0.95, tx, CARD_W - 64, 'left')
    else
      Ui.text(name, f.tiny, y + 1, C.white, 0.95, tx, CARD_W - 64, 'left')
    end
    if done then
      Ui.text(rec.bestTime and clock(rec.bestTime) or '--', f.small, y + 38, C.dim, 0.95, tx, CARD_W - 64, 'left')
      local n = rec.bestDeaths
      Ui.text(n == nil and '' or (n == 0 and 'no deaths' or (n == 1 and '1 death' or n .. ' deaths')), f.tiny, y + 59, C.dim, 0.8, tx, CARD_W - 64, 'left')
      drawCheck(x + CARD_W - 20, y + CARD_H - 18, 0.9)
      if Progress.hasEmber(Levels[i]) then Ui.ember(x + CARD_W - 20, y + 20, rec.ember, 0.95) end
    else
      Ui.text('not cleared', f.tiny, y + 40, C.dim, 0.7, tx, CARD_W - 64, 'left')
      if Progress.hasEmber(Levels[i]) then Ui.ember(x + CARD_W - 20, y + 20, false, 0.95) end
    end
  else
    Ui.text('locked', f.small, y + 30, C.locked, 0.8, tx, CARD_W - 64, 'left')
    drawLock(x + CARD_W - 20, y + CARD_H - 18, 0.8)
  end
end

function select_.drawUI()
  Ui.dim(0.62)
  local f = Ui.fonts
  heading('SELECT LEVEL', 30)
  local rows, scroll = select_.rows, select_.scroll or 0
  local tops = rowTops(rows)
  local left = (Ui.W - (Progress.COLS * CARD_W + (Progress.COLS - 1) * CARD_GAP)) / 2
  local pulse = 0.5 + 0.5 * sin(Ui.time() * 4)
  Ui.scissor(0, AREA_TOP - 6, Ui.W, AREA_BOTTOM - AREA_TOP + 6)
  local acts = Progress.acts(Levels)
  for r, row in ipairs(rows) do
    local y = AREA_TOP + tops[r] - scroll
    if row.label then
      local act = acts[row.act]
      local cleared = 0
      for _, i in ipairs(act.indices) do
        if Progress.done(data(), i) then cleared = cleared + 1 end
      end
      Ui.text(row.label, f.small, y, C.amber, 0.85, left, 300, 'left')
      Ui.text(('%d / %d cleared'):format(cleared, #act.indices), f.tiny, y + 2, C.dim, 0.8, left, Progress.COLS * CARD_W + (Progress.COLS - 1) * CARD_GAP, 'right')
      gfx.setColor(1, 0.82, 0.45, 0.18)
      gfx.rectangle('fill', left + 64, y + 9, Progress.COLS * CARD_W + (Progress.COLS - 1) * CARD_GAP - 64 - 108, 1)
      y = y + LABEL_H
    end
    for c, i in ipairs(row.indices) do
      drawCard(i, left + (c - 1) * (CARD_W + CARD_GAP), y, i == select_.sel, pulse)
    end
  end
  gfx.setScissor()
  Ui.footer(hints({ 'move', 'Move' }, { 'confirm', 'Play' }, { 'back', 'Back' }))
end

select_.actions = {
  confirm = function()
    local sel = select_.sel
    if Progress.unlocked(data(), sel) then
      feedback('select')
      startLevel(sel)
    else
      feedback('denied')
    end
  end,
}
for _, a in ipairs({ 'up', 'down', 'left', 'right' }) do
  select_.actions[a] = function()
    local nxt = Progress.neighbor(select_.rows, select_.sel, a)
    if nxt ~= select_.sel then feedback('move') end
    select_.sel = nxt
  end
end
select_.actions.back = function() feedback('back') S.to(unpack(select_.returnTo)) end


local settings = {}
S.settings = settings
settings.returnTo = { 'title' }

local function percent(v) return ('%d%%'):format(floor(v * 100 + 0.5)) end

local function slider(key, label)
  return {
    label = label,
    value = function() return percent(data().settings[key]) end,
    meter = function() return data().settings[key] end,
    adjust = function(dir)
      local s = data().settings
      s[key] = max(0, min(1, floor((s[key] + dir * 0.1) * 10 + 0.5) / 10))
      S.applySettings()
      persist()
    end,
  }
end

local function toggle(key, label)
  return {
    label = label,
    value = function() return data().settings[key] and 'On' or 'Off' end,
    adjust = function()
      local s = data().settings
      s[key] = not s[key]
      S.applySettings()
      persist()
    end,
  }
end

function settings.enter()
  loadAmbient()
  settings.menu = Menu.new({
    slider('master', 'Master volume'),
    slider('sfx', 'Sound effects'),
    toggle('shake', 'Screen shake'),
    toggle('fullscreen', 'Fullscreen'),
    { label = 'Back', action = function() feedback('back') S.to(unpack(settings.returnTo)) end },
  })
end

ambientScene(settings)

function settings.drawUI()
  Ui.dim(0.62)
  heading('SETTINGS', 70)
  Ui.panel(Ui.W / 2 - 270, 140, 540, 290)
  Ui.menu(settings.menu, Ui.W / 2, 164, { rowHeight = 50, width = 480 })
  Ui.footer(hints({ 'move', 'Move' }, { 'confirm', 'Change' }, { 'back', 'Back' }))
end

settings.actions = withBack(menuActions(function() return settings.menu end), function() S.to(unpack(settings.returnTo)) end)


local clear = {}
S.levelclear = clear

function clear.enter(index, time, ember)
  clear.index, clear.time, clear.t, clear.ember = index, time, 0, ember
  clear.deaths = stats.deaths
  clear.result = Save.recordClear(data(), index, time, clear.deaths, ember)
  persist()
  local last = index >= #Levels
  clear.menu = Menu.new({
    { label = last and 'Finish' or 'Next level', action = function()
      if last then S.to('ending') else startLevel(index + 1) end
    end },
    { label = 'Replay', action = function() startLevel(index) end },
    { label = 'Level select', action = function() S.select.returnTo = { 'title' } S.to('select', index) end },
  })
end

function clear.update()
  clear.t = clear.t + DT
  Render.update(playing.world, DT)
  Particles.update(playing.particles, DT)
end

function clear.draw()
  drawScene(playing)
end

local function statRow(label, value, y, badge, a, x, w)
  local f = Ui.fonts
  Ui.text(label, f.mid, y, C.dim, a, x, w, 'left')
  Ui.text(value, f.mid, y, C.white, a, x, w, 'right')
  if badge then
    local tw = f.mid:getWidth(value)
    Ui.text('NEW BEST', f.tiny, y + 5, C.amber, a * (0.75 + 0.25 * sin(Ui.time() * 6)), x, w - tw - 14, 'right')
  end
end

function clear.drawUI()
  local a = min(1, clear.t * 2.5)
  local f = Ui.fonts
  Ui.dim(0.55 * a)
  local px, py, pw, ph = Ui.W / 2 - 230, 70 + (1 - a) * 14, 460, 400
  Ui.panel(px, py, pw, ph, a)
  Ui.glowText('LEVEL CLEAR', f.big, py + 22, C.cyan, a, { 0.3, 0.9, 1 })
  Ui.text(('%d. %s'):format(clear.index, Levels[clear.index].name), f.small, py + 70, C.dim, a)
  local r, rec = clear.result, data().levels[clear.index]
  statRow('Time', clock(clear.time), py + 112, r.newTime, a, px + 50, pw - 100)
  statRow('Deaths', tostring(clear.deaths), py + 148, r.newDeaths, a, px + 50, pw - 100)
  local best = ('best  %s,  %s'):format(rec.bestTime and clock(rec.bestTime) or '--',
    rec.bestDeaths == 1 and '1 death' or (rec.bestDeaths or 0) .. ' deaths')
  Ui.text(best, f.tiny, py + 186, C.dim, a * 0.85)
  if Progress.hasEmber(Levels[clear.index]) then
    local found = clear.ember or rec.ember
    local label = clear.ember and (r.newEmber and 'ember found' or 'ember carried out') or (rec.ember and 'ember found before' or 'an ember is still here somewhere')
    Ui.ember(Ui.W / 2 - f.tiny:getWidth(label) / 2 - 14, py + 210, found, a)
    Ui.text(label, f.tiny, py + 202, found and C.amber or C.dim, a * 0.9)
  end
  Ui.menu(clear.menu, Ui.W / 2, py + 236, { rowHeight = 46, width = 340 })
  Ui.footer(hints({ 'move', 'Move' }, { 'confirm', 'Select' }, { 'restart', 'Replay' }))
end

local function ready() return clear.t > 0.4 end

clear.actions = menuActions(function() return clear.menu end)
for name, fn in pairs(clear.actions) do
  clear.actions[name] = function() if ready() then fn() end end
end
clear.actions.restart = function() if ready() then startLevel(clear.index) end end
clear.actions.back = function()
  if not ready() then return end
  S.select.returnTo = { 'title' }
  S.to('select', clear.index)
end


S.ending = {}

function S.ending.enter()
  loadAmbient()
  S.ending.t = 0
  local time, deaths = 0, 0
  for i = 1, #Levels do
    local r = data().levels[i]
    time = time + (r and r.bestTime or 0)
    deaths = deaths + (r and r.bestDeaths or 0)
  end
  S.ending.time, S.ending.deaths = time, deaths
end

ambientScene(S.ending)

function S.ending.update()
  S.ending.t = S.ending.t + DT
  stepAmbient()
end

function S.ending.drawUI()
  local e, f = S.ending, Ui.fonts
  local a = min(1, e.t * 0.8)
  Ui.dim(0.5 * a)
  Ui.glowText('YOU FOUND THE WAY OUT', f.big, 150, C.amber, a, { 1, 0.6, 0.2 })
  Ui.text(('fewest deaths  %d'):format(e.deaths), f.mid, 240, C.white, a)
  Ui.text(('best total time  %s'):format(clock(e.time)), f.mid, 275, C.white, a)
  Ui.text('the echoes fade, the light remains', f.small, 330, C.cyan, a * 0.8)
  if e.t > 1.2 then Ui.footer(hints({ 'confirm', 'Title' })) end
end

local function endingDone() if S.ending.t > 1.2 then S.to('title') end end
S.ending.actions = { confirm = endingDone, back = endingDone }


function S.update()
  Trans.update(DT)
  current.update()
end

function S.draw()
  current.draw()
  Render.present()
  Ui.begin()
  if current.drawUI then current.drawUI() end
  Ui.iris(Trans.coverage(), Trans.cx, Trans.cy)
  Ui.finish()
end

local function act(action)
  if Trans.busy() then return false end
  local handler = current.actions and current.actions[action]
  if not handler then return false end
  handler()
  return true
end

function S.dispatch(actions)
  for _, action in ipairs(actions) do
    if act(action) then return true end
  end
  return false
end

return S
