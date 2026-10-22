-- Generic, read-only CC:Tweaked peripheral onboarding for Factory Manager.
-- No mod-specific adapter required for scalar, zero-argument telemetry.
local Devices={}
Devices.__index=Devices
local function copy(t)
  local n={}
  for k,v in pairs(t) do n[k]=v end
  return n
end
local function load(path)
  if not fs.exists(path) then return nil end
  local file=fs.open(path,"r")
  if not file then return nil end
  local raw=file.readAll();file.close()
  local ok,value=pcall(textutils.unserialize,raw)
  if ok and type(value)=="table" then return value end
end
local function store(path,data)
  local file,err=fs.open(path..".tmp","w")
  if not file then return false,err end
  file.write(textutils.serialize(data));file.close()
  if fs.exists(path) then fs.delete(path) end
  fs.move(path..".tmp",path)
  return true
end
local function timestamp()
  return os.epoch and os.epoch("utc")/1000 or os.clock()
end
-- Do not expose arbitrary peripheral methods as dashboard actions:
-- writing methods and argument-bearing methods must never run in a poll.
-- An author-supplied Lua "getter" may still have side effects, so keep
-- the allowlist deliberately narrow and document the trust assumption.
local BARE={
  voltage=true,current=true,power=true,energy=true,rpm=true,load=true,
  capacity=true,chargePercentage=true,powerDraw=true,rangePercentage=true,
  maxRange=true,temperature=true,pressure=true,speed=true,rotation=true,
  altitude=true,distance=true,heading=true,mode=true,isRunning=true,
  getStress=true,getStressCapacity=true,getSpeed=true,
  getEnergy=true,getEnergyCapacity=true,getFluidAmount=true
}
local BLOCKED={
  getItemDetail=true,getStockItemDetail=true,getMethods=true,
  getNamesRemote=true,getNames=true,getInventory=true,
  getAll=true,getContents=true,getItems=true,getTanks=true,
  getStoredItems=true,getRecipes=true,getPlayers=true
}
local function safeMethod(method)
  if type(method)~="string" or #method>80 or BLOCKED[method] then return false end
  if BARE[method] then return true end
  -- getX/isX/hasX methods may be arguments-required, so only attempt
  -- them when a user explicitly chooses the reading; pcall isolates errors.
  return method:match("^get[A-Z][%w_]*$")~=nil or
         method:match("^is[A-Z][%w_]*$")~=nil or
         method:match("^has[A-Z][%w_]*$")~=nil
end
local function validId(id)
  return type(id)=="string" and id:match("^reading_%d+$")~=nil
end
function Devices.new(dir)
  local self=setmetatable({},Devices)
  self.path=fs.combine(dir,"devices.db")
  local persisted=load(self.path) or {}
  self.known=type(persisted.known)=="table" and persisted.known or {}
  self.readings=type(persisted.readings)=="table" and persisted.readings or {}
  self.counter=tonumber(persisted.counter) or 0
  self.live={}
  self.values={}
  self.lastScan=0
  return self
end
function Devices:save()
  return store(self.path,{known=self.known,readings=self.readings,counter=self.counter})
end
function Devices:discover()
  local changed=false
  local live={}
  for _,name in ipairs(peripheral.getNames()) do
    local primary=peripheral.getType(name)
    if type(primary)=="string" then
      live[name]=primary
      if not self.known[name] then
        self.known[name]={name=name,type=primary,alias=name,firstSeen=timestamp()}
        changed=true
      end
      -- No automatic rebinding if a peripheral name is reused for a
      -- different type: we never want outputs or readings silently remapped.
    end
  end
  self.live=live
  if changed then self:save() end
  return self:list()
