-- FPBCRAFT Factory Core v3: peripheral discovery, machine control and stock rules.
-- Deliberately independent of Basalt so automation can be tested separately.
local Core = {}
Core.__index = Core
local TYPES = {
  powergrid_voltage_gauge={"Voltage","voltage","voltage","V"},
  powergrid_current_gauge={"Current","current","current","A"},
  powergrid_power_gauge={"Power","power","power","W"},
  powergrid_energy_meter={"Energy","energy","energy","J"},
  powergrid_battery={"Battery","battery","chargePercentage","%"},
  powergrid_generator_clutch={"Generator","generator","load","load"}
}
local function now()
  return os.epoch and os.epoch("utc") / 1000 or os.clock()
end
local function read(path)
  if not fs.exists(path) then return nil end
  local f=fs.open(path,"r")
  if not f then return nil end
  local data=f.readAll(); f.close()
  local ok,value=pcall(textutils.unserialize,data)
  if ok and type(value)=="table" then return value end
end
local function save(path,value)
  local f,err=fs.open(path..".tmp","w")
  if not f then return false,err end
  f.write(textutils.serialize(value)); f.close()
  if fs.exists(path) then fs.delete(path) end
  fs.move(path..".tmp",path)
  return true
end
local function safe(dev,method,...)
  if not dev or type(dev[method])~="function" then return nil end
  local ok,v=pcall(dev[method],...)
  if ok then return v end
