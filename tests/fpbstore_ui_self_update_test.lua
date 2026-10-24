-- Exercise real storefront update UI with no package, require, or shell.
-- A successful update must reload the installed entry point from disk.
local originalPackage,originalRequire,originalDofile=package,require,dofile
local originalLoadfile=loadfile
local updated,relaunched=false,false
local app={id="cogworks",name="COGWORKS",subtitle="LAB",genre="PUZZLE",
 description="A puzzle",entry="/cogworks/main.lua"}
local manager={
 catalog={apps={app}},installed=function()return true end,
 status=function()return {installed=true,installedVersion="1.0.0",
 latestVersion="1.0.0",updateAvailable=false}end,
 storeStatus=function()return {installedVersion="1.1.3"}end,
 installedRevision=function()return nil end,
 refreshVersions=function()return true end,
 updateStore=function()updated=true;return true end
}
local screen={}
for _,fn in ipairs({"setBackgroundColor","setTextColor","clear","setCursorPos",
 "write"})do screen[fn]=function()end end
screen.getSize=function()return 100,35 end
term={current=function()return screen end,redirect=function()end}
colors={black=32768,white=1,orange=2,gray=128,lightBlue=8,
 yellow=16,lightGray=256,blue=2048,lime=32}
keys={q=16,escape=1}
local events={{"mouse_click",1,53,29},{"key",keys.q}}
local index=0
local originalPull=os.pullEvent
os.pullEvent=function()
 index=index+1
 local event=events[index]
 assert(event,"UI event loop never exited")
 return table.unpack(event)
end
dofile=function(path)
 if path=="/fpbstore/manager.lua"then return manager end
 error("Unexpected dependency: "..path)
end
loadfile=function(path)
 if path=="/fpbstore/main.lua"then
  return function()relaunched=true end
 end
 return originalLoadfile(path)
end
package=nil;require=nil; shell=nil
local ok,err=pcall(function()
 return originalLoadfile("fpbstore/main.lua")("--classic")
end)
package,require,dofile,loadfile=originalPackage,originalRequire,originalDofile,originalLoadfile
os.pullEvent=originalPull
assert(ok,tostring(err))
assert(updated,"Store update button must execute manager.updateStore")
assert(relaunched,"Updated store must be loaded and relaunched")
print("FPB Store: graphical update action and disk reload without package or shell.")