end
function Devices:list()
  local all={}
  for name,entry in pairs(self.known) do
    local e=copy(entry)
    e.online=self.live[name]==entry.type
    e.typeMismatch=self.live[name]~=nil and not e.online
    e.readingCount=0
    for _,r in ipairs(self.readings) do
      if r.device==name then e.readingCount=e.readingCount+1 end
    end
    all[#all+1]=e
  end
  table.sort(all,function(a,b)
    if a.online~=b.online then return a.online end
    return (a.alias or a.name):lower() < (b.alias or b.name):lower()
  end)
  return all
end
function Devices:get(name)
  for _,e in ipairs(self:list()) do if e.name==name then return e end end
end
function Devices:rename(name,alias)
  if not self.known[name] then return false,"Unknown peripheral" end
  if type(alias)~="string" or #alias<1 or #alias>40 then
    return false,"Name must be 1-40 characters"
  end
  self.known[name].alias=alias
  return self:save()
end
function Devices:methods(name)
  local dev=self:get(name)
  if not dev or not dev.online then return {} end
  local methods=peripheral.getMethods(name) or {}
  local out={}
  for _,method in ipairs(methods) do
    if safeMethod(method) then out[#out+1]=method end
  end
  table.sort(out)
  return out
end
function Devices:add(name,method)
  local dev=self:get(name)
  if not dev or not dev.online then return nil,"Peripheral offline" end
  if not safeMethod(method) then return nil,"Not an approved read-only method" end
  local supported=false
  for _,m in ipairs(self:methods(name)) do if m==method then supported=true end end
  if not supported then return nil,"Method unavailable on this peripheral" end
  if #self.readings>=48 then return nil,"Maximum 48 readings reached" end
  for _,r in ipairs(self.readings) do
    if r.device==name and r.method==method then
      return nil,"This method is already tracked"
    end
  end
  self.counter=self.counter+1
  local reading={
    id="reading_"..self.counter,device=name,type=dev.type,
    method=method,label=dev.alias.." / "..method,unit="",
    graph=true,enabled=true
  }
  self.readings[#self.readings+1]=reading
  self:save()
  return reading
end
function Devices:getReading(id)
  for _,r in ipairs(self.readings) do
    if r.id==id then return r end
  end
end
function Devices:update(id,changes)
  local r=self:getReading(id)
  if not r then return false,"Unknown reading" end
  if changes.label~=nil then
    if type(changes.label)~="string" or #changes.label<1 or #changes.label>48 then
      return false,"Label must be 1-48 characters"
    end
    r.label=changes.label
  end
  if changes.unit~=nil then
    if type(changes.unit)~="string" or #changes.unit>12 then
      return false,"Unit must be 0-12 characters"
    end
    r.unit=changes.unit
  end
  if changes.graph~=nil then r.graph=changes.graph==true end
  if changes.enabled~=nil then r.enabled=changes.enabled==true end
  if changes.warnAbove~=nil then r.warnAbove=changes.warnAbove end
  if changes.warnBelow~=nil then r.warnBelow=changes.warnBelow end
  return self:save()
end
function Devices:rebind(id,name)
  local r=self:getReading(id)
  local dev=self:get(name)
  if not r or not dev or not dev.online then return false,"Reading/device unavailable" end
  if r.type~=dev.type then return false,"Peripheral types differ" end
  local ok=false
  for _,m in ipairs(self:methods(name)) do if m==r.method then ok=true end end
  if not ok then return false,"Target lacks "..r.method end
  r.device=name
  self.values[id]=nil
  return self:save()
end
function Devices:remove(id)
  for i,r in ipairs(self.readings) do
    if r.id==id then
      table.remove(self.readings,i)
      self.values[id]=nil
      return self:save()
    end
  end
  return false,"Unknown reading"
end
function Devices:readAll()
  self:discover()
  local samples={}
  for _,r in ipairs(self.readings) do
    local value={status="disabled",timestamp=timestamp()}
    if r.enabled then
      local dev=self:get(r.device)
      if not dev or not dev.online then
        value.status="offline"
      else
        -- Revalidate the exact method; attached peripherals can disappear
        -- between enumerating and polling. Never invoke setters.
        local valid=false
        for _,method in ipairs(self:methods(r.device)) do
          if method==r.method then valid=true;break end
        end
        if valid then
          local ok,result=pcall(peripheral.call,r.device,r.method)
          if ok and (type(result)=="number" or
              type(result)=="boolean" or type(result)=="string") then
            value.status="online"
            value.value=result
            if type(result)=="number" and result==result and
               result<math.huge and result>-math.huge then
              samples["sensor_"..r.id]=result
              if type(r.warnAbove)=="number" and result>r.warnAbove then
                value.warning="Above "..r.warnAbove
              elseif type(r.warnBelow)=="number" and result<r.warnBelow then
                value.warning="Below "..r.warnBelow
              end
            end
          else
            value.status=ok and "non-scalar value" or "method unavailable/error"
          end
        else
          value.status="method missing"
        end
      end
    end
    self.values[r.id]=value
  end
  self.lastScan=timestamp()
  return samples
end
function Devices:charts()
  local out={}
  for _,r in ipairs(self.readings) do
    if r.graph and r.enabled then
      local v=self.values[r.id]
      if not v or not v.value or type(v.value)=="number" then
        out[#out+1]={id="sensor_"..r.id,label=r.label,unit=r.unit}
      end
    end
  end
  return out
end
return Devices
