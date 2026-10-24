-- Original note sequences; no downloaded audio assets or blocking playback loops.
local A={};A.__index=A
local melody={12,16,19,16,14,17,21,17,12,19,24,19,11,14,19,14}
local effects={click={12},move={14,19},build={12,16},research={16,21},turn={12,19},error={6}}
function A.new()
 local self=setmetatable({enabled=true,volume=.3,step=1},A)
 for _,name in ipairs(peripheral.getNames())do
  if peripheral.getType(name)=='speaker'then self.speaker=peripheral.wrap(name);break end
 end
 local path='/games/civcraft/data/audio.dat'
 if fs and fs.exists(path)then
  local file=fs.open(path,'r')
  if file then local saved=textutils.unserialize(file.readAll());file.close();if type(saved)=='table'then self.enabled=saved.enabled~=false end end
 end
 return self
end
function A:note(instrument,note,volume)
 if self.enabled and self.speaker and self.speaker.playNote then pcall(self.speaker.playNote,instrument,volume or self.volume,note)end
end
function A:effect(name)
 for _,note in ipairs(effects[name]or effects.click)do self:note(name=='error'and 'bass'or 'harp',note,.45)end
end
function A:update(screen)
 if screen=='title' and self.enabled and self.speaker and os.startTimer then
  self:note('harp',melody[self.step],.22)
  if self.step%4==1 then self:note('bass',math.max(0,melody[self.step]-12),.18)end
  self.step=self.step%#melody+1;self.timer=os.startTimer(.38)
 else self.timer=nil end
end
function A:toggle(screen)
 self.enabled=not self.enabled
 local path='/games/civcraft/data';if not fs.exists(path)then fs.makeDir(path)end
 local file=fs.open(path..'/audio.dat','w');if file then file.write(textutils.serialize({enabled=self.enabled}));file.close()end
 self:update(screen);return self.enabled
end
return A
