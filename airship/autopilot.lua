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
  pcall(function()
    nativeTerm.setCursorPos(1,1)
    nativeTerm.clear()
    nativeTerm.write("Airship UI: "..activeMonitorName)
    nativeTerm.setCursorPos(1,2)
    nativeTerm.write("Input remains on computer")
  end)
  term.redirect(activeMonitor.monitor)
end
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
local routeNext=clamp(math.floor(tonumber(routeData.nextIndex) or 1),
  1,math.max(1,#route))
if routeData.nextWaypointId then
  for i,p in ipairs(route) do
    if p.id==routeData.nextWaypointId then routeNext=i; break end
  end
end
local function saveRoute()
  local current=route[routeNext]
  return writeTable(routeFile,{version=2,points=route,
    nextIndex=routeNext,nextWaypointId=current and current.id or nil,
    nextId=nextWaypointId})
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
  if mode=="route" and routeIndex<#route and dist<=CFG.PASS_RADIUS then
    routeIndex=routeIndex+1
    routeNext=routeIndex
    saveRoute()
    notice=("Waypoint reached; next "..routeIndex.."/"..#route)
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
    routeIndex=routeIndex, routeCount=#route,
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
local uiColor=(type(term.isColor)=="function" and term.isColor()) or false
local UI = {
  background=colors.black, text=colors.lightGray, muted=colors.gray,
  titleText=colors.white, titleBackground=colors.blue,
  accent=colors.cyan, good=colors.lime, warning=colors.orange,
  selectedText=colors.black, selectedBackground=colors.lightBlue,
}
local function line(s)
  return tostring(s or "")
end
local function buttonColors(action)
  if screen=="settings" and action=="y" and CFG.AUTO_MAP then
    return colors.black,colors.lime
  end
  if action=="s" and screen=="flight" or action=="q"
      or action=="d" and (screen=="route" or screen=="presets")
      or action=="x" or action=="cancel" or action=="stop" then
    return colors.white,colors.red
  end
  if action=="submit" or action=="g" and screen=="presets"
      or action=="p" and screen=="route" or action=="s" and screen=="route" then
    return colors.black,colors.lime
  end
  if action:sub(1,3)=="kp:" or action=="list_up" or action=="list_down" then
    return colors.black,colors.lightBlue
  end
  if action=="g" or action=="m" or action=="r" or action=="l"
      or action=="n" or action=="a" or action=="e" then
    return colors.white,colors.blue
  end
  if action=="c" or action=="o" or action=="p" or action=="i"
      or action=="u" or action=="f" then
    return colors.black,colors.orange
  end
  return colors.white,colors.gray
end
local function setupUi()
  hitboxes={}
  local rows={}
  local w,h=term.getSize()
  local function add(s,role)
    rows[#rows+1]={text=line(s),role=role or "text",buttons={}}
    return #rows
  end
  local function bar(options)
    local fragments,buttons={},{}
    local x=1
    local function flush()
      if #fragments==0 then return end
      local y=add(table.concat(fragments,"  "),"toolbar")
      for _,button in ipairs(buttons) do
        button.y=y
        rows[y].buttons[#rows[y].buttons+1]=button
        hitboxes[#hitboxes+1]=button
      end
      fragments,buttons={},{}
      x=1
    end
    for _,option in ipairs(options) do
      local label=("[%s]"):format(option[1])
      if #label>w then label=label:sub(1,w) end
      if x>1 and x+#label-1>w then flush() end
      fragments[#fragments+1]=label
      buttons[#buttons+1]={x1=x,x2=x+#label-1,action=option[2]}
      x=x+#label+2
    end
    flush()
  end
  local hr=string.rep("-",math.max(0,math.min(w,36)))
  if screen=="flight" then
    local state=(mode=="route") and ("ROUTE "..routeIndex.."/"..#route) or mode:upper()
    add("AIRSHIP  "..state..(CFG.ENGINE_AUTO and "  ENG:AUTO" or ""),"title")
    add(hr,"rule")
    local p=telemetry.position
    if p then add(("POS X%.0f Y%.0f Z%.0f"):format(p.x,p.y,p.z),"position")
    else add("POS --","muted") end
    if telemetry.target then
      add("NEXT "..(telemetry.label or "Target"):sub(1,23),"target")
      add(("X%.0f Z%.0f  DIST %.0f"):format(
        telemetry.target.x,telemetry.target.z,telemetry.distance or 0),"target")
      add(("ERR %+.1f  SPD %.1f"):format(telemetry.error or 0,telemetry.speed or 0))
    else
      add("NEXT none","muted")
      add("DEST Enter coords, map or route","muted")
    end
    add(("DRIVE F%02d B%02d L%02d R%02d"):format(outputs.forward or 0,
      outputs.reverse or 0,outputs.left or 0,outputs.right or 0))
    add(hr,"rule")
    bar({{"G Coords","g"},{"M Map","m"},{"R Route","r"}})
    bar({{"L Presets","l"},{"S Stop","s"},{"T Settings","t"}})
    bar({{"D Debug","debug"}})
    add("INFO "..notice,"notice")
  elseif screen=="settings" then
    add("SETTINGS","title")
    add(hr,"rule")
    add("Bow: "..(CFG.BOW_OFFSET and (CFG.BOW_OFFSET.." deg") or "unset"))
    add("Steering: "..(CFG.INVERT_STEERING and "REVERSED" or "NORMAL"))
    add("Auto map: "..(CFG.AUTO_MAP and "ON" or "OFF"))
    add("Engine auto: "..(CFG.ENGINE_AUTO and "ON" or "OFF"))
    add("Engine link: HIGH=ON via inverted LAC", "muted")
    add("Local display: "..#displayLinks.." link(s)","muted")
    add(("Max forward %d  reverse %d"):format(CFG.MAX_FORWARD,CFG.MAX_REVERSE))
    add(hr,"rule")
    bar({{"O Bow +90","o"},{"P Flip 180","p"}})
    bar({{"I Invert steer","i"},{"C Calibrate","c"}})
    bar({{"Y Auto-map","y"},{"J Engine auto","engine"}})
    bar({{"Back","back"}})
    add("INFO "..notice,"notice")
  elseif screen=="debug" then
    add("FLIGHT DIAGNOSTICS", "title")
    add(hr,"rule")
    add(("Tick %d | %s"):format(controlTicks,mode))
    add(("Last tick %.1fs ago"):format(os.clock()-lastFlightCompleted),"notice")
    add("Stage: "..flightStage,"notice")
    add(("Update time %.3fs"):format(flightTickDuration))
    add("Map "..(mapPresent and "present" or "absent"))
    add(("Bow %s | Nav %s"):format(tostring(CFG.BOW_OFFSET),navName or "?"))
    add(("F%02d B%02d L%02d R%02d"):format(outputs.forward or 0,
      outputs.reverse or 0,outputs.left or 0,outputs.right or 0))
    add("Display Links: "..#displayLinks)
    add("UI: "..(activeMonitorName or "computer"))
    add("Engine: "..(CFG.ENGINE_AUTO and "AUTO" or "MANUAL")..
      " (TX="..tostring(outputs.engine or 0)..")")
    if controlError then add("ERROR: "..controlError:sub(1,100),"notice") end
    add("Log: "..debugFile,"muted")
    add(hr,"rule")
    bar({{"Back","back"},{"S Stop","s"},{"X Clear log","x"}})
  elseif screen=="route" then
    add(("ROUTE  |  %d stops | NEXT %d"):format(#route,routeNext),"title")
    add("Click stop to select; P resumes","muted")
    add(hr,"rule")
    bar({{"^ Up","list_up"},{"v Down","list_down"}})
    local n=math.max(1,h-11)
    local start=clamp(routeSelected-math.floor(n/2),1,
      math.max(1,#route-n+1))
    for i=start,math.min(#route,start+n-1) do
      local p=route[i]
      local status=(i==routeNext and "*" or " ")
      local text=("%s%s%02d %-12s %d,%d"):format(i==routeSelected and ">" or " ",
        status,i,(p.name~="" and p.name or "Waypoint"):sub(1,12),round(p.x),round(p.z))
      local y=add(text,i==routeSelected and "selected" or "text")
      hitboxes[#hitboxes+1]={x1=1,x2=w,y=y,action="pick:"..i}
    end
    if #route==0 then add("(Empty route)","muted") end
    add("")
    bar({{"N Add","n"},{"L Presets","l"},{"E Edit","e"},{"D Del","d"}})
    bar({{"U Up","u"},{"F Down","f"},{"X Clear","x"}})
    bar({{"P Resume","p"},{"S From here","s"},{"Back","back"}})
    add("INFO "..notice,"notice")
  elseif screen=="presets" then
    add(("PRESET WAYPOINTS  |  %d saved"):format(#presets),"title")
    add("G fly directly  |  A add to route","muted")
    add(hr,"rule")
    bar({{"^ Up","list_up"},{"v Down","list_down"}})
    local n=math.max(1,h-11)
    local start=clamp(presetSelected-math.floor(n/2),1,
      math.max(1,#presets-n+1))
    for i=start,math.min(#presets,start+n-1) do
      local p=presets[i]
      local text=("%s%02d %-13s %d,%d"):format(i==presetSelected and ">" or " ",
        i,(p.name or "Waypoint"):sub(1,13),round(p.x),round(p.z))
      local y=add(text,i==presetSelected and "selected" or "text")
      hitboxes[#hitboxes+1]={x1=1,x2=w,y=y,action="preset:"..i}
    end
    if #presets==0 then add("(No saved presets)","muted") end
    add("")
    bar({{"N Save pos","n"},{"C Add coords","c"},{"E Edit","e"}})
    bar({{"G Fly","g"},{"A To route","a"},{"D Delete","d"}})
    bar({{"Back","back"}})
    add("INFO "..notice,"notice")
  else -- prompt
    add("ENTER "..prompt.title,"title")
    add(hr,"rule")
    add(prompt.help or "","muted")
    add(prompt.error or "","notice")
    -- Keep the editable end in view when the input is wider than the terminal.
    local visible = math.max(1,w-3)
    add("> "..prompt.input:sub(-visible),"prompt")
    if prompt.numeric then
      bar({{"7","kp:7"},{"8","kp:8"},{"9","kp:9"},{"DEL","kp:del"}})
      bar({{"4","kp:4"},{"5","kp:5"},{"6","kp:6"},{"-","kp:-"}})
      bar({{"1","kp:1"},{"2","kp:2"},{"3","kp:3"},{".","kp:."}})
      bar({{"X/Z","kp:space"},{"0","kp:0"},{"CLR","kp:clear"}})
    end
    bar({{"OK","submit"},{"Cancel","cancel"},{"Stop","stop"}})
    add("INFO "..notice,"notice")
  end
  return rows
end
local function rowColors(row)
  if row and row.role=="title" then return UI.titleText,UI.titleBackground end
  if row and row.role=="selected" then
    return UI.selectedText,UI.selectedBackground
  end
  if row and row.role=="rule" then return UI.muted,UI.background end
  if row and row.role=="muted" or row and row.role=="notice" then
    return UI.muted,UI.background
  end
  if row and row.role=="target" then return UI.warning,UI.background end
  if row and row.role=="position" or row and row.role=="prompt" then
    return UI.accent,UI.background
  end
  return UI.text,UI.background
end
local function paint(rows)
  local w,h=term.getSize()
  for y=1,h do
    local row=rows[y]
    local txt=tostring(row and row.text or ""):sub(1,w)
    txt=txt..string.rep(" ",math.max(0,w-#txt))
    local fore,back=rowColors(row)
    local fg=string.rep(colors.toBlit(fore),w)
    local bg=string.rep(colors.toBlit(back),w)
    if row then
      for _,button in ipairs(row.buttons) do
        local btnFore,btnBack=buttonColors(button.action)
        if not uiColor then
          -- Keep buttons distinct and high-contrast on normal computers.
          btnFore,btnBack=colors.black,colors.lightGray
          if button.action=="s" or button.action=="q"
              or button.action=="cancel" or button.action=="stop" then
            btnFore,btnBack=colors.white,colors.gray
          end
        end
        local start=clamp(button.x1,1,w)
        local stop=clamp(button.x2,1,w)
        if start<=stop then
          local count=stop-start+1
          fg=fg:sub(1,start-1)..string.rep(colors.toBlit(btnFore),count)..fg:sub(stop+1)
          bg=bg:sub(1,start-1)..string.rep(colors.toBlit(btnBack),count)..bg:sub(stop+1)
        end
      end
    end
    local cache=txt.."|"..fg.."|"..bg
    if cache~=lastLines[y] then
      term.setCursorPos(1,y)
      if term.blit then term.blit(txt,fg,bg)
      else term.setTextColor(fore); term.setBackgroundColor(back); term.write(txt) end
      lastLines[y]=cache
    end
  end
  for y=h+1,#lastLines do lastLines[y]=nil end
end
local function redraw()
  local rows=setupUi()
  paint(rows)
  if term.setCursorBlink then
    term.setCursorBlink(screen=="prompt")
    if screen=="prompt" then
      local w=term.getSize()
      term.setCursorPos(math.min(w,3+math.min(#prompt.input,math.max(1,w-3))),5)
    end
  end
end

-- Prompts never suspend the 10Hz navigation control loop.
local function openPrompt(kind,title,help,initial)
  screen="prompt"
  local numerical={coords=true,add=true,edit=true,preset_add=true,preset_edit=true}
  prompt={kind=kind,title=title,help=help,input=initial or "",error=nil,
    numeric=numerical[kind]==true}
end
local function editWaypoints()
  if mode=="calibration" then notice="Calibration running; press S to abort" return end
  stopHorizontal("Route editor: horizontal thrust stopped")
  routeSelected=clamp(routeSelected,1,math.max(1,#route))
  screen="route"
end
local function parseWaypoint(input)
  -- Numeric X/Y/Z is allowed as input for compatibility; Y is ignored.
  local tok={}
  for word in input:gmatch("%S+") do tok[#tok+1]=word end
  local x,b=cleanNumber(tok[1]),cleanNumber(tok[2])
  if not x or not b then return nil,"Enter X Z or X Y Z" end
  local c=cleanNumber(tok[3])
  local z,first=b,3
  if c then z,first=c,4 end
  local label={}
  for i=first,#tok do label[#label+1]=tok[i] end
  return {x=x,z=z,name=table.concat(label," ")}
end
local function routeAdd(point,editing)
  if editing then
    local old=route[routeSelected]
    if not old then return end
    point.id=old.id
    route[routeSelected]=point
    notice="Waypoint updated"
  else
    if #route>=100 then notice="Route limited to 100 waypoints" return end
    point.id=makeId()
    local index=clamp(routeSelected+1,1,#route+1)
    if #route>0 and index<=routeNext then routeNext=routeNext+1 end
    table.insert(route,index,point)
    routeSelected=index
    notice="Waypoint added to route"
  end
  routeNext=clamp(routeNext,1,math.max(1,#route))
  saveRoute()
end
local function presetAdd(point,editing)
  if editing then
    presets[presetSelected]=point
    notice="Preset updated"
  else
    if #presets>=200 then notice="Preset limit (200) reached" return end
    presets[#presets+1]=point
    presetSelected=#presets
    notice="Preset saved: "..point.name
  end
  savePresets()
end
local function openPresets(origin)
  presetReturn=origin or screen
  presetSelected=clamp(presetSelected,1,math.max(1,#presets))
  screen="presets"
end
local function promptSubmit(p)
  if not p then return end
  local input=p.input
  p.error=nil
  -- Validate while the prompt is still open. Previously a bad entry closed
  -- the dialog without any visible result, making it appear unresponsive.
  local parsed
  if p.kind=="coords" or p.kind=="add" or p.kind=="edit"
      or p.kind=="preset_add" or p.kind=="preset_edit" then
    local err
    parsed,err=parseWaypoint(input)
    if not parsed then p.error=err; return end
    if (p.kind=="preset_add" or p.kind=="preset_edit") and parsed.name=="" then
      parsed.name=("Preset %d,%d"):format(round(parsed.x),round(parsed.z))
    end
  elseif p.kind=="preset_position" then
    local name=input:match("^%s*(.-)%s*$")
    if name=="" then p.error="Enter a waypoint name"; return end
    parsed={x=p.origin.x,z=p.origin.z,name=name}
  end
  -- Apply the action only after successful validation. The navigation timer
  -- keeps running while the prompt is open.
  if p.kind=="coords" then
    directTarget=parsed
    beginNavigation("direct")
  elseif p.kind=="add" or p.kind=="edit" then
    routeAdd(parsed,p.kind=="edit")
  elseif p.kind=="preset_position" or p.kind=="preset_add" or p.kind=="preset_edit" then
    presetAdd(parsed,p.kind=="preset_edit")
  elseif p.kind=="clear" then
    if input:lower()=="yes" then
      route={}
      routeSelected=1
      routeNext=1
      local saved=saveRoute()
      notice=saved and "Route cleared" or "Route cleared (not saved)"
    else notice="Cancelled" end
  end
  screen=p.returnScreen or "flight"
  prompt=nil
end
local function keyFlight(k)
  if k=="g" then
    stopHorizontal("Enter destination X/Z")
    openPrompt("coords","DESTINATION","X Z [name] or X Y Z (Y ignored)")
  elseif k=="m" then
    currentMap=mapTarget()
    beginNavigation("map")
  elseif k=="r" then editWaypoints()
  elseif k=="l" then openPresets("flight")
  elseif k=="s" then
    if mode=="calibration" then cal=nil end
    stopHorizontal("Navigation stopped")
  elseif k=="t" then screen="settings"
  elseif k=="d" or k=="debug" then screen="debug"
  elseif k=="q" then running=false end
end
local function keySettings(k)
  if k=="back" or k=="escape" then screen="flight"
  elseif k=="c" then
    screen="flight"
    calibrateStart()
  elseif k=="o" or k=="p" then
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
  elseif k=="engine" or k=="j" then
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
local function keyRoute(k)
  if k=="back" or k=="r" then screen="flight"
  elseif k=="j" then routeSelected=math.min(#route,routeSelected+1)
  elseif k=="k" then routeSelected=math.max(1,routeSelected-1)
  elseif k=="n" then
    openPrompt("add","ADD ROUTE STOP","X Z [name] or X Y Z (Y ignored)")
    prompt.returnScreen="route"
  elseif k=="l" then openPresets("route")
  elseif k=="e" and #route>0 then
    local t=route[routeSelected]
    openPrompt("edit","EDIT ROUTE STOP","X Z [name]; Y ignored",
      tostring(t.x).." "..tostring(t.z)..(t.name~="" and " "..t.name or ""))
    prompt.returnScreen="route"
  elseif k=="d" and #route>0 then
    local removed=routeSelected
    table.remove(route,removed)
    if removed<routeNext then routeNext=routeNext-1 end
    routeNext=clamp(routeNext,1,math.max(1,#route))
    routeSelected=clamp(routeSelected,1,math.max(1,#route))
    saveRoute()
    notice="Route stop deleted"
  elseif (k=="u" or k=="f") and #route>1 then
    local other=routeSelected+(k=="u" and -1 or 1)
    if other>=1 and other<=#route then
      if routeNext==routeSelected then routeNext=other
      elseif routeNext==other then routeNext=routeSelected end
      route[routeSelected],route[other]=route[other],route[routeSelected]
      routeSelected=other
      saveRoute()
    end
  elseif k=="p" then
    screen="flight"
    beginNavigation("route") -- resume from saved next waypoint
  elseif k=="s" then
    screen="flight"
    beginNavigation("route",routeSelected) -- explicit new starting point
  elseif k=="x" then
    openPrompt("clear","CLEAR ROUTE","Type yes to confirm")
    prompt.returnScreen="route"
  end
end
local function keyPresets(k)
  if k=="back" or k=="escape" then screen=presetReturn
  elseif k=="j" then presetSelected=math.min(#presets,presetSelected+1)
  elseif k=="k" then presetSelected=math.max(1,presetSelected-1)
  elseif k=="n" then
    local here=shipPosition()
    openPrompt("preset_position","SAVE CURRENT POSITION","Enter a name for this position",
      ("At %d,%d"):format(round(here.x),round(here.z)))
    prompt.origin={x=round(here.x),z=round(here.z)}
    prompt.returnScreen="presets"
  elseif k=="c" then
    openPrompt("preset_add","NEW PRESET","X Z Name, or X Y Z Name (Y ignored)")
    prompt.returnScreen="presets"
  elseif k=="e" and #presets>0 then
    local p=presets[presetSelected]
    openPrompt("preset_edit","EDIT PRESET","X Z Name (Y ignored)",
      tostring(p.x).." "..tostring(p.z).." "..p.name)
    prompt.returnScreen="presets"
  elseif k=="d" and #presets>0 then
    table.remove(presets,presetSelected)
    presetSelected=clamp(presetSelected,1,math.max(1,#presets))
    savePresets()
    notice="Preset deleted"
  elseif k=="g" and #presets>0 then
    local p=presets[presetSelected]
    directTarget={x=p.x,z=p.z,name=p.name}
    screen="flight"
    beginNavigation("direct")
    notice="Flying to "..p.name
  elseif k=="a" and #presets>0 then
    local p=presets[presetSelected]
    routeAdd({x=p.x,z=p.z,name=p.name},false)
    screen="route"
    notice="Added preset to route: "..p.name
  end
end
local function keyDebug(k)
  if k=="back" or k=="escape" or k=="d" then screen="flight"
  elseif k=="s" then stopHorizontal("Stopped from diagnostics")
  elseif k=="x" then
    pcall(function() if fs.exists(debugFile) then fs.delete(debugFile) end end)
    trace("Log cleared by user")
    notice="Debug log cleared"
  end
end
local function clickAt(x,y)
  if screen=="prompt" and y==5 then return end
  for _,hit in ipairs(hitboxes) do
    if hit.y==y and x>=hit.x1 and x<=hit.x2 then
      if screen=="prompt" and hit.action:sub(1,3)=="kp:" then
        local action=hit.action:sub(4)
        if action=="del" then prompt.input=prompt.input:sub(1,-2)
        elseif action=="clear" then prompt.input=""
        elseif action=="space" then
          if #prompt.input<180 then prompt.input=prompt.input:gsub("%s+$","").." " end
        elseif #prompt.input<180 then prompt.input=prompt.input..action end
        prompt.error=nil
      elseif hit.action=="list_up" then
        if screen=="route" then keyRoute("k") else keyPresets("k") end
      elseif hit.action=="list_down" then
        if screen=="route" then keyRoute("j") else keyPresets("j") end
      elseif hit.action:sub(1,7)=="preset:" then
        presetSelected=tonumber(hit.action:sub(8)) or presetSelected
      elseif hit.action:sub(1,5)=="pick:" then
        routeSelected=tonumber(hit.action:sub(6)) or routeSelected
      elseif hit.action=="submit" and screen=="prompt" then
        promptSubmit(prompt)
      elseif hit.action=="cancel" and screen=="prompt" then
        screen=prompt.returnScreen or "flight"
        prompt=nil
        notice="Cancelled"
      elseif hit.action=="stop" and screen=="prompt" then
        stopHorizontal("Navigation stopped")
        screen="flight"
        prompt=nil
      elseif screen=="flight" then keyFlight(hit.action)
      elseif screen=="settings" then keySettings(hit.action)
      elseif screen=="route" then keyRoute(hit.action)
      elseif screen=="presets" then keyPresets(hit.action)
      elseif screen=="debug" then keyDebug(hit.action) end
      return
    end
  end
end
-- UI errors should be visible without killing propulsion.
-- Actual controller/peripheral errors still go through the main crash cutoff.
local function safeUI(action)
  local ok,err=pcall(action)
  if not ok then
    local msg=tostring(err):match("^[^\n]+") or "unknown error"
    notice=("INPUT ERROR: "..msg):sub(1,150)
    trace(notice)
    if screen=="prompt" and prompt then prompt.error=notice end
  end
end
local function safeRedraw()
  local ok,err=pcall(redraw)
  if not ok then
    local msg=tostring(err):match("^[^\n]+") or "unknown error"
    notice=("DISPLAY ERROR: "..msg):sub(1,150)
    trace(notice)
    pcall(function()
      term.setCursorBlink(false)
      term.setBackgroundColor(colors.black)
      term.setTextColor(colors.white)
      term.clear()
      term.setCursorPos(1,1)
      print(notice)
    end)
  end
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

local function uiLoop()
  while running do
    local ev,a,b,c=os.pullEventRaw()
    if ev=="terminate" then
      trace("TERMINATE requested")
      running=false
      return
    elseif ev=="monitor_touch" and activeMonitorName==a then
      safeUI(function() clickAt(b,c) end)
      safeRedraw()
    elseif ev=="mouse_click" and not activeMonitorName then
      safeUI(function() clickAt(b,c) end)
      safeRedraw()
    elseif ev=="mouse_scroll" and not activeMonitorName
       and (screen=="route" or screen=="presets") then
      safeUI(function()
        if screen=="route" then
          routeSelected=clamp(routeSelected+(a>0 and 1 or -1),1,math.max(1,#route))
        else
          presetSelected=clamp(presetSelected+(a>0 and 1 or -1),1,math.max(1,#presets))
        end
      end)
      safeRedraw()
    elseif ev=="char" then
      safeUI(function()
        if screen=="prompt" then
          if #prompt.input<180 then
            prompt.input=prompt.input..a
            prompt.error=nil
          end
        elseif screen=="route" then keyRoute(a:lower())
        elseif screen=="presets" then keyPresets(a:lower())
        elseif screen=="settings" then keySettings(a:lower())
        elseif screen=="debug" then keyDebug(a:lower())
        else keyFlight(a:lower()) end
      end)
      safeRedraw()
    elseif ev=="paste" and screen=="prompt" then
      safeUI(function()
        prompt.input=(prompt.input..tostring(a)):sub(1,180)
        prompt.error=nil
      end)
      safeRedraw()
    elseif ev=="key" then
      safeUI(function()
        if screen=="prompt" then
          if a==keys.enter or a==keys.numPadEnter then
            promptSubmit(prompt)
          elseif a==keys.backspace then
            prompt.input=prompt.input:sub(1,-2)
            prompt.error=nil
          elseif a==keys.escape then
            screen=prompt.returnScreen or "flight"
            prompt=nil
            notice="Entry cancelled"
          end
        elseif screen=="route" or screen=="presets" then
          if a==keys.up then
            if screen=="route" then keyRoute("k") else keyPresets("k") end
          elseif a==keys.down then
            if screen=="route" then keyRoute("j") else keyPresets("j") end
          elseif a==keys.escape then
            if screen=="route" then screen="flight" else screen=presetReturn end
          end
        elseif screen=="settings" or screen=="debug" then
          if a==keys.escape then screen="flight" end
        elseif a==keys.escape then
          if mode=="calibration" then cal=nil end
          stopHorizontal("Navigation stopped")
        end
      end)
      safeRedraw()
    elseif ev=="term_resize" or (ev=="monitor_resize" and a==activeMonitorName) then
      lastLines={}
      term.clear()
      safeRedraw()
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
-- UI redrawing is isolated from propulsion. Wired monitors can yield
-- during blit(); the flight timer must never depend on monitor responsiveness.
local function uiRefreshLoop()
  local timer=os.startTimer(0)
  while running do
    local ev,id=os.pullEventRaw("timer")
    if ev=="timer" and id==timer then
      safeRedraw()
      timer=os.startTimer(CFG.UI_REFRESH_PERIOD)
    end
  end
end
-- Local Create Display Link updates use a separate coroutine and independent
-- timer. They NEVER run inside the flight tick. Disable DISPLAY_ENABLED above
-- if your Sable installation stalls while talking to a local Display Link;
-- a second display computer via rednet is the safest fallback.
local function displayLines(maxRows)
  local t=telemetry
  local status=mode=="route" and ("ROUTE "..routeIndex.."/"..#route)
    or mode:upper()
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
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  lastFlightCompleted=os.clock()
  trace("BOOT independent flight/UI/display loops; local displays="..#displayLinks)
  safeRedraw()
  parallel.waitForAny(uiLoop, flightLoop, watchdogLoop, displayLoop, telemetryLoop, engineLoop, uiRefreshLoop)
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
-- Do not write Display Links from the shutdown handler.
if activeMonitorName then term.redirect(nativeTerm) end
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
