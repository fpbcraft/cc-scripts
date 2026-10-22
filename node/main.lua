local Auth=require("auth")
local Pairing=require("pairing")
local UI=require("ui")
-- FPBCRAFT Remote Node v2: telemetry and paired, fail-safe control.
-- Attach a wireless/Ender modem to this computer, plus a wired modem and
-- peripherals on its local cable network. The main Factory Manager
-- automatically discovers the node and its read-only scalar telemetry.
local PROTOCOL="fpb.factory.node.v1"
local DIR="/fpb-node"
local CONF=DIR.."/config.db"
local function loadConfig()
  if not fs.exists(CONF) then return {} end
  local f=fs.open(CONF,"r")
  if not f then return {} end
  local raw=f.readAll();f.close()
  local ok,data=pcall(textutils.unserialize,raw)
  return ok and type(data)=="table" and data or {}
end
local function saveConfig(v)
  local f=assert(fs.open(CONF,"w"))
  f.write(textutils.serialize(v));f.close()
end
local cfg=loadConfig()
cfg.name=cfg.name or ("Factory Node "..os.getComputerID())
cfg.interval=math.max(3,math.min(30,tonumber(cfg.interval) or 5))
-- Auto-generated local pairing key. Never transmit this secret over Rednet.
-- The CraftOS PRNG is not cryptographically secure; for hostile multiplayer
-- environments replace the generated key with a long user-chosen secret.
if not cfg.key or #cfg.key<32 then
  math.randomseed((os.epoch("utc")+os.getComputerID()*15485863)%2147483647)
  local chars={}
  for i=1,24 do chars[i]=string.format("%02x",math.random(0,255)) end
  cfg.key=table.concat(chars)
end
cfg.managed=cfg.managed or {}
cfg.lastSeq=tonumber(cfg.lastSeq) or 0
-- Never replay an ACK belonging to a previous boot.
cfg.lastAck=nil
local bootId=tostring(os.epoch("utc"))..":"..tostring(os.getComputerID())
saveConfig(cfg)
local CONTROL="fpb.factory.control.v1"
local lastAuthenticated=os.epoch("utc")/1000
local safeApplied=false
local function safelySet(target,side,signal)
  if target=="computer" then return pcall(redstone.setOutput,side,signal) end
  if not peripheral.isPresent(target) or
     peripheral.getType(target)~="redstone_relay" then
    return false,"Relay unavailable"
  end
  return pcall(peripheral.call,target,"setOutput",side,signal)
end
local function safeOff()
  for _,item in pairs(cfg.managed) do
    safelySet(item.target,item.side,not item.polarity)
  end
  safeApplied=true
end
-- A saved actuator is forced OFF after reboot, before opening the radio.
safeOff()
local blockedTypes={modem=true,monitor=true,computer=true,drive=true,
  printer=true,disk_drive=true}
-- Explicit safe-default getter names. No dynamically discovered setters are
-- ever called. A new mod's methods need audit before expanding this list.
local readable={
  getStress=true,getStressCapacity=true,getSpeed=true,
  voltage=true,current=true,power=true,energy=true,
  capacity=true,chargePercentage=true,powerDraw=true,
  rpm=true,load=true,temperature=true,pressure=true,
  getValue=true,getEnergy=true,getEnergyCapacity=true,
  getFluidAmount=true,isRunning=true,heading=true,altitude=true,
  distance=true,speed=true,rotation=true
}
local function valid(v)
  local t=type(v)
  if t=="number" then return v==v and v<math.huge and v>-math.huge end
  if t=="boolean" then return true end
  return t=="string" and #v<=96
end
local function ensureWireless()
  local count=0
  for _,name in ipairs(peripheral.getNames()) do
    local has=peripheral.hasType and peripheral.hasType(name,"modem") or
      peripheral.getType(name)=="modem"
    if has then
      local d=peripheral.wrap(name)
      if d and d.isWireless and d.isWireless() then
        if not rednet.isOpen(name) then rednet.open(name) end
        count=count+1
      end
    end
  end
  return count>0
