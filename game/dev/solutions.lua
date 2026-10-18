local Levels = require 'content.levels'
local Script = require 'dev.script'

-- Aggregates the per-act solution files. Each act file returns { scripts = {}, strategies = {}, rooms = {} }
-- keyed by level name, so adding a level touches only its act's content and solution files.
--   scripts     a full scripted playthrough; --selftest proves every level has one that reaches the goal.
--   strategies  a solution written as a human plays it, every decision a swept parameter (dev/slack.lua).
--   rooms       the level's rooms: where each starts, where it ends, its insight, a solve from a fresh respawn at its
--               checkpoint and the naive approaches that must fail. See docs/level-design.md.
local ACTS = { 'dev.solutions.act1', 'dev.solutions.act2', 'dev.solutions.act3', 'dev.solutions.act4', 'dev.solutions.act5' }

local M = { scripts = {}, strategies = {}, rooms = {} }
M.run, M.driver, M.cond, M.decisions = Script.run, Script.driver, Script.cond, Script.decisions

for _, path in ipairs(ACTS) do
  local act = require(path)
  for _, key in ipairs({ 'scripts', 'strategies', 'rooms' }) do
    for name, v in pairs(act[key] or {}) do
      assert(M[key][name] == nil, ('%s: %s for %q defined twice'):format(path, key, name))
      M[key][name] = v
    end
  end
end

for name, strategy in pairs(M.strategies) do
  assert(M.scripts[name] == nil, ('%q has both a script and a strategy; the strategy builds the script'):format(name))
  M.scripts[name] = strategy.build(Script.decisions(strategy))
end

-- An input source for a live scene: returns the next scripted input, then idles.
function M.provider(index)
  local drive = Script.driver(M.scripts[Levels[index].name])
  local done = false
  return function(world)
    if done then return {} end
    local input = drive(world)
    if not input then
      done = true
      return {}
    end
    return input
  end
end

return M
