-- FPBCRAFT: export this node's pairing credentials to a ComputerCraft disk.
-- Stop the node (Ctrl+T), insert a floppy disk into an attached disk drive,
-- run /fpb-node/export_pairing.lua, then reboot the node.
local path="/fpb-node/config.db"
local file=assert(fs.open(path,"r"),"No remote node config installed")
local ok,cfg=pcall(textutils.unserialize,file.readAll())
file.close()
assert(ok and type(cfg)=="table" and type(cfg.key)=="string"
  and #cfg.key>=32,"Pairing key unavailable; boot the node once first")
local mount=nil
for _,name in ipairs(peripheral.getNames()) do
  local isDrive=(peripheral.hasType and peripheral.hasType(name,"drive"))
    or peripheral.getType(name)=="drive"
  if isDrive then
    local m=disk.getMountPath(name)
    if m and fs.exists(m) and not fs.isReadOnly(m) then
      mount=m
      break
    end
  end
end
assert(mount,"Insert a writable floppy disk into an attached Disk Drive")
local output=fs.combine(mount,"fpb_pairing.db")
assert(not fs.exists(output),"Pairing file already exists on disk; delete it first")
local f=assert(fs.open(output,"w"))
f.write(textutils.serialize({
  format=1,
  node=os.getComputerID(),
  name=cfg.name,
  key=cfg.key
}))
f.close()
print("Pairing file exported to "..output)
print("Move floppy to Factory Manager computer's disk drive.")
print("Factory Manager > Devices > remote computer > PAIR FROM DISK.")
print("Remove the floppy when pairing is confirmed.")
print("Restart node with reboot.")