end
local function periph(typeName)
  local out={}
  for _,name in ipairs(peripheral.getNames()) do
    if peripheral.hasType and peripheral.hasType(name,typeName)
       or peripheral.getType(name)==typeName then
      local dev=peripheral.wrap(name)
      if dev then out[#out+1]={name=name,dev=dev} end
    end
  end
  table.sort(out,function(a,b) return a.name<b.name end)
  return out
end
local function itemCount(items,id)
  local total=0
  for _,item in ipairs(items) do
    if item.name==id then total=total+item.count end
  end
  return total
end
local function validSide(side)
  return side=="top" or side=="bottom" or side=="left"
      or side=="right" or side=="front" or side=="back"
end
function Core.new(root)
  root=root or "."
  local dir=fs.combine(root,"data")
  if not fs.exists(dir) then fs.makeDir(dir) end
  local old=read("fpb_factory.cfg") or {}
  local cfg=read(fs.combine(dir,"config.db")) or {}
  local self=setmetatable({},Core)
  self.dir=dir
  self.config={
    site=cfg.site or old.site or "FACTORY 01",
    hubAddress=cfg.hubAddress or old.hubAddress or "Hub",
    refreshSeconds=tonumber(cfg.refreshSeconds or old.refreshSeconds) or 5,
    maxOrder=tonumber(cfg.maxOrder or old.maxOrder) or 4096,
    textScale=tonumber(cfg.textScale or old.textScale) or 0.5,
    rateWindowSeconds=tonumber(cfg.rateWindowSeconds) or 120,
    rateEstimatorVersion=tonumber(cfg.rateEstimatorVersion) or 1,
  }
  self.config.refreshSeconds=math.max(2,math.min(30,self.config.refreshSeconds))
  self.config.rateWindowSeconds=math.max(15,math.min(900,self.config.rateWindowSeconds))
  local oldOrders=read("fpb_factory_orders.db") or {}
  self.orders=read(fs.combine(dir,"orders.db")) or oldOrders
  for _,order in ipairs(self.orders) do
    -- Convert the v2.1 order history schema without discarding existing data.
    order.quantity=order.quantity or order.accepted or order.amount or 0
    order.requested=order.requested or order.amount or order.quantity
    order.to=order.to or order.address or self.config.hubAddress
    order.status=order.status or "Previously requested"
  end
  self.remote=require("remote").new(dir)
  self.devices=require("devices").new(dir)
  self.devices.remote=self.remote
  self.machines=read(fs.combine(dir,"machines.db")) or {}
  self.samples=read(fs.combine(dir,"samples.db")) or {}
  if self.config.rateEstimatorVersion<2 then
    -- Legacy per-poll spikes are not comparable to smoothed rate estimates.
    -- Keep the rest of historical telemetry without graphing stale spikes.
    for _,sample in ipairs(self.samples) do
      for key in pairs(sample) do
        if type(key)=="string" and key:sub(1,5)=="rate_" then
          sample[key]=nil
        end
      end
    end
    self.config.rateEstimatorVersion=2
    self:save("samples",self.samples)
  end
  self.snapshot={stock={},stockError="Not scanned",stress={},speed={},power={}}
  self.prevStock=nil
  self.prevTime=nil
  self.rates={}
  self.rateState={}
  self.states={}
  self.errors={}
  self.lastTick=0
  self.dirty=0
  self:save("config",self.config)
  self:save("orders",self.orders)
  return self
end
function Core:save(key,value)
  return save(fs.combine(self.dir,key..".db"),value)
end
function Core:configure(fields)
  if fields.site and fields.site~="" then self.config.site=fields.site end
  if fields.hubAddress and fields.hubAddress~="" then
    self.config.hubAddress=fields.hubAddress
  end
  if fields.refreshSeconds then
    self.config.refreshSeconds=math.max(2,math.min(30,tonumber(fields.refreshSeconds) or 5))
  end
  if fields.rateWindowSeconds then
    self.config.rateWindowSeconds=math.max(15,math.min(900,tonumber(fields.rateWindowSeconds) or 120))
  end
  self:save("config",self.config)
end
function Core:setRateWindow(machine,seconds)
  seconds=tonumber(seconds)
  if not seconds or seconds%1~=0 or seconds<15 or seconds>900 then
    return false,"Averaging range must be 15-900 seconds"
  end
  local tracked=false
  for _,m in ipairs(self.machines) do
    if m==machine then tracked=true;break end
  end
  if not tracked then return false,"Unknown machine" end
  if machine.rateWindowSeconds==seconds then return true end
  machine.rateWindowSeconds=seconds
  -- Previous samples used a different averaging period: remove only this
  -- machine's obsolete rate history to prevent misleading mixed curves.
  self.rateState[machine.id]=nil
  self.rates[machine.id]=0
  local key="rate_"..machine.id
  for _,sample in ipairs(self.samples) do sample[key]=nil end
  self:save("machines",self.machines)
  self:save("samples",self.samples)
  return true
end
function Core:register(fields)
  local id=tostring(fields.id or ""):lower()
  if not id:match("^[a-z0-9_-]+$") then return false,"ID: letters, digits, - or _" end
  local side=tostring(fields.side or "")
  if not validSide(side) then return false,"Invalid side" end
  local device=tostring(fields.device or "")
  if device=="" then return false,"Specify computer or relay peripheral name" end
  if device:sub(1,7)=="remote:" then
    local remote=self.remote:find(device)
    if not remote or (remote.type~="remote_computer" and
      remote.type~="redstone_relay") then
      return false,"Remote node/relay is not available"
    end
    if not self.remote:paired(remote.node) then
      return false,"Pair the remote node in Devices first"
    end
  elseif device~="computer" and (not peripheral.isPresent(device)
    or peripheral.getType(device)~="redstone_relay") then
    return false,"Choose a connected wired Redstone Relay"
  end
  local rateWindow=tonumber(fields.rateWindowSeconds) or self.config.rateWindowSeconds
  if rateWindow<15 or rateWindow>900 or rateWindow%1~=0 then
    return false,"Rate averaging must be 15-900 seconds"
  end
  local stop=tonumber(fields.stopAt) or 0
  local resume=tonumber(fields.resumeBelow) or 0
  if stop<0 or resume<0 or (stop>0 and resume>=stop) then
    return false,"Resume threshold must be below stop threshold"
  end
  local previous=nil
  for i,m in ipairs(self.machines) do
    if m.id==id then previous=i break end
  end
  local machine={
    id=id,name=tostring(fields.name or id),device=device,side=side,
    onSignal=fields.onSignal~=false,
    mode=fields.mode=="auto" and "auto" or "manual",
    enabled=false, -- fail off following application restart
    item=tostring(fields.item or ""),
    stopAt=stop,resumeBelow=resume,
    product=tostring(fields.product or ""),
    rateWindowSeconds=rateWindow
  }
  if previous then
    machine.enabled=self.machines[previous].enabled or false
    self.machines[previous]=machine
  else
    self.machines[#self.machines+1]=machine
  end
  self:save("machines",self.machines)
  return true
end
function Core:remove(id)
  for i,m in ipairs(self.machines) do
    if m.id==id then
      local ok=self:setRunning(m,false,"remove")
      if not ok then return false,"Cannot turn output off; not removed" end
      table.remove(self.machines,i)
      self.rateState[id]=nil
      self.rates[id]=nil
      self:save("machines",self.machines)
      return true
    end
  end
  return false,"Unknown machine"
end
function Core:device(m)
  if m.device=="computer" then return redstone end
  if not peripheral.isPresent(m.device)
      or peripheral.getType(m.device)~="redstone_relay" then return nil end
  return peripheral.wrap(m.device)
end
function Core:setRunning(m,run,why)
  if m.device:sub(1,7)=="remote:" then
    local ok,err=self.remote:control(m.device,m.side,run,m.onSignal)
    if not ok then
      self.errors[m.id]=err
      return false,err
    end
    m.enabled=run
    self.states[m.id]={running=run,reason=why or "operator",
      time=now(),pending=true}
    self.errors[m.id]=nil
    self:save("machines",self.machines)
    return true,"Remote command sent; awaiting signed acknowledgment"
  end
  local dev=self:device(m)
  if not dev then
    self.errors[m.id]="Relay offline: "..m.device
    return false,self.errors[m.id]
  end
  local signal=(run==m.onSignal)
  local ok,err=pcall(dev.setOutput,m.side,signal)
  if not ok then
    self.errors[m.id]=tostring(err)
    return false,self.errors[m.id]
  end
  m.enabled=run
  self.states[m.id]={running=run,reason=why or "manual",time=now()}
  self.errors[m.id]=nil
  self:save("machines",self.machines)
  return true
end
function Core:actual(m)
  if m.device:sub(1,7)=="remote:" then
    return self.remote:state(m.device,m.side)
  end
  local dev=self:device(m)
  if not dev then return nil end
  local val=safe(dev,"getOutput",m.side)
  if type(val)~="boolean" then return nil end
  return val==m.onSignal
end
function Core:setMode(m,mode)
  if mode~="auto" and mode~="manual" then return false,"Invalid mode" end
  m.mode=mode
  self:save("machines",self.machines)
  if mode=="auto" then self:evaluate(m) end
  return true
end
function Core:evaluate(m)
  if m.mode~="auto" then return end
  if m.item=="" or m.stopAt<=0 or m.resumeBelow>=m.stopAt then
    self.errors[m.id]="Configure item/stock thresholds first"
    return
  end
  if self.snapshot.stockError then
    self.errors[m.id]="Inventory unavailable; automatic control held"
    return -- never act on stale/unknown stock
  end
  local n=itemCount(self.snapshot.stock,m.item)
  local desired=m.enabled
  if n>=m.stopAt then desired=false
  elseif n<=m.resumeBelow then desired=true end
  if desired~=m.enabled then
    self:setRunning(m,desired,"Stock "..n)
  elseif m.device:sub(1,7)=="remote:" and desired and
    self.remote:state(m.device,m.side)==nil then
    -- Auto mode only: reassert the inventory rule after reconnect.
    -- The remote node will have entered its safe OFF state after a timeout.
    local id=tonumber(m.device:match("^remote:(%d+):"))
    if id and self.remote:paired(id) and
       not self.remote:hasPending(m.device,m.side) then
      self:setRunning(m,desired,"Auto recovery")
    end
  end
end
function Core:toggle(m)
  if m.mode~="manual" then return false,"Set Manual mode first" end
  if m.device:sub(1,7)=="remote:" and self:actual(m)==nil then
    -- Unknown state after wireless interruption must be forced OFF first.
    -- The operator can turn it on after receiving an authenticated ACK.
    return self:setRunning(m,false,"operator safe-off")
  end
  return self:setRunning(m,not m.enabled,"operator")
end
function Core:scan()
  local snap={stock={},stockError=nil,stress={},speed={},power={},ticker=nil}
  local tickers=periph("Create_StockTicker")
  if tickers[1] then
    snap.ticker=tickers[1].name
    local stock=safe(tickers[1].dev,"stock",true)
    if type(stock)=="table" then
      for _,item in pairs(stock) do
        if type(item)=="table" and type(item.name)=="string"
          and type(item.count)=="number" then
          snap.stock[#snap.stock+1]=item
        end
      end
    else snap.stockError="Stock Ticker returned no inventory" end
  else snap.stockError="No Stock Ticker connected" end
  for _,p in ipairs(periph("Create_Stressometer")) do
    local used=safe(p.dev,"getStress")
    local capacity=safe(p.dev,"getStressCapacity")
    snap.stress[#snap.stress+1]={name=p.name,used=used,capacity=capacity}
  end
  for _,p in ipairs(periph("Create_Speedometer")) do
    snap.speed[#snap.speed+1]={name=p.name,rpm=safe(p.dev,"getSpeed")}
  end
  for kind,spec in pairs(TYPES) do
    for _,p in ipairs(periph(kind)) do
      local val=safe(p.dev,spec[3])
      if kind=="powergrid_battery" and val then val=val*100 end
      snap.power[#snap.power+1]={name=p.name,kind=kind,label=spec[1],
        key=spec[2],value=val,unit=spec[4],
        capacity=safe(p.dev,"capacity"),energy=safe(p.dev,"energy"),
        load=safe(p.dev,"load"),rpm=safe(p.dev,"rpm")}
    end
  end
  table.sort(snap.power,function(a,b) return a.name<b.name end)
  local ts=now()
  if not snap.stockError then
    for _,m in ipairs(self.machines) do
      if m.product and m.product~="" then
        local count=itemCount(snap.stock,m.product)
        local state=self.rateState[m.id]
        local window=m.rateWindowSeconds or self.config.rateWindowSeconds
        if state and state.product==m.product and
           state.window==window and ts>state.timestamp then
          local dt=ts-state.timestamp
          local observed=math.max(0,count-state.count)/dt*60
          -- Exponential time-weighted average of net stock gains.
          -- A batched deposit changes the displayed rate gradually instead
          -- of briefly producing a huge items/min reading.
          local alpha=1-math.exp(-dt/window)
          self.rates[m.id]=(self.rates[m.id] or 0)+alpha*
            (observed-(self.rates[m.id] or 0))
        else
          self.rates[m.id]=0
        end
        self.rateState[m.id]={
          count=count,timestamp=ts,product=m.product,window=window
        }
      end
    end
  else
    -- Never derive rates across an unobserved inventory outage.
    self.rateState={}
  end
  self.prevStock=snap.stockError and nil or snap.stock
  self.prevTime=ts
  self.snapshot=snap
  self.lastTick=ts
  for _,m in ipairs(self.machines) do self:evaluate(m) end
  local point={time=ts}
  if snap.stress[1] and type(snap.stress[1].used)=="number" and
     type(snap.stress[1].capacity)=="number" and snap.stress[1].capacity>0 then
    point.stress=snap.stress[1].used/snap.stress[1].capacity*100
  end
  if snap.speed[1] then point.rpm=snap.speed[1].rpm end
  if not snap.stockError then
    point.stock=0
    for _,item in ipairs(snap.stock) do point.stock=point.stock+item.count end
  end
  for _,entry in ipairs(snap.power) do
    if entry.value and point[entry.key]==nil then point[entry.key]=entry.value end
  end
  for _,m in ipairs(self.machines) do
    if m.product and m.product~="" then
      point["rate_"..m.id]=self.rates[m.id]
    end
  end
  -- User-configured scalar peripheral readings require no mod-specific code.
  -- Each keeps a stable internal key, even if the user later renames it.
  local extras=self.devices:readAll()
  for key,value in pairs(extras) do point[key]=value end
  self.samples[#self.samples+1]=point
  while #self.samples>360 do table.remove(self.samples,1) end
  self.dirty=self.dirty+1
  if self.dirty>=12 then self:save("samples",self.samples);self.dirty=0 end
  return snap
end
-- Inventory quantity for a rule target or machine output, by stock item ID.
-- Returns nil while the ticker is unavailable (never present stale data as 0).
function Core:stockFor(id)
  if type(id)~="string" or id=="" then return nil,nil,"unconfigured" end
  if self.snapshot.stockError then return nil,nil,"unavailable" end
  local total=0
  local title=id
  for _,item in ipairs(self.snapshot.stock) do
    if item.name==id then
      total=total+item.count
      title=item.displayName or title
    end
  end
  return total,title,nil
end
function Core:sortedStock(query,sortMode)
  local stock={}
  local q=tostring(query or ""):lower()
  for _,item in ipairs(self.snapshot.stock) do
    local label=tostring(item.displayName or item.name)
    if q=="" or label:lower():find(q,1,true)
      or item.name:lower():find(q,1,true) then stock[#stock+1]=item end
  end
  table.sort(stock,function(a,b)
    if sortMode=="count" and a.count~=b.count then return a.count>b.count end
    if sortMode=="mod" then
      local am=a.name:match("^([^:]+):") or ""
      local bm=b.name:match("^([^:]+):") or ""
      if am~=bm then return am<bm end
    end
    return (a.displayName or a.name):lower() < (b.displayName or b.name):lower()
  end)
  return stock
end
function Core:request(item,quantity)
  quantity=tonumber(quantity)
  if not item or not quantity or quantity%1~=0 or quantity<1 then
    return false,"Quantity must be a positive integer"
  end
  if quantity>self.config.maxOrder then return false,"Over order limit" end
  if self.snapshot.stockError or not self.snapshot.ticker then
    return false,"Stock Ticker unavailable"
  end
  if quantity>item.count then return false,"Insufficient stock" end
  local ticker=peripheral.wrap(self.snapshot.ticker)
  if not ticker then return false,"Ticker disconnected" end
  local filter={name=item.name,_requestCount=quantity}
  if item.nbt~=nil then filter.nbt=item.nbt end
  if item.damage~=nil then filter.damage=item.damage end
  local ok,result=pcall(ticker.requestFiltered,self.config.hubAddress,filter)
  if not ok then return false,tostring(result) end
  if type(result)~="number" or result<=0 then
    return false,"Nothing was accepted by the logistics network"
  end
  table.insert(self.orders,1,{at=now(),item=item.displayName or item.name,
    id=item.name,quantity=result,requested=quantity,to=self.config.hubAddress,
    status="Requested (not confirmed delivered)"})
  while #self.orders>100 do table.remove(self.orders) end
  self:save("orders",self.orders)
  return true,result
end
function Core:shutdown()
  self:save("machines",self.machines)
  self:save("samples",self.samples)
end
return Core
