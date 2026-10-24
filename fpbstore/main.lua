-- FPB Store: terminal-first game manager, responsive to computer and monitor size.
-- Launch: /store.lua or /fpbstore/main.lua
package.path="/?.lua;/?/init.lua;"..package.path
local Manager=require("fpbstore.manager")
local catalog=Manager.catalog
local args={...}
if args[1]=="--test-api"then return Manager end
-- Basalt supplies a responsive terminal shell when installed. It never
-- replaces native pixel gameplay and remains optional for plain CraftOS.
if args[1]~="--classic" then
 local available,modern=pcall(require,"fpbstore.basalt_ui")
 if available and modern and modern.run then
  local keepRunning=true
  while keepRunning do
   local ok,supported,action,app=pcall(modern.run,Manager)
   if not ok or not supported then break end
   if action=="exit" or action=="none" then return end
   if action=="remove" then
    term.setBackgroundColor(colors.black);term.clear()
    term.setCursorPos(1,1)
    print("Remove "..app.name.." application code?")
    print("Saves and settings will be preserved.")
    write("Type REMOVE to confirm: ")
    if read()~="REMOVE" then action="cancel" end
   end
   if action~="cancel" then
    local success,reason=pcall(function()
     if action=="install" then Manager.install(app)
     elseif action=="play"then
      if Manager.installed(app)then Manager.launch(app)
      else error("Install "..app.name.." first")end
     elseif action=="remove"then Manager.remove(app,false)
     elseif action=="store-update"then Manager.updateStore()
     end
    end)
    if not success then
     term.setBackgroundColor(colors.black);term.clear()
     term.setCursorPos(1,1);print("FPB STORE ERROR")
     print(tostring(reason))
     print("Press any key to return to the Store.")
     os.pullEvent("key")
    end
    if success and action=="store-update"then
     package.loaded["fpbstore.catalog"]=nil
     package.loaded["fpbstore.manager"]=nil
     package.loaded["fpbstore.basalt_ui"]=nil
     assert(shell.run("/fpbstore/main.lua"),"Updated Store failed to relaunch")
     return
    end
   end
  end
 end
