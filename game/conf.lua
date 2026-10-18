local selftest, bench = false, false
for _, a in pairs(arg or {}) do
  if a == '--selftest' or a == '--slack' or a == '--cheese' then selftest = true end
  if a == '--bench' then bench = true end
end

function love.conf(t)
  t.identity = 'echoes'
  t.version = '11.5'
  t.window.title = 'ECHOES'
  t.window.width = 960
  t.window.height = 540
  t.window.vsync = bench and 0 or 1
  t.window.resizable = true
  t.window.minwidth = 960
  t.window.minheight = 540
  if selftest then
    t.window = false
    for _, m in ipairs({ 'graphics', 'window', 'audio', 'sound', 'joystick', 'video', 'touch', 'mouse' }) do
      t.modules[m] = false
    end
  end
end