end
local function sample()
  local entries={}
  local names=peripheral.getNames()
  table.sort(names)
  for _,name in ipairs(names) do
    if #entries>=40 then break end
    local kind=peripheral.getType(name)
    if type(kind)=="string" and not blockedTypes[kind] then
      local methods=peripheral.getMethods(name) or {}
      local supported,values={},{}
      for _,method in ipairs(methods) do
        if readable[method] and #supported<24 then
          supported[#supported+1]=method
          local ok,result=pcall(peripheral.call,name,method)
          if ok and valid(result) then values[method]=result end
        end
      end
      if #supported>0 or kind=="redstone_relay" then
        entries[#entries+1]={
          name=name,type=kind,methods=supported,values=values,
        }
      end
    end
  end
  entries[#entries+1]={
    name="computer",type="remote_computer",methods={},values={}
  }
  return {
    kind="snapshot",version=1,
    name=cfg.name,peripherals=entries,
  }
end
local radioOnline=false
local sensorCount=0
local dashboard=UI.new({
  info=function()
    local outputs=0
    for _ in pairs(cfg.managed) do outputs=outputs+1 end
    return {
      id=os.getComputerID(),name=cfg.name,key=cfg.key,
      wireless=radioOnline,sensors=sensorCount,
      hubId=cfg.hubId,outputs=outputs
    }
  end,
  drives=Pairing.drives,
  export=function(replace)
    return Pairing.export(cfg,os.getComputerID(),{replace=replace})
  end
})
local validSides={top=true,bottom=true,left=true,right=true,front=true,back=true}
local function receiveCommand(sender,msg)
  if type(sender)~="number" or type(msg)~="table" or
     msg.version~=1 or (msg.action~="set" and msg.action~="heartbeat") or
     type(msg.seq)~="number" or msg.seq%1~=0 or msg.seq<=0 or
     type(msg.mac)~="string" then return end
  if cfg.hubId and sender~=cfg.hubId then return end
  local expected=Auth.frame(msg.action,sender,os.getComputerID(),
    msg.seq,msg.target,msg.side,msg.on==true,msg.polarity==true,"")
  if not Auth.equal(Auth.mac(cfg.key,expected),msg.mac) then return end
  local frameId=msg.action.."|"..tostring(msg.target).."|"..
    tostring(msg.side).."|"..tostring(msg.on).."|"..tostring(msg.polarity)
  if msg.seq==cfg.lastSeq and cfg.lastFrame==frameId and cfg.lastAck then
    rednet.send(sender,cfg.lastAck,CONTROL)
    return
  end
  if msg.seq<=cfg.lastSeq then return end
  -- Lock to the first controller which knows the local pairing secret.
  cfg.hubId=cfg.hubId or sender
  cfg.lastSeq=msg.seq
  cfg.lastFrame=frameId
  lastAuthenticated=os.epoch("utc")/1000
  safeApplied=false
  local status="ok"
  local target,side=msg.target,msg.side
  if msg.action=="set" then
    if not validSides[side] or
       type(target)~="string" or #target>96 or
       (target~="computer" and
        (not peripheral.isPresent(target) or
         peripheral.getType(target)~="redstone_relay")) then
      status="invalid actuator"
    else
      local key=target.."|"..side
      cfg.managed[key]={target=target,side=side,polarity=msg.polarity==true}
      local applied,err=safelySet(target,side,
        (msg.on==true)==(msg.polarity==true))
      if not applied then status="output failed" end
    end
  end
  local ack={
    kind="ack",version=1,seq=msg.seq,status=status,
    on=msg.on==true,polarity=msg.polarity==true,bootId=bootId
  }
  ack.mac=Auth.mac(cfg.key,Auth.frame("ack:"..msg.action,sender,
    os.getComputerID(),msg.seq,target,side,ack.on,ack.polarity,status.."#"..bootId))
  cfg.lastAck=ack
  saveConfig(cfg) -- Persist replay counter and managed outputs before ACK.
  rednet.send(sender,ack,CONTROL)
end
local function publisher()
  while true do
    radioOnline=ensureWireless()
    if radioOnline then
      local msg=sample()
      sensorCount=#msg.peripherals-1 -- subtract virtual "computer" actuator
      rednet.broadcast(msg,PROTOCOL)
    else
      sensorCount=0
    end
    sleep(cfg.interval)
  end
end
local function listener()
  while true do
    if ensureWireless() then
      local sender,message=rednet.receive(CONTROL,1)
      if sender then receiveCommand(sender,message) end
    else sleep(1) end
  end
end
local function watchdog()
  while true do
    if not safeApplied and
       os.epoch("utc")/1000-lastAuthenticated>=15 then
      safeOff()
    end
    sleep(1)
  end
end
parallel.waitForAll(publisher,listener,watchdog,function()
  dashboard:run()
end)
