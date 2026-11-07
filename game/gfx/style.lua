local Style = {
  t = 0, look = nil, glow = nil,
  plates = { { 0.35, 0.95, 1 }, { 1, 0.45, 0.85 }, { 1, 0.85, 0.35 }, { 0.55, 1, 0.5 } },
}

local IDS = { ink = true, cut = true, photo = true }

function Style.paint(Ui)
  local cols = Style.look and Style.look.colors
  if not cols then return end
  for k, rgb in pairs(cols) do
    local dst = Ui.colors[k]
    if dst then dst[1], dst[2], dst[3] = rgb[1], rgb[2], rgb[3] end
  end
end

function Style.use(id)
  if not IDS[id] then
    error('unknown --style ' .. tostring(id) .. ' (ink, cut, photo)')
  end
  Style.look = require('gfx.looks').get(id)
  local Ui = require('gfx.ui')
  Style.paint(Ui)
end

return Style
