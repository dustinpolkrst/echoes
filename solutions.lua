local Level = require 'level'

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
-- The newest echo is heading right and has drawn level with the player (within lag pixels behind).
function C.lastEchoPassing(lag)
  return function(w)
    local e = w.echoes[#w.echoes]
    return e ~= nil and e.x > e.prevX and e.x >= w.player.x - lag
  end
end

local atX, atXLeft, onTop = C.atX, C.atXLeft, C.onTop
local apex, echoArrived, onLastEcho, grounded, doorOpen = C.apex, C.echoArrived, C.onLastEcho, C.grounded, C.doorOpen
local lastEchoPassing = C.lastEchoPassing

-- Coordinates are pixels (tile = 16). Each list is a full playthrough of the level at that index.
M.scripts = {
  -- 1 Wake
  {
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
  -- 2 First Echo
  {
    { 'R', atX(163) }, { 190, '-' }, { 1, 'X' },
    { 'R', atX(372) }, { 'RJ', atX(440) }, { 'R', grounded },
    { 'R', atX(488) }, { 'RJ', atX(540) }, { 'R', grounded },
    { 'R', atX(640) },
  },
  -- 3 Stairway
  {
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
  -- 4 Two Minds
  {
    { 'R', atX(66) }, { 190, '-' }, { 1, 'X' },
    { 'R', atX(130) }, { 190, '-' }, { 1, 'X' },
    { 'R', atX(316) }, { 'RJ', atX(372) }, { 'R', grounded },
    { 'R', atX(424) }, { 'RJ', atX(486) }, { 'R', grounded },
    { 'R', atX(700) },
  },
  -- 5 Ascent
  {
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
  -- 6 Other Side
  {
    { 'R', atX(66) }, { 100, '-' }, { 'R', atX(163) }, { 1, 'X' }, { 'R', atX(300) },
  },
  -- 7 Trapdoor
  {
    { 'R', atX(190) }, { 1, 'X' }, { '-', onTop(224) },
    { 'R', atX(255) }, { '-', doorOpen('a') }, { 'R', atX(340) },
  },
  -- 8 Undertow
  {
    { 'R', atX(70) }, { '-', onTop(224) }, { 1, 'X' }, { '-', echoArrived },
    { 'J', onLastEcho }, { 'LJ', onTop(144, 0, 54) }, { 'L', atXLeft(40) },
  },
  -- 9 Underfoot
  {
    { 'R', atX(48) }, { 190, '-' }, { 1, 'X' }, { 'R', atX(296) }, { '-', onTop(224) },
  },
  -- 10 Ferry
  {
    { 'R', atX(208) }, { 'L', atXLeft(80) }, { 'R', atX(209) }, { 1, 'X' },
    { '-', lastEchoPassing(8) }, { 'RJ', onLastEcho }, { '-', echoArrived }, { 'R', atX(400) },
  },
  -- 11 Short Memory
  {
    { 'R', atX(26) }, { 'RJ', onTop(208, 54, 102) }, { 130, '-' },
    { 'R', atX(163) }, { 1, 'X' }, { 'R', atX(300) },
  },
  -- 12 Confluence
  {
    { 'R', atX(208) }, { 'L', atXLeft(80) }, { 'R', atX(209) }, { 1, 'X' },
    { '-', lastEchoPassing(8) }, { 'RJ', onLastEcho }, { '-', echoArrived }, { 'R', atX(376) }, { 1, 'X' },
    { '-', doorOpen('a') }, { 'R', atX(440) },
  },
}

-- An input source for a live scene: returns the next scripted input, then idles.
function M.provider(index)
  local drive = M.driver(M.scripts[index])
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
