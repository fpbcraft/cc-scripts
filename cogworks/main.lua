-- COGWORKS / a standalone tactile kinetic workshop game for CC:Tweaked.
-- Launch: /cogworks/main.lua [optional_monitor_name]
-- Uses CC: Graphics when available, with a playable vanilla Advanced Monitor fallback.
package.path="/?.lua;/?/init.lua;"..package.path
local E=require("cogworks.engine")
local R=require("cogworks.render")
local args={...}
if args[1]=="--test-api"then return {engine=E,renderer=R}end

local function monitor(preferred)
 if preferred then
  local m=peripheral.wrap(preferred)
  assert(m and peripheral.getType(preferred)=="monitor","Unknown monitor: "..preferred,0)
  return m,preferred
 end
 local candidate,name,area=nil,nil,0
 for _,side in ipairs(peripheral.getNames())do
  if peripheral.getType(side)=="monitor"then
   local m=peripheral.wrap(side)
   local ok,w,h=pcall(m.getSize)
   if ok and (not m.isColor or m.isColor()) and w*h>area then
    candidate,name,area=m,side,w*h
   end
  end
 end
 return candidate,name
end
local function loadSave()
 local default={unlocked=1,level=1,best={}}
 if not fs.exists("/cogworks/save.dat")then return default end
 local f=fs.open("/cogworks/save.dat","r")
 if not f then return default end
 local content=f.readAll();f.close()
 local ok,data=pcall(textutils.unserialize,content)
 if not ok or type(data)~="table"then return default end
 local unlocked=math.max(1,math.min(#E.levels,math.floor(tonumber(data.unlocked) or 1)))
 local current=math.max(1,math.min(unlocked,math.floor(tonumber(data.level) or 1)))
 return {unlocked=unlocked,level=current,
  best=type(data.best)=="table" and data.best or {}}
end
local function save(data)
 local tmp="/cogworks/save.tmp"
 local f,err=fs.open(tmp,"w")
 if not f then print("Save failed: "..tostring(err));return end
 f.write(textutils.serialize(data));f.close()
 if fs.exists("/cogworks/save.dat")then fs.delete("/cogworks/save.dat")end
 fs.move(tmp,"/cogworks/save.dat")
end

local function start()
 local mon,name=monitor(args[1])
 assert(mon,"Attach a color Advanced Monitor (ideally at least 3x3 blocks).",0)
 assert(not mon.isColor or mon.isColor(),"Use a color Advanced Monitor.",0)
 local oldScale=mon.getTextScale and mon.getTextScale() or 1
 if mon.setTextScale then mon.setTextScale(0.5)end
 local renderer
 local ok,err=xpcall(function()
  renderer=R.new(mon)
  local progress=loadSave()
  local game=E.new(progress.level)
  local result=E.evaluate(game)
  local function redraw() renderer:draw(game,result,progress.unlocked)end
  local function visit(index)
   if index<1 or index>progress.unlocked or index>#E.levels then return end
   game=E.new(index);result=E.evaluate(game)
   progress.level=index;save(progress)
  end
  local function operate(kind,x,y)
   if kind=="rotate"then E.rotate(game,x,y)
   elseif kind=="hint"then if not result.win then E.hint(game)end
   elseif kind=="reset"then game=E.new(game.number)
   elseif kind=="prev"then visit(game.number-1)
   elseif kind=="next"then visit(game.number+1)
   elseif kind=="quit"then return false
   end
   result=E.evaluate(game)
   if result.win then
    progress.unlocked=math.max(progress.unlocked,math.min(#E.levels,game.number+1))
    local previous=progress.best[game.number]
    if not previous or game.moves<previous then progress.best[game.number]=game.moves end
    save(progress)
   end
   redraw()
   return true
  end
  redraw()
  local timer=os.startTimer(0.2)
  while true do
   local event,a,b,c=os.pullEventRaw()
   if event=="terminate"then break
   elseif event=="monitor_touch" and a==name then
    local action,x,y=renderer:hit(b,c)
    if action and not operate(action,x,y)then break end
   elseif event=="monitor_resize" and a==name then
    renderer:resize();redraw()
   elseif event=="timer" and a==timer then
    if renderer.mode=="graphics"then redraw()end
    timer=os.startTimer(0.2)
   elseif event=="char"then
    local controls={h="hint",r="reset",p="prev",n="next",q="quit"}
    local action=controls[tostring(a):lower()]
    if action and not operate(action)then break end
   elseif event=="key" and keys then
    local action=(a==keys.left and "prev") or (a==keys.right and "next") or nil
    if action then operate(action)end
   end
  end
 end,function(e)
  return tostring(e)..(debug and debug.traceback and "\n"..debug.traceback() or "")
 end)
 if renderer then renderer:close()end
 if mon.setTextScale then pcall(mon.setTextScale,oldScale)end
 if not ok then error(err,0)end
end
start()
