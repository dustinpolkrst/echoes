local Echo = require 'echo'

local Model = {}
local STEP = 1 / 60
local max, min = math.max, math.min

function Model.clock(seconds)
  local m = math.floor(seconds / 60)
  return ('%d:%04.1f'):format(m, seconds - m * 60)
end

-- Fraction of the 3 second history the recorder holds; a cast now replays exactly that much.
function Model.memory(world)
  return world.rec.count / Echo.FRAMES
end

-- One entry per slot, oldest first. frac is the share of the echo's remaining life (replay plus linger).
function Model.slots(world)
  local out = {}
  for k = 1, Echo.MAX do
    local e = world.echoes[k]
    if e then
      local replayLeft = (#e.frames - e.i) * STEP
      local lingerLeft = Echo.LINGER + Echo.FADE - e.lingerT
      local total = #e.frames * STEP + Echo.LINGER + Echo.FADE
      out[k] = { alive = true, replaying = e.i < #e.frames, frac = max(0, min(1, (replayLeft + lingerLeft) / total)), fading = e.lingerT >= Echo.LINGER }
    else
      out[k] = { alive = false, frac = 0 }
    end
  end
  return out
end

return Model
