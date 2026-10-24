-- COGWORKS / touchscreen kinetic construction puzzle game for CC:Tweaked.
-- Launch: /cogworks/main.lua [monitor_name]; optional CC: Graphics mode 2.
package.path="/?.lua;/?/init.lua;"..package.path
local E=require("cogworks.engine")
local R=require("cogworks.render")
local args={...}
if args[1]=="--test-api"then return {engine=E,renderer=R}end
local function monitor(preferred)
 if preferred then
  local m=peripheral.wrap(preferred)
  assert(m and peripheral.getType(preferred)=="monitor",
   "Unknown monitor: "..preferred,0)
  return m,preferred
 end
 local chosen,name,area=nil,nil,0
 for _,side in ipairs(peripheral.getNames())do
  if peripheral.getType(side)=="monitor"then
   local m=peripheral.wrap(side)
   local ok,w,h=pcall(m.getSize)
   if ok and (not m.isColor or m.isColor()) and w*h>area then
    chosen,name,area=m,side,w*h
   end
  end
 end
 return chosen,name
end
local SAVE="/cogworks/save.dat"
local function loadSave()
 local fallback={unlocked=1,level=1,best={},sessions={},campaignVersion=2}
 if not fs.exists(SAVE)then return fallback end
 local f=fs.open(SAVE,"r")
 if not f then return fallback end
 local encoded=f.readAll();f.close()
 local ok,data=pcall(textutils.unserialize,encoded)
 if not ok or type(data)~="table"then return fallback end
 local max=#E.levels
 local unlocked=math.max(1,math.min(max,math.floor(tonumber(data.unlocked) or 1)))
 local level=math.max(1,math.min(unlocked,math.floor(tonumber(data.level) or 1)))
 local best=type(data.best)=="table" and data.best or {}
 local sessions=type(data.sessions)=="table" and data.sessions or {}
 if data.campaignVersion~=2 then
  -- Levels 4-12 have been rebuilt. Old layouts/scores no longer apply.
  -- Keep completed-level unlocks and early tutorial progress.
  for n=4,12 do sessions[n]=nil;best[n]=nil end
 end
 return {unlocked=unlocked,level=level,best=best,sessions=sessions,
  campaignVersion=2}
end
local function save(data)
 local nextPath=SAVE..".tmp"
 local previous=SAVE..".bak"
 local handle,err=fs.open(nextPath,"w")
 if not handle then print("Cannot save: "..tostring(err));return false end
 handle.write(textutils.serialize(data));handle.close()
 -- Preserve the last complete save if activation fails or the game is stopped.
 local ok,reason=pcall(function()
  if fs.exists(previous)then fs.delete(previous)end
  if fs.exists(SAVE)then fs.move(SAVE,previous)end
  fs.move(nextPath,SAVE)
 end)
 if not ok then
  if fs.exists(previous) and not fs.exists(SAVE)then fs.move(previous,SAVE)end
  print("Save failed: "..tostring(reason));return false
 end
 if fs.exists(previous)then fs.delete(previous)end
 return true
end
local function start()
 local mon,name=monitor(args[1])
 assert(mon,"Attach a color Advanced Monitor (3x3 blocks or larger).",0)
 assert(not mon.isColor or mon.isColor(),"Use a color Advanced Monitor.",0)
 local originalScale=mon.getTextScale and mon.getTextScale() or 1
 if mon.setTextScale then mon.setTextScale(0.5)end
 local renderer=nil
 local ok,err=xpcall(function()
  renderer=R.new(mon)
  local progress=loadSave()
  local selected="I"
  local help=false
  local message=""
  local game,result
  local function openLevel(index)
   game=E.new(index)
   local session=progress.sessions[index]
   if type(session)=="table" and E.restore(game,session.parts)then
    game.moves=math.max(0,math.floor(tonumber(session.moves) or 0))
    game.hints=math.max(0,math.floor(tonumber(session.hints) or 0))
   end
   result=E.evaluate(game)
   progress.level=index
   selected="I"
   message=""
  end
  local function persist()
   progress.sessions[game.number]={
    parts=E.snapshot(game),moves=game.moves,hints=game.hints,
   }
   save(progress)
  end
  local function redraw()renderer:draw(game,result,progress.unlocked,selected,message,help)end
  openLevel(progress.level)
  local function operate(action,x,y)
   if action=="back"then help=false;redraw();return true end
   if action=="help"then help=true;redraw();return true end
   if action=="quit"then return false end
   if help then help=false;redraw();return true end
   local changed=false
   message=""
   if action=="tool"then
    if x=="erase" or E.parts[x]then
     selected=x
     if x~="erase" and (game.remaining[x] or 0)==0 then
      message="EMPTY STOCK: REMOVE A PART"
     end
    end
   elseif action=="cell"then
    local tile=E.get(game,x,y)
    if selected=="erase"then
     changed=E.remove(game,x,y)
     if not changed then message="CANNOT REMOVE LOCKED MACHINERY"end
    elseif tile then
     changed=E.rotate(game,x,y)
     if not changed then
      message=tile.kind=="X" and "STONE: CANNOT BUILD HERE" or
       "SOURCE AND TARGETS ARE FIXED"
     end
    else
     changed=E.place(game,x,y,selected)
     if not changed then message="NO "..(E.parts[selected] and E.parts[selected].name or "PART").." LEFT"end
    end
   elseif action=="hint"then
    changed=E.hint(game)
    if changed then message="HINT: ONE STEP FIXED"
    else message="ALL REFERENCE PARTS ARE CORRECT"end
   elseif action=="reset"then
    game=E.new(game.number)
    changed=true;message="BOARD RESET / STOCK RESTORED"
   elseif action=="prev" or action=="next"then
    local target=game.number+(action=="prev" and -1 or 1)
    if target>=1 and target<=progress.unlocked and target<=#E.levels then
     openLevel(target)
     persist()
    else message="SOLVE THE PUZZLE TO UNLOCK"end
   end
   if changed then
    result=E.evaluate(game)
    if result.win then
     progress.unlocked=math.max(progress.unlocked,math.min(#E.levels,game.number+1))
     -- Hints are useful for learning but do not count toward personal bests.
     if game.hints==0 then
      local best=progress.best[game.number]
      if not best or game.moves<best then progress.best[game.number]=game.moves end
     end
     message="SUCCESS! ALL MACHINES POWERED"
    elseif result.jam then message="JAM! CONFLICTING SPEED OR SPIN"end
    persist()
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
    local action,x,y=renderer:hit(b,c,help)
    if action and not operate(action,x,y)then break end
   elseif event=="monitor_resize" and a==name then
    renderer:resize();redraw()
   elseif event=="timer" and a==timer then
    if renderer.mode=="graphics"then redraw()end
    timer=os.startTimer(0.2)
   elseif event=="char"then
    local key=tostring(a):lower()
    local n=tonumber(key)
    if n and n>=1 and n<=5 then
     operate("tool",E.order[n])
    elseif key=="6"then operate("tool","erase")
    else
     local shortcuts={h="hint",r="reset",p="prev",n="next",q="quit",["?"]="help"}
     local action=shortcuts[key]
     if action and not operate(action)then break end
    end
   elseif event=="key" and keys then
    local action=(a==keys.left and "prev") or (a==keys.right and "next") or nil
    if action then operate(action)end
   end
  end
 end,function(e)
  return tostring(e)..(debug and debug.traceback and "\n"..debug.traceback() or "")
 end)
 if renderer then renderer:close()end
 if mon.setTextScale then pcall(mon.setTextScale,originalScale)end
 if not ok then error(err,0)end
end
start()
