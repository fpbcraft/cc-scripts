-- Physically unpair a remote node after moving it to a new Factory Manager.
-- Stop the running node program (Ctrl+T), then run /fpb-node/unpair.lua.
local file="/fpb-node/config.db"
if not fs.exists(file) then error("Node config not found",0) end
local f=assert(fs.open(file,"r"))
local ok,cfg=pcall(textutils.unserialize,f.readAll())
f.close()
assert(ok and type(cfg)=="table","Invalid node config")
for _,m in pairs(cfg.managed or {}) do
  local signal=not (m.polarity==true)
  if m.target=="computer" then
    pcall(redstone.setOutput,m.side,signal)
  elseif peripheral.isPresent(m.target) and
         peripheral.getType(m.target)=="redstone_relay" then
    pcall(peripheral.call,m.target,"setOutput",m.side,signal)
  end
end
cfg.hubId=nil
cfg.key=nil -- main.lua generates a fresh pairing key at next boot
cfg.lastSeq=0
cfg.lastFrame=nil
cfg.lastAck=nil
cfg.managed={}
local tmp=file..".new"
local w=assert(fs.open(tmp,"w"))
w.write(textutils.serialize(cfg));w.close()
fs.delete(file);fs.move(tmp,file)
print("Unpaired; registered outputs set to OFF.")
print("Reboot and enter the new pairing key at the Factory Manager.")
