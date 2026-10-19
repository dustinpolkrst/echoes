-- Optional art and sound overrides. Drop files into assets/sprites and assets/sfx, named after a slot
-- below; any slot without a file keeps the procedural drawing or generated sound.
local A = {}

-- mode: 'anim' cycles frames at fps, 'variant' picks a frame per tile by hash, 'state' is chosen by the caller.
-- anchor: 'foot' puts the sprite origin at bottom-centre, 'tile' at the top-left corner.
-- par/vpar/valign (backgrounds): horizontal and vertical parallax factors, and which edge the image hangs from.
A.SLOTS = {
  player  = { kind = 'sprite', size = { 16, 16 }, fps = 8, anchor = 'foot', note = 'faces right; flipped when facing left' },
  echo    = { kind = 'sprite', size = { 16, 16 }, fps = 8, anchor = 'foot', note = 'tinted cyan (violet when mirrored) and faded by the game' },
  solid   = { kind = 'sprite', size = { 16, 16 }, mode = 'variant', anchor = 'tile', note = 'strip of variants, one picked per cell' },
  oneway  = { kind = 'sprite', size = { 16, 16 }, mode = 'variant', anchor = 'tile', note = 'draw the platform in the top 5 rows' },
  spike   = { kind = 'sprite', size = { 16, 16 }, fps = 6, anchor = 'tile' },
  plate   = { kind = 'sprite', size = { 16, 16 }, mode = 'state', anchor = 'tile', note = 'frame 1 idle, frame 2 pressed; multiplied by the plate colour' },
  door    = { kind = 'sprite', size = { 16, 16 }, fps = 6, anchor = 'tile', note = 'one cell, stacked down the door and cropped as it opens; multiplied by the plate colour' },
  goal    = { kind = 'sprite', size = { 16, 16 }, fps = 8, anchor = 'tile' },
  torch   = { kind = 'sprite', size = { 16, 16 }, fps = 8, anchor = 'tile', note = 'replaces the chain and the flame' },
  mirror  = { kind = 'sprite', size = { 16, 16 }, fps = 8, anchor = 'tile', note = 'the shrine; the procedural one overhangs the cell above' },
  veil    = { kind = 'sprite', size = { 16, 16 }, fps = 8, anchor = 'tile', note = 'drawn with alpha over the background; echoes halt at it' },
  crumble = { kind = 'sprite', size = { 16, 16 }, mode = 'state', anchor = 'tile', note = 'frame 1 intact, frame 2 cracking, frame 3 gone' },
  checkpoint = { kind = 'sprite', size = { 16, 16 }, mode = 'state', anchor = 'tile', note = 'the waystone; frame 1 unlit, frame 2 lit (the respawn point)' },
  ember   = { kind = 'sprite', size = { 16, 16 }, fps = 8, anchor = 'tile', note = 'the optional spark; hidden once taken' },
  bg_far  = { kind = 'sprite', size = { 480, 270 }, fps = 4, par = 0.05, vpar = 0, valign = 'top', note = 'replaces the sky gradient' },
  bg_mid  = { kind = 'sprite', size = { 480, 270 }, fps = 4, par = 0.12, vpar = 0.08, valign = 'bottom', note = 'replaces the arches' },
  bg_near = { kind = 'sprite', size = { 480, 270 }, fps = 4, par = 0.35, vpar = 0.35, valign = 'top', note = 'replaces the hanging vines' },
}

-- Sounds are keyed apart from sprites because plate, door and goal exist in both.
A.SOUNDS = {
  jump  = { kind = 'sound' },
  land  = { kind = 'sound', note = 'played at varying pitch' },
  cast  = { kind = 'sound' },
  plate = { kind = 'sound', note = 'played at two pitches for press and release' },
  door  = { kind = 'sound', note = 'played at two pitches for open and close' },
  death = { kind = 'sound' },
  goal  = { kind = 'sound' },
  crumble = { kind = 'sound', note = 'played at two pitches for collapse and regrowth' },
  checkpoint = { kind = 'sound', note = 'a waystone lights' },
  ember = { kind = 'sound', note = 'an ember is taken; pitch 1.0 by you, 1.25 by an echo' },
  rewind = { kind = 'sound', note = 'a tick while rewinding, every few steps' },
}

