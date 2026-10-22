-- AIRSHIP AUTOPILOT | Avionics Navigation Edition
-- CC:Tweaked / Create: Avionics / Create: Aeronautics / Redstone Link Bridge
-- X/Z navigation only. No altitude/burner outputs or Xaero integration.
-- Named presets, persistent route/resume, separate Display Link renderer.
-- Keep a physical emergency propulsion cutoff; links retain output if
-- a computer is forcibly stopped, and manual transmitters can override it.

local CFG = {
  NAV_NAME = nil,             -- nil = autodetect across any side / wired modems
  BRIDGE_NAME = nil,
  TICK = 0.10,                 -- 10 Hz controller
  DISPLAY_NAME = nil,           -- nil = all connected Create Display Links
  DISPLAY_ENABLED = true,      -- runs in an independent event loop
  DISPLAY_PERIOD = 1.0,
  MONITOR_NAME = nil,           -- automatically use the largest connected monitor
  MONITOR_SCALE = 0.5,         -- more characters for the clickable UI
  UI_REFRESH_PERIOD = 0.3,    -- UI updates isolated from flight controller
  -- ENGINE WIRING: use a Create LAC INVERTED receiver, so the engine
  -- actually sees LOW when this network is HIGH. Autopilot sends HIGH
  -- when active, LOW when idle. A manual HIGH on the SAME network wins.
  -- Leave disabled until the receiver is inverted and wired correctly.
  ENGINE_AUTO = false,
  ENGINE_PERIOD = 0.5,
  -- Optional broadcast to a SECOND display computer using display_receiver.lua
  TELEMETRY_ENABLED = false,
  TELEMETRY_PERIOD = 1.0,
  TELEMETRY_PROTOCOL = "airship.ap.telemetry.v1",
  AUTO_MAP = true,

  -- Steering is ON/OFF (0 or 15); propulsion is analog (0-15).
  MAX_FORWARD = 15,
  MAX_REVERSE = 6,
  ARRIVAL_RADIUS = 20,
  ARRIVAL_SPEED = 1.25,
  OVERSHOOT_RADIUS = 50,
  OVERSHOOT_REVERSE = 4,
  PASS_RADIUS = 20,           -- intermediate waypoints: don't fully stop
  BRAKE_ACCEL = 2.2,         -- tune downward if stopping distances are too short
  BRAKE_MARGIN = 3,
  APPROACH_SPEED_CAP = 30,
  FINAL_APPROACH_SPEED = 4,
  APPROACH_BASE_POWER = 3,
  APPROACH_POWER_GAIN = 1.5,
  COAST_SPEED_BAND = 0.6,
  BRAKE_SPEED_TOLERANCE = 0.8,
  BRAKE_POWER_GAIN = 1.5,
  TURN_START = 14,
  TURN_STOP = 5,
  TURN_LOOKAHEAD = 0.5,
  TURN_CONTINUOUS = 65,
  TURN_PULSE_ON = 0.18,
  TURN_PULSE_OFF = 0.75,
  TURN_MEDIUM_ON = 0.30,
  TURN_MEDIUM_OFF = 0.40,
  REVERSE_STEER_DELAY = 0.8,
  TRIM_START = 2.5,
  TRIM_STABLE_SECONDS = 1.2,
  TRIM_MAX_TURN_RATE = 1.5,
  TRIM_PULSE_ON = 0.12,
  TRIM_PULSE_OFF = 2.0,

  -- Avionics getHeading(): 0=south, 90=east. Offset is local bow direction.
  -- Set once using C calibration or O/P manual changes. Saved across restarts.
  BOW_OFFSET = nil,
  INVERT_STEERING = false,
  CAL_FORWARD = 6,
  CAL_SETTLE = 2.0,
  CAL_PULSE = 4.0,
  CAL_COAST = 0.8,
  CAL_MAX_INITIAL_SPEED = 0.4,
  CAL_MIN_DISTANCE = 2.0,
  CAL_MAX_CARDINAL_ERROR = 25,
  CAL_MAX_YAW_CHANGE = 12,
}

local scriptDir = (fs and shell and shell.getRunningProgram)
  and fs.getDir(shell.getRunningProgram()) or ""
local function sibling(name)
  return fs.combine(scriptDir, name)
end
local settingsFile = sibling(".airship_avionics_burners_settings")
local routeFile = sibling(".airship_avionics_route")
local function readTable(path)
  if not fs.exists(path) then return nil end
  local h = fs.open(path, "r")
  if not h then return nil end
  local raw = h.readAll()
  h.close()
  local ok, result = pcall(textutils.unserialize, raw)
  if ok and type(result) == "table" then return result end
  return nil
end
local function writeTable(path, data)
  -- Disk or serialization errors must not terminate the flight-control loop.
  local ok, result, reason = pcall(function()
    local serialized = textutils.serialize(data)
    local h = fs.open(path, "w")
    if not h then return false, "cannot open " .. path end
    local written, writeError = pcall(function() h.write(serialized) end)
    pcall(function() h.close() end)
    if not written then return false, tostring(writeError) end
    return true
  end)
  if not ok then return false, tostring(result) end
  return result, reason
end
local function clamp(x, lo, hi) return math.max(lo, math.min(hi, x)) end
local function round(x) return math.floor(x + 0.5) end
local function wrap(x) return (x + 180) % 360 - 180 end
local function atan2(y, x)
  if math.atan2 then return math.atan2(y, x) end
  if x > 0 then return math.atan(y/x) end
  if x < 0 then return math.atan(y/x) + (y >= 0 and math.pi or -math.pi) end
  return (y > 0 and math.pi/2) or (y < 0 and -math.pi/2) or 0
end
local function distance(a,b)
  local dx,dz = a.x-b.x,a.z-b.z
  return math.sqrt(dx*dx+dz*dz)
end
local function pos(value)
  if type(value) ~= "table" then return nil end
  local x,y,z = tonumber(value.x),tonumber(value.y),tonumber(value.z)
  if not x or not z then return nil end
  return {x=x,y=y or 0,z=z}
