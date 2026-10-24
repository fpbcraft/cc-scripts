-- Runtime smoke test: monitor scale, standard touch, addon button-aware removal.
package.path="./?.lua;./?/init.lua;"..package.path
local E=require("cogworks.engine")
colors={black=32768,white=1,gray=128,lightGray=256,orange=2,
 lightBlue=8,yellow=16,green=8192,blue=2048,lime=32,red=16384,brown=4096}
local m={w=55,h=35,scale=1,writes=0,history={}}
function m.getSize()return m.w,m.h end
function m.getTextScale()return m.scale end
function m.setTextScale(scale)m.scale=scale;m.history[#m.history+1]=scale end
function m.setBackgroundColor(_)end
function m.setTextColor(_)end
function m.clear()end
function m.setCursorPos(x,y)
 assert(x>=1 and x<=m.w and y>=1 and y<=m.h,"Invalid monitor cursor")
end
function m.write(s)m.writes=m.writes+#s end
function m.isColor()return true end
peripheral={
 getNames=function()return {"monitor_1"}end,
 getType=function(side)if side=="monitor_1"then return "monitor"end end,
 wrap=function(side)if side=="monitor_1"then return m end end,
}
local saved={}
local store={}
fs={}
function fs.exists(path)return store[path]~=nil end
function fs.open(path,mode)
 if mode=="r"then
  if not store[path]then return nil end
  return {readAll=function()return store[path]end,close=function()end}
 end
 assert(mode=="w","Unexpected mode")
 return {write=function(s)store[path]=s end,close=function()end}
end
function fs.delete(path)store[path]=nil end
function fs.move(a,b)assert(store[a]);store[b]=store[a];store[a]=nil end
textutils={
 serialize=function(data)
  local savedData={unlocked=data.unlocked,level=data.level,bonuses=data.awards}
  local stage=data.sessions[data.level]
  savedData.parts=stage and stage.parts or {}
  saved[#saved+1]=savedData
  return "MOCK_SAVE"
 end,
 unserialize=function(_)return nil end,
}
local events={
 {"monitor_touch","monitor_1",14,10}, -- standard right-click, place shaft
 {"monitor_touch","monitor_1",14,10,2}, -- addon supplies right button, remove
 {"char","q"},
}
local position=0
local pull=os.pullEventRaw
local timer=os.startTimer
os.startTimer=function()return 1 end
os.pullEventRaw=function()
 position=position+1
 assert(events[position],"Unexpected event poll")
 return table.unpack(events[position])
end
local ok,err=pcall(function()
 local game=assert(loadfile("cogworks/main.lua"))
 game()
end)
os.pullEventRaw=pull
os.startTimer=timer
assert(ok,tostring(err))
assert(m.writes>0,"Main should render")
assert(m.history[1]==0.5,"Main must force monitor scale to 0.5")
assert(m.scale==1,"Main must restore previous monitor scale")
assert(#saved==2,"Both placement and remove need to save")
assert(#saved[1].parts==1 and saved[1].parts[1].kind=="I",
 "Vanilla right-click should build/rotate")
assert(#saved[2].parts==0,"Extended button 2 should remove directly")
print("COGWORKS: monitor scale and optional button-aware input passed.")