A.version = 0
local sprites, sounds = {}, {}
local SOUND_EXT = { 'ogg', 'wav', 'mp3' }

local function exists(path)
  return love.filesystem.getInfo(path, 'file') ~= nil
end

local function loadSprite(name, slot)
  local path = 'assets/sprites/' .. name .. '.png'
  if not exists(path) then return end
  local okImg, img = pcall(love.graphics.newImage, path)
  if not okImg then
    print(('assets: cannot load %s: %s'):format(path, img))
    return
  end
  img:setFilter('nearest', 'nearest')

  local cfg = {}
  local cfgPath = 'assets/sprites/' .. name .. '.lua'
  if exists(cfgPath) then
    local okCfg, chunk = pcall(love.filesystem.load, cfgPath)
    local okRun, res = false, nil
    if okCfg and chunk then okRun, res = pcall(chunk) end
    if okRun and type(res) == 'table' then cfg = res else print('assets: bad config ' .. cfgPath) end
  end

  local iw, ih = img:getDimensions()
  local fh = cfg.frameH or ih
  local fw = cfg.frameW or ((iw % ih == 0) and ih or iw)
  local cols, rows = math.max(1, math.floor(iw / fw)), math.max(1, math.floor(ih / fh))
  local quads = {}
  for r = 0, rows - 1 do
    for c = 0, cols - 1 do
      quads[#quads + 1] = love.graphics.newQuad(c * fw, r * fh, fw, fh, iw, ih)
    end
  end

  local ox, oy = 0, 0
  if slot.anchor == 'foot' then ox, oy = fw / 2, fh end
  sprites[name] = {
    image = img, quads = quads, w = fw, h = fh, iw = iw, ih = ih,
    fps = cfg.fps or slot.fps or 0, mode = slot.mode or 'anim',
    ox = cfg.ox or ox, oy = cfg.oy or oy,
    par = slot.par, vpar = slot.vpar, valign = slot.valign,
  }
end

local function loadSound(name)
  for _, ext in ipairs(SOUND_EXT) do
    local path = 'assets/sfx/' .. name .. '.' .. ext
    if exists(path) then
      local ok, src = pcall(love.audio.newSource, path, 'static')
      if ok then
        sounds[name] = src
        return
      end
      print(('assets: cannot load %s: %s'):format(path, src))
    end
  end
end

local function warnUnknown(dir, known, exts)
  for _, f in ipairs(love.filesystem.getDirectoryItems(dir)) do
    local base, ext = f:match('^(.+)%.(%w+)$')
    if base and exts[ext:lower()] and not known[base] then
      print(('assets: %s/%s matches no slot'):format(dir, f))
    end
  end
end

-- Safe to call again: rescans everything and bumps A.version so renderers and Sfx refresh lazily.
function A.load()
  sprites, sounds = {}, {}
  if love.graphics then
    for name, slot in pairs(A.SLOTS) do
      if slot.kind == 'sprite' then loadSprite(name, slot) end
    end
    local known = {}
    for name, slot in pairs(A.SLOTS) do if slot.kind == 'sprite' then known[name] = true end end
    warnUnknown('assets/sprites', known, { png = true })
  end
  if love.audio then
    local known = {}
    for name in pairs(A.SOUNDS) do
      loadSound(name)
      known[name] = true
    end
    warnUnknown('assets/sfx', known, { ogg = true, wav = true, mp3 = true })
  end
  A.version = A.version + 1
end
A.reload = A.load

-- nil when the slot has no file; the caller then falls back to its procedural version.
function A.sprite(name)
  return sprites[name]
end

function A.sound(name)
  return sounds[name]
end

return A
