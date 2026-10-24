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
local ship={x=0,z=0}
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
 getTablePosition=function()return{x=ship.x,y=100,z=ship.z,projected=true}end,
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
   local function check(ok,msg)assert(ok,msg)end
   local s=api.snapshot()
   check(#s.savedRoutes==1,'legacy route not imported')
   check(s.route[1].name=='Old','legacy waypoint lost')
   check(api.createRoute('Ferry Run',false),'create route failed')
   check(api.snapshot().routeName=='Ferry Run','new route not selected')
   ship.x=120;ship.y=90;ship.z=-65;ship.heading=90
   check(api.recordWaypoint('Dock Alpha',true),'recording failed')
   local p=api.snapshot().route[1]
   check(p.x==120 and p.y==90 and p.z==-65 and p.heading==90,'position/heading not recorded')
   check(p.main==8 and p.fine==6 and p.station,'manual lift signals not recorded')
   check(api.editStop(1,{wait=1.5,radius=1,main=9,fine=7,station=true}),'edit stop failed')
   check(api.addRoute(140,-65,'Second stop',1),'second stop failed')
   check(api.setRouteLoop(true),'loop enable failed')
   -- invalid strength/frequency mappings should be rejected.
   check(api.setSignal('forward','minecraft:diamond','minecraft:redstone'),'custom forward signal')
   check(not api.setSignal('left','minecraft:diamond','minecraft:redstone'),'duplicate freq accepted')
   check(not api.setSignal('main','invalid freq','minecraft:redstone'),'invalid freq accepted')
   local drives=api.listDisks()
   check(#drives==1 and drives[1].mount=='disk','disk discovery failed')
   check(api.exportRoute('drive_0',api.snapshot().routeKey),'route export failed')
   check(not api.exportRoute('drive_0',api.snapshot().routeKey),'overwriting floppy route allowed')
   check(api.importRoutes('drive_0'),'import failed')
   check(#api.snapshot().savedRoutes==3,'import did not add route')
   check(api.snapshot().routeName=='Ferry Run','import changed active route')
   check(api.selectRoute('route-1'),'select original failed')
   check(api.snapshot().route[1].name=='Old','original route lost')
   local current
   for _,r in ipairs(api.snapshot().savedRoutes) do if r.name=='Ferry Run' then current=r.key end end
   check(current and api.selectRoute(current),'switch back failed')
   check(api.snapshot().route[1].station and api.snapshot().routeLoop,'station/loop not preserved')
   -- Docking cannot pass when the Y coordinate differs, even when X/Z match.
   ship.y=93
   check(api.flyRouteFrom(1),'start route failed')
   for i=1,70 do os.pullEventRaw('timer') end
   check(api.snapshot().routeIndex==1,'advanced despite Y mismatch')
   ship.y=90
   for i=1,150 do os.pullEventRaw('timer') end
   local endState=api.snapshot()
   check(endState.routeIndex==2,'station did not advance after 1.5s dwell')
   check((endState.outputs.main or 0)==9 and (endState.outputs.fine or 0)==7,
     'route lift outputs wrong')
   check(type(endState.error)=='number','heading error not numeric')
   check(api.stop(),'stop failed')
   check(files['airship/.airship_route_library']~=nil,'library not persisted')
   check(api.snapshot().routeNext==2,'next waypoint not saved')
   lastSnapshot=endState
 end}
end
local originalPrint=print
print=function()end
local chunk=assert(loadfile('airship/autopilot.lua'))
chunk()
originalPrint('PASS airship route features: legacy migration, capture, altitude, stations, wait, channels, library, floppy')
