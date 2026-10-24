-- Basalt 2.5 storefront. Optional dependency, never required by the games.
-- If Basalt is absent or incompatible, fpbstore/main.lua uses its existing UI.
local B={}
function B.run(manager)
 local ok,basalt=pcall(require,"basalt")
 if not ok or type(basalt)~="table" or
  type(basalt.getMainFrame)~="function" or
  type(basalt.run)~="function" then return false end
 manager.refreshVersions()
 local frame=basalt.getMainFrame()
 local w,h=term.getSize()
 if w<36 or h<16 then return false end
 frame.background=colors.black
 local selected=1
 local message="SELECT A GAME"
 local action="none"
 local function label(x,y,width,text,color)
  local item=frame:addLabel({x=x,y=y,width=width,
   text=tostring(text):sub(1,width)})
  item.foreground=color or colors.white
  return item
 end
 local function button(x,y,width,title,fn)
  return frame:addButton({x=x,y=y,width=width,height=1,text=title})
   :onClick(fn)
 end
 label(2,2,w-3,"FPB STORE  /  GAMES",colors.orange)
 label(2,3,w-3,"INSTALL - UPDATE - PLAY - REMOVE",colors.lightBlue)
 local status=label(2,h-2,w-3,message,colors.yellow)
 local appButtons={}
 local function refresh()
  for i,item in ipairs(appButtons)do
   local app=manager.catalog.apps[i]
   local info=manager.status(app)
   local installed=info.installedVersion and ("v"..info.installedVersion) or
    (info.installed and "v?" or "NOT INSTALLED")
   local latest=info.latestVersion and ("v"..info.latestVersion) or "?"
   local upgrade=info.updateAvailable and " UPDATE!" or ""
   item.text=((i==selected and "> " or "  ")..app.name..
    " "..installed.." > "..latest..upgrade):sub(1,w-5)
  end
  status.text=message:sub(1,w-3)
 end
 local y=5
 for i,app in ipairs(manager.catalog.apps)do
  local index=i
  appButtons[i]=button(2,y,w-4,"",function()
   selected=index;message=app.subtitle;refresh()
  end)
  y=y+2
 end
 local function finish(name)
  action=name
  basalt.stop()
 end
 local row=h-7
 local width=math.floor((w-5)/3)
 button(2,row,width,"INSTALL/UPDATE",function()finish("install")end)
 button(3+width,row,width,"PLAY",function()finish("play")end)
 button(4+width*2,row,width,"REMOVE",function()finish("remove")end)
 button(2,row+2,math.max(12,w-4),"UPDATE STORE",function()finish("store-update")end)
 button(2,row+4,math.max(12,w-4),"EXIT",function()finish("exit")end)
 refresh()
 basalt.run()
 return true,action,manager.catalog.apps[selected]
end
return B
