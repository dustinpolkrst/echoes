-- Compares two PNGs from the save directory pixel by pixel and writes a mask of the differences.
local D = {}

function D.run(a, b)
  local ia, ib = love.image.newImageData(a), love.image.newImageData(b)
  local w, h = ia:getDimensions()
  if w ~= ib:getWidth() or h ~= ib:getHeight() then
    print(('DIFF %s %s  size %dx%d vs %dx%d'):format(a, b, w, h, ib:getWidth(), ib:getHeight()))
    return false
  end
  local mask = love.image.newImageData(w, h)
  local count, worst = 0, 0
  local x0, y0, x1, y1 = w, h, -1, -1
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local r1, g1, b1 = ia:getPixel(x, y)
      local r2, g2, b2 = ib:getPixel(x, y)
      local d = math.max(math.abs(r1 - r2), math.abs(g1 - g2), math.abs(b1 - b2))
      if d > 0 then
        count = count + 1
        worst = math.max(worst, d)
        x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x), math.max(y1, y)
        mask:setPixel(x, y, 1, 0, 0, 1)
      else
        mask:setPixel(x, y, r1 * 0.25, g1 * 0.25, b1 * 0.25, 1)
      end
    end
  end
  local out = b:gsub('%.png$', '') .. '_diff.png'
  mask:encode('png', out)
  print(('DIFF %s %s  %d of %d pixels differ, max channel delta %d/255%s  mask %s/%s'):format(a, b, count, w * h,
    math.floor(worst * 255 + 0.5), count > 0 and (' in %d,%d..%d,%d'):format(x0, y0, x1, y1) or '',
    love.filesystem.getSaveDirectory(), out))
  return count == 0
end

return D
