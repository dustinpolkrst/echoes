local Echo = require 'world.echo'

local Model = {}
local STEP = 1 / 60
local max, min = math.max, math.min

function Model.clock(seconds)
  local m = math.floor(seconds / 60)
  local s = seconds - m * 60
  if tonumber(('%.1f'):format(s)) >= 60 then m, s = m + 1, 0 end
  return ('%d:%04.1f'):format(m, s)
end

function Model.memory(world)
  return world.rec.count / Echo.FRAMES
end

-- One entry per slot, oldest first. frac is remaining life over the full life.
-- Remaining life is frames the echo will still play, plus linger. A halt plays none of what is left.
function Model.slots(world)
  local out = {}
  for k = 1, Echo.MAX do
    local e = world.echoes[k]
    if e then
      local replaying = not e.halted and e.i < #e.frames
      local replayLeft = replaying and (#e.frames - e.i) * STEP or 0
      local lingerLeft = Echo.LINGER + Echo.FADE - e.lingerT
      local total = #e.frames * STEP + Echo.LINGER + Echo.FADE
      out[k] = { alive = true, replaying = replaying, frac = max(0, min(1, (replayLeft + lingerLeft) / total)), fading = e.lingerT >= Echo.LINGER }
    else
      out[k] = { alive = false, frac = 0 }
    end
  end
  return out
end

return Model
