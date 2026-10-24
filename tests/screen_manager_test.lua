package.path="./factory/?.lua;"..package.path
colors={
 black=32768,white=1,blue=2,cyan=4,orange=8,lime=16,
 lightGray=32,yellow=64,red=128
}
local Manager=require("screen_manager")
local displays={}
local live={"main_monitor","small_monitor","large_monitor","workstation"}
local writes={}
local function screen(name,w,h)
  local obj={w=w,h=h,scaled=false,draws=0}
  function obj.getSize()return obj.w,obj.h end
  function obj.setTextScale(scale)
    assert(scale==0.5)
    obj.scaled=true
    if name=="small_monitor" then obj.w=20;obj.h=10 end
  end
  function obj.setCursorPos(x,y)end
  function obj.setTextColor()end
  function obj.setBackgroundColor()end
  function obj.clear()obj.draws=obj.draws+1 end
  function obj.write(value)
    writes[name]=writes[name] or {}
    writes[name][#writes[name]+1]=value
  end
  return obj
end
displays.main_monitor=screen("main_monitor",100,60)
displays.small_monitor=screen("small_monitor",10,5)
displays.large_monitor=screen("large_monitor",80,43)
displays.workstation=screen("workstation",82,40)
local api={
 getNames=function()return live end,
 getType=function(name)
   return name=="workstation" and "terminal" or "monitor"
 end,
 hasType=function(name,kind)
   return api and false
 end,
 wrap=function(name)return displays[name]end
}
local core={
 snapshot={stock={{name="iron",count=75}}},
 samples={{time=0,stress=12},{time=5,stress=15}},
 machines={{id="m",name="Iron"}},rates={m=7},
 devices={readings={},values={},list=function()return {}end},
 remote={nodes={},online=function()return false end},
 actual=function()return false end
}
local metrics=function()return {
 {"stress","Stress","%"},{"rpm","RPM","rpm"}
}end
local mgr=Manager.new(core,metrics,"main_monitor",api)
assert(mgr:discover()==3,"Must discover all three nonprimary displays")
assert(mgr.screens.main_monitor==nil)
assert(displays.small_monitor.scaled,"Small monitors should auto-scale to 0.5")
for _,name in ipairs({"small_monitor","large_monitor","workstation"}) do
  assert(displays[name].draws>0,"Screen "..name.." must be initialized")
end
local smallText=table.concat(writes.small_monitor," ")
assert(smallText:find("FPBCRAFT") and smallText:find("STOCK"),
  "Small monitor must show compact status instead of a blank display")
local large=mgr.screens.large_monitor
assert(large.page=="OVERVIEW")
assert(mgr:handle("monitor_touch","large_monitor",25,3))
assert(large.page=="GRAPHS","Secondary monitor input should be routed")
assert(mgr.screens.workstation.page=="OVERVIEW",
  "Other screens must keep independent navigation")
mgr:refresh()
assert(large.page=="GRAPHS","Periodic refresh must preserve selected pages")
local count,errors=mgr:status()
assert(count==3 and #errors==0)
local before=displays.large_monitor.draws
mgr:handle("monitor_resize","large_monitor")
assert(displays.large_monitor.draws>before)
-- A rendering error must be observable on the affected monitor.
core.devices.list=function()error("stock display failed")end
large.page="OVERVIEW"
assert(mgr:draw("large_monitor")==false)
local _,messages=mgr:status()
assert(messages[1] and messages[1]:find("large_monitor"),
  "Rendering errors must not be silently swallowed")
assert(table.concat(writes.large_monitor," "):find("SCREEN ERROR"))
core.devices.list=function()return {}end
assert(mgr:draw("large_monitor"))
-- Hot unplug a monitor; it must disappear from the manager's inventory.
live={"main_monitor","small_monitor","workstation"}
assert(mgr:discover()==2 and mgr.screens.large_monitor==nil)
print("Secondary monitor discovery, compact UI, refresh and diagnostics passed")
