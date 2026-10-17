local Input = {}

local DEADZONE = 0.35

-- Held actions are polled every step; edge actions arrive from key/button events.
-- confirm shares the jump bindings so "press jump" prompts work on both devices.
local BINDINGS = {
  left = { keys = { 'left', 'a' }, buttons = { 'dpleft' } },
  right = { keys = { 'right', 'd' }, buttons = { 'dpright' } },
  jump = { keys = { 'z', 'space', 'w', 'up' }, buttons = { 'a' } },
  cast = { keys = { 'x', 'k' }, buttons = { 'x', 'b' } },
  confirm = { keys = { 'z', 'space', 'w', 'up' }, buttons = { 'a', 'start' } },
  restart = { keys = { 'r' }, buttons = { 'back' } },
}
local HELD = { 'left', 'right', 'jump', 'cast' }
local EDGE = { 'confirm', 'restart', 'jump', 'cast' }
Input.BINDINGS = BINDINGS

Input.lastDevice = 'key'

local function contains(list, v)
  for _, x in ipairs(list) do
    if x == v then return true end
  end
  return false
end

local function actionsFor(field, value)
  local out = {}
  for _, name in ipairs(EDGE) do
    if contains(BINDINGS[name][field], value) then out[#out + 1] = name end
  end
  return out
end

function Input.fromKey(key)
  Input.lastDevice = 'key'
  return actionsFor('keys', key)
end

function Input.fromButton(button)
  Input.lastDevice = 'pad'
  return actionsFor('buttons', button)
end

function Input.joysticks()
  return love.joystick and love.joystick.getJoysticks() or {}
end

local function padHeld(joysticks, name)
  for _, j in ipairs(joysticks) do
    for _, b in ipairs(BINDINGS[name].buttons) do
      if j:isGamepadDown(b) then return true end
    end
    local x = j:getGamepadAxis('leftx')
    if name == 'left' and x < -DEADZONE then return true end
    if name == 'right' and x > DEADZONE then return true end
  end
  return false
end

-- joysticks and keyDown are injectable so the mapping runs headless in the selftest.
function Input.read(joysticks, keyDown)
  joysticks = joysticks or Input.joysticks()
  keyDown = keyDown or love.keyboard.isDown
  local input, padUsed, keyUsed = {}, false, false
  for _, name in ipairs(HELD) do
    local k = keyDown(unpack(BINDINGS[name].keys))
    local p = padHeld(joysticks, name)
    input[name] = k or p
    keyUsed = keyUsed or k
    padUsed = padUsed or p
  end
  if padUsed and not keyUsed then Input.lastDevice = 'pad' elseif keyUsed then Input.lastDevice = 'key' end
  return input
end

function Input.rumble(strength, seconds)
  if Input.lastDevice ~= 'pad' then return end
  for _, j in ipairs(Input.joysticks()) do
    if j.isVibrationSupported and j:isVibrationSupported() then
      j:setVibration(strength, strength, seconds)
    end
  end
end

local PAD_WORDS = {
  { 'Arrows move', 'D-pad or stick moves' },
  { 'Z, Space or Up', 'A' },
  { 'Press R to restart', 'Press Back to restart' },
}

-- Level hints are written for the keyboard; swap the button names when a pad is in use.
function Input.hint(text)
  if Input.lastDevice ~= 'pad' then return text end
  for _, w in ipairs(PAD_WORDS) do
    local a, b = text:find(w[1], 1, true)
    if a then text = text:sub(1, a - 1) .. w[2] .. text:sub(b + 1) end
  end
  return text
end

function Input.confirmLabel()
  return Input.lastDevice == 'pad' and 'press A' or 'press jump'
end

function Input.confirmKeys()
  return Input.lastDevice == 'pad' and 'A / Start' or 'Z / Space / Up'
end

return Input
