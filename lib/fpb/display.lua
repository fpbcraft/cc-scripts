-- Shared display-selection policy for monitor / CraftOS-PC / plain CraftOS.
-- Graphics capability is tested on the REAL terminal, before a text wrapper.
-- The renderer itself enters graphics mode and restores it on exit.
local D = {}
function D.hasPixels(device)
  return type(device) == "table"
    and type(device.setGraphicsMode) == "function"
    and type(device.drawPixels) == "function"
    and type(device.getSize) == "function"
end
function D.select(monitor, native, viewport, w, h)
  if monitor then
    return monitor, "monitor"
  end
  assert(native and type(native.getSize) == "function", "No computer terminal")
  if D.hasPixels(native) then
    return native, "native-pixels"
  end
  -- Retain the scrollable fallback on small, non-graphics CC computers.
  if viewport then
    return viewport.new(native, w, h), "virtual-text"
  end
  return native, "native-text"
end
function D.isComputer(mode)
  return mode ~= "monitor"
end
function D.resize(device, mode)
  if mode == "virtual-text" and device.present then
    device.present()
  end
end
function D.click(device, mode, x, y)
  if mode == "virtual-text" then
    return device.mouse(x, y)
  end
  -- CraftOS-PC mouse_click reports pixel coordinates in graphics mode.
  return x, y
end
function D.present(device, mode)
  if mode == "virtual-text" and device.present then
    device.present()
  end
end
function D.close(device, mode)
  if mode == "virtual-text" and device.close then
    device.close()
  end
end
return D
