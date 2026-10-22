-- Remote-node registry, authenticated control and asynchronous acknowledgements.
local Auth=require("auth")
local Remote={}
Remote.CONTROL="fpb.factory.control.v1"
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
local function load(path)
  if not path or not fs.exists(path) then return {} end
  local f=fs.open(path,"r")
  if not f then return {} end
  local raw=f.readAll();f.close()
  local ok,result=pcall(textutils.unserialize,raw)
  return ok and type(result)=="table" and result or {}
end
function Remote.new(dir)
  local path=dir and fs.combine(dir,"remote_pairs.db") or nil
  local persisted=load(path)
  return setmetatable({
    nodes={},opened=false,modems={},path=path,
    pairs=type(persisted.pairs)=="table" and persisted.pairs or {},
    pending={},outputs={},lastHeartbeat=0,errors={}
  },Remote)
end
function Remote:save()
  if not self.path then return true end
  local f,err=fs.open(self.path..".tmp","w")
  if not f then return false,err end
  f.write(textutils.serialize({pairs=self.pairs}));f.close()
  if fs.exists(self.path) then fs.delete(self.path) end
  fs.move(self.path..".tmp",self.path)
  return true
end
function Remote:paired(id)
  local p=self.pairs[id]
  return p~=nil and p.ready==true and self:online(self.nodes[id])
end
function Remote:pair(id,code)
  id=tonumber(id)
  if not id or not self:online(self.nodes[id]) then
    return false,"Node is offline"
  end
  code=tostring(code or "")
  if not code:match("^[a-fA-F0-9]+$") or #code<32 or #code>128 then
    return false,"Enter the full 48-character key shown on the node computer"
  end
  self.pairs[id]={key=code:lower(),seq=0,ready=false}
  self:save()
  self:send(id,"heartbeat")
  return true,"Pairing requested; wait for authenticated reply"
end
function Remote:send(id,action,target,side,on,polarity)
  id=tonumber(id)
  local pair=self.pairs[id]
  if not pair or not self:online(self.nodes[id]) then return false,"Node offline/unpaired" end
  if action~="heartbeat" and not pair.ready then return false,"Pairing not confirmed yet" end
  pair.seq=(pair.seq or 0)+1
  local seq=pair.seq
  local frame=Auth.frame(action,os.getComputerID(),id,seq,target,side,on,polarity,"")
  local msg={version=1,action=action,seq=seq,target=target,side=side,
    on=on==true,polarity=polarity==true,mac=Auth.mac(pair.key,frame)}
  self:save() -- Persist monotonic sequence before the packet is transmitted.
  self.pending[id]=self.pending[id] or {}
  self.pending[id][seq]={message=msg,action=action,target=target,side=side,
    at=now(),retry=0}
  local ok=rednet.send(id,msg,self.CONTROL)
  if not ok then self.errors[id]="Modem failed to send" end
  return ok==true,ok and "Awaiting acknowledgment" or "Modem could not send"
end
function Remote:handleAck(sender,msg)
  local pair=self.pairs[sender]
  if not pair or type(msg)~="table" or msg.kind~="ack" or
      type(msg.seq)~="number" or type(msg.status)~="string" then return false end
  local pending=self.pending[sender] and self.pending[sender][msg.seq]
  if not pending then return false end
  local signature=Auth.frame("ack:"..pending.action,os.getComputerID(),
    sender,msg.seq,pending.target,pending.side,msg.on==true,
    msg.polarity==true,msg.status)
  if not Auth.equal(Auth.mac(pair.key,signature),msg.mac) then return false end
  self.pending[sender][msg.seq]=nil
  if msg.status=="ok" then
    pair.ready=true
    self.errors[sender]=nil
    if pending.action=="set" then
      self.outputs["remote:"..sender..":"..pending.target.."|"..pending.side]={
        running=msg.on==true,at=now(),confirmed=true
      }
    end
    return true
  end
  self.errors[sender]="Node rejected command: "..msg.status
  return false
end
function Remote:state(name,side)
  local id=name:match("^remote:(%d+):")
  id=tonumber(id)
  if not id or not self:paired(id) then return nil end
  local output=self.outputs[name.."|"..side]
  if not output then return nil end
  -- Do not show stale observed state after link loss.
  if now()-output.at>22 then return nil end
  return output.running
end
function Remote:control(name,side,on,polarity)
  local id,target=name:match("^remote:(%d+):(.+)$")
  id=tonumber(id)
  if not self:paired(id) then return false,"Pair the node before controlling it" end
  local dev=self:find(name)
  if not dev or not (dev.type=="redstone_relay" or
    dev.type=="remote_computer" and target=="computer") then
    return false,"Remote actuator not available"
  end
  if not ({top=true,bottom=true,left=true,right=true,front=true,back=true})[side] then
    return false,"Invalid redstone side"
  end
  local ok,err=self:send(id,"set",target,side,on,polarity)
  if ok then self.outputs[name.."|"..side]=nil end
  return ok,err
end
function Remote:tick()
  if not self.opened then return end
  local t=now()
  if t-self.lastHeartbeat>=4 then
    self.lastHeartbeat=t
    for id,node in pairs(self.nodes) do
      if self.pairs[id] and self:online(node) then
        self:send(id,"heartbeat")
      end
    end
  end
  for id,commands in pairs(self.pending) do
    for seq,p in pairs(commands) do
      if t-p.at>=2 and p.retry<2 then
        rednet.send(id,p.message,self.CONTROL)
        p.retry=p.retry+1;p.at=t
      elseif t-p.at>=6 then
        commands[seq]=nil
        if p.action=="set" then
          self.errors[id]="Command unacknowledged"
        end
      end
    end
  end
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
  while true do
    -- Re-enumerate regularly: a modem may be attached or removed while
    -- the manager is running.
    if self:open() then
      local sender,message,protocol=rednet.receive(nil,1)
      if sender and protocol==self.PROTOCOL then
        self:ingest(sender,message)
      elseif sender and protocol==self.CONTROL then
        self:handleAck(sender,message)
      end
      self:tick()
    else
      sleep(3)
    end
  end
end
return Remote
