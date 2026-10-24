-- Contextual encyclopedia and action previews for the train-first campaign.
-- All values are derived from the live rule catalog/state rather than UI guesses.
local C=require('train.catalog')
local S=require('train.state')
local Rules=require('train.rules')
local Info={}

local goodsHelp={
 logs='Raw timber. A sawmill uses 1 log to produce 2 planks. Can be bought and sold at stations.',
 planks='Processed lumber. Used for delivery contracts and certain bridge encounters. Made from logs at sawmills.',
 ore='Iron ore. A press shop turns 1 ore into 2 sheets; a foundry turns 1 ore into 2 parts.',
 sheets='Metal sheets. Needed for some deliveries and to brace damaged bridges. Made in a press shop.',
 parts='Mechanical parts. Spent when laying new railway tracks, repairing signals and clearing rockslides.',
 coal='Stored cargo coal. A fuel depot turns 1 coal into up to 3 locomotive fuel. Coal takes cargo space.',
 food='Supplies for settlements. A ticket office converts 1 food into 2 passengers when there is room.',
 passengers='Travellers count as one cargo unit each. Deliver them through passenger contracts for coins and reputation.',
}
local upgradeHelp={
 brass='Shows a forecast on the railway map before eligible trips. Travel events are deterministic, so scouting helps route planning.',
 burner='Reduces fuel spent on journeys costing 2 or more fuel by 1. Every journey still uses at least 1 fuel.',
 loader='Adds 5 shared cargo slots immediately. Any goods or passengers can use this extra capacity.',
 relay='Makes the repair option on SIGNAL FAILURE events cost no mechanical parts. Waiting still takes a turn.',
 whistle='Adds 2 shared cargo slots. These can carry any goods, including passengers; it does not change contract rewards.',
 armor='Raises maximum hull by 30 and immediately repairs 30 hull, up to the new maximum. Reduces risk from damaging events.',
}
local wagonHelp={
 engine='The locomotive drives the train. Each level above 1 adds 4 maximum fuel and provides 4 fuel when upgraded.',
 cargo='Adds 8 shared cargo slots at level 1. Each higher level adds 4 more slots.',
 passenger='Adds 4 shared cargo slots at level 1 and 2 more per level. Passengers are cargo; the wagon does not unlock jobs.',
 fuel='Adds 8 maximum fuel and 2 cargo slots. Upgrading increases the maximum fuel by another 4 per level.',
 crane='Clears a rockslide using the USE PARTS option for zero parts. Provides 2 shared cargo slots, plus 2 per level.',
}
local resourceHelp={
 coins='Currency for buying cargo, refuelling, repairs, station modules and train upgrades. Earn it by deliveries, sales and local jobs.',
 fuel='Locomotive fuel, separate from coal in cargo. Each railway segment uses fuel; some upgrades reduce long-trip costs.',
 hull='Train condition. Events can damage it; station repair restores up to 25 hull for 12 coins. Hull never drops below 1.',
 reputation='Earned by completing delivery contracts. Reach Eastport with at least 2 completed jobs and 2 reputation to win.',
}
local topicHelp={
 title='Begin a new solo or shared-screen expedition, or continue your saved journey. The game is turn-based, so nothing advances while you read.',
 setup='Choose 1 to 4 players and a difficulty. Explorer offers cheaper goods and gentler damage. Frontier raises market prices and event damage.',
 hub='Tap your train to inspect and upgrade wagons. The top icons show coins, fuel, hull and reputation. MAP chooses your next destination.',
 map='Tap a station dot to select it. A connected station requires fuel and, on first use of a track, mechanical parts. Select DETAILS to preview the trip.',
 station='Buy goods, install simple production modules, accept jobs, refuel, repair or advance a single production shift. Every action can be inspected first.',
 modules='Station buildings turn cargo inputs into useful outputs when you run a shift. They cost coins, have a maximum level of 3 and use one of four slots.',
 market='Tap an item for its purpose, current stock and exact buy or sell price. Buying 1 item uses 1 cargo slot; selling frees a slot.',
 contracts='Accept up to 3 active jobs at their origin station. Deliver the required cargo at the destination to earn coins and reputation.',
 train='Select a wagon to see its exact cargo or fuel benefits. Upgrade an existing wagon or add a new one. Maximum train length is 6 wagons.',
 wagons='Each new wagon costs coins and changes train capacity or events. Tap a wagon card to see its effects and purchase requirements.',
 upgrades='Permanent train upgrades apply to the entire expedition. Tap any technology to review its exact effect and price before installing it.',
 travel='A railway event interrupts travel until you choose a solution. Inspect either option for its exact cost and consequence. There is no timer.',
 results='Your final score rewards deliveries, reputation, travel and money, and subtracts time and recovery-work penalties.',
 help='Learn the train-first loop, then use the question-mark button on other screens to get context-specific instructions.',
}