end
local function cleanNumber(n)
  n=tonumber(n)
  return n and n == n and math.abs(n)<3e7 and n or nil
end

local settings=readTable(settingsFile)
if not settings then
  settings=readTable(sibling(".airship_autopilot_avionics_burners_calibration"))
    or readTable(sibling(".airship_autopilot_avionics_calibration"))
end
if settings then
  if type(settings.bowOffset)=="number" and settings.bowOffset%90==0 then
    CFG.BOW_OFFSET = settings.bowOffset%360
  end
  if type(settings.invertSteering)=="boolean" then
    CFG.INVERT_STEERING=settings.invertSteering
  end
  if type(settings.autoMap)=="boolean" then CFG.AUTO_MAP=settings.autoMap end
  if type(settings.engineAuto)=="boolean" then CFG.ENGINE_AUTO=settings.engineAuto end

end
local function saveSettings()
  return writeTable(settingsFile,{bowOffset=CFG.BOW_OFFSET,
    invertSteering=CFG.INVERT_STEERING,autoMap=CFG.AUTO_MAP,engineAuto=CFG.ENGINE_AUTO})
end

local CHANNELS = {
  left={"aeronautics:white_envelope","create:shaft"},
  right={"create:shaft","aeronautics:white_envelope"},
  forward={"create:shaft","quark:spruce_ladder"},
  reverse={"quark:spruce_ladder","create:shaft"},
  engine={"aeronautics:white_envelope","aeronautics:white_envelope"}, -- HIGH request via inverted LAC
}
local function matches(d, methods)
  if not d then return false end
  for _,method in ipairs(methods) do
    if type(d[method])~="function" then return false end
  end
  return true
