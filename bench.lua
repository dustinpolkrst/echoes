local Levels = require 'levels'
local Solutions = require 'solutions'
local Trans = require 'transition'
local Shot = require 'shot'

local gfx = love.graphics
local getTime = love.timer.getTime

local B = { WARMUP = 120, FRAMES = 1200, ALLOC_FRAMES = 300, IRIS_EVERY = 60 }

local function playLevel(Scenes, i)
  Scenes.go('playing', i)
  Scenes.inputSource = Solutions.provider(i)
end

-- Each scenario: setup() enters the scene; after(), run outside the timed region, loops the scripted
-- solution so every level fills the same frame count, and returns the load time when it reloaded.
-- iris restarts level 5 every IRIS_EVERY frames, so its level loads land inside update like a player's do.
local function scenarios(Scenes)
  local list = {
    { name = 'title', setup = function()
      Scenes.init(Shot.seededStore(2))
      Scenes.go('title')
    end },
    { name = 'pause', setup = function()
      Scenes.init(Shot.seededStore(0))
      Scenes.go('playing', 2)
      Shot.frames(Scenes, 90, Shot.input)
      Scenes.go('pause', 'playing')
    end },
    { name = 'select', setup = function()
      Scenes.init(Shot.seededStore(3))
      Scenes.go('select', 4)
    end },
    { name = 'iris', setup = function()
      Scenes.init(Shot.seededStore(0))
      Scenes.go('playing', 5)
      B.irisFrame = 0
      Scenes.inputSource = function() return Shot.input(B.irisFrame % B.IRIS_EVERY) end
    end, after = function()
      B.irisFrame = B.irisFrame + 1
      if B.irisFrame % B.IRIS_EVERY == 0 then Scenes.dispatch({ 'restart' }) end
    end },
  }
  for i = 1, #Levels do
    list[#list + 1] = {
      name = ('L%02d'):format(i),
      setup = function()
        Scenes.init(Shot.seededStore(0))
        playLevel(Scenes, i)
      end,
      after = function()
        local p = Scenes.playing.world.player
        if Scenes.name ~= 'playing' or (p.state == 'cleared' and p.stateT >= 1) then
          Trans.reset()
          local t0 = getTime()
          playLevel(Scenes, i)
          gfx.flushBatch()
          return getTime() - t0
        end
      end,
    }
  end
  return list
end

local function pumpEvents()
  love.event.pump()
  for name in love.event.poll() do
    if name == 'quit' then os.exit(2) end
  end
end

local stats = {}
local lastPresent

-- One full frame the way love.run does it, split into update, draw submission and present.
local function frame(Scenes)
  pumpEvents()
  local t0 = getTime()
  Scenes.update()
  local t1 = getTime()
  gfx.origin()
  gfx.clear(gfx.getBackgroundColor())
  Scenes.draw()
  gfx.flushBatch()
  local t2 = getTime()
  gfx.getStats(stats)
  gfx.present()
  local t3 = getTime()
  local wall = t3 - lastPresent
  lastPresent = t3
  return t1 - t0, t2 - t1, t3 - t2, wall
end

local function zeros(n)
  local t = {}
  for i = 1, n do t[i] = 0 end
  return t
end

-- Userdata finalizers resurrect their objects for one cycle, so one collect leaves them counted.
local function fullCollect()
  collectgarbage('collect')
  collectgarbage('collect')
end

