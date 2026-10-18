local P = {}

P.W, P.H = 10, 12

local MAX_RUN = 100
local ACC_GROUND, DEC_GROUND = 900, 1100
local ACC_AIR, DEC_AIR = 600, 350
local JUMP_V = 310
local JUMP_CUT = 110
local GRAV_UP, GRAV_DOWN = 900, 1500
local MAX_FALL = 280
local COYOTE, JUMP_BUFFER = 0.1, 0.1
local DEATH_DELAY = 0.7
local EPS_LAND = 120

P.DEATH_DELAY = DEATH_DELAY
P.MAX_RUN = MAX_RUN
P.JUMP_V = JUMP_V

local function approach(v, target, amount)
  if v < target then return math.min(v + amount, target) end
  return math.max(v - amount, target)
end

local function emit(w, name, x, y, extra)
  w.events[#w.events + 1] = { name = name, x = x, y = y, v = extra }
end

local function setState(p, w, name, ...)
  p.state = name
  p.stateT = 0
  local s = P.states[name]
  if s.enter then s.enter(p, w, ...) end
end

local function jump(p, w)
  p.vy = -JUMP_V
  p.jumpBuf = 0
  p.coyote = 0
  p.support = nil
  p.sx, p.sy = 0.7, 1.35
  emit(w, 'jump', p.x + P.W / 2, p.y + P.H)
end

local function physics(p, w, input, dt, grounded)
  local dir = (input.right and 1 or 0) - (input.left and 1 or 0)
  local acc = grounded and ACC_GROUND or ACC_AIR
  local dec = grounded and DEC_GROUND or DEC_AIR
  if dir ~= 0 then
    p.facing = dir
    local rate = (p.vx * dir < 0) and dec or acc
    p.vx = approach(p.vx, dir * MAX_RUN, rate * dt)
  else
    p.vx = approach(p.vx, 0, dec * dt)
  end

  local g = p.vy < 0 and GRAV_UP or GRAV_DOWN
  p.vy = math.min(p.vy + g * dt, MAX_FALL)
  if not input.jump and p.vy < -JUMP_CUT then p.vy = -JUMP_CUT end

  local impact = p.vy
  if w:moveX(p, p.vx * dt) then p.vx = 0 end
  local landed = w:moveY(p, p.vy * dt)
  return landed, impact
end

local function carry(p, w)
  local e = p.support
  if type(e) ~= 'table' or not e:isSolid() then return end
  w:moveX(p, e.x - e.prevX)
  w:moveY(p, (e.y - p.h) - p.y)
end

P.states = {
  ground = {
    enter = function(p, w, impact)
      p.coyote = COYOTE
      if impact and impact > EPS_LAND then
        p.sx, p.sy = 1.35, 0.65
        emit(w, 'land', p.x + P.W / 2, p.y + P.H, impact)
      end
    end,
    update = function(p, w, input, dt)
      carry(p, w)
      if p.jumpBuf > 0 then jump(p, w) end
      local landed = physics(p, w, input, dt, true)
      if landed then
        p.support = landed
        p.coyote = COYOTE
      else
        p.support = nil
        setState(p, w, 'air')
      end
    end,
  },
  air = {
    update = function(p, w, input, dt)
      p.coyote = p.coyote - dt
      if p.jumpBuf > 0 and p.coyote > 0 then jump(p, w) end
      local landed, impact = physics(p, w, input, dt, false)
      if landed then
        p.support = landed
        setState(p, w, 'ground', impact)
      end
    end,
  },
  dead = {
    enter = function(p, w)
      p.vx, p.vy = 0, 0
      p.support = nil
      emit(w, 'death', p.x + P.W / 2, p.y + P.H / 2)
    end,
    update = function() end,
  },
  cleared = {
    enter = function(p, w)
      p.vx, p.vy = 0, 0
      emit(w, 'goal', p.x + P.W / 2, p.y + P.H / 2)
    end,
    update = function() end,
  },
}

function P.new(x, y)
  return {
    x = x, y = y, w = P.W, h = P.H, vx = 0, vy = 0, facing = 1,
    state = 'air', stateT = 0, coyote = 0, jumpBuf = 0, prevJump = false,
    support = nil, sx = 1, sy = 1,
  }
end

function P.update(p, w, input, dt)
  if input.jump and not p.prevJump then
    p.jumpBuf = JUMP_BUFFER
  else
    p.jumpBuf = math.max(0, p.jumpBuf - dt)
  end
  p.prevJump = input.jump or false
  P.states[p.state].update(p, w, input, dt)
  p.stateT = p.stateT + dt
  p.sx = approach(p.sx, 1, 3 * dt)
  p.sy = approach(p.sy, 1, 3 * dt)
end

function P.kill(p, w)
  if p.state == 'dead' or p.state == 'cleared' then return end
  setState(p, w, 'dead')
end

function P.clear(p, w)
  if p.state == 'dead' or p.state == 'cleared' then return end
  setState(p, w, 'cleared')
end

function P.isAlive(p)
  return p.state == 'ground' or p.state == 'air'
end

return P
