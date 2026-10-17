local Echo = {}
Echo.__index = Echo

Echo.W, Echo.H = 10, 12
Echo.FRAMES = 180
Echo.LINGER = 4
Echo.FADE = 0.5
Echo.MAX = 2

function Echo.newRecorder()
  return { buf = {}, head = 0, count = 0 }
end

function Echo.record(rec, x, y, facing, state)
  rec.head = rec.head % Echo.FRAMES + 1
  local f = rec.buf[rec.head]
  if not f then
    f = {}
    rec.buf[rec.head] = f
  end
  f.x, f.y, f.facing, f.state = x, y, facing, state
  rec.count = math.min(rec.count + 1, Echo.FRAMES)
end

-- Oldest to newest; copies so later recording can't mutate a live echo.
function Echo.snapshot(rec)
  local out = {}
  for k = 1, rec.count do
    local f = rec.buf[(rec.head - rec.count + k - 1) % Echo.FRAMES + 1]
    out[k] = { x = f.x, y = f.y, facing = f.facing, state = f.state }
  end
  return out
end

-- Reflects a recording about the vertical line x = axis, in place.
function Echo.mirror(frames, axis)
  for _, f in ipairs(frames) do
    f.x = 2 * axis - f.x - Echo.W
    f.facing = -f.facing
  end
end

function Echo.new(frames, mirrored)
  local f = frames[1]
  return setmetatable({
    frames = frames, i = 1, lingerT = 0, halted = false, mirrored = mirrored or false,
    x = f.x, y = f.y, prevX = f.x, prevY = f.y,
    facing = f.facing, state = f.state,
    w = Echo.W, h = Echo.H,
  }, Echo)
end

-- blocked(x, y, w, h) says whether the next pose may be taken; a refused pose halts the replay for good.
function Echo:update(dt, blocked)
  self.prevX, self.prevY = self.x, self.y
  if self.i < #self.frames and not self.halted then
    local n = self.frames[self.i + 1]
    if blocked and blocked(n.x, n.y, self.w, self.h) then
      self.halted = true
    else
      self.i = self.i + 1
    end
  end
  if self.halted or self.i >= #self.frames then
    self.lingerT = self.lingerT + dt
  end
  local f = self.frames[self.i]
  self.x, self.y, self.facing, self.state = f.x, f.y, f.facing, f.state
end

function Echo:arrived()
  return self.halted or self.i >= #self.frames
end

function Echo:isSolid()
  return self.lingerT < Echo.LINGER
end

function Echo:isAlive()
  return self.lingerT < Echo.LINGER + Echo.FADE
end

return Echo