local function add(t,s) t[#t+1]=tostring(s) end
function Info.describe(g,kind,id,extra)
 local lines={};local info={kind=kind,id=id,lines=lines,title='INFORMATION',icon='parts'}
 if kind=='topic' then
  info.title=({hub='TRAIN HUB',map='ROUTE MAP',station='AT STATION'})[id] or (id or 'HELP'):upper()
  add(lines,topicHelp[id] or 'Select an item or a question-mark button to learn how it works.')
 elseif kind=='resource' then
  info.title=id:upper();info.icon=({coins='coin',fuel='fuel',hull='wrench',reputation='star'})[id] or 'box'
  add(lines,resourceHelp[id]);if g then
   local value=({coins=g.coins,fuel=g.fuel..' / '..g.maxFuel,hull=g.hull..' / '..g.maxHull,reputation=g.reputation})[id]
   add(lines,'CURRENT: '..tostring(value))
  end
 elseif kind=='good' then
  local s=C.goodsById[id];assert(s,'Invalid good '..tostring(id))
  info.title=s.name;info.icon=s.icon;add(lines,goodsHelp[id]);add(lines,'IN CARGO: '..g.cargo[id]..' | TRAIN LOAD: '..S.load(g)..' / '..S.capacity(g))
  local buy,sell=Rules.cost(g,s);add(lines,'BUY: '..buy..' COINS EACH | SELL: '..sell..' COINS EACH')
  local side=extra=='sell' and 'sell' or 'buy'
  info.action=side;info.actionLabel=side=='sell' and 'SELL 1' or 'BUY 1';info.args={id}
  if side=='buy' and S.load(g)>=S.capacity(g)then add(lines,'WARNING: CARGO IS FULL.')end
  if side=='sell' and g.cargo[id]<1 then add(lines,'WARNING: NONE IN CARGO.')end
 elseif kind=='upgrade' then
  local s=C.upgradeById[id];assert(s,'Invalid upgrade')
  info.title=s.name;info.icon=s.icon;add(lines,upgradeHelp[id]);add(lines,'COST: '..s.cost..' COINS | HAVE: '..g.coins)
  add(lines,g.upgrades[id] and 'STATUS: ALREADY INSTALLED.' or 'STATUS: NOT INSTALLED.')
  if not g.upgrades[id]then info.action='upgrade';info.actionLabel='INSTALL';info.args={id}end
 elseif kind=='module' then
  local s=C.moduleById[id];assert(s,'Invalid module')
  local level=g.stations[g.location].modules[id] or 0;local price=s.cost+level*25
  info.title=s.name;info.icon=s.icon
  add(lines,'CREATE-STYLE STATION PROCESSING MODULE.')
  local output=s.to=='fuel' and 'LOCOMOTIVE FUEL' or C.goodsById[s.to].name
  add(lines,'EACH CYCLE: '..s.input..' '..C.goodsById[s.from].name..' INTO '..s.output..' '..output..'.')
  if s.to=='fuel' then
   add(lines,'ONE SHIFT USES 1 COAL FOR UP TO '..(s.output*math.max(1,level))..' FUEL, CAPPED BY TANK SIZE.')
  else
   add(lines,'ONE SHIFT RUNS UP TO '..math.max(1,level)..' CYCLES IF INPUT AND SPACE ARE AVAILABLE.')
  end
  add(lines,'LEVEL: '..level..' / 3 | SLOTS USED: MAX 4 DIFFERENT MODULES.')
  add(lines,'NEXT LEVEL: '..price..' COINS | HAVE: '..g.coins)
  if level<3 then info.action='module';info.actionLabel=level==0 and 'BUILD' or 'UPGRADE';info.args={id} end
 elseif kind=='wagonNew' then
  local s=C.wagonById[id];assert(s,'Invalid wagon')
  info.title=s.name;info.icon=s.icon;add(lines,wagonHelp[id])
  add(lines,'PRICE: '..s.cost..' COINS | HAVE: '..g.coins)
  add(lines,'WAGONS: '..#g.wagons..' / 6 (INCLUDING ENGINE)')
  info.action='addWagon';info.actionLabel='COUPLE WAGON';info.args={id}
 elseif kind=='wagon' then
  local index=id;local w=g.wagons[index];assert(w,'Invalid wagon')
  local s=C.wagonById[w.id];info.title=w.id=='engine' and 'LOCOMOTIVE' or s.name
  info.icon=w.id=='engine' and 'train' or s.icon
  add(lines,wagonHelp[w.id]);add(lines,'CURRENT LEVEL: '..w.level..' / 3')
  add(lines,'TRAIN LOAD: '..S.load(g)..' / '..S.capacity(g)..' | FUEL: '..g.fuel..' / '..g.maxFuel)
  if w.level<3 then
   local price=(index==1 and 65 or 35)+w.level*20
   add(lines,'UPGRADE PRICE: '..price..' COINS | HAVE: '..g.coins)
   info.action='wagonUpgrade';info.actionLabel='LEVEL UP';info.args={index}
  else add(lines,'MAXIMUM LEVEL REACHED.')end
 elseif kind=='contract' then
  local s=C.contractById[id];assert(s,'Invalid contract');local goods=C.goodsById[s.item]
  local status=g.contracts[id];info.title=s.name;info.icon=goods.icon
  add(lines,'TAKE '..s.count..' '..goods.name..' FROM '..C.stations[s.origin].short..' TO '..C.stations[s.destination].short..'.')
  add(lines,'REWARD: '..s.reward..' COINS AND '..s.rep..' REPUTATION.')
  add(lines,'CARGO ON TRAIN: '..g.cargo[s.item]..' / '..s.count..' REQUIRED.')
  add(lines,'STATUS: '..status:upper()..'. JOBS MUST BE ACCEPTED AT THEIR ORIGIN.')
  if status=='available' then info.action='accept';info.actionLabel='ACCEPT JOB';info.args={id}
  elseif status=='active' then info.action='deliver';info.actionLabel='DELIVER GOODS';info.args={id}end
 elseif kind=='route' then
  local st=C.stations[id];assert(st,'Invalid station')
  local edge=S.edge(g.location,id);info.title=st.short;info.icon='map'
  add(lines,'FROM '..C.stations[g.location].short..' TO '..st.short..'.')
  if edge then
   local fuel=Rules.fuelCost(g,edge);local track=g.built[S.edgeKey(g.location,id)] and 0 or edge[4]
   add(lines,'TRAVEL: '..fuel..' FUEL. TRACK CONSTRUCTION: '..track..' PARTS.')
   add(lines,'AVAILABLE: '..g.fuel..' FUEL AND '..g.cargo.parts..' PARTS.')
   add(lines,'TRAVEL ADVANCES 1 TURN. SOME TRIPS TRIGGER A CHOICE EVENT.')
   if g.upgrades.brass then
    local upcoming=C.events[((g.seed+(g.trips+1)*7+id*3)%#C.events)+1]
    add(lines,(g.trips+1)%2==1 and 'SCOUT REPORT: '..upcoming.name or 'SCOUT REPORT: CLEAR ROUTE.')
   end
   if id~=g.location then info.action='depart';info.actionLabel='DEPART';info.args={id}end
  else add(lines,id==g.location and 'YOU ARE AT THIS STATION.' or 'NO DIRECT TRACK FROM CURRENT STATION.')end
 elseif kind=='service' then
  local t={repair={'REPAIR TRAIN','wrench','PAYS 12 COINS TO RESTORE UP TO 25 HULL. MAXIMUM HULL DEPENDS ON REINFORCEMENT.'},
   refuel={'REFUEL','coal','PAYS 9 COINS TO RESTORE UP TO 4 LOCOMOTIVE FUEL. THIS DOES NOT USE STORED COAL.'},
   shift={'PRODUCTION SHIFT','clock','ADVANCES ONE GAME TURN. BUILT STATION MODULES CONVERT STORED CARGO AUTOMATICALLY IF INPUTS AND SPACE ARE AVAILABLE.'},
   salvage={'LOCAL REPAIR JOB','wrench','ADVANCES ONE TURN AND EARNS 12 COINS. ADDS A SCORE PENALTY. USE IT TO RECOVER FROM LOW FUNDS.'}}
  local s=t[id];assert(s,'Invalid service');info.title=s[1];info.icon=s[2];add(lines,s[3]);add(lines,'CURRENT COINS: '..g.coins..' | HULL: '..g.hull..' / '..g.maxHull..' | FUEL: '..g.fuel..' / '..g.maxFuel)
  info.action=id;info.actionLabel=({repair='REPAIR',refuel='REFUEL',shift='RUN SHIFT',salvage='TAKE JOB'})[id]
 elseif kind=='event' then
  local event=C.eventById[g.pending.event];assert(event,'No event');local choice=event.choices[id];assert(choice,'Invalid event choice')
  info.title=event.name;info.icon=choice.icon
  add(lines,event.desc);add(lines,'CHOICE: '..choice.label..'.')
  local costs={};for item,n in pairs(choice.cost or {})do
   local free=(event.id=='rocks' and id==1 and (function()for _,w in ipairs(g.wagons)do if w.id=='crane'then return true end end end)()) or (event.id=='signal' and id==1 and g.upgrades.relay)
   costs[#costs+1]=(free and 'FREE WITH EQUIPMENT' or n..' '..item:upper())
  end
  if choice.coins then add(costs,choice.coins..' COINS')end
  if choice.damage then add(costs,choice.damage..' HULL DAMAGE BEFORE DIFFICULTY MODIFIER')end
  if choice.turns then add(costs,choice.turns..' EXTRA TURN')end
  add(lines,'CONSEQUENCE: '..(#costs>0 and table.concat(costs,', ') or 'NO EXTRA COST')..'.')
  add(lines,'SELECTING THE CHOICE COMPLETES TRAVEL TO '..C.stations[g.pending.to].short..'.')
  info.action='resolve';info.actionLabel='CHOOSE THIS';info.args={id}
 else error('Unknown information type '..tostring(kind)) end
 return info
end

-- Short, live summaries shown on primary screens; full descriptions remain available.
function Info.wagonBenefit(w)
 local l=w.level or 1
 if w.id=='engine' then return '+4 FUEL TANK PER LEVEL' end
 if w.id=='cargo' then return '+'..(8+(l-1)*4)..' CARGO CAPACITY' end
 if w.id=='passenger' then return '+'..(4+(l-1)*2)..' CARGO CAPACITY' end
 if w.id=='fuel' then return '+'..(8+(l-1)*4)..' FUEL TANK; +2 CARGO' end
 if w.id=='crane' then return 'FREE ROCKSLIDES; +'..(2+(l-1)*2)..' CARGO' end
 return 'TRAIN EQUIPMENT'
end
function Info.eventBrief(g,choiceIndex)
 if not(g and g.pending) then return 'NO EVENT' end
 local event=C.eventById[g.pending.event]
 local choice=event and event.choices[choiceIndex]
 if not choice then return 'UNKNOWN CHOICE' end
 local parts={}
 for good,quantity in pairs(choice.cost or {}) do
  local free=false
  if event.id=='rocks' and choiceIndex==1 then
   for _,w in ipairs(g.wagons)do if w.id=='crane'then free=true;break end end
  elseif event.id=='signal' and choiceIndex==1 and g.upgrades.relay then free=true end
  parts[#parts+1]=free and 'FREE WITH EQUIPMENT' or (quantity..' '..good:upper())
 end
 if choice.coins then parts[#parts+1]=choice.coins..' COINS' end
 if choice.damage then parts[#parts+1]='-'..choice.damage..' HULL' end
 if choice.turns then parts[#parts+1]='+'..choice.turns..' TURN' end
 return #parts>0 and table.concat(parts,' / ') or 'NO EXTRA COST'
end

function Info.wrap(lines,width)
 local out={};width=math.max(8,math.floor(width))
 for _,str in ipairs(lines)do
  local current='';for word in tostring(str):gmatch('%S+') do
   while #word>width do
    if current~='' then out[#out+1]=current;current=''end
    out[#out+1]=word:sub(1,width);word=word:sub(width+1)
   end
   if current=='' then current=word
   elseif #current+#word+1<=width then current=current..' '..word
   else out[#out+1]=current;current=word end
  end
  if current~='' then out[#out+1]=current end
  out[#out+1]=''
 end
 if out[#out]=='' then out[#out]=nil end
 return out
end
return Info