end
local function discover(label, methods, desired, optional)
  if desired then
    local d=peripheral.wrap(desired)
    assert(matches(d,methods),label.." unavailable at "..desired)
    return d,desired
  end
  local found={}
  for _,name in ipairs(peripheral.getNames()) do
    local d=peripheral.wrap(name)
    if matches(d,methods) then found[#found+1]={d=d,name=name} end
  end
  if #found==0 then
    if optional then return nil,nil end
    error("No "..label.." detected; check wired modems",0)
  end
  if #found>1 then
    if optional then return nil,nil end
    error("Multiple "..label.." peripherals; set its NAME in CFG",0)
  end
  return found[1].d,found[1].name
end
local nav,navName=discover("Navigation Table",
  {"getHeading","getTablePosition","getTargetPosition"},CFG.NAV_NAME)
local bridge,bridgeName=discover("Redstone Link Bridge",
  {"sendLinkSignal","getLinkSignal"},CFG.BRIDGE_NAME)
-- Direct display calls are isolated in a separate coroutine. The flight
-- controller never invokes getSize(), update(), or other Display Link methods.
local displayLinks={}
if CFG.DISPLAY_ENABLED then
  for _,name in ipairs(peripheral.getNames()) do
    if not CFG.DISPLAY_NAME or CFG.DISPLAY_NAME==name then
      local d=peripheral.wrap(name)
      if matches(d,{"getSize","clear","setCursorPos","write","update"}) then
        displayLinks[#displayLinks+1]={name=name,p=d}
      end
    end
  end
end
-- The UI is redirected to an Advanced Monitor if one is available.
-- Display Links are NOT monitors: they remain independent telemetry outputs.
local nativeTerm=term.current()
local activeMonitorName=nil
local function findMonitor()
  local found={}
  for _,name in ipairs(peripheral.getNames()) do
    if (not CFG.MONITOR_NAME or CFG.MONITOR_NAME==name)
       and peripheral.hasType(name,"monitor") then
      local m=peripheral.wrap(name)
      if m and m.setTextScale and m.getSize then
        local ok=pcall(m.setTextScale,CFG.MONITOR_SCALE)
        if ok then
          local okSize,w,h=pcall(m.getSize)
          if okSize and w and h then
            found[#found+1]={name=name,monitor=m,area=w*h,w=w,h=h}
          end
        end
      end
    end
  end
  table.sort(found,function(a,b) return a.area>b.area end)
  return found[1]
end
local activeMonitor=findMonitor()
if activeMonitor then
  activeMonitorName=activeMonitor.name
end
-- Basalt manages its own monitor frame, not term.redirect(). The controller
-- never draws to a monitor or calls Basalt from its 10 Hz flight loop.
local telemetryModems={}
local function openTelemetryNetwork()
  if not CFG.TELEMETRY_ENABLED then return end
  if not rednet or not rednet.open then return end
  for _,name in ipairs(peripheral.getNames()) do
    local ok,kind=pcall(peripheral.getType,name)
    if ok and kind=="modem" then
      if pcall(rednet.open,name) then telemetryModems[#telemetryModems+1]=name end
    end
  end
end
openTelemetryNetwork()

local function shipPosition()
  local raw=nav.getTablePosition()
  if raw and raw.projected==false then error("Navigation position is not world-projected") end
  return assert(pos(raw),"Invalid navigation-table world position")
end
local function mapTarget() return pos(nav.getTargetPosition()) end
local function keyFor(p)
  return p and ("%.1f:%.1f:%.1f"):format(p.x,p.y,p.z) or nil
end
local function heading()
  local h=tonumber(nav.getHeading())
  if not h then error("Avionics getHeading() unavailable") end
  return CFG.BOW_OFFSET and wrap(h+CFG.BOW_OFFSET) or nil
end

local route={}
local routeData=readTable(routeFile) or {}
local nextWaypointId=math.max(1,math.floor(tonumber(routeData.nextId) or 1))
local function makeId()
  local id=nextWaypointId
  nextWaypointId=nextWaypointId+1
  return id
end
local rawRoute=routeData.points or routeData
if type(rawRoute)=="table" then
  for _,p in ipairs(rawRoute) do
    local x,z=cleanNumber(p.x),cleanNumber(p.z)
    if x and z and #route<100 then
      local id=tonumber(p.id)
      if not id or id<=0 then id=makeId()
      else nextWaypointId=math.max(nextWaypointId,id+1) end
      route[#route+1]={id=id,x=x,z=z,name=tostring(p.name or "")}
    end
  end
end
-- Loop mode is stored alongside waypoint progress, independently from
-- navigation settings. Older array-only route files default to one-shot.
local routeLoop=routeData.loop==true
local routeNext=clamp(math.floor(tonumber(routeData.nextIndex) or 1),
  1,math.max(1,#route))
if routeData.nextWaypointId then
  for i,p in ipairs(route) do
    if p.id==routeData.nextWaypointId then routeNext=i; break end
  end
end
local function saveRoute()
  local current=route[routeNext]
  return writeTable(routeFile,{version=3,points=route,
    loop=routeLoop,nextIndex=routeNext,
    nextWaypointId=current and current.id or nil,nextId=nextWaypointId})
end

local presetFile=sibling(".airship_avionics_presets")
local presets={}
local presetData=readTable(presetFile) or {}
for _,p in ipairs(presetData.points or presetData) do
  local x,z=cleanNumber(p.x),cleanNumber(p.z)
  if x and z and #presets<200 then
    presets[#presets+1]={x=x,z=z,name=tostring(p.name or "Waypoint")}
  end
end
local function savePresets()
  return writeTable(presetFile,{version=1,points=presets})
end

local mode="idle"   -- idle, map, direct, route, arrived, calibration
local screen="flight" -- flight, route, presets, settings, debug, prompt
local routeSelected=1
local presetSelected=1
local presetReturn="flight"
local routeIndex=routeNext
local directTarget=nil
local currentMap=nil
local lastMapKey=nil
local notice="Ready: G coords, R route, L presets"
local prompt=nil
local running=true
local outputs={}
local telemetry={}
local cal=nil
local lastDist,lastTick,lastErr,lastPos=nil,nil,nil,nil
local speed,closing,turnRate,along=0,0,0,0
local arrivalCount=0
local overshootReturn=false
local turnIntent,pulseStart,steeringLock=0,0,0
local trimStable,trimUntil,trimReady,trimDir=nil,0,0,0
local controlTicks=0
local controlError=nil
local engineFault=nil
local lastEngineFault=nil
local engineEverEnabled=false
-- Diagnostics are deliberately independent of peripheral displays.
-- Diagnostics are deliberately independent of Display Links and rednet.
-- The flight and UI loops use separate event queues (parallel API).
local debugFile=sibling("airship_autopilot_debug.log")
local flightStage="initializing"
local lastFlightCompleted=os.clock()
local flightTickStarted=os.clock()
local flightTickDuration=0
local lastLoggedStall=0
local mapPresent=false
local function trace(message)
  local stamp=("[%8.2f T%-6d %-11s SYS:%s %-18s] "):format(
    os.clock(), controlTicks, mode, "NAV", flightStage)
  pcall(function()
    -- Limit disk usage; retain the most recent section of the log.
    if fs.exists(debugFile) and fs.getSize(debugFile)>65536 then
      local old=fs.open(debugFile,"r")
      local contents=old and old.readAll() or ""
      if old then old.close() end
      local trimmed=contents:sub(-24576)
      local first=trimmed:find("\n",1,true)
      if first then trimmed=trimmed:sub(first+1) end
      local h=fs.open(debugFile,"w")
      if h then h.write("-- previous log truncated --\n"..trimmed); h.close() end
    end
    local h=fs.open(debugFile,"a")
    if h then h.writeLine(stamp..tostring(message)); h.close() end
  end)
end
local function reportControlError(context, err)
  local message = tostring(context)..": "..tostring(err)
  controlError = message:sub(1,220)
  trace("ERROR "..message)
  notice = "CONTROL ERROR: "..controlError
  -- This is a diagnostic, not a dependency. Do not let filesystem issues
  -- prevent the flight loop from continuing.
  pcall(function()
    local h=fs.open(sibling(".airship_autopilot_control_error"),"w")
    if h then h.write(message); h.close() end
  end)
end

local function send(channel,power)
  local v=clamp(round(power),0,15)
  if outputs[channel]==v then return end
  local c=assert(CHANNELS[channel])
  flightStage="send "..channel.."="..v
  bridge.sendLinkSignal(c[1],c[2],v)
  outputs[channel]=v
end
local function zeroHorizontal()
  for _,c in ipairs({"left","right","forward","reverse"}) do send(c,0) end
end
local function motionReset()
  lastDist,lastTick,lastErr,lastPos=nil,nil,nil,nil
  speed,closing,turnRate,along,arrivalCount=0,0,0,0,0
  overshootReturn=false
  turnIntent,pulseStart,steeringLock=0,0,0
  trimStable,trimUntil,trimReady,trimDir=nil,0,0,0
end
local function stopHorizontal(message)
  if mode=="route" then
    routeNext=clamp(routeIndex,1,math.max(1,#route))
    saveRoute()
  end
  zeroHorizontal()
  mode="idle"
  motionReset()
  telemetry={}
  if message then notice=message; trace("STOP "..message) end
end

local function currentTarget()
  if mode=="map" then return currentMap end
  if mode=="direct" then return directTarget end
  if mode=="route" then return route[routeIndex] end
  return nil
end
local function targetName(t)
  if mode=="route" then
    return t.name~="" and t.name or ("Waypoint "..routeIndex)
  end
  if mode=="map" then return "Map marker" end
  return t.name and t.name~="" and t.name or "Coordinates"
end
local function beginNavigation(kind,startAt)
  if CFG.BOW_OFFSET==nil then
    notice="Bow offset unset: C calibrate or O/P select orientation"
    return false
  end
  if kind=="route" and #route==0 then
    notice="Route empty. Press R then N to add waypoints"
    return false
  end
  if kind=="map" and not currentMap then
    notice="No valid marker in Navigation Table"
    return false
  end
  zeroHorizontal()
  motionReset()
  if kind=="route" then
    routeIndex=clamp(startAt or routeNext,1,#route)
    routeNext=routeIndex
    saveRoute()
  end
  mode=kind
  trace("BEGIN "..kind)
  notice=kind=="route" and ("Flying route "..routeIndex.."/"..#route)
    or kind=="map" and "Flying to map marker" or "Flying to coordinates"
  return true
end
local function activeDestination()
  local t=currentTarget()
  -- Y from entered coordinates and saved routes is intentionally ignored.
  -- Altitude changes ONLY through H / altitude hold controls.
  return t
end
local function steer(error,rate,now)
  local predicted=wrap(error+rate*CFG.TURN_LOOKAHEAD)
  local direction=predicted>0 and 1 or predicted<0 and -1 or 0
  local magnitude=math.abs(predicted)
  if now<trimUntil then
    if direction==trimDir and magnitude<CFG.TURN_START then return trimDir end
    trimUntil=0
  end
  if turnIntent~=0 and (magnitude<=CFG.TURN_STOP or direction~=turnIntent) then
    if direction~=turnIntent and magnitude>CFG.TURN_STOP then
      steeringLock=now+CFG.REVERSE_STEER_DELAY
    end
    turnIntent=0
  end
  if turnIntent==0 and now>=steeringLock and magnitude>=CFG.TURN_START then
    turnIntent=direction
    pulseStart=now
  end
  if turnIntent~=0 then
    trimStable=nil
    if magnitude>=CFG.TURN_CONTINUOUS then return turnIntent end
    local on,off=CFG.TURN_PULSE_ON,CFG.TURN_PULSE_OFF
    if magnitude>=35 then on,off=CFG.TURN_MEDIUM_ON,CFG.TURN_MEDIUM_OFF end
    return ((now-pulseStart)%(on+off)<on) and turnIntent or 0
  end
  if magnitude<CFG.TRIM_START or magnitude>=CFG.TURN_START
    or math.abs(rate)>CFG.TRIM_MAX_TURN_RATE then
    trimStable=nil
    return 0
  end
  if not trimStable then trimStable=now end
  if now>=trimReady and now-trimStable>=CFG.TRIM_STABLE_SECONDS then
    trimDir=direction
    trimUntil=now+CFG.TRIM_PULSE_ON
    trimReady=trimUntil+CFG.TRIM_PULSE_OFF
    trimStable=nil
    return direction
  end
  return 0
end

-- Calibration is required only to learn which ship-local cardinal axis is the
-- bow, NOT for altitude. Avionics' yaw cannot deduce actuator direction.
local function calibrateStart()
  stopHorizontal()
  mode="calibration"
  cal={phase="settle",startTime=os.clock(),p=shipPosition(),yaw=nav.getHeading()}
  notice="Calibration: settle then forward pulse"
end
local function calibrateStop(message)
  cal=nil
  stopHorizontal(message)
end
local function calibrateStep(now,p)
  if not cal then return end
  local elapsed=now-cal.startTime
  if cal.phase=="settle" then
    if elapsed<CFG.CAL_SETTLE then return end
    local drift=distance(cal.p,p)/math.max(elapsed,0.01)
    if drift>CFG.CAL_MAX_INITIAL_SPEED then
      calibrateStop("Calibration refused: vessel moving") return
    end
    if math.abs(wrap(nav.getHeading()-cal.yaw))>5 then
      calibrateStop("Calibration refused: vessel rotating") return
    end
    cal.p,cal.yaw=p,nav.getHeading()
    cal.phase,cal.startTime="pulse",now
    send("forward",CFG.CAL_FORWARD)
    return
  end
  if cal.phase=="pulse" then
    if elapsed<CFG.CAL_PULSE then return end
    send("forward",0)
    cal.phase,cal.startTime="coast",now
    return
  end
  if cal.phase~="coast" or elapsed<CFG.CAL_COAST then return end
  local travelled=distance(cal.p,p)
  if travelled<CFG.CAL_MIN_DISTANCE then
    calibrateStop("Calibration inconclusive: too little movement") return
  end
  if math.abs(wrap(nav.getHeading()-cal.yaw))>CFG.CAL_MAX_YAW_CHANGE then
    calibrateStop("Calibration inconclusive: rotated during test") return
  end
  local dx,dz=p.x-cal.p.x,p.z-cal.p.z
  local travelYaw=math.deg(atan2(dx,dz))
  local offset=wrap(travelYaw-cal.yaw)
  local best,err=nil,math.huge
  for _,o in ipairs({0,90,180,270}) do
    local e=math.abs(wrap(offset-o))
    if e<err then best,err=o,e end
  end
  if err>CFG.CAL_MAX_CARDINAL_ERROR then
    calibrateStop("Calibration ambiguous: use O/P to set bow") return
  end
  CFG.BOW_OFFSET=best
  saveSettings()
  calibrateStop("Bow set to "..best.." deg (saved)")
end

local function update(now)
  flightStage="read position"
  local p=shipPosition()
  telemetry.position=p
  -- A target inserted in the table may initiate map navigation, but should
  -- never override a programmed route or manual coordinate destination.
  -- Direct/route navigation must not depend on the presence of a map.
  -- Avoid querying the map peripheral when it cannot affect navigation.
  if mode=="map" or mode=="idle" or mode=="arrived" then
    flightStage="read map target"
    local mt=mapTarget()
    local mk=keyFor(mt)
    mapPresent=mt~=nil
    currentMap=mt
    if mk~=lastMapKey then
      trace(mt and ("MAP target="..mk) or "MAP target removed/unavailable")
      lastMapKey=mk
      if mode=="map" and not mt then
        -- Map flights have no destination when the marker is removed;
        -- stopping ONLY this mode is intentional. Other modes continue.
        stopHorizontal("Map removed: map navigation stopped")
      end
      if CFG.AUTO_MAP and mt and screen=="flight"
         and (mode=="idle" or mode=="arrived") then
        beginNavigation("map")
      end
    end
  end
  if mode=="calibration" then
    calibrateStep(now,p)
    return
  end
  if not (mode=="map" or mode=="direct" or mode=="route") then
    return
  end
  local t=activeDestination()
  if not t then stopHorizontal("Target unavailable") return end
  flightStage="read heading"
  local bow=heading()
  if not bow then stopHorizontal("Bow orientation unavailable") return end
  local dx,dz=t.x-p.x,t.z-p.z
  local goal=math.deg(atan2(dx,dz))
  local err=wrap(goal-bow)
  local dist=distance(p,t)
  local dt=lastTick and now-lastTick or 0
  local sampled=dt>=0.05 and dt<3 and lastDist~=nil
  if sampled then
    closing=closing*0.7+clamp((lastDist-dist)/dt,-60,60)*0.3
    if lastPos then
      speed=speed*0.7+clamp(distance(p,lastPos)/dt,0,60)*0.3
      local vx,vz=(p.x-lastPos.x)/dt,(p.z-lastPos.z)/dt
      local bowRad=math.rad(bow)
      local bodyForward=vx*math.sin(bowRad)+vz*math.cos(bowRad)
      along=along*0.7+clamp(bodyForward,-60,60)*0.3
    end
    if lastErr then
      turnRate=turnRate*0.7+clamp(wrap(err-lastErr)/dt,-180,180)*0.3
    end
  else
    speed,closing,turnRate,along=0,0,0,0
  end
  lastDist,lastTick,lastErr,lastPos=dist,now,err,p

  -- Fly THROUGH intermediate waypoints; do not brake to a full stop at each.
  -- Loop routes wrap after the last waypoint rather than entering ARRIVED.
  -- One-stop routes still use the usual arrival behavior: repeatedly
  -- reacquiring an already-reached destination would be unsafe.
  if mode=="route" and dist<=CFG.PASS_RADIUS
     and (routeIndex<#route or (routeLoop and #route>1)) then
    local previous=routeIndex
    routeIndex=routeIndex<#route and routeIndex+1 or 1
    routeNext=routeIndex
    saveRoute()
    notice=previous==#route and "Route loop completed; returning to stop 1"
      or ("Waypoint reached; next "..routeIndex.."/"..#route)
    trace("ROUTE advance "..previous.." -> "..routeIndex..(routeLoop and " loop" or ""))
    motionReset()
    zeroHorizontal()
    return
  end
  -- A 20-block arrival zone. We first shed momentum, then finish.
  -- No more forward propulsion once within the zone. If we pass the
  -- destination but remain within 50 blocks and it is behind the bow,
  -- reverse is the natural way to return without turning the vessel.
  if sampled and dist<=CFG.ARRIVAL_RADIUS and speed<=CFG.ARRIVAL_SPEED then
    arrivalCount=arrivalCount+1
  else arrivalCount=0 end
  if arrivalCount>=5 then
    zeroHorizontal()
    if mode=="route" then
      routeNext=routeIndex
      saveRoute()
    end
    mode="arrived"
    motionReset()
    notice="Arrived: within 20 blocks"
    return
  end

  local remain=math.max(0,dist-CFG.ARRIVAL_RADIUS)
  local safe=math.max(0,remain-CFG.BRAKE_MARGIN)
  local envelope=math.sqrt(2*CFG.BRAKE_ACCEL*safe)
  local final=math.min(CFG.FINAL_APPROACH_SPEED,
    math.sqrt(2*CFG.BRAKE_ACCEL*remain))
  local targetClosing=clamp(math.max(envelope,final),0,CFG.APPROACH_SPEED_CAP)
  if dist<=CFG.ARRIVAL_RADIUS then targetClosing=0 end
  local aerr=math.abs(err)
  -- Near-target overshoot: goal is behind and we are still moving forward.
  -- Reverse first, rather than spinning 180 degrees with forward thrust.
  local overshot=sampled and dist<=CFG.OVERSHOOT_RADIUS
    and aerr>=105 and closing< -0.3 and along>0.25
  if overshot then overshootReturn=true end
  -- Once returning backwards, keep the reverse maneuver active while the
  -- destination remains behind. Otherwise a velocity reversal could make
  -- the autopilot start turning away instead of completing its return.
  if dist<=CFG.ARRIVAL_RADIUS or dist>CFG.OVERSHOOT_RADIUS
    or aerr<85 then overshootReturn=false end
  local turn=overshootReturn and 0 or steer(err,turnRate,now)
  if CFG.INVERT_STEERING then turn=-turn end
  flightStage="steering outputs"
  send("left",turn<0 and 15 or 0)
  send("right",turn>0 and 15 or 0)
  local fwd,rev=0,0
  if overshootReturn then
    rev=clamp(round(CFG.OVERSHOOT_REVERSE + math.max(0,along-3)*0.3),
      2,CFG.MAX_REVERSE)
  elseif aerr<=70 then
    if closing>targetClosing+CFG.BRAKE_SPEED_TOLERANCE then
      rev=clamp(round(2+(closing-targetClosing)*CFG.BRAKE_POWER_GAIN),2,CFG.MAX_REVERSE)
    elseif dist>CFG.ARRIVAL_RADIUS
       and closing<targetClosing-CFG.COAST_SPEED_BAND then
      fwd=clamp(round(CFG.APPROACH_BASE_POWER
        +(targetClosing-closing)*CFG.APPROACH_POWER_GAIN),1,CFG.MAX_FORWARD)
      if aerr>35 then fwd=math.min(fwd,2)
      elseif aerr>16 then fwd=math.min(fwd,4) end
    end
  end
  if dist<=CFG.ARRIVAL_RADIUS then fwd=0 end
  flightStage="throttle outputs"
  send("forward",fwd)
  send("reverse",rev)
  telemetry.distance=dist
  telemetry.error=err
  telemetry.speed=speed
  telemetry.closing=closing
  telemetry.target=t
  telemetry.label=targetName(t)
  telemetry.goal=goal
  telemetry.bow=bow
end

-- Engine requests are simple OR-able HIGH signals. With an LAC inverted
-- receiver: network HIGH (15) -> receiver LOW -> physical engine ON.
-- Autopilot active: transmit 15; idle/stopped: transmit 0.
-- A manual transmitter on this SAME frequency can send 15 to force ON.
-- The controller never sends OFF (15) directly to an uninverted receiver.
-- When automation is switched off, release our previous HIGH request.
local function engineStep()
  if not CFG.ENGINE_AUTO and not engineEverEnabled then return end
  local active=CFG.ENGINE_AUTO and
    (mode=="map" or mode=="direct" or mode=="route" or mode=="calibration")
  -- Deassert engine request when inactive or automation was disabled.
  send("engine",active and 15 or 0)
  engineEverEnabled=CFG.ENGINE_AUTO
end
local function engineLoop()
  local timer=os.startTimer(0)
  while running do
    local ev,id=os.pullEventRaw("timer")
    if ev=="timer" and id==timer then
      local ok,err=pcall(engineStep)
      if not ok then
        engineFault=tostring(err)
        -- Fail low: never retain a forced engine ON from a broken script.
        CFG.ENGINE_AUTO=false
        pcall(function() outputs.engine=nil; send("engine",0) end)
        if lastEngineFault~=engineFault then
          trace("ENGINE automation disabled: "..engineFault)
          notice="ENGINE ERROR: see diagnostics"
          lastEngineFault=engineFault
        end
      else
        engineFault=nil
      end
      timer=os.startTimer(CFG.ENGINE_PERIOD)
    end
  end
end

-- Non-blocking telemetry transport. Rendering to Create Display Links is
-- optional for a second display computer (the local display worker is
-- independent of the flight timer).
local lastTelemetry=0
local telemetryNetworkError=nil
local function sendTelemetry(now)
  if not CFG.TELEMETRY_ENABLED then return end
  if #telemetryModems==0 or not rednet or not rednet.broadcast then return end
  if now-lastTelemetry<CFG.TELEMETRY_PERIOD then return end
  lastTelemetry=now
  local t=telemetry
  local msg={
    tick=controlTicks, mode=mode,
    routeIndex=routeIndex, routeCount=#route, routeLoop=routeLoop,
    position=t.position, target=t.target,
    label=t.label, distance=t.distance, error=t.error,
    speed=t.speed, closing=t.closing,
    outputs={forward=outputs.forward or 0, reverse=outputs.reverse or 0,
      left=outputs.left or 0, right=outputs.right or 0},
  }
  local ok,err=pcall(rednet.broadcast,msg,CFG.TELEMETRY_PROTOCOL)
  if not ok then telemetryNetworkError=tostring(err) end
end

-- Compact mouse-aware TUI with CC:Tweaked colored buttons.
-- A standard computer displays the same palette in grayscale; an Advanced
-- Computer (or Advanced Monitor when redirected) displays all 16 colors.
-- Text, foreground, and background buffers are cached to avoid flicker.
local lastLines,hitboxes={},{}
-- Basalt owns rendering and mouse events. Settings changes preserve the
-- existing navigation calibration and engine options without touching flight
-- timer ownership.
local function keySettings(k)
  if k=="o" or k=="p" then
    stopHorizontal("Bow changed; resume navigation")
    CFG.BOW_OFFSET=((CFG.BOW_OFFSET or (k=="o" and -90 or 0))
      +(k=="o" and 90 or 180))%360
    saveSettings()
    notice="Bow offset: "..CFG.BOW_OFFSET.." deg saved"
  elseif k=="i" then
    stopHorizontal("Steering changed; resume navigation")
    CFG.INVERT_STEERING=not CFG.INVERT_STEERING
    saveSettings()
    notice="Steering: "..(CFG.INVERT_STEERING and "REVERSED" or "NORMAL")
  elseif k=="j" then
    CFG.ENGINE_AUTO=not CFG.ENGINE_AUTO
    saveSettings()
    notice=CFG.ENGINE_AUTO and "Engine automation ON (inverted LAC)" or "Engine automation disabled"
    trace("Engine automation "..tostring(CFG.ENGINE_AUTO))
  elseif k=="y" then
    CFG.AUTO_MAP=not CFG.AUTO_MAP
    saveSettings()
    notice="Auto map: "..(CFG.AUTO_MAP and "ON" or "OFF")
  end
end

-- Flight/persistence adapter for Basalt. UI callbacks do not own any
-- propulsion or navigation timers. No coordinates are persisted outside the
-- existing per-script route, preset and calibration files.
local controller={monitor=activeMonitor and activeMonitor.monitor or nil,
  monitorName=activeMonitorName}
local function validDestination(x,z)
  x,z=cleanNumber(x),cleanNumber(z)
  if not x or not z then return nil,nil,"World X and Z must be finite coordinates" end
  return x,z
end
function controller.setPage(name)
  -- Prevent automatic map engagement while editing waypoints/settings.
  screen=(name=="FLIGHT") and "flight" or tostring(name or ""):lower()
end
function controller.snapshot()
  return {mode=mode,notice=notice,position=telemetry.position,
    target=telemetry.target,label=telemetry.label,distance=telemetry.distance,
    error=telemetry.error,speed=telemetry.speed,outputs=outputs,
    route=route,routeNext=routeNext,routeIndex=routeIndex,
    routeLoop=routeLoop,presets=presets,
    bowOffset=CFG.BOW_OFFSET,invertSteering=CFG.INVERT_STEERING,
    autoMap=CFG.AUTO_MAP,engineAuto=CFG.ENGINE_AUTO,
    tick=controlTicks,tickAge=os.clock()-lastFlightCompleted,
    tickDuration=flightTickDuration,stage=flightStage,controlError=controlError,
    navName=navName,bridgeName=bridgeName,displayLinks=#displayLinks}
end
function controller.fly(x,z,name)
  local err; x,z,err=validDestination(x,z)
  if not x then return false,err end
  directTarget={x=x,z=z,name=tostring(name or "")}
  if not beginNavigation("direct") then return false,notice end
  return true
end
function controller.flyMap()
  local ok,dst=pcall(mapTarget)
  if not ok then return false,"Could not read Navigation Table: "..tostring(dst) end
  currentMap=dst
  if not beginNavigation("map") then return false,notice end
  return true
end
function controller.stop()
  if mode=="calibration" then cal=nil end
  stopHorizontal("Navigation stopped by operator")
  return true
end
function controller.resumeRoute()
  if not beginNavigation("route") then return false,notice end
  return true
end
function controller.setRouteLoop(enabled)
  routeLoop=(enabled==true)
  local ok,err=saveRoute()
  if not ok then
    return false,"Unable to persist loop setting: "..tostring(err)
  end
  notice=routeLoop and "Route will repeat after the last waypoint"
    or "Route will stop at the last waypoint"
  trace("ROUTE looping "..(routeLoop and "ON" or "OFF"))
  return true
end
function controller.flyRouteFrom(index)
  index=tonumber(index)
  if not index or index%1~=0 or index<1 or index>#route then
    return false,"Select an existing route stop"
  end
  if not beginNavigation("route",index) then return false,notice end
  return true
end
function controller.addRoute(x,z,name,after)
  local err; x,z,err=validDestination(x,z)
  if not x then return false,err end
  if #route>=100 then return false,"Route is limited to 100 stops" end
  if mode=="route" then stopHorizontal("Route edited; press Resume") end
  local item={id=makeId(),x=x,z=z,name=tostring(name or "")}
  local idx=clamp(math.floor(tonumber(after) or #route)+1,1,#route+1)
  if #route>0 and idx<=routeNext then routeNext=routeNext+1 end
  table.insert(route,idx,item)
  routeNext=clamp(routeNext,1,#route)
  saveRoute();notice="Route stop added"
  return true
end
function controller.editRoute(index,x,z,name)
  local err; x,z,err=validDestination(x,z)
  if not x then return false,err end
  index=tonumber(index)
  if not index or not route[index] then return false,"Unknown route stop" end
  if mode=="route" then stopHorizontal("Route edited; press Resume") end
  local id=route[index].id
  route[index]={id=id,x=x,z=z,name=tostring(name or "")}
  saveRoute();notice="Route stop updated"
  return true
end
function controller.removeRoute(index)
  index=tonumber(index)
  if not index or not route[index] then return false,"Unknown route stop" end
  if mode=="route" then stopHorizontal("Route edited; press Resume") end
  table.remove(route,index)
  if index<routeNext then routeNext=routeNext-1 end
  routeNext=clamp(routeNext,1,math.max(1,#route))
  saveRoute();notice="Route stop deleted"
  return true
end
function controller.moveRoute(index,by)
  index=tonumber(index)
  local other=index and (index+by)
  if not other or other<1 or other>#route then return index end
  if mode=="route" then stopHorizontal("Route reordered; press Resume") end
  if routeNext==index then routeNext=other
  elseif routeNext==other then routeNext=index end
  route[index],route[other]=route[other],route[index]
  saveRoute();notice="Route stop moved"
  return other
end
function controller.addPreset(x,z,name)
  local err; x,z,err=validDestination(x,z)
  if not x then return false,err end
  if #presets>=200 then return false,"200 preset limit" end
  presets[#presets+1]={x=x,z=z,
    name=name and name~="" and tostring(name) or ("Waypoint "..#presets+1)}
  savePresets();notice="Preset saved"
  return true
end
function controller.editPreset(index,x,z,name)
  local err; x,z,err=validDestination(x,z)
  if not x then return false,err end
  index=tonumber(index)
  if not index or not presets[index] then return false,"Unknown preset" end
  presets[index]={x=x,z=z,name=tostring(name or "")}
  savePresets();notice="Preset updated"
  return true
end
function controller.removePreset(index)
  index=tonumber(index)
  if not index or not presets[index] then return false,"Unknown preset" end
  table.remove(presets,index)
  savePresets();notice="Preset deleted"
  return true
end
function controller.capturePreset()
  local ok,p=pcall(shipPosition)
  if not ok then return false,"Position unavailable: "..tostring(p) end
  local x,z=round(p.x),round(p.z)
  return controller.addPreset(x,z,("Current %d,%d"):format(x,z))
end
function controller.flyPreset(index)
  local p=presets[tonumber(index) or -1]
  if not p then return false,"Select a preset" end
  return controller.fly(p.x,p.z,p.name)
end
function controller.presetToRoute(index)
  local p=presets[tonumber(index) or -1]
  if not p then return false,"Select a preset" end
  return controller.addRoute(p.x,p.z,p.name,#route)
end
function controller.setting(id)
  local map={bow90="o",bow180="p",invert="i",autoMap="y",engineAuto="j"}
  if not map[id] then return false,"Unknown setting" end
  keySettings(map[id]);return true
end
function controller.calibrate()
  local ok,err=pcall(calibrateStart)
  if not ok then return false,tostring(err) end
  return true
end
local function uiBasaltLoop()
  -- CraftOS shell-injected require resolves ./ui.lua and ./basalt.lua beside
  -- this running autopilot.lua (same loading mechanism as the factory app).
  require("ui").run(controller)
  running=false
end

-- Independent CC:Tweaked event loops: the UI always remains responsive, and
-- main-thread peripheral calls cannot consume the NEXT flight timer event.
-- This preserves the timer fix from the T10 freeze on target changes.
local function flightLoop()
  local timer=os.startTimer(0)
  while running do
    local ev,id=os.pullEventRaw("timer")
    if ev=="timer" and id==timer then
      controlTicks=controlTicks+1
      flightTickStarted=os.clock()
      flightStage="update"
      local stepOk,stepError=pcall(update,flightTickStarted)
      if not stepOk then
        reportControlError("NAV",stepError)
        pcall(function() stopHorizontal("NAV ERROR: "..tostring(stepError)) end)
      end
      flightTickDuration=os.clock()-flightTickStarted
      lastFlightCompleted=os.clock()
      flightStage="waiting for timer"
      if controlTicks%50==0 then
        trace(("HEARTBEAT tick took %.3fs; position %s; map %s"):format(
          flightTickDuration,telemetry.position and
            ("X%.1f Y%.1f Z%.1f"):format(telemetry.position.x,telemetry.position.y,telemetry.position.z) or "?",
          mapPresent and "yes" or "no"))
      end
      -- Never render (or call a monitor) on the flight-control coroutine.
      -- Critical: schedule AFTER all potentially yielding peripheral calls.
      -- Arm-before-update caused the next timer to be lost to task_complete.
      timer=os.startTimer(CFG.TICK)
    end
  end
end

local function watchdogLoop()
  local timer=os.startTimer(1)
  while running do
    local ev,id=os.pullEventRaw("timer")
    if ev=="timer" and id==timer then
      local age=os.clock()-lastFlightCompleted
      if age>2.5 and os.clock()-lastLoggedStall>4 then
        lastLoggedStall=os.clock()
        trace(("STALL %.1fs since completed tick; stage=%s"):format(age,flightStage))
        notice=("FLIGHT DELAY %.1fs at %s"):format(age,flightStage)
      end
      timer=os.startTimer(1)
    end
  end
end
local function displayLines(maxRows)
  local t=telemetry
  local status=mode=="route" and ("ROUTE "..routeIndex.."/"..#route
    ..(routeLoop and " LOOP" or "")) or mode:upper()
  local name=t.label or "--"
  local headingError=t.error and ("E%+.0f"):format(t.error) or ""
  local dist=t.distance and ("D%.0f"):format(t.distance) or ""
  local drive=("F%02d B%02d"):format(outputs.forward or 0,outputs.reverse or 0)
  local title=("AP %s %s"):format(status,dist)
  if maxRows<=1 then return {title} end
  if maxRows==2 then return {title,headingError.."  "..drive} end
  local lines={title}
  if t.target then
    lines[#lines+1]="NEXT "..name
    lines[#lines+1]=("X%.0f Z%.0f %s"):format(t.target.x,t.target.z,headingError)
  end
  lines[#lines+1]=("SPD %.1f  %s"):format(t.speed or 0,drive)
  if t.position then
    lines[#lines+1]=("POS X%.0f Z%.0f"):format(t.position.x,t.position.z)
  end
  return lines
end
local function displayLoop()
  local timer=os.startTimer(0)
  while running do
    local ev,id=os.pullEventRaw("timer")
    if ev=="timer" and id==timer then
      for _,link in ipairs(displayLinks) do
        -- getSize() returns rows, columns, in that order.
        local ok,err=pcall(function()
          if not link.rows then
            local rows,cols=link.p.getSize()
            link.rows=clamp(math.floor(tonumber(rows) or 2),1,24)
            link.cols=clamp(math.floor(tonumber(cols) or 30),1,128)
          end
          local rows,cols=link.rows,link.cols
          local lines=displayLines(rows)
          link.p.clear()
          for i=1,math.min(#lines,rows) do
            link.p.setCursorPos(1,i)
            link.p.write(lines[i]:sub(1,cols))
          end
          link.p.update()
        end)
        if not ok then
          if not link.lastError or link.lastError~=tostring(err) then
            trace("DISPLAY "..link.name.." ERROR "..tostring(err))
          end
          link.lastError=tostring(err)
        else link.lastError=nil end
      end
      timer=os.startTimer(CFG.DISPLAY_PERIOD)
    end
  end
end
local function telemetryLoop()
  local timer=os.startTimer(CFG.TELEMETRY_PERIOD)
  while running do
    local ev,id=os.pullEventRaw("timer")
    if ev=="timer" and id==timer then
      local ok,err=pcall(sendTelemetry,os.clock())
      if not ok then trace("TELEMETRY ERROR "..tostring(err)) end
      timer=os.startTimer(CFG.TELEMETRY_PERIOD)
    end
  end
end
local function main()
  zeroHorizontal()
  lastFlightCompleted=os.clock()
  trace("BOOT independent flight/UI/display loops; local displays="..#displayLinks)
  parallel.waitForAny(uiBasaltLoop, flightLoop, watchdogLoop,
    displayLoop, telemetryLoop, engineLoop)
end
local ok,err=xpcall(main,function(e)
  if debug and debug.traceback then return debug.traceback(tostring(e),2) end
  return tostring(e)
end)
-- Shut down horizontal control; this version NEVER changes gas burners.
for _,c in ipairs({"left","right","forward","reverse"}) do
  pcall(function() outputs[c]=nil; send(c,0) end)
end
-- Release autopilot's HIGH request on shutdown. The inverted LAC receiver
-- then turns the engine OFF unless a manual HIGH transmitter still holds it ON.
if CFG.ENGINE_AUTO or engineEverEnabled or outputs.engine~=nil then
  pcall(function() outputs.engine=nil; send("engine",0) end)
end
-- Restore the local computer terminal, not the Basalt monitor frame.
if term.redirect then term.redirect(nativeTerm) end
if term.setCursorBlink then term.setCursorBlink(false) end
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1,1)
if ok then
  trace("SHUTDOWN normal")
  print("Autopilot off. Horizontal propulsion reset.")
else
  trace("FATAL "..tostring(err))
  print("Autopilot error: "..tostring(err))
  print("Horizontal output reset. Gas burners unaffected.")
  pcall(function()
    local h=fs.open(sibling(".airship_autopilot_last_error"),"w")
    if h then h.write(tostring(err)); h.close() end
  end)
end