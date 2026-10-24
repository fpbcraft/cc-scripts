-- COGWORKS / kinetic workshop for CC:Tweaked Advanced Monitors.
-- Uses CC: Graphics when available, with a vanilla text-mode fallback.
package.path="/?.lua;/?/init.lua;"..package.path
local App=require("cogworks.app")
local Renderer=require("cogworks.render")
local E=require("cogworks.engine")
local Display=require("cogworks.display")
local args={...}
if args[1]=="--test-api"then
 return {app=App,engine=E,renderer=Renderer}
end
local function selectMonitor(preferred)
 if preferred then
  local m=peripheral.wrap(preferred)
  assert(m and peripheral.getType(preferred)=="monitor",
   "Unknown monitor: "..tostring(preferred),0)
  return m,preferred
 end
 local chosen,name,largest=nil,nil,0
 for _,side in ipairs(peripheral.getNames())do
  if peripheral.getType(side)=="monitor"then
   local m=peripheral.wrap(side)
   local ok,w,h=pcall(m.getSize)
   if ok and (not m.isColor or m.isColor()) and w*h>largest then
    chosen,name,largest=m,side,w*h
   end
  end
 end
 return chosen,name
end
local function start()
 local monitor,name=selectMonitor(args[1])
 local mode
 local native=nil
 if not monitor then native=term.current()end
 monitor,mode=Display.select(monitor,native,
  require("cogworks.terminal_view"),70,40)
 local computerMode=Display.isComputer(mode)

 local previous=monitor.getTextScale and monitor.getTextScale() or 1
 if monitor.setTextScale then monitor.setTextScale(0.5)end
 local renderer,app
 local ok,reason=xpcall(function()
  renderer=Renderer.new(monitor)
  app=App.new()
  local function redraw()
   renderer:draw(app:model())
   Display.present(monitor,mode)
  end
  local function act(action,x,y)
   if not action then return true end
   local response=app:act(action,x,y)
   if response=="exit"then return false end
   redraw()
   return true
  end
  redraw()
  local timer=os.startTimer(0.2)
  while true do
   local event,a,b,c,d=os.pullEventRaw()
   if event=="terminate"then
    if app then app:save()end
    break
   elseif event=="monitor_touch" and a==name then
    local action,x,y=renderer:hit(b,c)
    -- Vanilla monitor_touch only reports right-click and carries no button.
    -- Addons that append an explicit mouse button can use button 2 to remove.
    if action=="cell" and (app.hasLeftInput or d==2 or d=="right")then
     action="remove"
    end
    if not act(action,x,y)then break end
   elseif event=="monitor_left_click" and a==name then
    -- FPB Monitor Input companion sends normalized 0..1 screen positions.
    -- After it is detected, vanilla right-clicks remove directly.
    local action,x,y=renderer:hitNormalized(b,c)
    if action then
     app.hasLeftInput=true
     if not act(action,x,y)then break end
    end
   elseif computerMode and event=="mouse_click" then
    local x,y=Display.click(monitor,mode,b,c)
    if x then
     local action,arg1,arg2=renderer:hit(x,y)
     if not act(action,arg1,arg2)then break end
    end
   elseif mode=="virtual-text" and event=="mouse_scroll"then
    monitor.pan(0,a*3)
   elseif computerMode and event=="term_resize"then
    renderer:resize();redraw()
   elseif event=="monitor_resize" and a==name then
    renderer:resize();redraw()
   elseif event=="timer" and a==timer then
    if renderer.mode=="graphics" and app.settings.animations and
      (app.scene=="game" or app.scene=="briefing" or
       app.scene=="tutorial")then redraw()end
    timer=os.startTimer(app.scene=="briefing" and 0.1 or 0.2)
   elseif event=="char"then
    local char=tostring(a):lower()
    local n=tonumber(char)
    if n and n>=1 and n<=9 then
     if not act("tool",E.order[n])then break end
    elseif char=="0"then act("tool",E.order[10])
    elseif char=="x"then act("tool","erase")
    elseif char=="s"then act("save")
    elseif char=="n"then
     act(app.scene=="briefing" and "beginLevel" or "next")
    elseif char==" " and app.scene=="briefing"then act("beginLevel")
    elseif char=="p" or char=="q"then
     if app.scene=="game"then act("pause")
     elseif app.scene=="pause"then act("resume")
     elseif app.scene=="title" and char=="q"then
      if not act("exit")then break end
     end
    elseif char=="b"then act("back")
    end
   elseif event=="key" and keys then
    if mode=="virtual-text" and (a==keys.up or a==keys.down or
      a==keys.left or a==keys.right)then
     local dx=a==keys.left and -8 or (a==keys.right and 8 or 0)
     local dy=a==keys.up and -5 or (a==keys.down and 5 or 0)
     monitor.pan(dx,dy)
    elseif (a==keys.enter or a==keys.numPadEnter or a==keys.space) and
      app.scene=="briefing"then act("beginLevel")
    elseif a==keys.escape or a==keys.backspace then
     local state=app.scene
     if state=="game"then act("pause")
     elseif state=="pause"then act("resume")
     else act("back")end
    elseif a==keys.left and app.scene=="game"then act("prev")
    elseif a==keys.right and app.scene=="game"then act("next")
    end
   end
  end
 end,function(e)
  return tostring(e)..(debug and debug.traceback and
   "\n"..debug.traceback() or "")
 end)
 if renderer then renderer:close()end
 Display.close(monitor,mode)
 if monitor.setTextScale then pcall(monitor.setTextScale,previous)end
 if not ok then error(reason,0)end
end
start()
