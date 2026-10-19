local Player = require 'world.player'
local Echo = require 'world.echo'

local M = {}

local T = 16
local EPS = 0.001
local ECHO_LAND_TOL = 1.5
local floor = math.floor

M.T = T
M.DT = 1 / 60

M.LEGEND = {
  ['#'] = { kind = 'solid' },
  ['^'] = { kind = 'spike' },
  ['='] = { kind = 'oneway' },
  ['t'] = { kind = 'torch' },
  ['G'] = { kind = 'goal' },
  ['M'] = { kind = 'mirror' },
  ['~'] = { kind = 'veil' },
  ['%'] = { kind = 'crumble' },
  ['w'] = { kind = 'checkpoint' },
  ['*'] = { kind = 'ember' },
}
for i = 1, 4 do
  local plate, door = string.char(96 + i), string.char(64 + i)
  M.LEGEND[plate] = { kind = 'plate', id = plate, idx = i }
  M.LEGEND[door] = { kind = 'door', id = plate, idx = i }
end

M.CRACK, M.REGROW = 0.5, 3

-- draw functions are attached by gfx/render.lua so the simulation stays headless.
M.TILES = {
  solid = { solid = true, static = true },
  oneway = { oneway = true, static = true },
  spike = { hurts = true, static = true, rect = { 2, 8, T - 4, 8 }, worldList = 'spikes' },
  torch = { light = 64 },
  goal = { light = 78, goal = true },
  plate = { plate = true, rect = { 1, 12, T - 2, 4 }, worldList = 'plates' },
  door = { solid = true, openable = true },
  mirror = { light = 56, mirror = true, worldList = 'mirrors' },
  veil = { light = 30, veil = true, rect = { 0, 0, T, T }, worldList = 'veils' },
  crumble = { solid = true, crumble = true, worldList = 'crumbles' },
  checkpoint = { light = 44, checkpoint = true, rect = { 3, 0, T - 6, T }, worldList = 'checkpoints' },
  ember = { light = 40, ember = true, rect = { 3, 3, T - 6, T - 6 }, worldList = 'embers' },
}
local TILES = M.TILES

local WALL = { kind = 'solid' }
local World = {}
World.__index = World

local function overlaps(a, r)
  return a.x < r.x + r.w and a.x + a.w > r.x and a.y < r.y + r.h and a.y + a.h > r.y
end

