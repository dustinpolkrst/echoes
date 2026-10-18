local Level = require 'world.level'
local Levels = require 'content.levels'

local M = {}

local SEGMENT_CAP = 1200
local KEYS = { R = 'right', L = 'left', J = 'jump', X = 'cast' }

local function inputOf(keys)
  local t = {}
  for ch in keys:gmatch('.') do
    if KEYS[ch] then t[KEYS[ch]] = true end
  end
  return t
end

-- A segment is {frames, keys} or {keys, untilFn}; the latter holds keys until untilFn(world) is true.
-- Keys: R L J X, '-' for none. The driver yields one input table per simulation step.
function M.driver(script)
  return coroutine.wrap(function(w)
    local held = false
    local function emit(input)
      held = input.jump or false
      return coroutine.yield(input)
    end
    for i, seg in ipairs(script) do
      local timed = type(seg[1]) == 'number'
      local input = inputOf(timed and seg[2] or seg[1])
      if input.jump and held and w.player.state == 'ground' then
        w = emit({ right = input.right, left = input.left })
      end
      if timed then
        for _ = 1, seg[1] do w = emit(input) end
      else
        local n = 0
        while not seg[2](w) do
          n = n + 1
          if n > SEGMENT_CAP then
            error(('segment %d (%s) timed out at x=%.1f y=%.1f state=%s'):format(
              i, seg[1], w.player.x, w.player.y, w.player.state), 0)
          end
          w = emit(input)
        end
      end
    end
  end)
end

-- Returns ok, outcome|reason. Stops early on goal; any death is a failure.
function M.run(w, script, afterStep)
  local drive = M.driver(script)
  local ok, result = pcall(function()
    local input = drive(w)
    while input do
      Level.step(w, input)
      if afterStep then afterStep(w) end
      local state = w.player.state
      if state == 'cleared' then return 'cleared' end
      if state == 'dead' then
        error(('died at x=%.1f y=%.1f'):format(w.player.x, w.player.y), 0)
      end
      input = drive(w)
    end
    return 'finished'
  end)
  return ok, result
end

local C = {}
M.cond = C
function C.atX(x) return function(w) return w.player.x >= x end end
function C.atXLeft(x) return function(w) return w.player.x <= x end end
function C.onTop(y, minx, maxx)
  return function(w)
    local p = w.player
    return p.state == 'ground' and math.abs(p.y + p.h - y) < 0.01
      and p.x >= (minx or -1e9) and p.x <= (maxx or 1e9)
  end
