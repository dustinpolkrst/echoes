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
  rec.buf[rec.head] = { x = x, y = y, facing = facing, state = state }
  rec.count = math.min(rec.count + 1, Echo.FRAMES)
end

-- Recorded frames are never mutated after they are written, so a timeline snapshot can share them.
function Echo.copyRecorder(rec)
  local buf = {}
  for k, f in pairs(rec.buf) do buf[k] = f end
  return { buf = buf, head = rec.head, count = rec.count }
end

-- Oldest to newest; copies so mirroring can't reach the recorder's frames.
function Echo.snapshot(rec)
  local out = {}
  for k = 1, rec.count do
    local f = rec.buf[(rec.head - rec.count + k - 1) % Echo.FRAMES + 1]
    out[k] = { x = f.x, y = f.y, facing = f.facing, state = f.state }
  end
  return out
end

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

local function slideToContact(self, isBlockedAt)
  local f, n = self.frames[self.i], self.frames[self.i + 1]
  local lo, hi = 0, 1
  for _ = 1, 10 do
    local mid = (lo + hi) / 2
    if isBlockedAt(f.x + (n.x - f.x) * mid, f.y + (n.y - f.y) * mid, self.w, self.h) then hi = mid else lo = mid end
  end
  self.stopX, self.stopY = f.x + (n.x - f.x) * lo, f.y + (n.y - f.y) * lo
end

function Echo:update(dt, isBlockedAt)
  self.prevX, self.prevY = self.x, self.y
  if self.i < #self.frames and not self.halted then
    local n = self.frames[self.i + 1]
    if isBlockedAt and isBlockedAt(n.x, n.y, self.w, self.h) then
      self.halted = true
      slideToContact(self, isBlockedAt)
    else
      self.i = self.i + 1
    end
  end
  if self.halted or self.i >= #self.frames then
    self.lingerT = self.lingerT + dt
  end
  local f = self.frames[self.i]
  self.x, self.y, self.facing, self.state = self.stopX or f.x, self.stopY or f.y, f.facing, f.state
end

function Echo:copy()
  local c = {}
  for k, v in pairs(self) do c[k] = v end
  return setmetatable(c, Echo)
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
