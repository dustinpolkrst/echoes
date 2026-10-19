-- The world's recent past, one saved state per step, for rewinding. A ring of states so a long attempt
-- keeps only the last SECONDS of history.
local Timeline = {}

Timeline.SECONDS = 30
local CAP = Timeline.SECONDS * 60

function Timeline.new(world)
  local tl = { states = {}, first = 1, last = 0 }
  Timeline.push(tl, world)
  return tl
end

function Timeline.push(tl, world)
  tl.last = tl.last + 1
  tl.states[tl.last] = world:save()
  if tl.last - tl.first >= CAP then
    tl.states[tl.first] = nil
    tl.first = tl.first + 1
  end
end

-- Steps the world back one step. Returns false when there is no earlier state to return to.
function Timeline.back(tl, world)
  if tl.last <= tl.first then return false end
  tl.states[tl.last] = nil
  tl.last = tl.last - 1
  world:load(tl.states[tl.last])
  return true
end

function Timeline.seconds(tl)
  return (tl.last - tl.first) / 60
end

return Timeline
