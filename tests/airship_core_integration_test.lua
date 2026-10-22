-- Regression: Basalt UI coroutine cannot consume the dedicated flight timer.
local now,timerId=0,0
local timers={}
local writes={}
local files={}
local saved={}
local activeMonitor=nil
local lastSnapshot
fs={getDir=function()return 'airship' end,
 combine=function(a,b)return a..'/'..b end,
 exists=function(path)return files[path]~=nil end,
 getSize=function(path)return #(files[path] or '') end,
 open=function(path,mode)
  if mode=='r' then
    if not files[path] then return nil end
    return {readAll=function()return files[path] end,close=function()end}
  end
  if mode=='w' then files[path]='' end
  return {write=function(txt)files[path]=(files[path] or '')..txt end,
   writeLine=function(txt)files[path]=(files[path] or '')..txt..'\n' end,
   close=function()end}
 end}
textutils={serialize=function(obj)return 'stub' end,
 unserialize=function(raw)if raw=='settings' then return {bowOffset=0,autoMap=false} end end}
files['airship/.airship_avionics_burners_settings']='settings'
shell={getRunningProgram=function()return 'airship/autopilot.lua'end}
local nav={getHeading=function()return 0 end,
 getTablePosition=function()return{x=0,y=100,z=0,projected=true}end,
 getTargetPosition=function()return nil end}
local bridge={getLinkSignal=function()return 0 end,
 sendLinkSignal=function(a,b,v)writes[#writes+1]={a,b,v}end}
peripheral={getNames=function()return {'nav','bridge'}end,
 wrap=function(name)if name=='nav' then return nav elseif name=='bridge' then return bridge end end,
 hasType=function()return false end,getType=function()return 'other'end}
term={current=function()return term end,redirect=function()end,
 setCursorBlink=function()end,setBackgroundColor=function()end,setTextColor=function()end,
 clear=function()end,setCursorPos=function()end}
colors={black=1,white=2}
os.clock=function()return now end
os.startTimer=function(delay)
 timerId=timerId+1;timers[timerId]=now+delay
 return timerId
end
os.pullEventRaw=function(filter)return coroutine.yield(filter)end
parallel={}
function parallel.waitForAny(...)
 local jobs={...}
 local active,filters={},{}
 for i,job in ipairs(jobs)do
  active[i]=coroutine.create(job)
  local ok,f=coroutine.resume(active[i]);assert(ok,f);filters[i]=f
 end
 for _=1,6000 do
  local nextId,min=nil,math.huge
  for id,t in pairs(timers) do if t<min then nextId,min=id,t end end
  assert(nextId,'Flight/engine timers stopped')
  now=min;timers[nextId]=nil
  for i,co in ipairs(active)do
   if coroutine.status(co)~='dead' and (filters[i]==nil or filters[i]=='timer') then
    local ok,f=coroutine.resume(co,'timer',nextId)
    assert(ok,f)
    filters[i]=f
    if coroutine.status(co)=='dead' then return end
   end
  end
 end
 error('No UI exit from scheduler')
end
package.preload.ui=function()
 return {run=function(controller)
   controller.setPage('FLIGHT')
   assert(controller.snapshot().mode=='idle')
   assert(controller.addPreset(100,200,'Dock'))
   assert(controller.addRoute(0,500,'First',0))
   assert(controller.addRoute(0,1000,'Second',1))
   assert(controller.flyRouteFrom(2))
   assert(controller.snapshot().routeIndex==2)
   for i=1,200 do os.pullEventRaw('timer') end
   lastSnapshot=controller.snapshot()
   controller.stop()
   assert(controller.snapshot().routeNext==2)
 end}
end
local originalPrint=print
print=function()end
local chunk=assert(loadfile('airship/autopilot.lua'))
chunk()
assert(lastSnapshot and lastSnapshot.tick>=30,'flight tick stalled while UI active')
assert(#writes>4,'no controls were sent')
assert(files['airship/.airship_avionics_route'],'route not saved')
assert(files['airship/.airship_avionics_presets'],'preset not saved')
originalPrint('Airship core integration: PASS, '..lastSnapshot.tick..' ticks, '..#writes..' outputs')