end
function C.apex(w) return w.player.state == 'air' and w.player.vy >= 0 end
function C.echoArrived(w)
  local e = w.echoes[#w.echoes]
  return e ~= nil and e:arrived()
end
function C.onLastEcho(w) return w.player.support == w.echoes[#w.echoes] end
function C.grounded(w) return w.player.state == 'ground' end
function C.doorOpen(id) return function(w) return w.doorOpen[id] end end

local atX, atXLeft, onTop = C.atX, C.atXLeft, C.onTop
local apex, echoArrived, onLastEcho, grounded, doorOpen = C.apex, C.echoArrived, C.onLastEcho, C.grounded, C.doorOpen

-- Coordinates are pixels (tile = 16). Each list is a full playthrough of the level of that name.
M.scripts = {
  ['Wake'] = {
    { 'R', atX(202) }, { 'RJ', atX(246) }, { 'R', grounded },
    { 'R', atX(284) }, { 'RJ', atX(312) }, { 'R', atX(332) }, { 'R', grounded },
    { 'R', atX(348) }, { 'RJ', atX(374) }, { 'R', atX(404) }, { 'R', grounded },
    { 'R', atX(468) }, { 'RJ', atX(516) }, { 'R', grounded },
    { 'R', atX(570) }, { 'RJ', atX(630) }, { 'R', grounded },
    { 'R', atX(668) }, { 'RJ', atX(690) }, { 'R', grounded },
    { 'R', atX(694) }, { 'RJ', atX(708) }, { 'R', grounded },
    { 'R', atX(762) }, { 'R', grounded }, { 'R', atX(778) }, { 'R', grounded },
    { 'R', atX(822) }, { 'RJ', atX(870) }, { 'R', grounded },
    { 'R', atX(940) },
  },
  ['First Echo'] = {
    { 'R', atX(163) }, { 190, '-' }, { 1, 'X' },
    { 'R', atX(372) }, { 'RJ', atX(440) }, { 'R', grounded },
    { 'R', atX(488) }, { 'RJ', atX(540) }, { 'R', grounded },
    { 'R', atX(640) },
  },
  ['Stairway'] = {
    { 'R', atX(66) }, { 'RJ', onTop(192, 80) }, { 'R', atX(133) }, { 'R', grounded },
    { 1, 'J' }, { 'J', apex }, { 1, 'JX' }, { '-', grounded },
    { 'L', atXLeft(116) }, { 'LJ', onTop(192, 80, 112) },
    { 'R', atX(104) },
    { '-', echoArrived },
    { 'RJ', onLastEcho },
    { 2, '-' }, { 'RJ', onTop(128, 144) },
    { 'R', atX(358) }, { 'RJ', atX(410) }, { 'R', grounded },
    { 'R', atX(600) },
  },
  ['Two Minds'] = {
    { 'R', atX(66) }, { 190, '-' }, { 1, 'X' },
    { 'R', atX(130) }, { 190, '-' }, { 1, 'X' },
    { 'R', atX(316) }, { 'RJ', atX(372) }, { 'R', grounded },
    { 'R', atX(424) }, { 'RJ', atX(486) }, { 'R', grounded },
    { 'R', atX(700) },
  },
  ['Ascent'] = {
    { 'R', atX(99) }, { 190, '-' }, { 1, 'X' },
    { 'R', atX(200) }, { 'RJ', onTop(528, 209) },
    { 'R', atX(246) }, { 'RJ', onTop(496, 288) },
    { 'R', atX(326) }, { 'RJ', onTop(464, 368) },
    { 'L', atXLeft(366) }, { 'LJ', onTop(432, 270, 340) },
    { 'L', atXLeft(266) }, { 'LJ', onTop(400, 190, 250) },
    { 'R', atX(246) }, { 'RJ', onTop(368, 256) },
    { 'R', atX(312) }, { 'RJ', onTop(336, 336) },
    { 'R', atX(392) }, { 'RJ', onTop(304, 400) },
    { 1, '-' }, { 'J', onTop(272, 384, 464) },
    { 'L', atXLeft(386) }, { 'LJ', onTop(240, 256, 384) },
    { 'L', atXLeft(326) }, { 'LJ', onTop(208, 288, 320) },
    { 'L', onTop(240, 256, 288) },
    { 1, 'J' }, { 'J', apex }, { 1, 'JX' }, { '-', onTop(240, 256, 288) },
    { 'R', atX(276) }, { 'RJ', onTop(208, 288, 320) },
    { '-', echoArrived },
    { 'LJ', onLastEcho }, { 2, '-' }, { 'LJ', onTop(144, 0, 250) },
    { 'L', atXLeft(176) }, { 'LJ', atXLeft(116) }, { 'L', grounded },
    { 'L', atXLeft(40) },
  },
  ['Other Side'] = {
    { 'R', atX(66) }, { 100, '-' }, { 'R', atX(163) }, { 1, 'X' }, { 'R', atX(300) },
  },
  ['Trapdoor'] = {
    { 'R', atX(190) }, { 1, 'X' }, { '-', onTop(224) },
    { 'R', atX(255) }, { '-', doorOpen('a') }, { 'R', atX(340) },
  },
  ['Undertow'] = {
    { 'R', atX(70) }, { '-', onTop(224) }, { 1, 'X' }, { '-', echoArrived },
    { 'J', onLastEcho }, { 'LJ', onTop(144, 0, 54) }, { 'L', atXLeft(40) },
  },
  ['Underfoot'] = {
    { 'R', atX(48) }, { 190, '-' }, { 1, 'X' }, { 'R', atX(296) }, { '-', onTop(224) },
  },
  ['Short Memory'] = {
    { 'R', atX(26) }, { 'RJ', onTop(208, 54, 102) }, { 130, '-' },
    { 'R', atX(163) }, { 1, 'X' }, { 'R', atX(300) },
  },
}

-- A strategy is a solution written as a human would play it: every decision a human has to time or place is a
-- parameter with the range a player might plausibly pick. dev/slack.lua sweeps each one and reports the winning window,
-- which the selftest holds to 30 frames or 24 px unless the decision says what it needs instead.
local FERRY_DECISIONS = {
  { name = 'footX', unit = 'px', nominal = 166, min = 130, max = 166, step = 2, need = 4, note = 'the pedestal wall stops you here' },
  { name = 'idle', unit = 'frames', nominal = 120, min = 0, max = 240, step = 4 },
  { name = 'turnX', unit = 'px', nominal = 104, min = 30, max = 178, step = 2 },
  { name = 'hopX', unit = 'px', nominal = 130, min = 60, max = 180, step = 2 },
  { name = 'hopHold', unit = 'frames', nominal = 6, min = 1, max = 40, step = 1 },
  { name = 'castX', unit = 'px', nominal = 190, min = 160, max = 210, step = 1 },
  { name = 'castDelay', unit = 'frames', nominal = 10, min = 0, max = 150, step = 2 },
  { name = 'stepDelay', unit = 'frames', nominal = 20, min = 0, max = 200, step = 2 },
  { name = 'stepHold', unit = 'frames', nominal = 3, min = 0, max = 30, step = 1, need = 6, note = 'a tap; the echo is 10 px wide' },
}

-- Wait at the foot of the shrine pedestal, walk away, hop back up, cast, step off onto the waiting reflection, ride.
local function ferry(p)
  return {
    { 'R', atX(p.footX) }, { p.idle, '-' }, { 'L', atXLeft(p.turnX) },
    { 'R', atX(p.hopX) }, { p.hopHold, 'RJ' }, { 'R', onTop(208, 134, 208) },
    { 'R', atX(p.castX) }, { p.castDelay, '-' }, { 1, 'X' },
    { p.stepDelay, '-' }, { 'R', onLastEcho }, { p.stepHold, 'R' }, { '-', echoArrived },
  }
end

local function append(script, more)
  for _, seg in ipairs(more) do script[#script + 1] = seg end
  return script
end

M.strategies = {
  ['Ferry'] = {
    params = FERRY_DECISIONS,
    build = function(p) return append(ferry(p), { { 'R', atX(360) } }) end,
  },
  ['Confluence'] = {
    params = append({ { name = 'landDelay', unit = 'frames', nominal = 20, min = 0, max = 240, step = 4 } }, FERRY_DECISIONS),
    build = function(p)
      return append(ferry(p), {
        { p.landDelay, '-' }, { 'R', atX(326) }, { 1, 'X' }, { '-', doorOpen('a') }, { 'R', atX(360) },
      })
    end,
  },
}

function M.decisions(strategy, overrides)
  local p = {}
  for _, d in ipairs(strategy.params) do p[d.name] = d.nominal end
  for k, v in pairs(overrides or {}) do p[k] = v end
  return p
end

for name, strategy in pairs(M.strategies) do M.scripts[name] = strategy.build(M.decisions(strategy)) end

-- An input source for a live scene: returns the next scripted input, then idles.
function M.provider(index)
  local drive = M.driver(M.scripts[Levels[index].name])
  local done = false
  return function(world)
    if done then return {} end
    local input = drive(world)
    if not input then
      done = true
      return {}
    end
    return input
  end
end

return M
