package.path="./apps/factory/?.lua;"..package.path
local metrics=require("graph_metrics")
local C={pink=1,magenta=2}
local defaults={
 {"stress","Stress","%",3},{"rpm","RPM","rpm",4},
 {"voltage","Voltage","V",5},{"current","Current","A",6},
 {"power","Power","W",7},{"battery","Battery","%",8},
 {"energy","Energy","J",9},
}
local function ids(result)
  local out={}
  for _,m in ipairs(result) do out[m[1]]=true end
  return out
end
local none=ids(metrics.available(defaults,{power={}}, {},{},C))
assert(none.stress and none.rpm)
assert(not none.voltage and not none.current and not none.power and
  not none.battery and not none.energy,
  "No-data Power Grid graphs must be hidden")
local some=ids(metrics.available(defaults,{power={
  {key="voltage",value=24},
  {key="power",value=0},
  {key="current",value=nil},
  {key="battery",value=0/0}
}},{ {id="iron",name="Iron Farm",product="minecraft:iron_nugget"} },
  { {id="sensor_reading_1",label="Gauge",unit="A"} },C))
assert(some.voltage and some.power and not some.current and not some.battery)
assert(some.rate_iron and some.sensor_reading_1)
print("Power Grid graph visibility tests passed")
