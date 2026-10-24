-- Executes real CIVCRAFT rules in one-computer hotseat mode.
local files,dirs,versions={}, {["/"]=true},{}
fs={}
function fs.exists(p)return files[p]~=nil or dirs[p]==true end
function fs.makeDir(p)dirs[p]=true end
function fs.getDir(p)return p:match("^(.*)/[^/]+$")or"/"end
function fs.delete(p)files[p]=nil;dirs[p]=nil end
function fs.move(a,b)assert(files[a]);files[b]=files[a];files[a]=nil end
function fs.open(p,mode)
 if mode=="r"then
  if files[p]==nil then return nil end
  return {readAll=function()return files[p]end,close=function()end}
 end
 local result=""
 return {write=function(s)result=result..s end,close=function()files[p]=result end}
end
local last
textutils={
 serialize=function(data)
  local id="saved-"..(#versions+1)
  local function copy(obj)
   if type(obj)~="table"then return obj end
   local out={}
   for k,v in pairs(obj)do out[k]=copy(v)end
   return out
  end
  versions[#versions+1]=copy(data);last=versions[#versions]
  return id
 end,
 unserialize=function(id)
  local i=tonumber(id:match("^saved%-(%d+)$"))
  return i and versions[i]or nil
 end,
}
peripheral={getNames=function()return {}end}
rednet={}
term={current=function()return {}end}
os.getComputerID=function()return 9 end
keys={q=16,escape=1}
local frames,stage=0,0
local originalDofile=dofile
dofile=function(path)
 if path:sub(1,16)=="/games/civcraft/" and path~="/games/civcraft/ui.lua"then
  return originalDofile(path:sub(2))
 end
 if path~="/games/civcraft/ui.lua"then return originalDofile(path)end
 return {new=function(_,callback)
  return {
   message=function()end,
   draw=function(self,s,id,opt)
    frames=frames+1
    stage=stage+1
    if stage==1 then
     callback("continue")
     assert(s.phase=="lobby" and #s.players==2 and opt.localMode)
     callback("addPlayer")
    elseif stage==2 then
     assert(#s.players==3)
     callback("removePlayer")
    elseif stage==3 then
     assert(#s.players==2)
     callback("start")
    elseif stage==4 then
     assert(s.phase=="game" and s.round==1)
     assert(id==s.players[1].id)
     callback("end")
    elseif stage==5 then
     assert(opt.handoff and id==s.players[2].id)
     callback("reveal")
    elseif stage==6 then
     assert(not opt.handoff)
     callback("end")
    elseif stage==7 then
     assert(s.round==2 and opt.handoff and id==s.players[1].id,
      "Turn rotation and handoff across rounds")
     callback("reveal")
    elseif stage==8 then
     assert(s.round==2 and not opt.handoff)
     callback("exit")
    end
   end,
   resize=function()end,tap=function()end,close=function()end
  }
 end}
end
local originalPull=os.pullEvent
local count=0
os.pullEvent=function()
 count=count+1
 if count>=8 then return "timer",0 end
 return "term_resize"
end
local ok,err=pcall(function()assert(loadfile("games/civcraft/game.lua"))("local","--new")end)
os.pullEvent=originalPull
dofile=originalDofile
assert(ok,err)
assert(frames==8,"Should render through complete hotseat sequence")
assert(last.round==2 and #last.players==2,"Round persists with correct player count")
assert(last.activeIndex==1,"Current player persisted")
assert(files["/games/civcraft/data/slot-1.dat"],"Separate local save exists")
assert(not files["/games/civcraft/data/save.dat"],"Network save untouched")
print("CIVCRAFT: hotseat lobby, turn ownership, privacy handoff, 2nd round and save passed.")
