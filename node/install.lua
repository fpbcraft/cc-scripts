-- FPBCRAFT Remote Node: one-command, no-backup installer/updater.
-- wget run .../node/install.lua [git_ref] [node_name]
local args={...}
local ref=args[1] or "main"
local label=args[2]
assert(ref:match("^[%w._/-]+$") and not ref:find("..",1,true),"Invalid ref")
local root="/fpb-node"
local url="https://raw.githubusercontent.com/fpbcraft/cc-scripts/"..ref.."/"
local files={
  ["main.lua"]=url.."node/main.lua",
  ["auth.lua"]=url.."factory/auth.lua",
  ["unpair.lua"]=url.."node/unpair.lua"
}
local function remove(path) if fs.exists(path) then fs.delete(path) end end
local function read(path)
  if not fs.exists(path) then return nil end
  local f=fs.open(path,"r");if not f then return nil end
  local data=f.readAll();f.close();return data
end
local function write(path,bytes)
  local f,err=fs.open(path,"w")
  assert(f,"Cannot write "..path..": "..tostring(err))
  f.write(bytes);f.close()
end
local function get(address)
  local h,err=http.get(address,nil,true)
  assert(h,"HTTP failure: "..tostring(err))
  local status=h.getResponseCode and h.getResponseCode() or 200
  local bytes=h.readAll();h.close()
  assert(status==200 and bytes and #bytes>20,"Download failed: "..status)
  assert(load(bytes,"@node module","t"),"Downloaded Lua failed parsing")
  return bytes
end
local launcher="shell.run('/fpb-node/main.lua')\n"
local boot=read("/startup.lua")
local shadow=read("/startup")
if boot and boot~=launcher and
   not boot:find("/fpb-node/",1,true) and
   not boot:find("node/main.lua",1,true) then
  error("Unrelated startup.lua exists; move it manually. No backup is made.",0)
end
if shadow and not shadow:find("fpb-node",1,true) then
  error("Unrelated /startup exists; move it manually.",0)
end
print("FPBCRAFT Remote Node updater (no backups)")
if not fs.exists(root) then fs.makeDir(root) end
if fs.exists("/fpb-node.backup") and not fs.exists(root.."/config.db")
    and fs.exists("/fpb-node.backup/config.db") then
  fs.move("/fpb-node.backup/config.db",root.."/config.db")
end
remove("/fpb-node.backup")
remove("/fpb-node.next")
remove("/startup.lua.fpb-node-backup")
remove("/startup.fpb-node-backup")
print("Old installer backups cleared")
-- Download both code files before replacing either.
local loaded={}
for name,address in pairs(files) do loaded[name]=get(address) end
for name,code in pairs(loaded) do
  local target=root.."/"..name
  local tmp=target..".new"
  remove(tmp);write(tmp,code)
  remove(target);fs.move(tmp,target)
end
local old=read(root.."/config.db")
local config={}
if old then
  local ok,val=pcall(textutils.unserialize,old)
  if ok and type(val)=="table" then config=val end
end
if label and label~="" then config.name=label:sub(1,40) end
if not config.name then config.name="Factory Node "..os.getComputerID() end
local tmp=root.."/config.db.new"
remove(tmp);write(tmp,textutils.serialize(config))
remove(root.."/config.db");fs.move(tmp,root.."/config.db")
if shadow then remove("/startup") end
if boot~=launcher then
  local t="/startup.fpb-node-next.lua"
  remove(t);write(t,launcher)
  remove("/startup.lua");fs.move(t,"/startup.lua")
end
print("Installed without backup, retained pairing configuration")
print("Node: "..config.name.." | Auto-start enabled")
print("Reboot, then copy the pairing key displayed on this node")