end
local screen=term.current()
local selected=1
local confirmation=nil
local banner="SELECT AN APP"
local busy=false
local restartAfterUpdate=false
local versionNotice="Versions not checked"
local buttons={}
local function centered(s,w)
 s=tostring(s)
 if #s>=w then return s:sub(1,w)end
 return (" "):rep(math.floor((w-#s)/2))..s
end
local function put(x,y,s,fg,bg,max)
 local w,h=screen.getSize()
 if y<1 or y>h or x>w or x<1 then return end
 s=tostring(s)
 local cap=math.min(max or #s,w-x+1)
 if cap<=0 then return end
 screen.setCursorPos(x,y)
 screen.setTextColor(fg or colors.white)
 screen.setBackgroundColor(bg or colors.black)
 screen.write(s:sub(1,cap))
end
local function button(x,y,w,label,action,arg,enabled)
 local width,height=screen.getSize()
 if y<1 or y>height-1 then return end
 w=math.min(w,width-x+1)
 if w<3 then return end
 local bg=enabled==false and colors.gray or colors.blue
 put(x,y,centered(label,w),colors.white,bg,w)
 if enabled~=false then
  buttons[#buttons+1]={x=x,y=y,w=w,action=action,arg=arg}
 end
end
local function draw()
 buttons={}
 local w,h=screen.getSize()
 screen.setBackgroundColor(colors.black)
 screen.clear()
 local compact=w<52 or h<23
 local first=math.min(w,math.max(1,w))
 local storeVersion=Manager.storeStatus()
 put(1,1,centered(" FPB STORE v"..(storeVersion.installedVersion or "?").." / CC APPS ",first),colors.orange,colors.gray,first)
 put(2,2,"INSTALL  |  UPDATE  |  PLAY  |  REMOVE",colors.lightBlue,nil,w-2)
 if confirmation then
  put(2,4,"CONFIRM: "..confirmation.name,colors.yellow,nil,w-2)
  put(2,6,confirmation.description,colors.white,nil,w-2)
  if confirmation.kind=="remove" then
   put(2,8,"Save data will be preserved.",colors.lime,nil,w-2)
  end
  button(2,math.min(h-4,10),math.min(18,w-4),"CANCEL","cancel")
  button(math.max(2,math.min(w-19,22)),math.min(h-4,10),
   math.min(18,w-4),"CONFIRM","confirm")
 else
  local listTop=compact and 4 or 5
  for i,app in ipairs(catalog.apps)do
   local y=listTop+(i-1)*(compact and 2 or 3)
   local status=Manager.status(app)
   local active=selected==i
   local installedLabel=status.installed and
    ("v"..(status.installedVersion or "?")) or "NOT INSTALLED"
   local latestLabel=status.latestVersion and ("v"..status.latestVersion) or "?"
   local flag=status.updateAvailable and " [UPDATE AVAILABLE]" or ""
   local name=app.name.."  "..installedLabel.." / latest "..latestLabel..flag
   put(2,y,(active and "> " or "  ")..name,
    active and colors.yellow or colors.white,nil,w-3)
   if not compact then
    put(5,y+1,app.subtitle.." - "..app.genre,
     colors.lightGray,nil,w-6)
   end
   buttons[#buttons+1]={x=1,y=y,w=w,action="select",arg=i}
  end
  local app=catalog.apps[selected]
  local status=Manager.status(app)
  local detailY=listTop+#catalog.apps*(compact and 2 or 3)+1
  if detailY<h-7 then
   put(2,detailY,app.description,colors.lightBlue,nil,w-3)
   if detailY+1<h-7 then
    local note=status.versionUnknown and "Installed version unknown; reinstall to start tracking" or
     (status.updateAvailable and "A newer version is available" or versionNotice)
    put(2,detailY+1,note,colors.yellow,nil,w-3)
   end
  end
  local row=h-6
  local storeInfo=Manager.storeStatus()
  local storeLabel=storeInfo.updateAvailable and "UPDATE STORE!" or "STORE UPDATE"
  if w>=58 then
   button(2,row,17,status.installed and (status.updateAvailable and "UPDATE AVAILABLE" or "REINSTALL") or "INSTALL","install")
   button(20,row,13,"PLAY","play",nil,status.installed)
   button(34,row,16,"REMOVE","remove",nil,status.installed)
   button(51,row,math.min(14,w-51),storeLabel,"store-update")
   button(math.max(2,w-11),row+2,10,"EXIT","exit")
  else
   local cw=math.floor((w-4)/3)
   button(2,row,cw,status.installed and (status.updateAvailable and "UPDATE" or "REINSTALL") or "INSTALL","install")
   button(3+cw,row,cw,"PLAY","play",nil,status.installed)
   button(4+cw*2,row,cw,"REMOVE","remove",nil,status.installed)
   button(2,row+2,math.min(22,w-3),storeLabel,"store-update")
   button(math.max(2,w-12),row+2,10,"EXIT","exit")
  end
 end
 put(1,h-1,(" "..banner..(" "):rep(w)):sub(1,w),
  colors.white,colors.gray,w)
 put(1,h,(" UP/DOWN SELECT   ENTER INSTALL/UPDATE   Q QUIT   R REFRESH"..
   (" "):rep(w)):sub(1,w),colors.lightGray,colors.black,w)
end
local function perform(action,arg)
 if busy then return end
 if action=="select"then selected=arg;banner="SELECT AN ACTION";return end
 if action=="exit"then return "exit"end
 if action=="cancel"then confirmation=nil;banner="CANCELLED";return end
 if action=="remove"then
  local app=catalog.apps[selected]
  confirmation={kind="remove",app=app,name=app.name,
   description="Remove app code from this computer?"}
  return
 end
 if action=="confirm"then
  local op=confirmation
  confirmation=nil
  if not op then return end
  action=op.kind
  arg=op.app
 end
 local app=arg or catalog.apps[selected]
 if action=="play" then
  if not Manager.installed(app) then banner="INSTALL THIS APP FIRST";return end
  screen.setBackgroundColor(colors.black);screen.clear()
  local ok,result=pcall(Manager.launch,app)
  if not ok then banner="GAME ERROR: "..tostring(result)
  else banner="RETURNED FROM "..app.name end
  screen=term.current()
  return
 end
 if action=="install" or action=="remove" or action=="store-update" then
  busy=true
  screen.setBackgroundColor(colors.black);screen.clear()
  screen.setCursorPos(1,1)
  print("FPB STORE / "..action:upper())
  local ok,result=pcall(function()
   if action=="install"then return Manager.install(app)
   elseif action=="remove"then return Manager.remove(app,false)
   else return Manager.updateStore()end
  end)
  busy=false
  if ok and action=="store-update" then
   -- Reload new catalog and logic on next launch.
   banner="STORE UPDATED - RELOADING"
   restartAfterUpdate=true
  elseif ok then banner=action=="remove" and "APP REMOVED - SAVES PRESERVED"
    or (action=="store-update" and "STORE UPDATED" or "INSTALL/UPDATE COMPLETE")
  else
   banner="ERROR: "..tostring(result)
   -- Preserve the full diagnostic rather than clipping it to the footer.
   screen.setBackgroundColor(colors.black);screen.clear()
   screen.setCursorPos(1,1);screen.setTextColor(colors.red)
   print("FPB STORE / "..action:upper().." FAILED")
   screen.setTextColor(colors.white)
   print(tostring(result))
   print("")
   print("Press any key or tap to return to the Store.")
   while true do
    local event=os.pullEvent()
    if event=="key" or event=="mouse_click" or event=="monitor_touch" then break end
   end
  end
  screen=term.current()
 end
end
local function run()
 local ok=Manager.refreshVersions()
 versionNotice=ok and "Latest catalog checked" or "Offline: showing cached catalog"
 while true do
  if restartAfterUpdate then return end
  draw()
  local ev,a,b,c=os.pullEvent()
  if ev=="term_resize"then
   -- Layout is recomputed from real available columns and rows.
  elseif ev=="mouse_click"then
   for _,hit in ipairs(buttons)do
    if b>=hit.x and b<hit.x+hit.w and c==hit.y then
     if perform(hit.action,hit.arg)=="exit"then return end
     break
    end
   end
  elseif ev=="key"then
   if a==keys.q or a==keys.escape then
    if confirmation then confirmation=nil else break end
   elseif a==keys.up then
    selected=math.max(1,selected-1)
   elseif a==keys.down then
    selected=math.min(#catalog.apps,selected+1)
   elseif a==keys.enter then
    if confirmation then perform("confirm")else perform("install")end
   elseif a==keys.backspace and confirmation then
    confirmation=nil
   elseif a==keys.r then
    local ok=Manager.refreshVersions()
    versionNotice=ok and "Latest catalog checked" or "Version check unavailable"
    banner=versionNotice
   elseif a==keys.space and not confirmation then
    perform("play")
   end
  elseif ev=="char"then
   local ch=tostring(a):lower()
   if ch=="q"then if confirmation then confirmation=nil else break end end
  end
 end
end
local ok,err=xpcall(run,function(e)
 return tostring(e)..(debug and debug.traceback and "\n"..debug.traceback()or "")
end)
screen.setBackgroundColor(colors.black);screen.setTextColor(colors.white)
screen.clear();screen.setCursorPos(1,1)
if not ok then error(err,0)end
if restartAfterUpdate then
 -- This call runs the updated code from disk. Clear stale required modules
 -- before loading so the new catalog and manager take effect immediately.
 package.loaded["fpbstore.catalog"]=nil
 package.loaded["fpbstore.manager"]=nil
 assert(shell.run("/fpbstore/main.lua"),"Updated Store failed to launch")
end
