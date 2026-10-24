-- Real installed Store + real portable UI, with no shell/package/require.
local disk=dofile('tests/support/craftos.lua').new()
disk.install('fpbstore','main','--no-startup')
local screen=dofile('tests/support/store_screen.lua').new(51,19)
disk.env.colors=screen.colors;disk.env.keys=screen.keys
local target=screen
disk.env.term={current=function()return target end,redirect=function(t)target=t end}
disk.withoutRuntime()
local calls=0;local installedMain=disk.files['/apps/fpbstore/main.lua']
disk.env.os=setmetatable({pullEvent=function()
 calls=calls+1
 if calls==1 then
  assert(screen.text():find('FPB STORE 2.0.0',1,true))
  return 'char','u'
 end
 error('Updated Store should have reloaded the new main')
end},{__index=os})
-- Update through the real manager/bootstrap/engine. Only the downloaded main
-- fixture exits immediately so that the test observes the disk reload.
local get=disk.env.http.get
local updated=false
disk.env.http.get=function(url)
 if url:find('/apps/fpbstore/main.lua?',1,true)then
  updated=true
  local body='_G.storeReloaded=true;return true'
  return {getResponseCode=function()return 200 end,readAll=function()return body end,close=function()end}
 end
 return get(url)
end
disk.run('fpbstore')
assert(updated and disk.files['/apps/fpbstore/main.lua']~=installedMain)
-- The sentinel is inside the new loader environment, so observe its source on disk
-- and successful return after exactly one input event rather than global leakage.
assert(calls==1,'Self-update re-enters the installed main with a fresh module cache')
assert(target==screen and screen.mode==0,'Store terminal restored')
print('Store UI self-update downloads, installs and reloads without shell or package')
