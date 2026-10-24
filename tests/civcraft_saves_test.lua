local files,dirs={},{}
fs={}
function fs.exists(p)return files[p]~=nil or dirs[p]end
function fs.makeDir(p)dirs[p]=true end
function fs.open(p,mode)
 if mode=="r"then
  if not files[p]then return nil end
  return {readAll=function()return files[p]end,close=function()end}
 end
 local body=""
 return {write=function(v)body=body..v end,close=function()files[p]=body end}
end
function fs.move(a,b)assert(files[a]);files[b]=files[a];files[a]=nil end
function fs.delete(p)files[p]=nil end
local values,serial={},0
textutils={
 serialize=function(value)
  serial=serial+1;local name="sav"..serial
  values[name]=value;return name
 end,
 unserialize=function(str)return values[str]end
}
local Save=assert(loadfile("civcraft/saves.lua"))()
assert(#Save.list()==3 and not Save.list()[1].occupied)
local a={name="RED",round=4,phase="game",world={seed=101,size="compact"}}
local b={name="BLUE",round=12,phase="game",world={seed=202,size="large"}}
Save.save(1,a);Save.save(2,b)
assert(Save.load(1).name=="RED" and Save.load(2).name=="BLUE")
Save.save(1,{name="GREEN",round=5,phase="game",world={seed=303,size="standard"}})
assert(Save.load(1).name=="GREEN" and Save.load(2).name=="BLUE")
assert(files[Save.path(1)..".bak"],"Previous slot revision should be backed up")
Save.delete(2)
assert(Save.load(2)==nil and Save.load(1).name=="GREEN")
files["/civcraft/data/local-save.dat"]="sav1"
Save.delete(1)
assert(Save.load(1)==a,"Legacy single save remains loadable in empty slot 1")
assert(not pcall(Save.path,4),"Out of bounds save slot")
print("CIVCRAFT: three independent saves, backup, deletion and legacy import passed.")
