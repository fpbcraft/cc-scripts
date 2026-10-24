-- Reproduce CraftOS iOS shell-less process where Lua package/require are nil.
-- Load the actual store entrypoint, manager and catalog without mocks.
local originalPackage,originalRequire,originalDofile=package,require,dofile
dofile=function(path)
 local localPath=path:gsub("^/","")
 local chunk,err=loadfile(localPath)
 assert(chunk,err)
 return chunk()
end
package=nil
require=nil
local ok,result=pcall(function()
 local main=assert(loadfile("fpbstore/main.lua"))
 return main("--test-api")
end)
package,require,dofile=originalPackage,originalRequire,originalDofile
assert(ok,"Store boot without package/require failed: "..tostring(result))
assert(type(result)=="table" and type(result.status)=="function","Manager loaded")
assert(#result.catalog.apps>=4,"Installed game catalog loaded")
print("FPB Store: entrypoint, manager and catalog boot without package or require.")
