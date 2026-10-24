local S=require('games.railbreak.game.state')
local U=require('games.railbreak.core.util')
local M={}
function M.save(g)
 if not fs or not textutils then return false,'Minecraft file API unavailable' end
 local root='/games/railbreak/data'
 local ok,err=pcall(function()
  if not fs.exists(root) then fs.makeDir(root) end
  local path=root..'/save.lua';local tmp=path..'.new';local bak=path..'.bak'
  local h=assert(fs.open(tmp,'w'));h.write(textutils.serialize(g));h.close()
  if fs.exists(bak) then fs.delete(bak) end
  if fs.exists(path) then fs.move(path,bak) end
  local moved,why=pcall(fs.move,tmp,path)
  if not moved then
   if fs.exists(bak) and not fs.exists(path)then fs.move(bak,path)end
   error(why)
  end
  if fs.exists(bak) then fs.delete(bak) end
 end)
 return ok,err
end
function M.load()
 if not fs or not textutils then return nil end
 for _,p in ipairs({'/games/railbreak/data/save.lua','/games/railbreak/data/save.lua.bak'}) do
  local ok,state=pcall(function()
   if not fs.exists(p) then return nil end
   local h=assert(fs.open(p,'r'));local raw=h.readAll();h.close()
   return textutils.unserialize(raw)
  end)
  if ok and S.valid(state)then return state end
 end
 return nil
end
return M
