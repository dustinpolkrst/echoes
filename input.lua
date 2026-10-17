local Input = {}

local DEADZONE = 0.35
local REPEAT_DELAY, REPEAT_RATE = 0.4, 0.1

local BINDINGS = {
  left = { keys = { 'left', 'a' }, buttons = { 'dpleft' } },
  right = { keys = { 'right', 'd' }, buttons = { 'dpright' } },
  up = { keys = { 'up', 'w' }, buttons = { 'dpup' } },
  down = { keys = { 'down', 's' }, buttons = { 'dpdown' } },
  jump = { keys = { 'z', 'space', 'w', 'up' }, buttons = { 'a' } },
  cast = { keys = { 'x', 'k' }, buttons = { 'x', 'b' } },
  confirm = { keys = { 'z', 'space', 'return', 'kpenter' }, buttons = { 'a' } },
  back = { keys = { 'escape', 'backspace' }, buttons = { 'b' } },
  pause = { keys = { 'escape', 'p' }, buttons = { 'start' } },
  restart = { keys = { 'r' }, buttons = { 'back' } },
}
local HELD = { 'left', 'right', 'jump', 'cast' }
local EDGE = { 'confirm', 'back', 'pause', 'restart', 'up', 'down', 'left', 'right', 'jump', 'cast' }
local NAV = { 'up', 'down', 'left', 'right' }
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

function Input.fromKey(key, isRepeat)
  Input.lastDevice = 'key'
  local out = actionsFor('keys', key)
  if isRepeat then
    local nav = {}
    for _, name in ipairs(out) do
      if contains(NAV, name) then nav[#nav + 1] = name end
    end
    return nav
  end
  return out
end

function Input.fromButton(button)
  Input.lastDevice = 'pad'
  local out = {}
  for _, name in ipairs(actionsFor('buttons', button)) do
    if not contains(NAV, name) then out[#out + 1] = name end
  end
  return out
end

local function padDirections(joysticks)
  local held = {}
  for _, j in ipairs(joysticks) do
    for _, name in ipairs(NAV) do
      if j:isGamepadDown(BINDINGS[name].buttons[1]) then held[name] = true end
    end
    local x, y = j:getGamepadAxis('leftx'), j:getGamepadAxis('lefty')
    if x < -DEADZONE then held.left = true elseif x > DEADZONE then held.right = true end
    if y < -DEADZONE then held.up = true elseif y > DEADZONE then held.down = true end
  end
  return held
end

function Input.newNavState()
  return { held = {} }
end

function Input.navPoll(state, joysticks, dt)
  joysticks = joysticks or Input.joysticks()
  local now, out = padDirections(joysticks), {}
  for _, name in ipairs(NAV) do
    if now[name] then
      local t = state.held[name]
      if t == nil then
        out[#out + 1] = name
        state.held[name] = REPEAT_DELAY
      else
        t = t - dt
        if t <= 0 then
          out[#out + 1] = name
          t = t + REPEAT_RATE
        end
        state.held[name] = t
      end
    else
      state.held[name] = nil
    end
  end
  if #out > 0 then Input.lastDevice = 'pad' end
  return out
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

function Input.hint(text)
  if Input.lastDevice ~= 'pad' then return text end
  for _, w in ipairs(PAD_WORDS) do
    local a, b = text:find(w[1], 1, true)
    if a then text = text:sub(1, a - 1) .. w[2] .. text:sub(b + 1) end
  end
  return text
end

function Input.pad()
  return Input.lastDevice == 'pad'
end

function Input.names()
  if Input.pad() then
    return { confirm = 'A', back = 'B', pause = 'Start', restart = 'Back', move = 'D-pad' }
  end
  return { confirm = 'Z', back = 'Esc', pause = 'Esc', restart = 'R', move = 'Arrows' }
end

return Input
