local C=require('train.catalog')
local S=require('train.state')
local U=require('core.util')
local R={}
local function ok(g,message)
 S.log(g,message);g.score=R.score(g)
 local p=g.playerStats[g.currentPlayer];if p then p.actions=p.actions+1 end
 return true,message
end
local function deny(message)return false,message end
local function busy(g)
 if g.finished then return true,'EXPEDITION COMPLETE' end
 if g.pending then return true,'RESOLVE THE TRAVEL EVENT FIRST' end
 return false
end
local function has(g,cost)
 for key,n in pairs(cost or {})do if (g.cargo[key] or 0)<n then return false,'NEED '..n..' '..key:upper() end end
 return true
end
local function spend(g,cost)for key,n in pairs(cost or {})do g.cargo[key]=g.cargo[key]-n end end
function R.score(g)return g.delivered*150+g.reputation*85+g.trips*65+math.floor(g.coins/2)+g.hull-g.turn*2-(g.penalty or 0)*25 end
function R.cost(g,item)
 local station=C.stations[g.location];local p=(station.prices or {})[item.id] or item.base
 if g.difficulty=='frontier' then p=p+2 end
 if g.difficulty=='explorer' then p=math.max(1,p-1)end
 return p,math.max(1,math.floor(p*.6))
end
function R.buy(g,item)
 if busy(g) then return deny('RESOLVE CURRENT EXPEDITION') end
 local spec=C.goodsById[item];if not spec then return deny('UNKNOWN GOOD')end
 local price=R.cost(g,spec)
 if S.load(g)>=S.capacity(g) then return deny('CARGO FULL - SELL OR ADD A WAGON')end
 if g.coins<price then return deny('NEED '..price..' COINS')end
 g.coins=g.coins-price;g.cargo[item]=g.cargo[item]+1
 return ok(g,'BOUGHT '..spec.name)
end
function R.sell(g,item)
 if busy(g) then return deny('RESOLVE CURRENT EXPEDITION') end
 local spec=C.goodsById[item];if not spec then return deny('UNKNOWN GOOD')end
 if g.cargo[item]<1 then return deny('NOT IN CARGO')end
 local _,price=R.cost(g,spec)
 g.coins=g.coins+price;g.cargo[item]=g.cargo[item]-1
 return ok(g,'SOLD '..spec.name)
end
function R.repair(g)
 if busy(g) then return deny('RESOLVE CURRENT EXPEDITION')end
 if g.hull==g.maxHull then return deny('TRAIN IS ALREADY FULLY REPAIRED') end
 if g.coins<12 then return deny('REPAIR COST: 12 COINS')end
 g.coins=g.coins-12;g.hull=math.min(g.maxHull,g.hull+25)
 return ok(g,'WORKSHOP REPAIRED THE TRAIN')
end
function R.refuel(g)
 if busy(g) then return deny('RESOLVE CURRENT EXPEDITION')end
 if g.fuel>=g.maxFuel then return deny('FUEL TANK IS FULL') end
 if g.coins<9 then return deny('REFUEL COST: 9 COINS')end
 g.coins=g.coins-9;g.fuel=math.min(g.maxFuel,g.fuel+4)
 return ok(g,'TRAIN REFUELED')
