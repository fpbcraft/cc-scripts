package.path="./factory/?.lua;"..package.path
-- Reuse the Lua 5.3 bit32 compatibility shim and SHA256 reference vectors.
dofile("tests/auth_test.lua")
local Remote=require("remote")
local Auth=require("auth")
local time=100000
os.epoch=function()return time end
os.getComputerID=function()return 10 end
local sends={}
rednet={send=function(id,msg,protocol)
  sends[#sends+1]={id=id,msg=msg,protocol=protocol}
  return true
end}
local r=Remote.new()
local nodeId=17
r:ingest(nodeId,{kind="snapshot",version=1,name="Andesite Node",peripherals={
  {name="computer",type="remote_computer",methods={},values={}},
  {name="redstone_relay_0",type="redstone_relay",methods={},values={}}
}})
assert(not r:control("remote:17:computer","front",true,true))
local secret=string.rep("0123456789abcdef",3)
assert(r:pair(nodeId,secret))
assert(not r:paired(nodeId),"An unacknowledged pair must not enable controls")
local function ack(pending,status,boot,key)
  local msg={kind="ack",version=1,seq=pending.message.seq,
    status=status or "ok",on=pending.message.on,
    polarity=pending.message.polarity,bootId=boot or "boot-1"}
  msg.mac=Auth.mac(key or secret,Auth.frame("ack:"..pending.action,10,17,
    msg.seq,pending.target,pending.side,msg.on,msg.polarity,
    msg.status.."#"..msg.bootId))
  return msg
end
local packet=sends[#sends].msg
assert(packet.action=="heartbeat")
local pending=r.pending[nodeId][packet.seq]
assert(not r:handleAck(nodeId,ack(pending,"ok","boot-1","wrong-key")))
assert(r:handleAck(nodeId,ack(pending,"ok","boot-1")))
assert(r:paired(nodeId))
assert(not r:handleAck(nodeId,ack(pending,"ok","boot-1")),
  "Old acknowledgement must not be accepted twice")
local ok,message=r:control("remote:17:redstone_relay_0","left",true,false)
assert(ok and message:find("Awaiting"))
assert(r:hasPending("remote:17:redstone_relay_0","left"))
local command=sends[#sends].msg
assert(command.mac==Auth.mac(secret,Auth.frame(
  "set",10,17,command.seq,"redstone_relay_0","left",true,false,"")))
local pending2=r.pending[nodeId][command.seq]
assert(not r:handleAck(nodeId,ack(pending2,"ok","boot-1","wrong-key")))
assert(r:handleAck(nodeId,ack(pending2,"ok","boot-1")))
assert(r:state("remote:17:redstone_relay_0","left")==true)
-- A signed reboot acknowledgement must invalidate older ON state.
r:send(nodeId,"heartbeat")
local p3=r.pending[nodeId][sends[#sends].msg.seq]
assert(r:handleAck(nodeId,ack(p3,"ok","boot-2")))
assert(r:state("remote:17:redstone_relay_0","left")==nil)
time=time+13000
r:tick()
assert(not r:paired(nodeId),"Stale authenticated link is not paired")
assert(not r:control("remote:17:computer","top",true,true))
print("Signed remote control, replay and stale-state tests passed")
