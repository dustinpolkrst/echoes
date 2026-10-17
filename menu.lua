local Menu = {}

local CONFIRM_WINDOW = 2

Menu.clock = function() return love.timer.getTime() end

-- items: { label = string, action = fn?, value = fn -> string?, meter = fn -> 0..1?, adjust = fn(dir)?, confirm = string? }
function Menu.new(items, index)
  return { items = items, index = index or 1 }
end

local function armed(m)
  return m.armedIndex == m.index and Menu.clock() - m.armedAt < CONFIRM_WINDOW
end

function Menu.label(m, i)
  local item = m.items[i]
  if i == m.index and item.confirm and armed(m) then return item.confirm end
  return item.label
end

function Menu.move(m, delta)
  local index = math.max(1, math.min(#m.items, m.index + delta))
  if index == m.index then return false end
  m.index, m.armedIndex = index, nil
  return true
end

function Menu.activate(m)
  local item = m.items[m.index]
  if item.confirm and not armed(m) then
    m.armedIndex, m.armedAt = m.index, Menu.clock()
    return true
  end
  m.armedIndex = nil
  if item.action then
    item.action()
  elseif item.adjust then
    item.adjust(1)
  else
    return false
  end
  return true
end

function Menu.adjust(m, delta)
  local item = m.items[m.index]
  if not item.adjust then return false end
  item.adjust(delta)
  return true
end

-- Returns what happened ('move', 'select', 'adjust') so the caller can play the matching sound.
function Menu.handle(m, action)
  if action == 'up' then return Menu.move(m, -1) and 'move' or nil end
  if action == 'down' then return Menu.move(m, 1) and 'move' or nil end
  if action == 'confirm' then return Menu.activate(m) and 'select' or nil end
  if action == 'left' then return Menu.adjust(m, -1) and 'adjust' or nil end
  if action == 'right' then return Menu.adjust(m, 1) and 'adjust' or nil end
end

return Menu
