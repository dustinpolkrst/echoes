local Menu = {}

-- items: { label = string, action = fn?, value = fn -> string?, meter = fn -> 0..1?, adjust = fn(dir)? }
function Menu.new(items, index)
  return { items = items, index = index or 1 }
end

function Menu.move(m, delta)
  m.index = (m.index - 1 + delta) % #m.items + 1
end

function Menu.activate(m)
  local item = m.items[m.index]
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
  if action == 'up' then Menu.move(m, -1) return 'move' end
  if action == 'down' then Menu.move(m, 1) return 'move' end
  if action == 'confirm' then return Menu.activate(m) and 'select' or nil end
  if action == 'left' then return Menu.adjust(m, -1) and 'adjust' or nil end
  if action == 'right' then return Menu.adjust(m, 1) and 'adjust' or nil end
end

return Menu
