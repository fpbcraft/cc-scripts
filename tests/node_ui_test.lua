package.path="./node/?.lua;"..package.path
local Pairing=require("pairing")
local files={disk=true,["disk/notes.txt"]="keep this file"}
local function serialize(t)
  local result={}
  for k,v in pairs(t) do
    local val=type(v)=="string" and string.format("%q",v) or tostring(v)
    result[#result+1]=("["..string.format("%q",k).."]="..val)
  end
  return "{"..table.concat(result,",").."}"
end
fs={
  exists=function(path)return files[path]~=nil end,
  combine=function(a,b)return a.."/"..b end,
  isReadOnly=function(path)return false end,
  delete=function(path)files[path]=nil end,
  move=function(a,b)files[b]=files[a];files[a]=nil end,
  open=function(path,mode)
    if mode=="w" then
      return {write=function(value)files[path]=value end,close=function()end}
    end
    if not files[path] then return nil end
    return {readAll=function()return files[path]end,close=function()end}
  end
}
peripheral={
  getNames=function()return {"left"}end,
  getType=function(name)return name=="left" and "drive"end,
  hasType=function(_,kind)return kind=="drive"end,
}
disk={getMountPath=function()return "disk"end,eject=function()end}
textutils={serialize=serialize,unserialize=function(raw)
  return assert(load("return "..raw))()
end}
local cfg={name="Andesite Farm",key=string.rep("a",48)}
assert(#Pairing.drives()==1)
local ok,msg,drive=Pairing.export(cfg,42)
assert(ok and drive.name=="left" and msg:find("copied"))
local p=textutils.unserialize(files["disk/fpb_pairing.db"])
assert(p.node==42 and p.key==cfg.key and p.name=="Andesite Farm")
assert(p.managed==nil and p.hubId==nil)
local again,same=Pairing.export(cfg,42)
assert(again and same=="Already on disk")
local cfg2={name="Iron Farm",key=string.rep("b",48)}
local denied,why=Pairing.export(cfg2,43)
assert(not denied and why:find("confirm overwrite"))
assert(textutils.unserialize(files["disk/fpb_pairing.db"]).node==42)
local replaced=Pairing.export(cfg2,43,{replace=true})
assert(replaced and textutils.unserialize(files["disk/fpb_pairing.db"]).node==43)
assert(files["disk/notes.txt"]=="keep this file")
-- Test local UI controls without loading Basalt or starting the radio loop.
colors={black=1,white=2,cyan=3,lightGray=4,lime=5,orange=6,
 yellow=7,green=8,blue=9,gray=10}
keys={e=18,k=37,r=19}
term={
  getSize=function()return 51,20 end,
  setCursorPos=function()end,setBackgroundColor=function()end,
  setTextColor=function()end,clear=function()end,clearLine=function()end,
  write=function()end
}
local UI=require("ui")
local called=0
local view=UI.new({
  info=function()
    return {id=43,name="Iron Farm",key=cfg2.key,
      wireless=true,hubId=nil,sensors=2,outputs=0}
  end,
  drives=Pairing.drives,
  export=function(replace)
    called=called+1
    return Pairing.export(cfg2,43,{replace=replace})
  end
})
view:draw()
local exportButton
for _,b in ipairs(view.buttons) do
  if b.id=="export" then exportButton=b end
end
assert(exportButton and exportButton.enabled)
view:handle("mouse_click",1,exportButton.x,exportButton.y)
assert(called==1 and view.status:find("Already on disk"))
view:handle("key",keys.k)
assert(view.showKey)
view:handle("key",keys.e)
assert(called==2)
-- Basic computers do not emit mouse_click; keyboard E and Enter still work.
keys.j=36;keys.tab=15;keys.enter=28;keys.numPadEnter=156
local before=called
view:handle("key",keys.e)
assert(called==before+1)
view.focus=1
view:handle("key",keys.enter)
assert(called==before+2)
-- An attached Advanced Monitor generates monitor_touch(side,x,y).
local screen={
  isColor=function()return true end,
  getSize=function()return 51,24 end,
  setCursorPos=function()end,setBackgroundColor=function()end,
  setTextColor=function()end,clear=function()end,clearLine=function()end,
  write=function()end
}
peripheral.getNames=function()return {"left","back"}end
peripheral.getType=function(name)
  return name=="back" and "monitor" or "drive"
end
peripheral.wrap=function(name)
  return name=="back" and screen or nil
end
view:selectDisplay()
assert(view.monitorName=="back")
view:draw()
local action
for _,b in ipairs(view.buttons) do
  if b.id=="export" then action=b;break end
end
assert(action)
before=called
view:handle("monitor_touch","left",action.x,action.y)
assert(called==before,"Touches on a different monitor must be ignored")
view:handle("monitor_touch","back",action.x,action.y)
assert(called==before+1,"Advanced Monitor touches must activate buttons")
print("Node pairing disk and GUI tests passed")
