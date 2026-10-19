local Save = {}

local PATH = 'save.txt'
local HEADER = 'echoes-save 1'
local MAX_LEVEL = 999

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function finite(n)
  return n and n == n and n > -math.huge and n < math.huge
end

function Save.defaults()
  return {
    version = 1,
    levels = {},
    settings = { master = 0.8, sfx = 0.7, fullscreen = false, shake = true },
  }
end

local function parseLevel(data, index, done, time, deaths)
  index, time, deaths = tonumber(index), tonumber(time), tonumber(deaths)
  if not index or index ~= math.floor(index) or index < 1 or index > MAX_LEVEL then return end
  data.levels[index] = {
    done = done == '1',
    bestTime = finite(time) and time > 0 and time < 1e6 and time or nil,
    bestDeaths = finite(deaths) and deaths >= 0 and deaths < 1e6 and math.floor(deaths) or nil,
  }
end

local function parseSetting(settings, key, value)
  local n = tonumber(value)
  if (key == 'master' or key == 'sfx') and finite(n) then
    settings[key] = clamp(n, 0, 1)
  elseif key == 'fullscreen' or key == 'shake' then
    if value == '1' then settings[key] = true elseif value == '0' then settings[key] = false end
  end
end

function Save.decode(text)
  local data = Save.defaults()
  if type(text) ~= 'string' then return data end
  local first = true
  for line in text:gmatch('[^\r\n]+') do
    if first then
      if line ~= HEADER then return Save.defaults() end
      first = false
    else
      local kind, a, b, c, d = line:match('^(%a+) (%S+) ?(%S*) ?(%S*) ?(%S*)$')
      if kind == 'setting' then
        parseSetting(data.settings, a, b)
      elseif kind == 'level' then
        parseLevel(data, a, b, c ~= '-' and c or nil, d ~= '-' and d or nil)
      elseif kind == 'ember' then
        local rec = data.levels[tonumber(a)]
        if rec then rec.ember = true end
      end
    end
  end
  return data
end

function Save.encode(data)
  local out = { HEADER }
  local s = data.settings
  out[#out + 1] = ('setting master %.2f'):format(s.master)
  out[#out + 1] = ('setting sfx %.2f'):format(s.sfx)
  out[#out + 1] = ('setting fullscreen %d'):format(s.fullscreen and 1 or 0)
  out[#out + 1] = ('setting shake %d'):format(s.shake and 1 or 0)
  local indices = {}
  for i in pairs(data.levels) do indices[#indices + 1] = i end
  table.sort(indices)
  for _, i in ipairs(indices) do
    local r = data.levels[i]
    out[#out + 1] = ('level %d %d %s %s'):format(i, r.done and 1 or 0,
      r.bestTime and ('%.3f'):format(r.bestTime) or '-', r.bestDeaths and tostring(r.bestDeaths) or '-')
  end
  for _, i in ipairs(indices) do
    if data.levels[i].ember then out[#out + 1] = ('ember %d'):format(i) end
  end
  return table.concat(out, '\n') .. '\n'
end

-- io = { read = fn(path) -> string|nil, write = fn(path, text) -> boolean }
function Save.fileIO()
  return {
    read = function(path)
      if not love.filesystem.getInfo(path) then return nil end
      return (love.filesystem.read(path))
    end,
    write = function(path, text) return (love.filesystem.write(path, text)) end,
  }
end

function Save.memoryIO(files)
  files = files or {}
  return {
    files = files,
    read = function(path) return files[path] end,
    write = function(path, text) files[path] = text return true end,
  }
end

function Save.open(io)
  local ok, text = pcall(io.read, PATH)
  return { io = io, data = Save.decode(ok and text or nil) }
end

function Save.embers(data)
  local n = 0
  for _, r in pairs(data.levels) do
    if r.ember then n = n + 1 end
  end
  return n
end

function Save.persist(store)
  local ok, wrote = pcall(store.io.write, PATH, Save.encode(store.data))
  if not (ok and wrote) then print('WARN  could not write save file') end
  return ok and wrote == true
end

-- A first clear sets the records without counting as a "new best". An ember counts once it leaves with you.
function Save.recordClear(data, index, time, deaths, ember)
  local rec = data.levels[index]
  local result = { first = not (rec and rec.done), newTime = false, newDeaths = false,
    newEmber = ember == true and not (rec and rec.ember) }
  if not rec then
    rec = {}
    data.levels[index] = rec
  end
  rec.done = true
  rec.ember = rec.ember or ember == true
  if not rec.bestTime or time < rec.bestTime then
    result.newTime = not result.first
    rec.bestTime = time
  end
  if not rec.bestDeaths or deaths < rec.bestDeaths then
    result.newDeaths = not result.first
    rec.bestDeaths = deaths
  end
  return result
end

return Save
