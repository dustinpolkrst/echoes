local S = require 'dev.script'
local C = S.cond
local atX, atXLeft, onTop, apex, echoArrived, onLastEcho, grounded, doorOpen =
  C.atX, C.atXLeft, C.onTop, C.apex, C.echoArrived, C.onLastEcho, C.grounded, C.doorOpen
local append = S.append

local T = 16
local function tile(tx) return tx * T + 3 end

-- Clockwork ------------------------------------------------------------------------------------------------------
-- Room 1 Overlap: cast standing on a, cast on arrival at b, run; B opens while you wait between the doors.
-- Room 2 One Ghost: c is held by a standing ghost, so one ghost must press a and then b: stand on a, cast on arriving at b.
-- Room 3 Double Cast: one memory cast twice, plain on a and mirrored at the shrine, holds a and the sealed plate c.
local CLOCKWORK = {
  { name = 'standA1', unit = 'frames', nominal = 190, min = 0, max = 400, step = 10 },
  { name = 'holdB1', unit = 'frames', nominal = 10, min = 0, max = 300, step = 10 },
  { name = 'standC', unit = 'frames', nominal = 190, min = 0, max = 400, step = 10 },
  { name = 'standA2', unit = 'frames', nominal = 140, min = 0, max = 300, step = 10 },
  { name = 'holdB2', unit = 'frames', nominal = 60, min = 0, max = 200, step = 10 },
  { name = 'standA3', unit = 'frames', nominal = 100, min = 0, max = 300, step = 10 },
  { name = 'mirrorDelay', unit = 'frames', nominal = 10, min = 0, max = 200, step = 10 },
}
local CW = { a1 = 3, b1 = 9, w1 = 40, c2 = 42, a2 = 44, b2 = 46, wait2 = 52, w2 = 57, a3 = 61, M3 = 65, roof3 = 66, G3 = 72 }

local function clockworkRoom1(p)
  return {
    { 'R', atX(tile(CW.a1)) }, { p.standA1, '-' }, { 1, 'X' },
    { 'R', atX(tile(CW.b1)) }, { p.holdB1, '-' }, { 1, 'X' },
    { 'R', atX(tile(CW.w1 - 5)) }, { 'R', atX(tile(CW.w1)) },
  }
end

local function clockworkRoom2(p)
  return {
    { 'R', atX(tile(CW.c2)) }, { p.standC, '-' }, { 1, 'X' },
    { 'R', atX(tile(CW.a2)) }, { p.standA2, '-' },
    { 'R', atX(tile(CW.b2)) }, { p.holdB2, '-' }, { 1, 'X' },
    { 'R', atX(tile(CW.wait2)) }, { 'R', atX(tile(CW.w2)) },
  }
end

-- Drop onto a and stand, cast, walk to the shrine and cast the same memory again mirrored, then climb and run.
local function clockworkRoom3(p)
  return {
    { 'R', atX(tile(CW.a3 - 1)) }, { '-', grounded }, { p.standA3, '-' }, { 1, 'X' },
    { 'R', atX(CW.M3 * T + 2) }, { p.mirrorDelay, '-' }, { 1, 'X' },
    { 'RJ', onTop(10 * T, CW.roof3 * T) }, { 'R', atX(CW.G3 * T) },
  }
end

-- Hall of Mirrors ---------------------------------------------------------------------------------------------
-- Room 1 Which Shrine: the plate's reflection about the near shrine is the far shrine itself, so stand on the far
-- shrine, walk to the near one and cast; climb, cross the bridge and pass A while the reflection stands on air.
-- Room 2 Twice Mirrored: one stand cast at two adjacent shrines lands on both floating plates, a and b.
local HALL = {
  { name = 'standX1', unit = 'px', nominal = 196, min = 150, max = 240, step = 2 },
  { name = 'stand1', unit = 'frames', nominal = 100, min = 0, max = 300, step = 10 },
  { name = 'castDelay1', unit = 'frames', nominal = 10, min = 0, max = 200, step = 10 },
  { name = 'standX2', unit = 'px', nominal = 418, min = 380, max = 460, step = 2 },
  { name = 'stand2', unit = 'frames', nominal = 100, min = 0, max = 300, step = 10 },
  { name = 'castDelay2', unit = 'frames', nominal = 10, min = 0, max = 200, step = 10 },
  { name = 'castDelay3', unit = 'frames', nominal = 10, min = 0, max = 200, step = 10 },
}
local HM = { M2 = 12, M1 = 15, roof1 = 16, w1 = 22, drop = 25, M3 = 29, M4 = 30, roof2 = 31, G = 37 }

local function hallRoom1(p)
  return {
    { 'R', atX(68) }, { 'RJ', onTop(13 * T, 8 * T) }, { 'R', atX(p.standX1) }, { p.stand1, '-' },
    { 'R', atX(HM.M1 * T + 2) }, { p.castDelay1, '-' }, { 1, 'X' },
    { 'RJ', onTop(10 * T, HM.roof1 * T) }, { 'R', atX(tile(HM.w1)) },
  }
end

local function hallRoom2(p)
  return {
    { 'R', atX(372) }, { '-', grounded }, { 'R', atX(p.standX2) }, { p.stand2, '-' },
    { 'R', atX(HM.M3 * T + 2) }, { p.castDelay2, '-' }, { 1, 'X' },
    { 'R', atX(HM.M4 * T + 2) }, { p.castDelay3, '-' }, { 1, 'X' },
    { 'RJ', onTop(10 * T, HM.roof2 * T) }, { 'R', atX(HM.G * T) },
  }
