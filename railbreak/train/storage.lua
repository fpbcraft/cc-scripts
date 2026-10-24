-- Versioned, independent save slot. Never rewrites the v1 factory edition save.
local S=require('railbreak.train.state')
local M={}
local dir='/railbreak/data';local name=dir..'/train-save.lua'
function M.save(g)
 if not fs or not textutils then return false,'CraftOS file API not available' end
 if not S.valid(g) then return false,'Invalid expedition state' end
 local ok,err=pcall(function()
  if not fs.exists(dir) then fs.makeDir(dir)end
  local tmp=name..'.tmp';local bak=name..'.bak'
  local h=assert(fs.open(tmp,'w'));h.write(textutils.serialize(g));h.close()
  local previous=fs.exists(name)
  if previous then
   if fs.exists(bak) then fs.delete(bak)end
   fs.copy(name,bak)
  end
  local status,why=pcall(function()
   if previous then fs.delete(name)end
   fs.move(tmp,name)
  end)
  if not status then
   if previous and fs.exists(bak)then fs.copy(bak,name)end
   error(why)
  end
 end)
 return ok,err
end
function M.load()
 if not fs or not textutils then return nil end
 for _,path in ipairs({name,name..'.bak'})do
  local ok,g=pcall(function()
   if not fs.exists(path) then return nil end
   local h=assert(fs.open(path,'r'));local raw=h.readAll();h.close()
   return textutils.unserialize(raw)
  end)
  if ok and S.valid(g) then return g end
 end
 return nil
end
return M
