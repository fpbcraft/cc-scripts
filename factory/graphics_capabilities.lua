-- Read-only CC: Graphics feature detection. Never changes a terminal's mode.
local M={}
function M.inspect(surface)
  if type(surface)~="table" and type(surface)~="userdata" then
    return {available=false,mode=0}
  end
  local has=type(surface.setGraphicsMode)=="function" and
    type(surface.getGraphicsMode)=="function" and
    type(surface.drawPixels)=="function"
  if not has then return {available=false,mode=0} end
  local ok,current=pcall(surface.getGraphicsMode)
  if not ok then return {available=false,mode=0} end
  local value={available=true,mode=current or 0}
  local sized,w,h=pcall(surface.getSize,2)
  if sized and type(w)=="number" and type(h)=="number" then
    value.width=w;value.height=h
  end
  return value
end
return M
