-- Data-backed suggestions for touch + physical keyboard editors.
-- No peripheral calls: uses the Factory Manager's existing snapshots/registry.
local M={}
local SIDES={"top","bottom","left","right","front","back"}
local function offer(out,seen,value,display,kind)
  value=tostring(value or "")
  if value=="" or seen[value] then return end
  seen[value]=true
  out[#out+1]={value=value,label=display or value,kind=kind}
end
function M.candidates(kind,core,context)
  local out,seen={},{}
  if kind=="device" then
    offer(out,seen,"computer","computer (local redstone)")
    for _,entry in ipairs(core.devices and core.devices:list() or {}) do
      if entry.online and entry.type=="redstone_relay" then
        offer(out,seen,entry.name,(entry.alias or entry.name).." / relay")
      end
    end
  elseif kind=="side" then
    for _,v in ipairs(SIDES) do offer(out,seen,v) end
  elseif kind=="item" or kind=="product" then
    local items={}
    for _,item in ipairs(core.snapshot and core.snapshot.stock or {}) do
      items[#items+1]=item
    end
    table.sort(items,function(a,b)
      if (a.count or 0)~=(b.count or 0) then
        return (a.count or 0)>(b.count or 0)
      end
      return a.name<b.name
    end)
    for _,item in ipairs(items) do
      offer(out,seen,item.name,(item.displayName or item.name)..
        " ("..tostring(item.count or 0)..")")
    end
  elseif kind=="stopAt" or kind=="resumeBelow" or kind=="quantity" or
         kind=="rateWindowSeconds" then
    local numbers=kind=="rateWindowSeconds" and {30,60,120,180,300,600,900} or
      {1,16,32,64,128,256,512,1024,2048,4096,8192}
    for _,n in ipairs(numbers) do
      if kind~="resumeBelow" or not context or
         not tonumber(context.stopAt) or n<tonumber(context.stopAt) then
        offer(out,seen,tostring(n))
      end
    end
  elseif kind=="hubAddress" then
    offer(out,seen,core.config and core.config.hubAddress or "Hub")
    for _,order in ipairs(core.orders or {}) do
      offer(out,seen,order.to)
    end
  elseif kind=="search" then
    local stock=core.snapshot and core.snapshot.stock or {}
    local names={}
    for _,item in ipairs(stock) do
      names[#names+1]=item.displayName or item.name
    end
    table.sort(names)
    for _,name in ipairs(names) do offer(out,seen,name) end
  elseif kind=="id" then
    for _,m in ipairs(core.machines or {}) do offer(out,seen,m.id) end
  end
  return out
end
function M.suggest(kind,typed,core,max,context)
  local available=M.candidates(kind,core,context)
  local prefix,partial,all={}, {}, {}
  typed=tostring(typed or ""):lower()
  for _,entry in ipairs(available) do
    local a=entry.value:lower()
    local b=entry.label:lower()
    if typed=="" or a:sub(1,#typed)==typed or b:sub(1,#typed)==typed then
      prefix[#prefix+1]=entry
    elseif a:find(typed,1,true) or b:find(typed,1,true) then
      partial[#partial+1]=entry
    end
  end
  for _,entry in ipairs(prefix) do all[#all+1]=entry end
  for _,entry in ipairs(partial) do all[#all+1]=entry end
  local result={}
  for i=1,math.min(max or 4,#all) do result[#result+1]=all[i] end
  return result
end
return M
