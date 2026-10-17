local Progress = {}

Progress.ACT_SIZE = 4
Progress.COLS = 4

local ROMAN = { 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X' }

function Progress.done(data, i)
  local r = data.levels[i]
  return r ~= nil and r.done == true
end

function Progress.unlocked(data, i)
  return i == 1 or Progress.done(data, i - 1)
end

function Progress.started(data)
  for _, r in pairs(data.levels) do
    if r.done then return true end
  end
  return false
end

function Progress.furthest(data, count)
  for i = 1, count do
    if not Progress.done(data, i) then return i end
  end
  return count
end

local function actLabel(act)
  if type(act) == 'number' then return 'ACT ' .. (ROMAN[act] or act) end
  return tostring(act):upper()
end

function Progress.acts(levels)
  local explicit = false
  for _, l in ipairs(levels) do
    if l.act ~= nil then explicit = true end
  end
  local acts, last = {}, nil
  for i, l in ipairs(levels) do
    local key
    if explicit then
      key = l.act ~= nil and l.act or last or 1
    else
      key = math.floor((i - 1) / Progress.ACT_SIZE) + 1
    end
    if key ~= last then
      acts[#acts + 1] = { label = actLabel(key), indices = {} }
      last = key
    end
    local a = acts[#acts]
    a.indices[#a.indices + 1] = i
  end
  return acts
end

function Progress.rows(acts)
  local rows = {}
  for ai, a in ipairs(acts) do
    for start = 1, #a.indices, Progress.COLS do
      local row = { act = ai, label = start == 1 and a.label or nil, indices = {} }
      for k = start, math.min(start + Progress.COLS - 1, #a.indices) do
        row.indices[#row.indices + 1] = a.indices[k]
      end
      rows[#rows + 1] = row
    end
  end
  return rows
end

local function locate(rows, index)
  for r, row in ipairs(rows) do
    for c, i in ipairs(row.indices) do
      if i == index then return r, c end
    end
  end
end

function Progress.neighbor(rows, index, action)
  local r, c = locate(rows, index)
  if not r then return index end
  if action == 'left' or action == 'right' then
    local delta = action == 'left' and -1 or 1
    local nc = c + delta
    if rows[r].indices[nc] then return rows[r].indices[nc] end
    local nr = (r - 1 + delta) % #rows + 1
    local target = rows[nr].indices
    return delta > 0 and target[1] or target[#target]
  end
  local nr = (r - 1 + (action == 'up' and -1 or 1)) % #rows + 1
  local target = rows[nr].indices
  return target[math.min(c, #target)]
end

return Progress
