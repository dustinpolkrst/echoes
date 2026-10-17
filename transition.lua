local X = { OUT = 0.2, IN = 0.26 }

local phase, t, fn = 'idle', 0, nil
X.cx, X.cy = 480, 270

local function ease(f)
  f = math.max(0, math.min(1, f))
  return f * f * (3 - 2 * f)
end

-- callback runs once, at the moment the screen is fully covered. Returns false if a transition is already running.
function X.start(callback, cx, cy)
  if phase ~= 'idle' then return false end
  phase, t, fn = 'out', 0, callback
  X.cx, X.cy = cx or 480, cy or 270
  return true
end

function X.reset()
  phase, t, fn = 'idle', 0, nil
end

function X.busy() return phase == 'out' end

function X.update(dt)
  if phase == 'idle' then return end
  t = t + dt
  if phase == 'out' and t >= X.OUT then
    local cb = fn
    phase, t, fn = 'in', 0, nil
    if cb then cb() end
  elseif phase == 'in' and t >= X.IN then
    phase, t = 'idle', 0
  end
end

function X.coverage()
  if phase == 'out' then return ease(t / X.OUT) end
  if phase == 'in' then return 1 - ease(t / X.IN) end
  return 0
end

return X
