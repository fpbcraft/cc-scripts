-- Verify the entry point applies scale 0.5 before the CC: Graphics canvas is
-- initialized, and restores the previous monitor scale on exit.
local script=(arg and arg[0]) or ''
local root=script:match('^(.*)/games/railbreak/tests/[^/]+$') or '.'
package.path=root..'/games/railbreak/?.lua;'..root..'/games/railbreak/?/init.lua;'..package.path
local calls={}
local m={scale=1, firstScreenSize=nil}
function m.setTextScale(value)assert(value==0.5 or value==1);calls[#calls+1]=value;m.scale=value end
function m.getTextScale()return m.scale end
function m.getSize(mode)
  local cw,ch=m.scale==0.5 and 135 or 65,m.scale==0.5 and 92 or 42
  if mode then return cw*6,ch*9 end
  if m.scale==0.5 then m.firstScreenSize=m.firstScreenSize or {cw,ch,m.scale} end
  return cw,ch
end
function m.setGraphicsMode(_)end
function m.setPaletteColor(...)end
function m.getPaletteColor(...)return 0,0,0 end
function m.setFrozen(_)end
function m.drawPixels(...)end
local env={}
setmetatable(env,{__index=_G})
env.term={current=function()return m end}
env.peripheral={getNames=function()return {'monitor_0'}end,getType=function()return 'monitor'end,wrap=function()return m end}
env.os=setmetatable({pullEvent=function()error('__STOP_AFTER_DRAW__',0)end}, {__index=os})
local entry,err=loadfile(root..'/games/railbreak/main.lua','t',env)
assert(entry,err)
local ok,why=pcall(entry)
assert(not ok and tostring(why):find('__STOP_AFTER_DRAW__',1,true), 'Expected intentional halt after first render: '..tostring(why))
assert(calls[1]==0.5,'Monitor should switch to text scale 0.5 before UI startup')
assert(m.firstScreenSize[1]==135 and m.firstScreenSize[2]==92 and m.firstScreenSize[3]==0.5,
 'Renderer must read dimensions after monitor text scale 0.5')
assert(calls[#calls]==1 and m.scale==1,'The original monitor scale must be restored on exit')
print('MONITOR SCALE: 0.5 applied before rendering and restored on exit')