local function runScenario(Scenes, sc)
  love.math.setRandomSeed(1)
  math.randomseed(1)
  Trans.reset()
  sc.setup()
  local after = sc.after or function() end
  for _ = 1, B.WARMUP do
    frame(Scenes)
    after()
  end

  local n = B.FRAMES
  local r = {
    name = sc.name, update = zeros(n), draw = zeros(n), present = zeros(n), wall = zeros(n),
    drawcalls = zeros(n), canvasswitches = zeros(n), shaderswitches = zeros(n), mem = zeros(n), loads = {},
  }
  fullCollect()
  lastPresent = getTime()
  for f = 1, n do
    local u, d, p, w = frame(Scenes)
    local load = after()
    if load then lastPresent = getTime() end
    r.update[f], r.draw[f], r.present[f], r.wall[f] = u * 1000, d * 1000, p * 1000, w * 1000
    r.drawcalls[f], r.canvasswitches[f], r.shaderswitches[f] = stats.drawcalls, stats.canvasswitches, stats.shaderswitches
    r.mem[f] = collectgarbage('count')
    if load then r.loads[#r.loads + 1] = load * 1000 end
  end
  r.texturememory = stats.texturememory
  fullCollect()
  r.liveKB = collectgarbage('count')

  -- GC stopped, so each frame's count delta is exactly what it allocated.
  r.alloc = zeros(B.ALLOC_FRAMES)
  collectgarbage('stop')
  for f = 1, B.ALLOC_FRAMES do
    local before = collectgarbage('count')
    frame(Scenes)
    r.alloc[f] = collectgarbage('count') - before
    if after() then lastPresent = getTime() end
  end
  collectgarbage('restart')
  collectgarbage('collect')
  return r
end

local function sorted(t)
  local c = {}
  for i, v in ipairs(t) do c[i] = v end
  table.sort(c)
  return c
end

local function pct(s, q)
  return s[math.max(1, math.min(#s, math.ceil(q * #s)))]
end

local function mean(t)
  local sum = 0
  for _, v in ipairs(t) do sum = sum + v end
  return #t > 0 and sum / #t or 0
end

local function summarize(r)
  local w, u, d, p = sorted(r.wall), sorted(r.update), sorted(r.draw), sorted(r.present)
  local loads = sorted(r.loads)
  return {
    scene = r.name,
    wall_p50 = pct(w, 0.5), wall_p95 = pct(w, 0.95), wall_p99 = pct(w, 0.99), wall_max = w[#w],
    update_p50 = pct(u, 0.5), update_max = u[#u],
    draw_p50 = pct(d, 0.5), draw_max = d[#d],
    present_p50 = pct(p, 0.5), present_max = p[#p],
    drawcalls = mean(r.drawcalls), canvasswitches = mean(r.canvasswitches), shaderswitches = mean(r.shaderswitches),
    texmemMB = r.texturememory / 1048576,
    allocKB = mean(r.alloc), liveKB = r.liveKB,
    loads = #loads, load_max = loads[#loads] or 0,
  }
end

local COLUMNS = {
  'scene', 'wall_p50', 'wall_p95', 'wall_p99', 'wall_max', 'update_p50', 'update_max', 'draw_p50', 'draw_max',
  'present_p50', 'present_max', 'drawcalls', 'canvasswitches', 'shaderswitches', 'texmemMB', 'allocKB', 'liveKB',
  'loads', 'load_max',
}

local function cell(v)
  if type(v) == 'number' then return ('%.3f'):format(v) end
  return tostring(v)
end

local function csv(rows)
  local out = { table.concat(COLUMNS, ',') }
  for _, row in ipairs(rows) do
    local line = {}
    for i, c in ipairs(COLUMNS) do line[i] = cell(row[c]) end
    out[#out + 1] = table.concat(line, ',')
  end
  return table.concat(out, '\n') .. '\n'
end

local function framesCsv(results)
  local out = { 'scene,frame,update_ms,draw_ms,present_ms,wall_ms,drawcalls,canvasswitches,shaderswitches,memKB' }
  for _, r in ipairs(results) do
    for f = 1, #r.wall do
      out[#out + 1] = ('%s,%d,%.4f,%.4f,%.4f,%.4f,%d,%d,%d,%.1f'):format(r.name, f, r.update[f], r.draw[f],
        r.present[f], r.wall[f], r.drawcalls[f], r.canvasswitches[f], r.shaderswitches[f], r.mem[f])
    end
  end
  return table.concat(out, '\n') .. '\n'
end

local function printTable(rows)
  print(('%-7s %7s %7s %7s %7s | %6s %6s %6s %6s | %5s %4s %6s %7s %6s'):format('scene', 'p50', 'p95', 'p99', 'max',
    'upd', 'updmx', 'draw', 'pres', 'calls', 'cnv', 'KB/fr', 'liveKB', 'loadmx'))
  for _, s in ipairs(rows) do
    print(('%-7s %7.3f %7.3f %7.3f %7.3f | %6.3f %6.3f %6.3f %6.3f | %5.0f %4.0f %6.2f %7.1f %6.2f'):format(s.scene,
      s.wall_p50, s.wall_p95, s.wall_p99, s.wall_max, s.update_p50, s.update_max, s.draw_p50, s.present_p50,
      s.drawcalls, s.canvasswitches, s.allocKB, s.liveKB, s.load_max))
  end
end

-- Wraps the frame's top-level draw and step functions with timers. The wrappers cost time themselves,
-- so a profiled run names where time goes; its frame times are not the ones to report.
local profile = {}

local function instrument(Scenes)
  local function wrap(tbl, key, label)
    local fn = tbl[key]
    tbl[key] = function(...)
      local t0 = getTime()
      local a, b, c, d = fn(...)
      profile[label] = (profile[label] or 0) + getTime() - t0
      return a, b, c, d
    end
  end
  local Render, Ui = require 'render', require 'ui'
  for _, k in ipairs({ 'drawBackground', 'drawWorld', 'drawLighting', 'drawGlows', 'drawMotes', 'present' }) do
    wrap(Render, k, 'Render.' .. k)
  end
  for _, k in ipairs({ 'glowText', 'text', 'menu', 'footer', 'panel', 'iris' }) do wrap(Ui, k, 'Ui.' .. k) end
  wrap(require('particles'), 'draw', 'Particles.draw')
  wrap(require('particles'), 'update', 'Particles.update')
  wrap(require('level'), 'step', 'Level.step')
  wrap(require('hud'), 'draw', 'Hud.draw')
  for _, n in ipairs({ 'title', 'pause', 'select', 'playing' }) do wrap(Scenes[n], 'drawUI', n .. '.drawUI') end
end

local function printProfile(name, frames)
  local keys = {}
  for k in pairs(profile) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return profile[a] > profile[b] end)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = ('%s %.3f'):format(k, profile[k] * 1000 / frames) end
  print(('PROFILE %-7s ms/frame  %s'):format(name, table.concat(parts, ', ')))
  profile = {}
end

-- opts: size {w, h} to run at instead of the conf window, profile to print a per-function breakdown.
function B.run(Scenes, label, opts)
  opts = opts or {}
  label = label or os.date('%Y%m%d_%H%M%S')
  love.audio.setVolume(0)
  if opts.size then love.window.setMode(opts.size[1], opts.size[2], { vsync = 0, resizable = true }) end
  if opts.profile then instrument(Scenes) end
  local name, version, vendor, device = gfx.getRendererInfo()
  local ww, wh = gfx.getDimensions()
  print(('BENCH %s  %s %s %s %s  window %dx%d vsync=%d visible=%s minimized=%s'):format(label, name, version,
    vendor, device, ww, wh, love.window.getVSync(), tostring(love.window.isVisible()),
    tostring(love.window.isMinimized())))
  assert(love.window.getVSync() == 0, 'bench needs vsync off')
  lastPresent = getTime()
  local results, rows = {}, {}
  for _, sc in ipairs(scenarios(Scenes)) do
    local r = runScenario(Scenes, sc)
    if opts.profile then printProfile(sc.name, B.WARMUP + B.FRAMES + B.ALLOC_FRAMES) end
    results[#results + 1] = r
    rows[#rows + 1] = summarize(r)
  end
  printTable(rows)
  love.filesystem.createDirectory('bench')
  local base = 'bench/' .. label
  love.filesystem.write(base .. '_summary.csv', csv(rows))
  love.filesystem.write(base .. '_frames.csv', framesCsv(results))
  print('WROTE ' .. love.filesystem.getSaveDirectory() .. '/' .. base .. '_summary.csv')
  return true
end

return B