end

-- Three Steps Behind -------------------------------------------------------------------------------------------
-- Hatches open for a quarter second when a replaying ghost runs across their plate, three seconds after you did,
-- and stay open for as long as you paused on it. Room 1 teaches the drop. Room 2 puts hatches B and C four tiles
-- apart below plates two tiles apart, so you must pause between the plates. Room 3 seals the plates in a gallery:
-- a reflection runs it, so you pause at the mirror spots on the way to the shrine and cast standing on hatch A.
local STEPS = {
  { name = 'holdA1', unit = 'frames', nominal = 10, min = 0, max = 200, step = 10 },
  { name = 'pauseB', unit = 'frames', nominal = 50, min = 0, max = 200, step = 10 },
  { name = 'pauseC', unit = 'frames', nominal = 40, min = 0, max = 200, step = 10 },
  { name = 'holdA2', unit = 'frames', nominal = 10, min = 0, max = 200, step = 10 },
  { name = 'pause1', unit = 'frames', nominal = 20, min = 0, max = 150, step = 10 },
  { name = 'pause2', unit = 'frames', nominal = 30, min = 0, max = 150, step = 10 },
  { name = 'pause3', unit = 'frames', nominal = 30, min = 0, max = 150, step = 10 },
  { name = 'holdM', unit = 'frames', nominal = 10, min = 0, max = 150, step = 10 },
}
local TS = { A1 = 11, w1 = 14, a2 = 17, b2 = 19, c2 = 21, A2 = 23, B2 = 27, C2 = 31, w2 = 35,
  aSpot = 592, bSpot = 624, cSpot = 656, M3 = 43, B3 = 47, C3 = 51, G = 54 }

local function stepsRoom1(p)
  return {
    { 'R', atX(tile(TS.A1)) }, { p.holdA1, '-' }, { 1, 'X' }, { '-', onTop(9 * T) }, { 'R', atX(tile(TS.w1)) },
  }
end

local function stepsRoom2(p)
  return {
    { 'R', atX(tile(TS.b2)) }, { p.pauseB, '-' }, { 'R', atX(tile(TS.c2)) }, { p.pauseC, '-' },
    { 'R', atX(tile(TS.A2)) }, { p.holdA2, '-' }, { 1, 'X' }, { '-', onTop(12 * T) },
    { 'R', atX(tile(TS.B2)) }, { '-', onTop(15 * T) }, { 'R', atX(tile(TS.C2)) }, { '-', onTop(18 * T) },
    { 'R', atX(tile(TS.w2)) },
  }
end

local function stepsRoom3(p)
  return {
    { 'R', atX(TS.aSpot) }, { p.pause1, '-' }, { 'R', atX(TS.bSpot) }, { p.pause2, '-' },
    { 'R', atX(TS.cSpot) }, { p.pause3, '-' },
    { 'R', atX(tile(TS.M3)) }, { p.holdM, '-' }, { 1, 'X' }, { '-', onTop(21 * T) },
    { 'R', atX(tile(TS.B3)) }, { '-', onTop(24 * T) }, { 'R', atX(tile(TS.C3)) }, { '-', onTop(27 * T) },
    { 'R', atX(TS.G * T) },
  }
end

-- Let Go ---------------------------------------------------------------------------------------------------------
-- The third cast removes the oldest ghost, and door A is both the gate you pass and the floor beyond it over spikes.
-- Room 1 Let Go: a ghost on a opens the gate; two casts from inside the doorway take that ghost and shut the floor.
-- Room 2 Oldest First: the keeper on b must outlive the kill, so cast on a first, on b second, and once in the doorway.
-- Room 3 Borrowed Time: the kill casts are ghosts too; pause on c so they hold C when you arrive, within the seven
-- seconds the ghost on a can spare. Plates a sit behind each waystone, and every gate stands on crumble over spikes.
local LETGO = {
  { name = 'standA1', unit = 'frames', nominal = 100, min = 0, max = 400, step = 10 },
  { name = 'killX1', unit = 'px', nominal = 392, min = 340, max = 440, step = 2 },
  { name = 'standA2', unit = 'frames', nominal = 100, min = 0, max = 400, step = 10 },
  { name = 'standB2', unit = 'frames', nominal = 40, min = 0, max = 400, step = 10 },
  { name = 'killX2', unit = 'px', nominal = 244, min = 200, max = 300, step = 2 },
  { name = 'standA3', unit = 'frames', nominal = 190, min = 0, max = 400, step = 10 },
  { name = 'pauseC', unit = 'frames', nominal = 90, min = 0, max = 300, step = 10 },
  { name = 'killX3', unit = 'px', nominal = 440, min = 390, max = 490, step = 2 },
}
-- Storey 1 runs right (a at 1, gate 24, shaft 36), storey 2 runs left (a at 40, b at 34, gate 15, B at 6, shaft 3),
-- storey 3 runs right (a at 1, c at 23, gate 27, C at 35, goal 37). Every door-floor is five tiles, past any jump.
local LG = { foot1 = 20, shaft1 = 36, floor2 = 12 * T, a2 = 40, b2 = 34, past2 = 4, floor3 = 18 * T, c3 = 23, G3 = 37 }

