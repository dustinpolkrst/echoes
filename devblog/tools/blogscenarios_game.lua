-- Extra --shot targets for the dev blog, for commits that keep the game in game/ (7ae145b on).
-- shots.sh copies this file into an exported commit's dev/ folder (never into the repo) and wraps
-- that commit's dev/shot.lua so these names resolve. Each target takes one number, as --shot does.
local S = {}

local function freezeClocks()
  love.math.setRandomSeed(1)
  math.randomseed(1)
  require('gfx.ui').time = function() return 0 end
end

local function freshScenes(Scenes)
  local Save = require 'platform.save'
  Scenes.init(Save.open(Save.memoryIO()))
end

-- Other Side (level 6): run to the door, cast once at the shrine, keep holding right, and draw frame n.
-- Before d3180c1 this replayed the run across the plate's reflection and opened the door.
function S.othersiderun(Scenes, n)
  freezeClocks()
  freshScenes(Scenes)
  local Script = require 'dev.script'
  local drive = Script.driver({ { 'R', Script.cond.atX(166) }, { 1, 'RX' }, { 1200, 'R' } })
  Scenes.go('playing', 6)
  Scenes.inputSource = function(world) return drive(world) or {} end
  for _ = 1, n or 100 do Scenes.update() end
  return ('shot_othersiderun_%d.png'):format(n or 100)
end

-- Relay (level 13): play the scripted solution for n frames, press R, and draw the room after the respawn.
function S.relayrespawn(Scenes, n)
  freezeClocks()
  freshScenes(Scenes)
  Scenes.go('playing', 13)
  Scenes.inputSource = require('dev.solutions').provider(13)
  for _ = 1, n or 700 do Scenes.update() end
  Scenes.inputSource = function() return {} end
  Scenes.dispatch(require('platform.input').fromKey('r'))
  for _ = 1, 45 do Scenes.update() end
  return ('shot_relayrespawn_%d.png'):format(n or 700)
end

local function play(Scenes, level, provider, untilFn, limit)
  freezeClocks()
  freshScenes(Scenes)
  Scenes.go('playing', level)
  Scenes.inputSource = provider
  for _ = 1, limit or 4000 do
    Scenes.update()
    if untilFn(Scenes) then return true end
  end
  error('scenario never reached its moment on level ' .. level)
end

local function emberRoute(level)
  local Solutions = require 'dev.solutions'
  local drive = Solutions.driver(Solutions.embers[require('content.levels')[level].name])
  return function(world) return drive(world) or {} end
end

-- Play level n's solution up to the first moment the player touches a mirror shrine with a full memory and no echo
-- out, so the trail previews the reflection.
function S.atshrine(Scenes, n)
  play(Scenes, n, require('dev.solutions').provider(n), function()
    local w = Scenes.playing.world
    return w:touchedMirror() and w.rec.count >= 170 and #w.echoes == 0
  end)
  return ('shot_atshrine_%d.png'):format(n)
end

-- Run right into level n's first hazard and hold on the death prompt.
function S.deathprompt(Scenes, n)
  play(Scenes, n, function() return { right = true } end, function() return Scenes.playing.world.player.state == 'dead' end)
  Scenes.inputSource = function() return {} end
  for _ = 1, 40 do Scenes.update() end
  return ('shot_deathprompt_%d.png'):format(n)
end

-- Play level n's ember route to the step the ember is taken, plus a few frames of the burst.
function S.embertaken(Scenes, n)
  play(Scenes, n, emberRoute(n), function() return Scenes.playing.world:emberTaken() end)
  for _ = 1, 6 do Scenes.update() end
  return ('shot_embertaken_%d.png'):format(n)
end

-- Play level n's ember route through to the level clear card.
function S.emberclear(Scenes, n)
  play(Scenes, n, emberRoute(n), function() return Scenes.name == 'levelclear' end)
  for _ = 1, 50 do Scenes.update() end
  return ('shot_emberclear_%d.png'):format(n)
end

-- The level select after clearing levels 1 to n, with the embers of the odd levels found.
function S.emberselect(Scenes, n)
  freezeClocks()
  local Save = require 'platform.save'
  local store = Save.open(Save.memoryIO())
  for i = 1, n do
    store.data.levels[i] = { done = true, bestTime = 14 + i * 3.7, bestDeaths = i % 3, ember = i % 2 == 1 }
  end
  Scenes.init(store)
  Scenes.go('select', n + 1)
  for _ = 1, 60 do Scenes.update() end
  return ('shot_emberselect_%d.png'):format(n)
end

return S
