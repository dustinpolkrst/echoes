local Level = require 'world.level'
local Levels = require 'content.levels'
local Player = require 'world.player'
local Solutions = require 'dev.solutions'

-- Cheese search (--cheese N): plays a family of shallow strategies against a level and reports any that reach a
-- room's exit or the goal. It is not a solver. It catches the routes a player finds without the room's insight:
-- running and jumping, one echo cast somewhere along the natural path, and a stack of standing echoes as a step.
-- A room with no hit still needs a human to try the naive approaches its builder listed (dev/solutions, rooms).
local M = {}

local T = Level.T
local floor = math.floor
local MAX_FRAMES = 1200
local STAND = 190
local HITS_PER_FAMILY = 4

-- exit: { tx0, ty0, tx1, ty1 } inclusive tiles, or nil for the goal.
function M.reached(w, exit)
  if w.player.state == 'cleared' then return true end
  if not exit then return false end
  local p = w.player
  return Player.isAlive(p) and p.x < (exit[3] + 1) * T and p.x + p.w > exit[1] * T
    and p.y < (exit[4] + 1) * T and p.y + p.h > exit[2] * T
end

-- A policy maps (world, scratch) to an input each step, or returns nil to give up.
local function simulate(def, from, exit, policy, afterStep)
  local w = Level.new(def, { checkpoint = from })
  local s = { frame = 0, jumps = 0, holdLeft = 0 }
  for f = 1, MAX_FRAMES do
    s.frame = f
    local input = policy(w, s)
    if not input then return false end
    Level.step(w, input)
    if afterStep then afterStep(w, s, input) end
    local scored = exit == 'ember' and w:emberTaken() or (exit ~= 'ember' and M.reached(w, exit))
    if scored then return true, f end
    if w.player.state == 'dead' then return false end
  end
  return false
end

local function solidAhead(w, p, dir)
  local ax = dir > 0 and p.x + p.w + 1 or p.x - 1
  local tx = floor(ax / T)
  local foot, head = floor((p.y + p.h - 1) / T), floor(p.y / T)
  return w:solidCell(tx, foot) or w:solidCell(tx, head)
end

local function dropAhead(w, p, dir)
  local ax = dir > 0 and p.x + p.w + 1 or p.x - 1
  local tx, below = floor(ax / T), floor((p.y + p.h) / T)
  local c = w:cell(tx, below)
  return c == nil or c.kind == 'spike'
end

local function spikeAhead(w, p, dir)
  local ax = dir > 0 and p.x + p.w + 4 or p.x - 4
  local c = w:cell(floor(ax / T), floor((p.y + p.h - 1) / T))
  return c ~= nil and c.kind == 'spike'
end

-- Runs one way and jumps, holding for `hold` frames, at every wall, drop, spike or stall.
local function autorun(dir, hold)
  return function(w, s)
    local p = w.player
    local input = { right = dir > 0, left = dir < 0 }
    if s.holdLeft > 0 then
      s.holdLeft = s.holdLeft - 1
      input.jump = true
    elseif p.state == 'ground' and s.frame > 1 and not s.prevJump
        and (solidAhead(w, p, dir) or dropAhead(w, p, dir) or spikeAhead(w, p, dir) or (s.frame > 20 and p.vx == 0)) then
      s.holdLeft = hold - 1
      s.jumps, s.jumpY, s.jumpFromEcho = s.jumps + 1, p.y, type(p.support) == 'table'
      input.jump = true
    end
    s.prevJump = input.jump or false
    return input
  end
end

-- Runs one way and jumps once, where the player crosses jumpX.
local function runAndJump(dir, jumpX, hold)
  return function(w, s)
    local p = w.player
    local input = { right = dir > 0, left = dir < 0 }
    if s.holdLeft > 0 then
      s.holdLeft = s.holdLeft - 1
      input.jump = true
    elseif s.jumps == 0 and p.state == 'ground' and ((dir > 0 and p.x >= jumpX) or (dir < 0 and p.x <= jumpX)) then
      s.holdLeft = hold - 1
      s.jumps = 1
      input.jump = true
    end
    return input
  end
end

-- The policy with one cast at frame castAt, then `wait` frames standing still before it carries on.
local function withCast(policy, castAt, wait)
  return function(w, s)
    if s.frame > castAt and s.frame <= castAt + wait then return {} end
    local input = policy(w, s)
    if s.frame == castAt then input.cast = true end
    return input
  end
end