local function kill() return { { 1, 'X' }, { 2, '-' }, { 1, 'X' } } end

local function letgoRoom1(p)
  return append(append({
    { 'L', atXLeft(LG.foot1) }, { p.standA1, '-' }, { 1, 'X' }, { 'R', atX(p.killX1) },
  }, kill()), { { 'R', atX(tile(LG.shaft1)) }, { '-', onTop(LG.floor2) } })
end

local function letgoRoom2(p)
  return {
    { 'R', atX(tile(LG.a2)) }, { p.standA2, '-' }, { 1, 'X' },
    { 'L', atXLeft(tile(LG.b2)) }, { p.standB2, '-' }, { 1, 'X' },
    { 'L', atXLeft(p.killX2) }, { 1, 'X' },
    { 'L', atXLeft(tile(LG.past2)) }, { '-', onTop(LG.floor3) },
  }
end

local function letgoRoom3(p)
  return append(append({
    { 'L', atXLeft(LG.foot1) }, { p.standA3, '-' }, { 1, 'X' },
    { 'R', atX(tile(LG.c3)) }, { p.pauseC, '-' }, { 'R', atX(p.killX3) },
  }, kill()), { { 'R', atX(LG.G3 * T) } })
end

-- Room 2 naives: the plate order, how many casts in the doorway, the stands, then the walk out past B.
local function letgoRoom2Naive(order, doorCasts, standA, standB)
  local s = {}
  local onA = { { 'R', atX(tile(LG.a2)) }, { standA, '-' }, { 1, 'X' } }
  local onB = { { 'L', atXLeft(tile(LG.b2)) }, { standB, '-' }, { 1, 'X' } }
  if order == 'ba' then append(append(s, onB), onA)
  elseif order == 'a' then append(s, onA)
  elseif order == 'b' then append(s, onB)
  else append(append(s, onA), onB) end
  append(s, { { 'L', atXLeft(244) } })
  for _ = 1, doorCasts do append(s, { { 1, 'X' }, { 2, '-' } }) end
  return append(s, { { 'L', atXLeft(tile(7)) }, { 200, 'L' } })
end

-- Room 3 naives: the stand on a, the pause on c (cast there when standC), casts in the doorway, then the run to the goal.
local function letgoRoom3Naive(standA, pause, doorCasts, standC)
  local s = { { 'L', atXLeft(LG.foot1) }, { standA, '-' }, { 1, 'X' }, { 'R', atX(tile(LG.c3)) }, { pause, '-' } }
  if standC then append(s, { { 1, 'X' } }) end
  append(s, { { 'R', atX(440) } })
  for _ = 1, doorCasts do append(s, { { 1, 'X' }, { 2, '-' } }) end
  return append(s, { { 'R', atX(LG.G3 * T) }, { 100, 'R' } })
end

local function letgoMash()
  local s = { { 'L', atXLeft(LG.foot1) }, { 20, '-' } }
  for _ = 1, 14 do append(s, { { 1, 'RX' }, { 29, 'R' } }) end
  return append(s, { { 'R', atX(tile(30)) }, { 200, 'R' } })
end

-- The Last Light ------------------------------------------------------------------------------------------------
-- Room 1 Toll Gate: a standing ghost on plate a holds the gate mid-pit while the ferry carries you through.
-- Rooms 2 and 3 are Hall of Mirrors again with the finale's letters: Which Shrine, then Twice Mirrored.
-- Room 4 The Last Light: one memory, two ghosts. Idle at the pedestal's foot, walk away to plate d and cast there on
-- arrival (that ghost ends on d), walk back, hop up and cast at the shrine: the same memory mirrored is the ferry,
-- which docks on pad c. Ride, then run the far shore to doors D and C before the ghost on d fades.
local LAST = {
  { name = 'standA', unit = 'frames', nominal = 120, min = 0, max = 300, step = 10 },
  { name = 'idle1', unit = 'frames', nominal = 90, min = 0, max = 300, step = 10 },
  { name = 'turnX1', unit = 'px', nominal = 104, min = 30, max = 150, step = 2 },
  { name = 'hopHold1', unit = 'frames', nominal = 6, min = 1, max = 40, step = 1 },
  { name = 'castDelay1', unit = 'frames', nominal = 10, min = 0, max = 150, step = 2 },
  { name = 'stepDelay1', unit = 'frames', nominal = 20, min = 0, max = 200, step = 2 },
  { name = 'stepHold1', unit = 'frames', nominal = 3, min = 0, max = 30, step = 1, need = 6, note = 'a tap; the echo is 10 px wide' },
  { name = 'standX1', unit = 'px', nominal = 580, min = 534, max = 624, step = 2 },
  { name = 'stand2', unit = 'frames', nominal = 100, min = 0, max = 300, step = 10 },
  { name = 'castDelay2', unit = 'frames', nominal = 10, min = 0, max = 200, step = 10 },
  { name = 'standX2', unit = 'px', nominal = 778, min = 734, max = 824, step = 2 },
  { name = 'stand3', unit = 'frames', nominal = 100, min = 0, max = 300, step = 10 },
  { name = 'castDelay3', unit = 'frames', nominal = 10, min = 0, max = 200, step = 10 },
  { name = 'castDelay4', unit = 'frames', nominal = 10, min = 0, max = 200, step = 10 },
  { name = 'idle4', unit = 'frames', nominal = 120, min = 0, max = 300, step = 10 },
  { name = 'holdD', unit = 'frames', nominal = 6, min = 0, max = 100, step = 2 },
  { name = 'hopHold4', unit = 'frames', nominal = 6, min = 1, max = 40, step = 1 },
  { name = 'castDelay5', unit = 'frames', nominal = 6, min = 0, max = 100, step = 2 },
  { name = 'stepDelay5', unit = 'frames', nominal = 10, min = 0, max = 150, step = 2 },
  { name = 'stepHold5', unit = 'frames', nominal = 3, min = 0, max = 30, step = 1, need = 6, note = 'a tap; the echo is 10 px wide' },
}
-- Pixel landmarks: the foot is where the pedestal wall stops you; the hop lands on the shelf before it.
local LL = { a1 = 5, foot1 = 166, hop1 = 130, shelf1 = { 134, 208 }, cast1 = 190, w1 = 23,
  M1b = 39, roof2 = 40, w2 = 46, drop3 = 46, M3 = 52, M4 = 53, roof3 = 54, w3 = 60, drop4 = 61,
  d4 = 1112, foot4 = 1174, hop4 = 1138, shelf4 = { 1142, 1216 }, cast4 = 1198, G = 99 }

