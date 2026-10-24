-- Basalt TUI route planner navigation and paste regression.
local route={
 {id=1,x=10,y=80,z=20,name='Harbor',station=false,wait=0,main=8,fine=7,heading=90},
 {id=2,x=15,z=30,name='Station B',station=true,wait=2}
}
local presets={{x=10,z=20,name='Dock'}}
local routes={{key='route-a',name='Ferry',loop=false,points=route}}
local signals={forward={'minecraft:shaft','minecraft:ladder'},reverse={'minecraft:ladder','minecraft:shaft'},
 left={'minecraft:iron_ingot','minecraft:shaft'},right={'minecraft:shaft','minecraft:iron_ingot'},
 main={'minecraft:iron_ingot','minecraft:white_wool'},fine={'minecraft:oak_log','minecraft:white_wool'},
 engine={'minecraft:blue_wool','minecraft:white_wool'}}
local actions={}
local api={}
function api.snapshot()return {
 mode='idle',route=route,routeNext=1,routeIndex=1,routeLoop=false,
 savedRoutes=routes,routeName='Ferry',routeKey='route-a',presets=presets,
 position={x=10,y=80,z=20},outputs={main=8,fine=7},signals=signals,
 observedLevels={main=8,fine=7,engine=0},altitudeAssist=false,altRiseSign=1,engineAuto=false,
 notice='Ready',navName='nav',bridgeName='bridge',displayLinks=0,tick=1,tickAge=0,tickDuration=0,stage='waiting'
} end
function api.recordWaypoint(name,station)
 route[#route+1]={x=10,y=80,z=20,name=name or 'Recorded',heading=0,main=7,fine=8,station=station==true,wait=0}
 actions[#actions+1]='record';return true
end
function api.editStop(index,field)
 for k,v in pairs(field)do route[index][k]=tonumber(v) or v end
 actions[#actions+1]='stop:'..index
 return true
end
function api.setPower(name,level) actions[#actions+1]='power:'..name..':'..level;return true end
function api.altitudeSetting(key) actions[#actions+1]='assist:'..key;return true end
function api.acceptCurrentHeight() actions[#actions+1]='override';return true end
function api.setSignal(name,a,b) signals[name]={a,b};actions[#actions+1]='signal:'..name;return true end
function api.createRoute(name,dup)
 routes[#routes+1]={key='r'..#routes,name=name,points=dup and route or {}}
 actions[#actions+1]='new:'..name;return true
end
function api.selectRoute(_) return true end
function api.renameRoute(_,name) routes[1].name=name;return true end
function api.deleteRoute(_)return true end
function api.listDisks() return {{name='drive_0',mount='disk'}} end
function api.exportRoute(name,key) actions[#actions+1]='export:'..name;return true end
function api.importRoutes(name) actions[#actions+1]='import:'..name;return true end
function api.setPage()end
function api.stop()return true end
function api.fly()return true end
function api.flyMap()return true end
function api.addRoute()return true end
function api.editRoute()return true end
function api.removeRoute()return true end
function api.moveRoute(i,j)return i+j end
function api.addPreset()return true end
function api.editPreset()return true end
function api.removePreset()return true end
function api.capturePreset()return true end
function api.flyPreset()return true end
function api.presetToRoute()return true end
function api.resumeRoute()return true end
function api.flyRouteFrom()return true end
function api.setRouteLoop()return true end
function api.setting()return true end
function api.calibrate()return true end
colors={black=1,white=2,lightBlue=4,cyan=8,lightGray=16,gray=32,blue=64,yellow=128,lime=256,red=512,orange=1024}
term={getSize=function()return 35,16 end}
local buttons,inputs,labels={},{},{}
local function frame()
 local f={}
 function f:addFrame(_)return frame()end
 function f:addLabel(arg) labels[#labels+1]=arg.text;return {text=arg.text,destroy=function()end}end
 function f:addInput(arg)
   local input={text=arg.text}
   function input:onChange(fn)self.changed=fn end
   function input:onEnter(fn)self.entered=fn end
   function input:focus()end
   inputs[#inputs+1]=input
   return input
 end
 function f:addButton(arg)
   local button={text=arg.text}
   function button:onClick(fn)buttons[#buttons+1]={label=arg.text,call=fn}end
   return button
 end
 function f:destroy()buttons={} end
 return f
end
local jobs={}
local basalt={getMainFrame=function()return frame()end,createFrame=function()return frame()end,
 schedule=function(fn)jobs[#jobs+1]=fn end}
sleep=function()end
local function click(name)
 for i=#buttons,1,-1 do
  if buttons[i].label==name then return buttons[i].call() end
 end
 error('missing UI button: '..name..' available: '..table.concat((function()local t={} for _,b in ipairs(buttons)do t[#t+1]=b.label end return t end)(),', '))
end
function basalt.run()
 jobs[1]() -- run splash + initial render
 click('RT')
 local readable=false
 for _,row in ipairs(labels) do
  if row:find('X10 Z20 Y80 W0s',1,true) then readable=true end
 end
 assert(readable,'route row did not expose rounded X/Z, target altitude, wait')
 click('DETAIL')
 click('SET STATION')
 assert(route[1].station)
 click('WAIT TIME')
 local input=inputs[#inputs];assert(input)
 input.text='12.5';input.changed(input)
 click('SAVE')
 assert(route[1].wait==12.5,'Wait edit through keyboard failed')
 click('Y TOLERANCE')
 input=inputs[#inputs]; input.text='2.5';input.changed(input)
 click('SAVE')
 assert(route[1].yTolerance==2.5,'station Y tolerance editor failed')
 click('BACK')
 click('RECORD')
 assert(#route==3 and actions[#actions]=='record','record button failed')
 click('LIBRARY')
 click('NEW')
 input=inputs[#inputs]
 input.text='Tour of Town';input.changed(input)
 click('SAVE')
 assert(actions[#actions]=='new:Tour of Town','route naming paste failed')
 click('EXPORT')
 click('EXPORT SELECTED ROUTE')
 assert(actions[#actions]=='export:drive_0','floppy export UI failed')
 click('BACK TO LIBRARY')
 click('BACK TO WAYPOINTS')
 click('SET')
 click('CONFIGURE CONTROL SIGNALS')
 click('EDIT SELECTED FREQUENCY')
 input=inputs[#inputs]
 input.text='minecraft:diamond minecraft:redstone';input.changed(input)
 click('SAVE')
 assert(actions[#actions]=='signal:forward','config item ID paste failed')
 click('PWR')
 local linkReadout=false
 for _,row in ipairs(labels) do
  if row:find('Link 8',1,true) then linkReadout=true end
 end
 assert(linkReadout,'POWER page must show observed Redstone Link levels')
 click('+') -- engine row is the last + button on the page
 assert(actions[#actions]=='power:engine:1','engine power controls did not send level')
 click('Y ASSIST OFF')
 assert(actions[#actions]=='assist:assist','Y assist UI toggle missing')
 click('RISE: +SIGN')
 assert(actions[#actions]=='assist:direction','rise direction UI toggle missing')
end
package.preload.basalt=function()return basalt end
assert(loadfile('airship/ui.lua'))().run(api)
print('PASS Basalt route UI: record, station, wait paste, new route, floppy, frequency configuration')
