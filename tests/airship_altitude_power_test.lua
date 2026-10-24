-- Regression: Basalt UI coroutine cannot consume the dedicated flight timer.
local now,timerId=0,0
local timers={}
local writes={}
local files={}
local saved={}
local activeMonitor=nil
local ship={x=0,y=80,z=0,heading=0}
local driveDirs={ ["disk/skyways-routes"]=true }
local lastSnapshot
-- A mutable simulated ship; Y is supplied from the navigation table.
ship.y=100
fs={getDir=function()return 'airship' end,
 combine=function(a,b)return a..'/'..b end,
 exists=function(path)return files[path]~=nil or driveDirs[path]==true end,
 isDir=function(path)return driveDirs[path]==true end,
 makeDir=function(path)driveDirs[path]=true end,
 list=function(path) local out={} for key in pairs(files) do local parent,name=key:match("^(.-)/([^/]+)$");if parent==path then out[#out+1]=name end end table.sort(out);return out end,
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
textutils={serialize=function(obj)
 if type(obj)=='table' and obj.points and obj.loop~=nil then
  saved.routeLoop=obj.loop;saved.routeNext=obj.nextIndex
 end
 return 'stub' end,
 unserialize=function(raw)if raw=='settings' then return {bowOffset=0,autoMap=false} end end}
files['airship/.airship_avionics_burners_settings']='settings'
shell={getRunningProgram=function()return 'airship/autopilot.lua'end}
local nav={getHeading=function()return 0 end,
 getTablePosition=function()return{x=ship.x,y=ship.y,z=ship.z,projected=true}end,
 getTargetPosition=function()return nil end}
local bridge={getLinkSignal=function(a,b)
  if a=='minecraft:iron_ingot' then return 8 end
  if a=='minecraft:oak_log' then return 6 end
  return 0 end,
 sendLinkSignal=function(a,b,v)writes[#writes+1]={a,b,v}end}
local drive={getMountPath=function()return 'disk' end,hasData=function()return true end}
peripheral={getNames=function()return {'nav','bridge','drive_0'}end,
 wrap=function(name)if name=='nav' then return nav elseif name=='bridge' then return bridge elseif name=='drive_0' then return drive end end,
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
 return {run=function(api)
  local function check(ok,why)assert(ok,why)end
  check(api.createRoute('Height-Test',false),'route creation')
  ship.x,ship.z,ship.y=0,0,100
  check(api.recordWaypoint('Station',true),'capture station')
  -- Make the recorded height higher than the ship and add a second stop.
  check(api.editStop(1,{y=108,yTolerance=0.5,main=8,fine=7,wait=0,station=true,radius=1.5}),'stop edit')
  check(api.addRoute(50,0,'Next',1),'next stop creation')
  check(api.flyRouteFrom(1),'navigate station')
  for i=1,140 do os.pullEventRaw('timer') end
  local s=api.snapshot()
  check(s.routeIndex==1 and s.heightGood==false,'height mismatch should block station')
  check(s.heightError==8,'Y delta should be +8, got '..tostring(s.heightError))
  check(s.altitudeAssist==false,'height assist must default OFF')
  check(api.altitudeSetting('assist'),'enable opt-in altitude assist')
  for i=1,140 do os.pullEventRaw('timer') end
  s=api.snapshot()
  check(s.routeIndex==1,'auto assist must NOT skip station Y')
  check(s.outputs.main>8 or s.outputs.fine>7,'altitude assist must raise configured signal when Y low')
  check(api.altitudeSetting('direction'),'invert rise polarity')
  check(api.snapshot().altRiseSign==-1,'rise polarity flip missing')
  for i=1,120 do os.pullEventRaw('timer') end
  s=api.snapshot()
  check(s.outputs.main<=8 and s.outputs.fine<=7,'negative polarity should decrease output')
  check(api.setPower('main',10),'manual normal lift')
  check(api.snapshot().altitudeAssist==false,'manual lift action must disable auto trim')
  check(api.snapshot().outputs.main==10,'manual lift level')
  check(not api.setPower('fine',16),'invalid strength accepted')
  check(api.setPower('fine',11),'manual fine lift')
  check(api.setPower('engine',7),'manual engine link level')
  check(api.snapshot().outputs.engine==7,'manual engine signal was not sent')
  check(api.acceptCurrentHeight(),'operator override available while stationary and docked X/Z')
  for i=1,220 do os.pullEventRaw('timer') end
  check(api.snapshot().routeIndex==2,'operator bypass should advance, respecting 1s stabilization')
  check(not api.snapshot().heightOverride,'operator bypass must expire on next leg')
  check(api.stop(),'stop')
  -- Y tolerance can solve small mismatches without changing saved target Y.
  check(api.flyRouteFrom(1),'resume first station')
  check(api.editStop(1,{yTolerance=10}),'change station Y tolerance')
  check(api.flyRouteFrom(1),'re-engage after editing')
  for i=1,230 do os.pullEventRaw('timer') end
  check(api.snapshot().routeIndex==2,'Y tolerance should permit docking when within 8 blocks')
 end}
end
local originalPrint=print
print=function()end
assert(loadfile('airship/autopilot.lua'))()
originalPrint('PASS power controls, bounded altitude feedback, operator Y override, Y tolerance')
