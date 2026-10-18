local Level = require 'level'
local Levels = require 'levels'
local Solutions = require 'solutions'

local M = {}

local function wins(def, script)
  local ok, outcome = Solutions.run(Level.new(def), script)
  return ok and outcome == 'cleared'
end

-- The window is the run of winning values that contains the nominal; width 0 means the nominal loses.
local function runAround(values, won, nominal)
  local i
  for k, v in ipairs(values) do
    if v == nominal then i = k end
  end
  if not i or not won[i] then return 0 end
  local lo, hi = i, i
  while lo > 1 and won[lo - 1] do lo = lo - 1 end
  while hi < #values and won[hi + 1] do hi = hi + 1 end
  return hi - lo + 1, values[lo], values[hi]
end

function M.sweep(def, strategy, decision, overrides)
  local base = Solutions.decisions(strategy, overrides)
  local values, won = {}, {}
  local first = base[decision.name] - math.floor((base[decision.name] - decision.min) / decision.step) * decision.step
  for v = first, decision.max, decision.step do
    local p = {}
    for k, x in pairs(base) do p[k] = x end
    p[decision.name] = v
    values[#values + 1] = v
    won[#won + 1] = wins(def, strategy.build(p))
  end
  local count, lo, hi = runAround(values, won, base[decision.name])
  local marks = {}
  for k, w in ipairs(won) do marks[k] = w and '#' or '.' end
  return {
    name = decision.name, unit = decision.unit, nominal = base[decision.name],
    width = count * decision.step, lo = lo, hi = hi, strip = table.concat(marks),
    min = decision.min, max = decision.max, step = decision.step, need = decision.need, note = decision.note,
  }
end

function M.measure(index, overrides)
  local def = Levels[index]
  local strategy = Solutions.strategies[def.name]
  if not strategy then return nil end
  local out = { level = index, name = def.name, nominalWins = wins(def, strategy.build(Solutions.decisions(strategy, overrides))), rows = {} }
  for _, d in ipairs(strategy.params) do
    out.rows[#out.rows + 1] = M.sweep(def, strategy, d, overrides)
  end
  return out
end

function M.format(r)
  local lines = { ('level %d "%s": nominal %s'):format(r.level, r.name, r.nominalWins and 'wins' or 'LOSES') }
  for _, row in ipairs(r.rows) do
    local window = row.width > 0 and ('%d %s (%s..%s)'):format(row.width, row.unit, row.lo, row.hi) or '0 ' .. row.unit
    lines[#lines + 1] = ('  %-10s nominal %-4s range %s..%s step %s  window %s%s'):format(
      row.name, row.nominal, row.min, row.max, row.step, window, row.note and ('  (' .. row.note .. ')') or '')
    lines[#lines + 1] = '  ' .. row.strip
  end
  return table.concat(lines, '\n')
end

-- args: optional level number, then name=value overrides for the strategy's decisions.
function M.run(args)
  local only, overrides = nil, {}
  for _, a in ipairs(args) do
    local k, v = a:match('^(%w+)=(-?%d+%.?%d*)$')
    if k then overrides[k] = tonumber(v) elseif tonumber(a) then only = tonumber(a) end
  end
  local ok = true
  for i = only or 1, only or #Levels do
    local r = M.measure(i, overrides)
    if r then
      print(M.format(r))
      ok = ok and r.nominalWins
    elseif only then
      print(('level %d "%s" has no strategy'):format(i, Levels[i].name))
      ok = false
    end
  end
  return ok
end

return M
