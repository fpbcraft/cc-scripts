-- Optional command-line fallback; the running remote GUI has EXPORT KEY.
-- Stop the node first only if using this standalone command.
local Pairing=require("pairing")
local f=assert(fs.open("/fpb-node/config.db","r"),"Node config unavailable")
local ok,cfg=pcall(textutils.unserialize,f.readAll())
f.close()
assert(ok and type(cfg)=="table","Invalid node config")
local success,message,drive=Pairing.export(cfg,os.getComputerID())
print(message)
if not success then error(message,0) end
print("Disk drive: "..drive.name)
print("Move the floppy to the main Factory Manager and select PAIR FROM DISK")