-- opts.checkpoint = k starts the player on the k-th checkpoint (map order) with everything else fresh: no echoes,
-- an empty memory, doors shut, crumble stone intact. That is the whole respawn model, so a room is solvable from
-- its checkpoint exactly when it is solvable with nothing carried in.
function M.new(def, opts)
  local rows = def.map
  local width = 0
  for _, r in ipairs(rows) do width = math.max(width, #r) end
  local w = setmetatable({
    name = def.name, hint = def.hint,
    W = width, H = #rows, cells = {},
    plates = {}, spikes = {}, mirrors = {}, veils = {}, crumbles = {}, checkpoints = {}, embers = {},
    doorCells = {}, doorOpen = {}, lights = {},
    echoes = {}, rec = Echo.newRecorder(), events = {}, time = 0, castPrev = false,
  }, World)

  for ty = 0, #rows - 1 do
    local row = rows[ty + 1]
    w.cells[ty] = {}
    for tx = 0, width - 1 do
      local ch = row:sub(tx + 1, tx + 1)
      if ch == '' or ch == '.' or ch == ' ' then
        -- empty
      elseif ch == 'P' then
        w.spawn = { x = tx * T + (T - Player.W) / 2, y = (ty + 1) * T - Player.H }
      elseif M.LEGEND[ch] then
        local def = M.LEGEND[ch]
        local c = { kind = def.kind, id = def.id, idx = def.idx, tx = tx, ty = ty, ch = ch }
        w.cells[ty][tx] = c
        local tile = TILES[c.kind]
        if tile.rect then
          local r = tile.rect
          c.rect = { x = tx * T + r[1], y = ty * T + r[2], w = r[3], h = r[4] }
        end
        if tile.worldList then table.insert(w[tile.worldList], c) end
        if tile.openable then
          w.doorCells[c.id] = w.doorCells[c.id] or {}
          table.insert(w.doorCells[c.id], c)
          w.doorOpen[c.id] = false
        elseif tile.goal then
          w.goal = c
        end
        if tile.light then
          w.lights[#w.lights + 1] = { x = tx * T + T / 2, y = ty * T + T / 2, r = tile.light, kind = c.kind, cell = c }
        end
      else
        error(('level %q: unknown tile %q at %d,%d'):format(tostring(def.name), ch, tx + 1, ty + 1))
      end
    end
  end
  assert(w.spawn, 'level ' .. tostring(def.name) .. ' has no player start')
  local at = w.spawn
  if opts and opts.checkpoint then
    local c = w.checkpoints[opts.checkpoint]
    assert(c, ('level %q has no checkpoint %s'):format(tostring(def.name), tostring(opts.checkpoint)))
    w:activate(opts.checkpoint, true)
    at = M.standingOn(c)
  end
  w.player = Player.new(at.x, at.y)
  w:updateDoors(true)
  return w
end

-- Where a body stands when it spawns on a cell.
function M.standingOn(c)
  return { x = c.tx * T + (T - Player.W) / 2, y = (c.ty + 1) * T - Player.H }
end

-- The respawn point is the checkpoint touched last. Only that one is lit.
function World:activate(k, silent)
  for i, c in ipairs(self.checkpoints) do c.active = (i == k) end
  self.respawn = k
  local c = self.checkpoints[k]
  if not silent then self:emit('checkpoint', c.tx * T + T / 2, c.ty * T + T / 2) end
end

function World:touchCheckpoints()
  local p = self.player
  if not Player.isAlive(p) then return end
  for k, c in ipairs(self.checkpoints) do
    if not c.active and overlaps(p, c.rect) then return self:activate(k) end
  end
end

function World:emit(name, x, y, v)
  self.events[#self.events + 1] = { name = name, x = x, y = y, v = v }
end

function World:cell(tx, ty)
  if tx < 0 or tx >= self.W then return WALL end
  local row = self.cells[ty]
  return row and row[tx]
end

function World:solidCell(tx, ty)
  local c = self:cell(tx, ty)
  if not c then return false end
  local t = TILES[c.kind]
  return t.solid and not (t.openable and self.doorOpen[c.id]) and not c.gone
end

function World:hitsSolid(x, y, w, h)
  for ty = floor(y / T), floor((y + h - EPS) / T) do
    for tx = floor(x / T), floor((x + w - EPS) / T) do
      if self:solidCell(tx, ty) then return true end
    end
  end
  return false
end

function World:moveX(b, dx)
  b.x = b.x + dx
  if dx == 0 or not self:hitsSolid(b.x, b.y, b.w, b.h) then return false end
  if dx > 0 then
    b.x = floor((b.x + b.w - EPS) / T) * T - b.w
  else
    b.x = (floor(b.x / T) + 1) * T
  end
  return true
end

-- One-way surfaces (tiles and solid echoes) only catch a body that was above them last step.
function World:supportTop(b, oldBottom)
  local bottom = b.y + b.h
  local best, support
  local row = floor(bottom / T)
  for tx = floor(b.x / T), floor((b.x + b.w - EPS) / T) do
    local c = self:cell(tx, row)
    if c and TILES[c.kind].oneway and oldBottom <= row * T + EPS and bottom > row * T then
      best, support = row * T, true
    end
  end
  for _, e in ipairs(self.echoes) do
    if e:isSolid() and b.x < e.x + e.w and b.x + b.w > e.x
        and oldBottom <= e.y + ECHO_LAND_TOL and bottom > e.y
        and (not best or e.y < best) then
      best, support = e.y, e
    end
  end
  return best, support
end

-- Returns the landing support (true for tiles, the echo otherwise) or nil.
function World:moveY(b, dy)
  local oldBottom = b.y + b.h
  b.y = b.y + dy
  local support
  if dy ~= 0 and self:hitsSolid(b.x, b.y, b.w, b.h) then
    if dy > 0 then
      b.y = floor((b.y + b.h - EPS) / T) * T - b.h
      support = true
    else
      b.y = (floor(b.y / T) + 1) * T
    end
    b.vy = 0
  end
  if dy >= 0 and not support then
    local top, s = self:supportTop(b, oldBottom)
    if top then
      b.y = top - b.h
      b.vy = 0
      support = s
    end
  end
  return support
end

function World:bodies()
  local list = {}
  if Player.isAlive(self.player) then list[1] = self.player end
  for _, e in ipairs(self.echoes) do
    if e:isSolid() then list[#list + 1] = e end
  end
  return list
end

local function touchesCell(b, c)
  return floor(b.x / T) <= c.tx and floor((b.x + b.w - EPS) / T) >= c.tx
    and floor(b.y / T) <= c.ty and floor((b.y + b.h - EPS) / T) >= c.ty
end

local function standsOn(b, c)
  return math.abs(b.y + b.h - c.ty * T) <= 1 and b.x < (c.tx + 1) * T and b.x + b.w > c.tx * T
end

-- Door state is a pure function of who stands where, so there is nothing to toggle or desync.
function World:updateDoors(silent)
  local bodies = self:bodies()
  local pressedBy = {}
  for _, p in ipairs(self.plates) do
    local pressed = false
    for _, b in ipairs(bodies) do
      if overlaps(b, p.rect) then pressed = true break end
    end
    if pressed ~= (p.pressed or false) and not silent then
      self:emit('plate', p.tx * T + T / 2, p.ty * T + T, pressed)
    end
    p.pressed = pressed
    if pressed then pressedBy[p.id] = true end
  end
  local player = Player.isAlive(self.player) and self.player
  for id, cells in pairs(self.doorCells) do
    local open = pressedBy[id] or false
    if not open and player then
      for _, c in ipairs(cells) do
        if touchesCell(player, c) then open = true break end
      end
    end
    if open ~= self.doorOpen[id] and not silent then
      self:emit('door', cells[1].tx * T + T / 2, cells[1].ty * T + T / 2, open)
    end
    self.doorOpen[id] = open
  end
end

function World:touchedMirror()
  for _, m in ipairs(self.mirrors) do
    if touchesCell(self.player, m) then return m end
  end
end

function World:cast()
  local snap = Echo.snapshot(self.rec)
  if #snap < 2 then return end
  if #self.echoes >= Echo.MAX then table.remove(self.echoes, 1) end
  local mirror = self:touchedMirror()
  if mirror then Echo.mirror(snap, mirror.tx * T + T / 2) end
  self.echoes[#self.echoes + 1] = Echo.new(snap, mirror ~= nil)
  local p = self.player
  self:emit('cast', p.x + p.w / 2, p.y + p.h / 2, mirror ~= nil)
end

function World:inVeil(x, y, w, h)
  for _, v in ipairs(self.veils) do
    local r = v.rect
    if x < r.x + r.w and x + w > r.x and y < r.y + r.h and y + h > r.y then return true end
  end
  return false
end

function World:updateCrumbles(dt)
  local bodies = self:bodies()
  for _, c in ipairs(self.crumbles) do
    local top = c.ty * T
    if c.gone then
      c.regrow = c.regrow - dt
      local blocked = false
      for _, b in ipairs(bodies) do
        if touchesCell(b, c) then blocked = true break end
      end
      if c.regrow <= 0 and not blocked then
        c.gone = false
        self:emit('crumble', c.tx * T + T / 2, top + T / 2, false)
      end
    elseif c.crack then
      c.crack = c.crack - dt
      if c.crack <= 0 then
        c.crack, c.gone, c.regrow = nil, true, M.REGROW
        self:emit('crumble', c.tx * T + T / 2, top + T / 2, true)
      end
    else
      for _, b in ipairs(bodies) do
        if standsOn(b, c) then
          c.crack = M.CRACK
          break
        end
      end
    end
  end
end

-- An ember is taken by anything that carries light through it: you, or one of your echoes.
function World:touchEmbers()
  for _, c in ipairs(self.embers) do
    if not c.taken then
      for _, b in ipairs(self:bodies()) do
        if overlaps(b, c.rect) then
          c.taken = true
          self:emit('ember', c.tx * T + T / 2, c.ty * T + T / 2, b ~= self.player)
          break
        end
      end
    end
  end
end

function World:emberTaken()
  for _, c in ipairs(self.embers) do
    if c.taken then return true end
  end
  return false
end

function World:checkHazards()
  local p = self.player
  if not Player.isAlive(p) then return end
  if p.y > self.H * T + 24 then return Player.kill(p, self) end
  for _, s in ipairs(self.spikes) do
    if overlaps(p, s.rect) then return Player.kill(p, self) end
  end
  if self.goal and overlaps(p, { x = self.goal.tx * T + 3, y = self.goal.ty * T, w = T - 6, h = T }) then
    Player.clear(p, self)
  end
end

-- Everything a step can change, captured so the world can be put back exactly. Tiles, lights and the map are
-- fixed at load; echo frames and recorded frames are never mutated, so they are shared rather than copied.
function World:save()
  local p = {}
  for k, v in pairs(self.player) do p[k] = v end
  local echoes, supportAt = {}, nil
  for i, e in ipairs(self.echoes) do
    echoes[i] = e:copy()
    if self.player.support == e then supportAt = i end
  end
  local crumbles = {}
  for i, c in ipairs(self.crumbles) do crumbles[i] = { c.crack, c.gone, c.regrow } end
  local plates = {}
  for i, c in ipairs(self.plates) do plates[i] = c.pressed end
  local embers = {}
  for i, c in ipairs(self.embers) do embers[i] = c.taken end
  local doors = {}
  for id, open in pairs(self.doorOpen) do doors[id] = open end
  return {
    player = p, supportAt = supportAt, echoes = echoes, rec = Echo.copyRecorder(self.rec),
    crumbles = crumbles, plates = plates, embers = embers, doors = doors,
    respawn = self.respawn, time = self.time, castPrev = self.castPrev,
  }
end

function World:load(s)
  local p = self.player
  for k in pairs(p) do p[k] = nil end
  for k, v in pairs(s.player) do p[k] = v end
  self.echoes = {}
  for i, e in ipairs(s.echoes) do self.echoes[i] = e:copy() end
  if s.supportAt then
    p.support = self.echoes[s.supportAt]
  elseif p.support ~= true then
    p.support = nil
  end
  self.rec = Echo.copyRecorder(s.rec)
  for i, c in ipairs(self.crumbles) do c.crack, c.gone, c.regrow = s.crumbles[i][1], s.crumbles[i][2], s.crumbles[i][3] end
  for i, c in ipairs(self.plates) do c.pressed = s.plates[i] end
  for i, c in ipairs(self.embers) do c.taken = s.embers[i] end
  for id, open in pairs(s.doors) do self.doorOpen[id] = open end
  for i, c in ipairs(self.checkpoints) do c.active = (i == s.respawn) end
  self.respawn, self.time, self.castPrev = s.respawn, s.time, s.castPrev
  self.events = {}
end

function M.step(w, input, dt)
  dt = dt or M.DT
  w.events = {}
  w.time = w.time + dt

  local inVeil = function(x, y, ew, eh) return w:inVeil(x, y, ew, eh) end
  for i = #w.echoes, 1, -1 do
    local e = w.echoes[i]
    e:update(dt, inVeil)
    if not e:isAlive() then table.remove(w.echoes, i) end
  end
  w:updateCrumbles(dt)
  w:updateDoors()

  local p = w.player
  Player.update(p, w, input, dt)
  if Player.isAlive(p) then
    Echo.record(w.rec, p.x, p.y, p.facing, p.state)
    if input.cast and not w.castPrev then w:cast() end
  end
  w.castPrev = input.cast or false

  w:checkHazards()
  w:touchEmbers()
  w:touchCheckpoints()
  w:updateDoors()
end

return M
