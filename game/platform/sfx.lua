local Assets = require 'platform.assets'

local M = {}

local RATE = 22050
local generated = {}
local sources = {}
local seenVersion = -1
M.volume = 0.7

local function clamp(v) return math.max(-1, math.min(1, v)) end

local function build(duration, fn)
  local n = math.floor(duration * RATE)
  local data = love.sound.newSoundData(n, RATE, 16, 1)
  for i = 0, n - 1 do
    data:setSample(i, clamp(fn(i / RATE, duration)))
  end
  return love.audio.newSource(data, 'static')
end

local function env(t, d, power)
  return math.max(0, 1 - t / d) ^ (power or 1)
end

local function lowpassNoise(k)
  local y = 0
  return function()
    y = y + k * ((love.math.random() * 2 - 1) - y)
    return y
  end
end

-- Phase accumulation keeps frequency sweeps click-free.
local function sweep(f0, f1)
  local phase = 0
  return function(t, d)
    local f = f0 + (f1 - f0) * (t / d)
    phase = phase + f / RATE
    return phase * 2 * math.pi
  end
end

local function sine(x) return math.sin(x) end
local function square(x) return math.sin(x) >= 0 and 1 or -1 end
local function saw(x) return ((x / (2 * math.pi)) % 1) * 2 - 1 end

local function generate()
  local jumpPhase = sweep(260, 640)
  generated.jump = build(0.14, function(t, d)
    local ph = jumpPhase(t, d)
    return (sine(ph) * 0.6 + square(ph) * 0.12) * env(t, d, 1.4) * 0.5
  end)

  local landNoise, landPhase = lowpassNoise(0.12), sweep(110, 45)
  generated.land = build(0.12, function(t, d)
    return (landNoise() * 1.6 + sine(landPhase(t, d))) * env(t, d, 2) * 0.55
  end)

  generated.cast = build(0.6, function(t, d)
    local trem = 0.6 + 0.4 * math.sin(t * 2 * math.pi * 16)
    local v = 0
    for _, f in ipairs({ 660, 880, 1320, 1767 }) do
      v = v + math.sin(2 * math.pi * f * t * (1 + 0.15 * t / d))
    end
    local a = math.min(1, t / 0.04) * env(t, d, 1.5)
    return v * 0.13 * trem * a
  end)

  generated.plate = build(0.09, function(t, d)
    local f = t < 0.03 and 900 or 520
    return square(2 * math.pi * f * t) * 0.3 * env(t, d, 1.2)
  end)

  local rumble = lowpassNoise(0.05)
  generated.door = build(0.7, function(t, d)
    local wobble = 0.7 + 0.3 * math.sin(t * 2 * math.pi * 9)
    local a = math.min(1, t / 0.08) * env(t, d, 0.8)
    return (rumble() * 3.2 + sine(2 * math.pi * 52 * t) * 0.6) * wobble * a * 0.5
  end)

  local deathNoise, deathPhase = lowpassNoise(0.4), sweep(440, 55)
  generated.death = build(0.5, function(t, d)
    return (saw(deathPhase(t, d)) * 0.5 + deathNoise() * 0.5) * env(t, d, 1.3) * 0.5
  end)

  local grit = lowpassNoise(0.3)
  generated.crumble = build(0.35, function(t, d)
    local crack = t < 0.05 and square(2 * math.pi * 70 * t) * 0.5 or 0
    return (grit() * 2.2 * env(t, d, 1.6) + crack) * 0.5
  end)

  generated.goal = build(0.9, function(t)
    local v = 0
    for i, f in ipairs({ 523.25, 659.25, 783.99, 1046.5 }) do
      local s = (i - 1) * 0.1
      if t >= s then
        local lt = t - s
        v = v + math.sin(2 * math.pi * f * lt) * math.exp(-lt * 5) * math.min(1, lt / 0.01)
      end
    end
    return v * 0.3
  end)
end

-- A file under assets/sfx wins over the generated sound of the same name.
local function applyAssets()
  if Assets.version == 0 then Assets.load() end
  for name in pairs(generated) do
    sources[name] = Assets.sound(name) or generated[name]
  end
  seenVersion = Assets.version
end

function M.init()
  if not next(generated) then generate() end
  applyAssets()
end

function M.play(name, pitch)
  if seenVersion ~= Assets.version then applyAssets() end
  local src = sources[name]
  if not src then return end
  local s = src:clone()
  s:setVolume(M.volume)
  if pitch then s:setPitch(pitch) end
  s:play()
end

return M
