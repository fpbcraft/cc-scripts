package.path="./factory/?.lua;"..package.path
colors={black=32768,white=1,blue=2,cyan=4,orange=8,lime=16,
 lightGray=32,yellow=64,red=128}
local Screen=require("screen_dashboard")
local function surface(w,h)
  local out={draws=0}
  function out.getSize()return w,h end
  function out.setCursorPos()end
  function out.setBackgroundColor()end
  function out.setTextColor()end
  function out.clear()out.draws=out.draws+1 end
  function out.write()end
  return out
end
local samples={}
for t=0,100,5 do
  samples[#samples+1]={time=t,stress=t/2,rpm=t*2,
    stock=100+t,rate=5+t/10}
end
local metrics={
 {"stress","Stress","%"},{"rpm","RPM","rpm"},
 {"stock","Stock","items"},{"rate","Rate","items/min"}
}
local core={samples=samples,machines={{id="iron",name="Iron Farm"}},
  snapshot={stock={{name="item",count=55}}},
  devices={readings={},values={},list=function()return {}end},
  remote={nodes={},online=function()return false end},
  rates={iron=8},actual=function()return false end}
local a=Screen.new("monitor_1",surface(90,45),core,function()return metrics end,"monitor")
local b=Screen.new("terminal_1",surface(90,45),core,function()return metrics end,"terminal")
a:draw();b:draw()
assert(a.page=="OVERVIEW" and b.page=="OVERVIEW")
assert(a:handle("monitor_touch","monitor_1",24,3))
assert(a.page=="GRAPHS" and b.page=="OVERVIEW",
  "Displays must have independent navigation state")
assert(b:handle("terminal_mouse_click","terminal_1",1,24,3))
assert(b.page=="GRAPHS")
assert(not b:handle("terminal_mouse_up","terminal_1",1,24,3))
assert(b.page=="GRAPHS")
a:draw();b:draw()
local first,second=a.tiles[1],a.tiles[2]
assert(first and second)
-- Advanced Monitor supports tap-to-select then tap-to-place.
a.reorder=true
a:activate(first.x,first.y)
assert(a.selection==first.id)
a:activate(second.x,second.y)
assert(a.reorderCount==1 and a.selection==nil)
assert(a.order[2]==first.id)
-- Advanced Terminal reports actual drag and release events.
b:draw()
local f,t=b.tiles[1],b.tiles[2]
assert(b:handle("terminal_mouse_click","terminal_1",1,f.x,f.y))
assert(b:handle("terminal_mouse_drag","terminal_1",1,t.x,t.y))
assert(b:handle("terminal_mouse_up","terminal_1",1,t.x,t.y))
assert(b.reorderCount==1 and b.order[2]==f.id)
assert(a.order[1]~=b.order[1] or a.order[2]==b.order[2])
-- Drag and reordering must never call the machine actuator.
assert(a.page=="GRAPHS" and b.page=="GRAPHS")
a.range=60
assert(b.range==300,"Each display has its own time window")
print("Independent monitor and Advanced Terminal drag/drop tests passed")