-- The policy with a cast `rise` px up jump nth, then one more up each later jump that starts from an echo, `count`
-- casts in all: one mid-air step, or a ladder of them. A frozen echo is a step only if it hangs low enough to land on,
-- so the height is swept, not fixed at the apex.
local function withRiseCasts(policy, nth, count, rise)
  return function(w, s)
    local input = policy(w, s)
    local p = w.player
    s.casts = s.casts or 0
    local due = s.casts == 0 and s.jumps >= nth or (s.casts > 0 and s.jumpFromEcho)
    if s.casts < count and due and s.castJump ~= s.jumps and p.state == 'air'
        and (s.jumpY - p.y >= rise or p.vy >= 0) then
      s.casts, s.castJump = s.casts + 1, s.jumps
      input.cast = true
    end
    return input
  end
end

-- Walks to x, stands three seconds, casts, hops onto the echo; `n` times over; then runs on from the top.
local function stack(x, n, dir, hold)
  local run = autorun(dir, hold)
  return function(w, s)
    local p = w.player
    s.phase = s.phase or 'walk'
    s.wait = (s.wait or 0) + 1
    if s.phase == 'walk' then
      if s.wait > 400 then return nil end
      local d = x - p.x
      if math.abs(d) <= 3 and p.state == 'ground' then
        s.phase, s.wait, s.built = 'stand', 0, 0
        return {}
      end
      return { right = d > 3, left = d < -3 }
    elseif s.phase == 'stand' then
      if s.wait < STAND then return {} end
      s.phase, s.wait = 'hop', 0
      return { cast = true }
    elseif s.phase == 'hop' then
      if s.wait <= 2 then return {} end
      if s.wait <= 14 then return { jump = true } end
      if p.state == 'ground' and p.support == w.echoes[#w.echoes] then
        s.built = s.built + 1
        s.phase, s.wait = s.built >= n and 'go' or 'stand', 0
        return {}
      end
      if s.wait > 60 then return nil end
      return {}
    end
    return run(w, s)
  end
end

M.simulate = simulate
M.policies = { autorun = autorun, runAndJump = runAndJump, withCast = withCast, withRiseCasts = withRiseCasts, stack = stack }

local function range(lo, hi, step)
  local out = {}
  for v = lo, hi, step do out[#out + 1] = v end
  return out
end

-- Each family yields {label, policy} pairs. Sweeps cover the whole level width so a room's exit can be reached
-- from any approach the shallow strategy allows.
local HOLDS = { 3, 12, 40 }
local RISES = { 20, 32, 38, 44 }

local function families(def, w)
  local width = w.W * T
  local list = {}
  local function family(name, gen) list[#list + 1] = { name = name, gen = gen } end

  family('run and jump', function(yield)
    for _, dir in ipairs({ 1, -1 }) do
      for _, hold in ipairs(HOLDS) do
        yield(('autorun %s hold %d'):format(dir > 0 and 'R' or 'L', hold), autorun(dir, hold))
        for _, x in ipairs(range(8, width - 8, 8)) do
          yield(('run %s, jump at x=%d hold %d'):format(dir > 0 and 'R' or 'L', x, hold), runAndJump(dir, x, hold))
        end
      end
    end
  end)

  family('one cast on the natural path', function(yield)
    for _, dir in ipairs({ 1, -1 }) do
      for _, hold in ipairs({ 12, 40 }) do
        local d = dir > 0 and 'R' or 'L'
        for _, castAt in ipairs(range(2, 600, 12)) do
          for _, wait in ipairs({ 0, 90, 200 }) do
            yield(('autorun %s hold %d, cast at frame %d, wait %d'):format(d, hold, castAt, wait), withCast(autorun(dir, hold), castAt, wait))
          end
        end
        for nth = 1, 6 do
          for _, rise in ipairs(RISES) do
            yield(('autorun %s hold %d, cast %d px up jump %d'):format(d, hold, rise, nth), withRiseCasts(autorun(dir, hold), nth, 1, rise))
          end
        end
      end
    end
  end)

  family('ladder of two mid-air casts', function(yield)
    for _, dir in ipairs({ 1, -1 }) do
      for nth = 1, 6 do
        for _, rise in ipairs(RISES) do
          yield(('autorun %s hold 40, casts %d px up jumps %d and %d'):format(dir > 0 and 'R' or 'L', rise, nth, nth + 1), withRiseCasts(autorun(dir, 40), nth, 2, rise))
        end
      end
    end
  end)

  family('standing echo stack', function(yield)
    for _, dir in ipairs({ 1, -1 }) do
      for n = 1, 2 do
        for _, x in ipairs(range(8, width - 8, 8)) do
          yield(('stack of %d at x=%d then autorun %s'):format(n, x, dir > 0 and 'R' or 'L'), stack(x, n, dir, 40))
        end
      end
    end
  end)
  return list
end

-- Rooms as the search sees them: the declared ones, or the whole level from its start to the goal.
function M.roomsOf(def)
  local rooms = Solutions.rooms[def.name]
  if rooms then return rooms end
  return { { name = 'whole level' } }
end

-- Returns { rooms = { { room, hits = { {family, label, frame} }, runs } }, runs, seconds }.
function M.search(def)
  local started = os.clock()
  local out = { rooms = {}, runs = 0 }
  for _, room in ipairs(M.roomsOf(def)) do
    local r = { room = room, hits = {}, runs = 0 }
    local w = Level.new(def, { checkpoint = room.from })
    for _, fam in ipairs(families(def, w)) do
      local hits = 0
      fam.gen(function(label, policy)
        if hits >= HITS_PER_FAMILY then return end
        r.runs = r.runs + 1
        local ok, frame = simulate(def, room.from, room.exit, policy)
        if ok then
          hits = hits + 1
          r.hits[#r.hits + 1] = { family = fam.name, label = label, frame = frame }
        end
      end)
    end
    out.runs = out.runs + r.runs
    out.rooms[#out.rooms + 1] = r
  end
  out.seconds = os.clock() - started
  return out
end

function M.format(index, def, result)
  local lines = { ('level %d "%s": %d rooms, %d runs in %.1f s'):format(index, def.name, #result.rooms, result.runs, result.seconds) }
  for k, r in ipairs(result.rooms) do
    local where = r.room.exit and ('exit %d,%d..%d,%d'):format(unpack(r.room.exit)) or 'the goal'
    if #r.hits == 0 then
      lines[#lines + 1] = ('  room %d "%s": no shallow strategy reaches %s (%d runs)'):format(k, r.room.name or '?', where, r.runs)
    else
      for _, h in ipairs(r.hits) do
        lines[#lines + 1] = ('  CHEESE room %d "%s": %s: %s reaches %s at frame %d'):format(k, r.room.name or '?', h.family, h.label, where, h.frame)
      end
    end
  end
  return table.concat(lines, '\n')
end

-- Shallow families plus the level's no-echo scripts, scored on the ember instead of a room exit.
function M.searchEmber(def)
  local started = os.clock()
  local hits, runs, familiesRun = {}, 0, {}
  local function family(name)
    local row = { name = name, runs = 0, hits = 0 }
    familiesRun[#familiesRun + 1] = row
    return row
  end
  local function score(row, label, policy)
    row.runs = row.runs + 1
    runs = runs + 1
    local ok, frame = simulate(def, nil, 'ember', policy)
    if ok then
      row.hits = row.hits + 1
      hits[#hits + 1] = { family = row.name, label = label, frame = frame }
    end
    return ok
  end
  local w = Level.new(def)
  for _, fam in ipairs(families(def, w)) do
    local row = family(fam.name)
    local n = 0
    fam.gen(function(label, policy)
      if n >= HITS_PER_FAMILY then return end
      if score(row, label, policy) then n = n + 1 end
    end)
  end
  local row = family('no echo')
  for _, block in ipairs(Solutions.emberBlocks[def.name] or {}) do
    score(row, block[1], function(world, s)
      if not s.drive then s.drive = Solutions.driver(block[2]) end
      return s.drive(world)
    end)
  end
  return { hits = hits, runs = runs, families = familiesRun, seconds = os.clock() - started }
end

-- args: level numbers; none means every level. Exits nonzero when any room has a hit.
function M.run(args)
  local picked = {}
  for _, a in ipairs(args) do
    if tonumber(a) then picked[#picked + 1] = tonumber(a) end
  end
  if #picked == 0 then picked = range(1, #Levels, 1) end
  local clean = true
  for _, i in ipairs(picked) do
    local def = Levels[i]
    if not def then
      print(('no level %d'):format(i))
      clean = false
    else
      local result = M.search(def)
      print(M.format(i, def, result))
      io.stdout:flush()
      for _, r in ipairs(result.rooms) do
        if #r.hits > 0 then clean = false end
      end
    end
  end
  return clean
end

return M