local function lastFerry(p, k)
  local shelf = LL['shelf' .. k]
  return {
    { 'L', atXLeft(p['turnX' .. k]) }, { 'R', atX(LL['hop' .. k]) }, { p['hopHold' .. k], 'RJ' },
    { 'R', onTop(13 * T, shelf[1], shelf[2]) }, { 'R', atX(LL['cast' .. k]) },
    { p['castDelay' .. k], '-' }, { 1, 'X' },
    { p['stepDelay' .. k], '-' }, { 'R', onLastEcho }, { p['stepHold' .. k], 'R' }, { '-', echoArrived },
  }
end

local function lastRoom1(p)
  return append(append({
    { 'R', atX(tile(LL.a1)) }, { p.standA, '-' }, { 1, 'X' }, { 'R', atX(LL.foot1) }, { p.idle1, '-' },
  }, lastFerry(p, 1)), { { 'R', atX(tile(LL.w1)) } })
end

local function lastRoom2(p)
  return {
    { 'R', atX(388) }, { 'RJ', onTop(14 * T, 28 * T) }, { 'R', atX(p.standX1) }, { p.stand2, '-' },
    { 'R', atX(LL.M1b * T + 2) }, { p.castDelay2, '-' }, { 1, 'X' },
    { 'RJ', onTop(11 * T, LL.roof2 * T) }, { 'R', atX(tile(LL.w2)) },
  }
end

local function lastRoom3(p)
  return {
    { 'R', atX(LL.drop3 * T + 6) }, { '-', grounded }, { 'R', atX(p.standX2) }, { p.stand3, '-' },
    { 'R', atX(LL.M3 * T + 2) }, { p.castDelay3, '-' }, { 1, 'X' },
    { 'R', atX(LL.M4 * T + 2) }, { p.castDelay4, '-' }, { 1, 'X' },
    { 'RJ', onTop(11 * T, LL.roof3 * T) }, { 'R', atX(tile(LL.w3)) },
  }
end

-- The walk away from the foot stops on plate d, where the plain cast happens; the ferry recipe then resumes.
local function ferry4(p)
  return { turnX4 = LL.d4, hopHold4 = p.hopHold4, castDelay4 = p.castDelay5, stepDelay4 = p.stepDelay5, stepHold4 = p.stepHold5 }
end

local function lastRoom4(p)
  local ferry = lastFerry(ferry4(p), 4)
  local rest = {}
  for i = 2, #ferry do rest[#rest + 1] = ferry[i] end
  return append(append({
    { 'R', atX(LL.drop4 * T + 6) }, { '-', grounded }, { 'R', atX(LL.foot4) }, { p.idle4, '-' },
    ferry[1], { p.holdD, '-' }, { 1, 'X' },
  }, rest), { { 'R', atX(LL.G * T) } })
end

local strategies = {
  ['Let Go'] = {
    params = LETGO,
    build = function(p) return append(append(letgoRoom1(p), letgoRoom2(p)), letgoRoom3(p)) end,
  },
  ['The Last Light'] = {
    params = LAST,
    build = function(p) return append(append(append(lastRoom1(p), lastRoom2(p)), lastRoom3(p)), lastRoom4(p)) end,
  },
  ['Three Steps Behind'] = {
    params = STEPS,
    build = function(p) return append(append(stepsRoom1(p), stepsRoom2(p)), stepsRoom3(p)) end,
  },
  ['Hall of Mirrors'] = {
    params = HALL,
    build = function(p) return append(hallRoom1(p), hallRoom2(p)) end,
  },
  ['Clockwork'] = {
    params = CLOCKWORK,
    build = function(p) return append(append(clockworkRoom1(p), clockworkRoom2(p)), clockworkRoom3(p)) end,
  },
}

local function nominal(name, overrides) return S.decisions(strategies[name], overrides) end

