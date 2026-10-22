-- Automatic read-only Rednet bridge for Factory Manager.
-- Remote nodes broadcast sanitized scalar telemetry, never remote commands.
local Remote={}
Remote.__index=Remote
Remote.PROTOCOL="fpb.factory.node.v1"
Remote.EXPIRY=22
local function now()
  return os.epoch and os.epoch("utc")/1000 or os.clock()
end
local function scalar(value)
  local t=type(value)
  if t=="number" then return value==value and value<math.huge and value>-math.huge end
  return t=="boolean" or t=="string" and #value<=96
end
local function nameOK(value)
  return type(value)=="string" and #value>0 and #value<=96
end
function Remote.new()
  return setmetatable({nodes={},opened=false,modems={}},Remote)
end
function Remote:open()
  local opened=0
  for _,name in ipairs(peripheral.getNames()) do
    if peripheral.hasType and peripheral.hasType(name,"modem") or
       peripheral.getType(name)=="modem" then
      local modem=peripheral.wrap(name)
      if modem and modem.isWireless and modem.isWireless() then
        if not rednet.isOpen(name) then rednet.open(name) end
        self.modems[name]=true
        opened=opened+1
      end
    end
  end
  self.opened=opened>0
  return self.opened
end
function Remote:ingest(sender,message)
  if type(sender)~="number" or type(message)~="table" or
     message.version~=1 or message.kind~="snapshot" or
     type(message.peripherals)~="table" or #message.peripherals>48 then
    return false
  end
  local label=type(message.name)=="string" and
    message.name:sub(1,40) or "Node "..sender
  local node=self.nodes[sender] or {}
  node.id=sender
  node.name=label
  node.lastSeen=now()
  node.peripherals={}
  local processed=0
  for _,entry in ipairs(message.peripherals) do
    if processed>=48 then break end
    if type(entry)=="table" and nameOK(entry.name) and
       nameOK(entry.type) and type(entry.methods)=="table" and
       type(entry.values)=="table" then
      local methods,values={},{}
      for _,method in ipairs(entry.methods) do
        if #methods>=24 then break end
        if type(method)=="string" and #method<=80 then
          methods[#methods+1]=method
          local v=entry.values[method]
          if scalar(v) then values[method]=v end
        end
      end
      node.peripherals[entry.name]={
        name=entry.name,type=entry.type,
        methods=methods,values=values,
      }
      processed=processed+1
    end
  end
  self.nodes[sender]=node
  return true
end
function Remote:online(node)
  return node and (now()-(node.lastSeen or 0))<self.EXPIRY
end
function Remote:deviceName(nodeId,rawName)
  return "remote:"..tostring(nodeId)..":"..rawName
end
function Remote:list()
  local result={}
  for id,node in pairs(self.nodes) do
    if self:online(node) then
      for _,device in pairs(node.peripherals) do
        result[#result+1]={
          name=self:deviceName(id,device.name),
          type=device.type,
          alias=node.name.." / "..device.name,
          node=id,
          methods=device.methods,
          values=device.values,
        }
      end
    end
  end
  table.sort(result,function(a,b)return a.name<b.name end)
  return result
end
function Remote:find(fullName)
  for _,entry in ipairs(self:list()) do
    if entry.name==fullName then return entry end
  end
end
function Remote:serve()
  self:open()
  while true do
    if not self.opened then
      self:open()
      sleep(3)
    else
      local sender,message=rednet.receive(self.PROTOCOL,3)
      if sender then self:ingest(sender,message) end
      -- Re-open modem if the player reconnects the wired network.
      if not self.opened then self:open() end
    end
  end
end
return Remote
