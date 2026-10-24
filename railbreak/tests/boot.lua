-- Reproduce CraftOS program-local `require` with its virtual filesystem mounted
-- at the repository root. This catches missing absolute module search paths.
local script=(arg and arg[0]) or ''
local root=script:match('^(.*)/railbreak/tests/[^/]+$') or '.'

local env={package={path='?.lua;?/init.lua;/rom/modules/main/?.lua'}}
setmetatable(env,{__index=_G})
local loaded,paths={},{}

function env.require(name)
 if loaded[name]~=nil then return loaded[name] end
 local part=name:gsub('%.','/')
 for pattern in env.package.path:gmatch('[^;]+') do
  local virtual=pattern:gsub('%?',part)
  -- Only absolute filesystem paths can be resolved from the test mount.
  if virtual:sub(1,1)=='/' then
   local filename=root..virtual
   local f=io.open(filename,'r')
   if f then
    f:close()
    local chunk,err=loadfile(filename,'t',env)
    assert(chunk,err)
    -- Cache before execution to mirror the CC loader's recursive protections.
    loaded[name]=true
    local result=chunk()
    if result~=nil then loaded[name]=result end
    paths[name]=virtual
    return loaded[name]
   end
  end
 end
 error('Unable to find module '..name,2)
end

local entry,err=loadfile(root..'/railbreak/main.lua','t',env)
assert(entry,err)
local ok,api=pcall(entry,'--test-api')
assert(ok,'Train-first entry point cannot boot with CC:Tweaked module paths: '..tostring(api))
assert(type(api)=='table' and type(api.UI)=='table' and type(api.State)=='table' and type(api.Rules)=='table',
 'Train-first boot must return all modules in --test-api mode')
assert(paths['train.ui']=='/railbreak/train/ui.lua','UI module did not resolve from installation root')
assert(paths['core.util']=='/railbreak/core/util.lua','Nested shared module did not resolve')
local n=0
for _ in pairs(paths) do n=n+1 end
assert(n>=8,'Expected all train, render and shared modules to load')
print('CC:TWEAKED BOOT: '..n..' modules loaded from absolute /railbreak paths')