end
function R.shift(g)
 if busy(g) then return deny('RESOLVE CURRENT EXPEDITION')end
 local built=g.stations[g.location];local results={};local count=0
 for _,m in ipairs(C.modules)do
  local level=built.modules[m.id] or 0
  if level>0 and (g.cargo[m.from] or 0)>=m.input and (m.to=='fuel' or (S.load(g)-m.input+m.output)<=S.capacity(g)) then
   if m.to=='fuel' then
    if g.fuel<g.maxFuel then
     g.cargo[m.from]=g.cargo[m.from]-m.input
     g.fuel=math.min(g.maxFuel,g.fuel+m.output*level)
     count=count+1;results[#results+1]=m.name..' +FUEL'
    end
   else
    local cycles=math.min(level,math.floor(g.cargo[m.from]/m.input),math.floor((S.capacity(g)-S.load(g))/(m.output-m.input)))
    if cycles>0 then
     g.cargo[m.from]=g.cargo[m.from]-m.input*cycles
     g.cargo[m.to]=g.cargo[m.to]+m.output*cycles
     count=count+cycles;results[#results+1]=m.name..' +'..m.output*cycles..' '..m.to
    end
   end
  end
 end
 g.turn=g.turn+1;g.shift=g.shift+1
 if count==0 then return ok(g,'SHIFT '..g.shift..': NO AVAILABLE INPUT / CARGO FULL')end
 return ok(g,'SHIFT '..g.shift..': '..table.concat(results,' / '))
end
function R.module(g,id)
 if busy(g) then return deny('RESOLVE CURRENT EXPEDITION')end
 local m=C.moduleById[id];if not m then return deny('UNKNOWN MODULE')end
 local loc=g.stations[g.location];local n=loc.modules[id] or 0
 if n>=3 then return deny('MODULE ALREADY AT MAX LEVEL')end
 local count=0;for _,level in pairs(loc.modules)do if level>0 then count=count+1 end end
 if n==0 and count>=4 then return deny('STATION HAS 4 MODULE SLOTS')end
 local price=m.cost+n*25
 if g.coins<price then return deny('NEED '..price..' COINS')end
 g.coins=g.coins-price;loc.modules[id]=n+1
 return ok(g,m.name..' NOW LEVEL '..(n+1))
end
function R.accept(g,id)
 if busy(g) then return deny('RESOLVE CURRENT EXPEDITION')end
 local c=C.contractById[id];if not c then return deny('UNKNOWN CONTRACT')end
 if g.contracts[id]~='available' then return deny('ALREADY ACCEPTED OR COMPLETE')end
 if g.location~=c.origin then return deny('TAKE THIS JOB AT '..C.stations[c.origin].short)end
 local active=0;for _,s in pairs(g.contracts)do if s=='active' then active=active+1 end end
 if active>=3 then return deny('MAXIMUM 3 ACTIVE CONTRACTS')end
 g.contracts[id]='active';return ok(g,c.name..' ACCEPTED')
end
function R.deliver(g,id)
 if busy(g) then return deny('RESOLVE CURRENT EXPEDITION')end
 local c=C.contractById[id];if not c or g.contracts[id]~='active' then return deny('CONTRACT NOT ACTIVE')end
 if g.location~=c.destination then return deny('DELIVER AT '..C.stations[c.destination].short)end
 if g.cargo[c.item]<c.count then return deny('NEED '..c.count..' '..c.item:upper())end
 g.cargo[c.item]=g.cargo[c.item]-c.count
 local extra=g.difficulty=='explorer' and 10 or 0
 g.coins=g.coins+c.reward+extra;g.reputation=g.reputation+c.rep;g.delivered=g.delivered+1
 g.contracts[id]='done'
 local p=g.playerStats[g.currentPlayer];if p then p.deliveries=p.deliveries+1 end
 R.victory(g)
 return ok(g,'DELIVERED '..c.name..'  +'..c.reward..' COINS')
end
function R.addWagon(g,id)
 if busy(g) then return deny('RESOLVE CURRENT EXPEDITION')end
 local spec=C.wagonById[id];if not spec then return deny('INVALID WAGON')end
 if #g.wagons>=6 then return deny('TRAIN LIMIT: 6 WAGONS')end
 if g.coins<spec.cost then return deny('NEED '..spec.cost..' COINS')end
 g.coins=g.coins-spec.cost;g.wagons[#g.wagons+1]={id=id,level=1}
 if id=='fuel' then g.maxFuel=g.maxFuel+8 end
 return ok(g,spec.name..' COUPLED TO TRAIN')
end
function R.wagonUpgrade(g,index)
 if busy(g) then return deny('RESOLVE CURRENT EXPEDITION')end
 local w=g.wagons[index];if not w then return deny('SELECT A WAGON') end
 if w.level>=3 then return deny('WAGON FULLY UPGRADED')end
 local price=(index==1 and 65 or 35)+w.level*20
 if g.coins<price then return deny('NEED '..price..' COINS')end
 g.coins=g.coins-price;w.level=w.level+1
 if w.id=='fuel' then g.maxFuel=g.maxFuel+4 end
 if w.id=='engine' then g.maxFuel=g.maxFuel+4;g.fuel=math.min(g.maxFuel,g.fuel+4)end
 return ok(g,'WAGON '..index..' UPGRADED TO LEVEL '..w.level)
end
function R.upgrade(g,id)
 if busy(g) then return deny('RESOLVE CURRENT EXPEDITION')end
 local u=C.upgradeById[id];if not u then return deny('UNKNOWN UPGRADE')end
 if g.upgrades[id] then return deny('ALREADY INSTALLED')end
 if g.coins<u.cost then return deny('NEED '..u.cost..' COINS')end
 g.coins=g.coins-u.cost;g.upgrades[id]=true
 if id=='armor' then g.maxHull=g.maxHull+30;g.hull=math.min(g.maxHull,g.hull+30) end
 return ok(g,u.name..' INSTALLED')
end
function R.salvage(g)
 if busy(g) then return deny('RESOLVE CURRENT EXPEDITION')end
 -- Never strand a solo player without the money to refuel or purchase essential stock.
 g.turn=g.turn+1;g.coins=g.coins+12;g.penalty=(g.penalty or 0)+1
 return ok(g,'LOCAL REPAIR JOB: EARNED 12 COINS')
end
function R.fuelCost(g,edge)
 local value=edge[3];if g.upgrades.burner then value=math.max(1,value-1)end
 return value
end
function R.depart(g,to)
 if busy(g) then return deny('RESOLVE CURRENT EXPEDITION')end
 local e=S.edge(g.location,to);if not e then return deny('ONLY CONNECTED STATIONS CAN BE VISITED')end
 local fuel=R.fuelCost(g,e)
 local key=S.edgeKey(g.location,to)
 local material=g.built[key] and 0 or e[4]
 if g.fuel<fuel then return deny('NEED '..fuel..' FUEL. VISIT THE STATION.') end
 if g.cargo.parts<material then return deny('NEED '..material..' PARTS TO LAY RAILS')end
 g.fuel=g.fuel-fuel;g.cargo.parts=g.cargo.parts-material;g.built[key]=true
 g.turn=g.turn+1;g.trips=g.trips+1
 local from=g.location
 local eventIndex=((g.seed+g.trips*7+to*3)%#C.events)+1
 local event=C.events[eventIndex]
 -- The first trip and every other trip has an event; all have safe fallback choices.
 if g.trips%2==1 then
  g.pending={to=to,from=from,event=event.id};
  return ok(g,'TRAVEL TO '..C.stations[to].short..' - '..event.name)
 end
 g.location=to;g.discovered[to]=true
 R.victory(g)
 return ok(g,'ARRIVED AT '..C.stations[to].short)
end
function R.resolve(g,index)
 if g.finished then return deny('EXPEDITION COMPLETE')end
 local pending=g.pending;if not pending then return deny('NO TRAVEL EVENT')end
 local event=C.eventById[pending.event];if not event then return deny('INVALID EVENT')end
 local choice=event.choices[index];if not choice then return deny('SELECT ONE OF THE EVENT OPTIONS')end
 local cost=U.copy(choice.cost or {})
 if pending.event=='rocks' and index==1 then
  for _,wagon in ipairs(g.wagons)do if wagon.id=='crane' then cost.parts=0;break end end
 end
 if pending.event=='signal' and index==1 and g.upgrades.relay then cost.parts=0 end
 local enough,why=has(g,cost);if not enough then return deny(why)end
 if g.coins<(choice.coins or 0)then return deny('NEED '..choice.coins..' COINS')end
 spend(g,cost);g.coins=g.coins-(choice.coins or 0)
 local damage=choice.damage or 0
 if pending.event=='rocks' then
  for _,w in ipairs(g.wagons)do if w.id=='crane' and index==1 then damage=0;break end end
 end
 if pending.event=='signal' and g.upgrades.relay then damage=0 end
 if g.difficulty=='explorer' then damage=math.floor(damage*.65)end
 if g.difficulty=='frontier' then damage=math.floor(damage*1.3)end
 g.hull=math.max(1,g.hull-damage);g.turn=g.turn+(choice.turns or 0)
 g.location=pending.to;g.discovered[pending.to]=true;g.pending=nil
 R.victory(g)
 return ok(g,'ARRIVED AT '..C.stations[g.location].short..' - '..choice.label)
end
function R.victory(g)
 if g.location==5 and g.reputation>=2 and g.delivered>=2 then
  g.finished=true;g.won=true;S.log(g,'EASTPORT CONNECTED - RAILWAY COMPANY ESTABLISHED')
 end
end
return R
