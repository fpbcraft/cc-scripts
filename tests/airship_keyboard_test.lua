-- Basalt keyboard / clipboard regression with an attached touch monitor.
-- Keyboard events belong to the *computer* root; monitor uses touch events.
local calls={}
local core={monitor={getSize=function()return 52,23 end},monitorName='monitor_left',
 snapshot=function()return {mode='idle',route={},routeNext=1,presets={},
  position={x=0,z=0,y=100},outputs={},notice='Ready'}end,
 fly=function(x,z,name)calls[#calls+1]={x=x,z=z,name=name};return true end,
 flyMap=function()return true end,stop=function()return true end,
 setPage=function()end,
}
colors={black=1,white=2,lightBlue=4,cyan=8,lightGray=16,gray=32,blue=64,
 yellow=128,lime=256,red=512,orange=1024}
term={getSize=function()return 51,19 end}
local buttons={}
local inputs={}
local labels={}
local function frame()
 local f={}
 function f:addFrame(_)return frame()end
 function f:addLabel(args)
  local o={text=args.text}
  labels[#labels+1]=o
  function o:destroy()end
  return o
 end
 function f:addButton(args)
  local o={text=args.text}
  function o:onClick(fn)buttons[#buttons+1]={text=self.text,fn=fn}end
  return o
 end
 function f:addInput(args)
  local o={text=args.text or ''}
  inputs[#inputs+1]=o
  function o:onChange(cb)self.changed=cb end
  function o:onEnter(cb)self.enter=cb end
  function o:focus()self.focused=true end
  function o:paste(v)
   self.text=v
   if self.changed then self.changed(self,v)end
  end
  return o
 end
 function f:destroy()end
 return f
end
local scheduler={}
local basalt={getMainFrame=function()return frame()end,
 createFrame=function()return frame()end,
 schedule=function(fn)scheduler[#scheduler+1]=fn end}
package.preload.basalt=function()return basalt end
sleep=function()end
local function click(name)
 for i=#buttons,1,-1 do
  if buttons[i].text==name then return buttons[i].fn() end
 end
 error('Button not found: '..name)
end
local function latestInputs()
 assert(#inputs>=3,'The computer must have real Basalt Input elements')
 return inputs[#inputs-2],inputs[#inputs-1],inputs[#inputs]
end
function basalt.run()
 scheduler[1]() -- splash then flight
 click('FLY TO X/Z')
 local x,z,name=latestInputs()
 assert(x.focused,'X input must start keyboard-focused')
 x:paste('120 -340') -- Ctrl+V on physical computer, not the monitor
 assert(x.text=='120' and z.text=='-340',
   'pasted coordinate pair not split to X/Z: '..tostring(x.text)..' / '..tostring(z.text))
 name:paste('Base Camp')
 click('SAVE / FLY') -- monitor touch submits values from physical keyboard
end
local ui=assert(loadfile('apps/airship/ui.lua'))()
ui.run(core)
assert(#calls==1,'Expected exactly one destination submitted')
assert(calls[1].x==120 and calls[1].z==-340 and calls[1].name=='Base Camp',
 'Pasted coordinates/name not used by autopilot')
print('Basalt keyboard/paste: PASS (terminal keyboard, monitor touch, coordinate pair)')
