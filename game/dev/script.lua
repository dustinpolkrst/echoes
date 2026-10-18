local Level = require 'world.level'

-- The scripting primitives every solution file uses: a driver that turns a script into per-step inputs,
-- a runner, and the conditions a script can wait on.
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

function M.append(script, more)
  for _, seg in ipairs(more) do script[#script + 1] = seg end
  return script
end

-- The nominal value of every decision in a strategy, with overrides applied.
function M.decisions(strategy, overrides)
  local p = {}
  for _, d in ipairs(strategy.params) do p[d.name] = d.nominal end
  for k, v in pairs(overrides or {}) do p[k] = v end
  return p
end

return M