local rooms = {
  ['Let Go'] = {
    {
      name = 'Let Go',
      insight = 'the third cast takes the oldest ghost with it, so two casts from inside the gate shut the floor behind the ghost that opened it',
      exit = { LG.shaft1, 3, LG.shaft1 + 1, 8 },
      solve = letgoRoom1(nominal('Let Go')),
      naive = {
        { 'no ghost at all: the gate is shut and the stone before it gives way', { { 'R', atX(tile(23)) }, { 200, 'R' } } },
        { 'a ghost on a, then straight through: the floor is still open', {
          { 'L', atXLeft(LG.foot1) }, { 100, '-' }, { 1, 'X' }, { 'R', atX(tile(30)) }, { 100, 'R' } } },
        { 'one cast in the doorway: two ghosts, the plate still held', {
          { 'L', atXLeft(LG.foot1) }, { 100, '-' }, { 1, 'X' }, { 'R', atX(392) }, { 1, 'X' }, { 'R', atX(tile(30)) }, { 100, 'R' } } },
        { 'two casts before the doorway: the gate shuts in your face', append(append({
          { 'L', atXLeft(LG.foot1) }, { 100, '-' }, { 1, 'X' }, { 'R', atX(300) } }, kill()), { { 'R', atX(tile(30)) }, { 200, 'R' } }) },
        { 'stand in the doorway and wait for the ghost to fade: the stone under you goes first', {
          { 'L', atXLeft(LG.foot1) }, { 100, '-' }, { 1, 'X' }, { 'R', atX(392) }, { 300, '-' }, { 'R', atX(tile(30)) }, { 100, 'R' } } },
        { 'passing press: step on a and off, cast, run and hold into the gate', {
          { 'L', atXLeft(LG.foot1) }, { 'R', atX(40) }, { 1, 'X' }, { 'R', atX(tile(30)) }, { 300, 'R' } } },
        { 'mash a cast every half second from a to the gate', letgoMash() },
        { 'jump the open floor instead of shutting it', {
          { 'L', atXLeft(LG.foot1) }, { 100, '-' }, { 1, 'X' }, { 'R', atX(25 * T + 4) }, { 40, 'RJ' }, { 'R', atX(tile(LG.shaft1)) }, { 100, 'R' } } },
        { 'two standing ghosts on a, then run: both hold the plate', {
          { 'L', atXLeft(LG.foot1) }, { 190, '-' }, { 1, 'X' }, { 190, '-' }, { 1, 'X' }, { 'R', atX(tile(30)) }, { 100, 'R' } } },
      },
    },
    {
      name = 'Oldest First',
      insight = "the kill takes the oldest ghost, so the one that must die is cast first and the keeper second, though the keeper's plate is nearer",
      from = 1,
      exit = { LG.past2 - 1, 9, LG.past2, 14 },
      solve = letgoRoom2(nominal('Let Go')),
      naive = {
        { 'the near plate first: the kill takes the ghost on b and the floor stays open', letgoRoom2Naive('ba', 1, 100, 40) },
        { 'two casts in the doorway as in room 1: the second takes the ghost on b', letgoRoom2Naive('ab', 2, 100, 40) },
        { 'a ghost on a only: the kill works but B never opens', letgoRoom2Naive('a', 1, 100, 0) },
        { 'a ghost on b only: the gate never opens', letgoRoom2Naive('b', 1, 0, 40) },
        { 'stand three seconds on both: the ghost on a fades before you reach the gate', letgoRoom2Naive('ab', 1, 190, 190) },
        { 'jump the open floor instead of shutting it', {
          { 'R', atX(tile(LG.a2)) }, { 100, '-' }, { 1, 'X' }, { 'L', atXLeft(tile(LG.b2)) }, { 40, '-' }, { 1, 'X' },
          { 'L', atXLeft(14 * T + 2) }, { 40, 'LJ' }, { 'L', atXLeft(tile(7)) }, { 200, 'L' } } },
        { 'cast on the move past b: its quarter-second press comes while you are still on the bridge', {
          { 'R', atX(tile(LG.a2)) }, { 100, '-' }, { 1, 'X' }, { 'L', atXLeft(tile(33)) }, { 1, 'LX' }, { 'L', atXLeft(244) }, { 1, 'X' },
          { 'L', atXLeft(tile(7)) }, { 300, 'L' } } },
      },
    },
    {
      name = 'Borrowed Time',
      insight = 'the kill casts are ghosts too: pause on c so they hold C when you arrive, but no longer than the ghost on a can spare',
      from = 2,
      solve = letgoRoom3(nominal('Let Go')),
      naive = {
        { 'run over c without pausing: C opens after the stone before it has gone', letgoRoom3Naive(190, 0, 2) },
        { 'a short pause on c: C opens after you have fallen', letgoRoom3Naive(190, 30, 2) },
        { 'jump the open floor instead of shutting it', {
          { 'L', atXLeft(LG.foot1) }, { 190, '-' }, { 1, 'X' }, { 'R', atX(tile(LG.c3)) }, { 90, '-' }, { 'R', atX(28 * T + 4) }, { 40, 'RJ' },
          { 'R', atX(LG.G3 * T) }, { 200, 'R' } } },
        { 'pause on c but one cast in the doorway: the floor stays open', letgoRoom3Naive(190, 90, 1) },
        { 'stand three seconds on c and cast there: the ghost on a fades before the gate', letgoRoom3Naive(190, 190, 1, true) },
        { 'a long stand on a cannot stretch its ghost past seven seconds', letgoRoom3Naive(400, 190, 1, true) },
        { 'two casts before the doorway', append(append({
          { 'L', atXLeft(LG.foot1) }, { 190, '-' }, { 1, 'X' }, { 'R', atX(tile(LG.c3)) }, { 90, '-' }, { 'R', atX(380) } }, kill()),
          { { 'R', atX(LG.G3 * T) }, { 200, 'R' } }) },
        { 'passing press on a: step on it and off, cast, pause on c, run and hold into the gate', append(append({
          { 'L', atXLeft(LG.foot1) }, { 'R', atX(40) }, { 1, 'X' }, { 'R', atX(tile(LG.c3)) }, { 90, '-' }, { 'R', atX(440) } }, kill()),
          { { 'R', atX(LG.G3 * T) }, { 300, 'R' } }) },
      },
    },
  },
  ['Clockwork'] = {
    {
      name = 'Overlap',
      insight = 'a ghost cast on arrival opens its door three seconds later, so the second ghost is cast on the move',
      exit = { CW.w1 - 1, 5, CW.w1 + 1, 9 },
      solve = clockworkRoom1(nominal('Clockwork')),
      naive = {
        { 'stand three seconds on both plates', clockworkRoom1(nominal('Clockwork', { holdB1 = 190 })) },
        { 'no echo at all', { { 'R', atX(tile(CW.w1)) } } },
        { 'cast on the move past both plates', {
          { 'R', atX(tile(CW.a1)) }, { 1, 'X' }, { 'R', atX(tile(CW.b1)) }, { 1, 'X' }, { 'R', atX(tile(CW.w1)) },
        } },
      },
    },
    {
      name = 'One Ghost',
      insight = 'three plates and two ghosts: one ghost presses a, walks, and presses b, so stand on a and cast on arriving at b',
      from = 1,
      exit = { CW.w2, 5, CW.w2 + 1, 9 },
      solve = clockworkRoom2(nominal('Clockwork')),
      naive = {
        { 'a ghost standing on each plate: the third cast drops the one on c', {
          { 'R', atX(tile(CW.c2)) }, { 190, '-' }, { 1, 'X' },
          { 'R', atX(tile(CW.a2)) }, { 190, '-' }, { 1, 'X' },
          { 'R', atX(tile(CW.b2)) }, { 190, '-' }, { 1, 'X' },
          { 'R', atX(tile(CW.wait2)) }, { 'R', atX(tile(CW.w2)) },
        } },
        { 'skip c: a ghost for a then b, and C stays shut', {
          { 'R', atX(tile(CW.a2)) }, { 90, '-' },
          { 'R', atX(tile(CW.b2)) }, { 10, '-' }, { 1, 'X' },
          { 'R', atX(tile(CW.wait2)) }, { 'R', atX(tile(CW.w2)) },
        } },
        { 'cast on the move past a and b, then wait at the door on the bridge', {
          { 'R', atX(tile(CW.c2)) }, { 190, '-' }, { 1, 'X' },
          { 'R', atX(tile(CW.b2)) }, { 1, 'X' },
          { 'R', atX(tile(CW.wait2)) }, { 'R', atX(tile(CW.w2)) },
        } },
      },
    },
    {
      name = 'Double Cast',
      insight = 'one memory cast twice, plain on a and mirrored at the shrine, presses a and the sealed plate c at once',
      from = 2,
      solve = clockworkRoom3(nominal('Clockwork')),
      naive = {
        { 'one plain cast on a: C never opens', {
          { 'R', atX(tile(CW.a3 - 1)) }, { '-', grounded }, { 100, '-' }, { 1, 'X' },
          { 'RJ', onTop(10 * T, CW.roof3 * T) }, { 'R', atX(CW.G3 * T) },
        } },
        { 'one mirrored cast at the shrine after standing on a: A never opens', {
          { 'R', atX(tile(CW.a3 - 1)) }, { '-', grounded }, { 100, '-' }, { 'R', atX(CW.M3 * T + 2) }, { 10, '-' }, { 1, 'X' },
          { 'RJ', onTop(10 * T, CW.roof3 * T) }, { 'R', atX(CW.G3 * T) },
        } },
        { 'two casts on the move without standing on a', {
          { 'R', atX(tile(CW.a3 - 1)) }, { 1, 'X' }, { 'R', atX(CW.M3 * T + 2) }, { 10, '-' }, { 1, 'X' },
          { 'RJ', onTop(10 * T, CW.roof3 * T) }, { 'R', atX(CW.G3 * T) },
        } },
        { 'a ghost on a, then a plain cast at the shrine foot instead of a mirrored one', {
          { 'R', atX(tile(CW.a3 - 1)) }, { '-', grounded }, { 100, '-' }, { 1, 'X' }, { 'R', atX((CW.M3 - 1) * T) }, { 10, '-' }, { 1, 'X' },
          { 'RJ', onTop(10 * T, CW.roof3 * T) }, { 'R', atX(CW.G3 * T) },
        } },
      },
    },
  },
  ['Hall of Mirrors'] = {
    {
      name = 'Which Shrine',
      insight = 'the plate reflects about the near shrine onto the far shrine, so stand on the far shrine and cast at the near one',
      exit = { HM.w1, 7, HM.w1 + 1, 9 },
      solve = hallRoom1(nominal('Hall of Mirrors')),
      naive = {
        { 'stand on the far shrine and cast there', {
          { 'R', atX(68) }, { 'RJ', onTop(13 * T, 8 * T) }, { 'R', atX(196) }, { 100, '-' }, { 1, 'X' },
          { 'R', atX(HM.M1 * T + 2) }, { 'RJ', onTop(10 * T, HM.roof1 * T) }, { 'R', atX(tile(HM.w1)) },
        } },
        { 'stand beside the near shrine and cast there', {
          { 'R', atX(68) }, { 'RJ', onTop(13 * T, 8 * T) }, { 'R', atX(tile(14)) }, { 100, '-' },
          { 'R', atX(HM.M1 * T + 2) }, { 10, '-' }, { 1, 'X' },
          { 'RJ', onTop(10 * T, HM.roof1 * T) }, { 'R', atX(tile(HM.w1)) },
        } },
        { 'run past both shrines and cast at the near one on the move', {
          { 'R', atX(68) }, { 'RJ', onTop(13 * T, 8 * T) }, { 'R', atX(HM.M1 * T + 2) }, { 1, 'X' },
          { 'RJ', onTop(10 * T, HM.roof1 * T) }, { 'R', atX(tile(HM.w1)) },
        } },
      },
    },
    {
      name = 'Twice Mirrored',
      insight = 'one stand reflects about two shrines onto two plates two shrine-spacings apart, so cast at both within the memory',
      from = 1,
      solve = hallRoom2(nominal('Hall of Mirrors')),
      naive = {
        { 'cast only at the first shrine', {
          { 'R', atX(372) }, { '-', grounded }, { 'R', atX(418) }, { 100, '-' },
          { 'R', atX(HM.M3 * T + 2) }, { 10, '-' }, { 1, 'X' },
          { 'RJ', onTop(10 * T, HM.roof2 * T) }, { 'R', atX(HM.G * T) },
        } },
        { 'stand where the first shrine reflects onto b, so the second reflects into the hall', {
          { 'R', atX(372) }, { '-', grounded }, { 'R', atX(434) }, { 100, '-' },
          { 'R', atX(HM.M3 * T + 2) }, { 10, '-' }, { 1, 'X' },
          { 'R', atX(HM.M4 * T + 2) }, { 10, '-' }, { 1, 'X' },
          { 'RJ', onTop(10 * T, HM.roof2 * T) }, { 'R', atX(HM.G * T) },
        } },
        { 'two casts on the move', {
          { 'R', atX(372) }, { '-', grounded }, { 'R', atX(HM.M3 * T + 2) }, { 1, 'X' },
          { 'R', atX(HM.M4 * T + 2) }, { 1, 'X' },
          { 'RJ', onTop(10 * T, HM.roof2 * T) }, { 'R', atX(HM.G * T) },
        } },
      },
    },
  },
  ['Three Steps Behind'] = {
    {
      name = 'Quarter Second',
      insight = 'run across the plate and cast from the hatch: the ghost crosses the plate three seconds after you and the hatch drops you',
      exit = { TS.w1 - 1, 7, TS.w1 + 1, 8 },
      solve = stepsRoom1(nominal('Three Steps Behind')),
      naive = {
        { 'stand on the hatch and wait', { { 'R', atX(tile(TS.A1)) }, { 300, '-' }, { 'R', atX(tile(TS.w1)) } } },
        { 'cast before crossing the plate', {
          { 'R', atX(tile(3)) }, { 1, 'X' }, { 'R', atX(tile(TS.A1)) }, { 300, '-' }, { 'R', atX(tile(TS.w1)) },
        } },
      },
    },
    {
      name = 'Three Steps',
      insight = 'the hatches below are farther apart than the plates above, so pause on b and c: the ghost holds each as long as you did',
      from = 1,
      exit = { TS.w2 - 1, 16, TS.w2 + 1, 17 },
      solve = stepsRoom2(nominal('Three Steps Behind')),
      naive = {
        { 'run the plates without pausing', stepsRoom2(nominal('Three Steps Behind', { pauseB = 0, pauseC = 0 })) },
        { 'stand three seconds on c', stepsRoom2(nominal('Three Steps Behind', { pauseB = 0, pauseC = 190 })) },
        { 'cast on arrival at c', {
          { 'R', atX(tile(TS.c2)) }, { 1, 'X' }, { 'R', atX(tile(TS.A2)) }, { '-', onTop(12 * T) },
          { 'R', atX(tile(TS.B2)) }, { 300, '-' }, { 'R', atX(tile(TS.C2)) }, { '-', onTop(18 * T) }, { 'R', atX(tile(TS.w2)) },
        } },
        { 'a standing ghost on each plate: the third cast drops the first', {
          { 'R', atX(tile(TS.a2)) }, { 190, '-' }, { 1, 'X' }, { 'R', atX(tile(TS.b2)) }, { 190, '-' }, { 1, 'X' },
          { 'R', atX(tile(TS.c2)) }, { 190, '-' }, { 1, 'X' }, { 'R', atX(tile(TS.A2)) }, { 300, '-' },
          { 'R', atX(tile(TS.w2)) },
        } },
      },
    },
    {
      name = 'Gallery',
      insight = 'the plates are sealed in a gallery, so a reflection runs them: pause at each mirror spot on the way, then cast on the hatch under the shrine',
      from = 2,
      solve = stepsRoom3(nominal('Three Steps Behind')),
      naive = {
        { 'run straight to the shrine and cast', stepsRoom3(nominal('Three Steps Behind', { pause1 = 0, pause2 = 0, pause3 = 0 })) },
        { 'one long pause at the first spot only', stepsRoom3(nominal('Three Steps Behind', { pause1 = 100, pause2 = 0, pause3 = 0 })) },
        { 'a plain cast on the hatch without touching the shrine', {
          { 'R', atX(TS.aSpot) }, { 20, '-' }, { 'R', atX(TS.bSpot) }, { 30, '-' }, { 'R', atX(TS.cSpot) }, { 30, '-' },
          { 'R', atX(tile(TS.M3) - 14) }, { 10, '-' }, { 1, 'X' }, { 'R', atX(tile(TS.M3)) }, { 300, '-' },
          { 'R', atX(TS.G * T) },
        } },
      },
    },
  },
  ['The Last Light'] = {
    {
      name = 'Toll Gate',
      insight = 'a standing ghost on the plate holds the gate while the ferry carries you through it onto the pad',
      exit = { LL.w1, 12, LL.w1 + 1, 13 },
      solve = lastRoom1(nominal('The Last Light')),
      naive = {
        { 'the ferry without a ghost on the plate: the gate scrapes you off', lastRoom1(nominal('The Last Light', { standA = 0 })) },
        { 'cast on the plate on arrival with a fresh memory: the gate shuts before the ride', {
          { 'R', atX(tile(LL.a1)) }, { 1, 'X' }, { 'R', atX(LL.foot1) }, { 90, '-' },
          unpack(append(lastFerry(nominal('The Last Light'), 1), { { 'R', atX(tile(LL.w1)) } })),
        } },
      },
    },
    {
      name = 'Which Shrine',
      insight = 'the plate reflects about the near shrine onto the far shrine, so stand on the far shrine and cast at the near one',
      from = 3,
      exit = { LL.w2, 8, LL.w2 + 1, 10 },
      solve = lastRoom2(nominal('The Last Light')),
      naive = {
        { 'stand on the far shrine and cast there', {
          { 'R', atX(388) }, { 'RJ', onTop(14 * T, 28 * T) }, { 'R', atX(580) }, { 100, '-' }, { 1, 'X' },
          { 'R', atX(LL.M1b * T + 2) }, { 'RJ', onTop(11 * T, LL.roof2 * T) }, { 'R', atX(tile(LL.w2)) },
        } },
        { 'run past both shrines and cast at the near one on the move', {
          { 'R', atX(388) }, { 'RJ', onTop(14 * T, 28 * T) }, { 'R', atX(LL.M1b * T + 2) }, { 1, 'X' },
          { 'RJ', onTop(11 * T, LL.roof2 * T) }, { 'R', atX(tile(LL.w2)) },
        } },
      },
    },
    {
      name = 'Twice Mirrored',
      insight = 'one stand reflects about two shrines onto two plates, so cast at both within the memory',
      from = 1,
      exit = { LL.w3, 8, LL.w3 + 1, 10 },
      solve = lastRoom3(nominal('The Last Light')),
      naive = {
        { 'cast only at the first shrine', {
          { 'R', atX(LL.drop3 * T + 6) }, { '-', grounded }, { 'R', atX(778) }, { 100, '-' },
          { 'R', atX(LL.M3 * T + 2) }, { 10, '-' }, { 1, 'X' },
          { 'RJ', onTop(11 * T, LL.roof3 * T) }, { 'R', atX(tile(LL.w3)) },
        } },
        { 'stand where only the second shrine reflects onto a plate', {
          { 'R', atX(LL.drop3 * T + 6) }, { '-', grounded }, { 'R', atX(810) }, { 100, '-' },
          { 'R', atX(LL.M3 * T + 2) }, { 10, '-' }, { 1, 'X' }, { 'R', atX(LL.M4 * T + 2) }, { 10, '-' }, { 1, 'X' },
          { 'RJ', onTop(11 * T, LL.roof3 * T) }, { 'R', atX(tile(LL.w3)) },
        } },
      },
    },
    {
      name = 'The Last Light',
      insight = 'the walk away from the foot ends on plate d: cast there on arrival, then cast the same memory mirrored from the shrine as the ferry',
      from = 2,
      solve = lastRoom4(nominal('The Last Light')),
      naive = {
        { 'stand three seconds on d before casting: the far doors shut before you reach them', lastRoom4(nominal('The Last Light', { holdD = 190 })) },
        { 'the ferry alone, no ghost on d', {
          { 'R', atX(LL.drop4 * T + 6) }, { '-', grounded }, { 'R', atX(LL.foot4) }, { 120, '-' },
          unpack(append(lastFerry(ferry4(nominal('The Last Light')), 4), { { 'R', atX(LL.G * T) } })),
        } },
        { 'a standing ghost on d first, then the ferry prepared from the foot', {
          { 'R', atX(LL.drop4 * T + 6) }, { '-', grounded }, { 'R', atX(tile(69)) }, { 190, '-' }, { 1, 'X' },
          { 'R', atX(LL.foot4) }, { 120, '-' },
          unpack(append(lastFerry(ferry4(nominal('The Last Light')), 4), { { 'R', atX(LL.G * T) } })),
        } },
      },
    },
  },
}

return { scripts = {}, strategies = strategies, rooms = rooms }
