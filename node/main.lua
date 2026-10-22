-- FPBCRAFT Remote Node v1.
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
saveConfig(cfg)
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
      if #supported>0 then
        entries[#entries+1]={
          name=name,type=kind,methods=supported,values=values,
        }
      end
    end
  end
  return {
    kind="snapshot",version=1,
    name=cfg.name,peripherals=entries,
  }
end
local function writeStatus(msg)
  term.clear()
  term.setCursorPos(1,1)
  print("FPBCRAFT REMOTE NODE")
  print(cfg.name)
  print("Computer ID: "..os.getComputerID())
  print("--------------------------------")
  print(msg)
  print("Auto-discovery: enabled")
  print("Controls: disabled (telemetry only)")
end
while true do
  if ensureWireless() then
    local msg=sample()
    rednet.broadcast(msg,PROTOCOL)
    writeStatus("Published "..#msg.peripherals.." peripherals")
  else
    writeStatus("No wireless/Ender modem found.")
  end
  sleep(cfg.interval)
end
