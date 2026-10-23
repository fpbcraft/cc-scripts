local S=require('railbreak.game.state')
local C=require('railbreak.content.catalog')
local U=require('railbreak.core.util')
local K=require('railbreak.game.kinetics')
local P=require('railbreak.game.processing')
local A={}
local function empty()return {id='empty',face=1,filter='iron',slot={},output={},item=nil,work=0}end
function A.build(g,x,y,id,face)
 local existing=S.get(g,x,y);local spec=C.spec[id]
 if not existing or not spec or id=='empty' then return false,'Choose a valid build tile and machine' end
 if existing.id~='empty' then return false,'Dismantle the existing machinery first' end
 if (C.unlocks[id] or 0)>g.unlocked then return false,'Blueprint locked. Complete more expeditions.' end
 local ok,resource,need=U.cost(g.warehouse,spec.cost)
 if not ok then return false,'Need '..need..' '..resource end
 U.pay(g.warehouse,spec.cost)
 g.grid[y][x]={id=id,face=U.clamp(face or 1,1,4),filter='iron',slot={},output={},work=0}
 K.analyze(g);S.log(g,'Built '..spec.name..' at '..x..','..y)
 return true,spec.name..' constructed'
end
function A.remove(g,x,y)
 local t=S.get(g,x,y);if not t or t.id=='empty' then return false,'No machine here' end
 local spec=C.spec[t.id];local refund={}
 for res,cost in pairs(spec.cost or {})do refund[res]=math.floor(cost*.75)end
 U.add(g.warehouse,refund);U.add(g.warehouse,t.slot);U.add(g.warehouse,t.output)
 if t.item then U.add(g.warehouse,{[t.item.id]=t.item.n})end
 g.grid[y][x]=empty();K.analyze(g);S.log(g,'Dismantled '..spec.name)
 return true,'Dismantled. Recovered materials and buffered items.'
end
function A.rotate(g,x,y)
 local t=S.get(g,x,y)
 if not t or t.id=='empty' then return false,'Select a machine' end
 t.face=t.face%4+1;S.log(g,C.spec[t.id].name..' turned')
 return true,'Facing '..({ 'east','south','west','north' })[t.face]
end
function A.filter(g,x,y,resource)
 local t=S.get(g,x,y)
 if not t or t.id~='depot' then return false,'Select an input depot' end
 if not g.warehouse[resource] then return false,'Unknown material' end
 t.filter=resource;return true,'Depot feeds '..resource
end
function A.scavenge(g)
 if g.finished then return false,'Run finished' end
 P.advanceClock(g,{})
 U.add(g.warehouse,{iron=2,logs=2,cobble=2,coal=1});g.penalty=g.penalty+1
 S.log(g,'Emergency salvage collected; one shift spent')
 return true,'Recovered raw materials, but salvage reduces score'
end
function A.advance(g,n)
 n=U.clamp(math.floor(tonumber(n) or 1),1,30)
 local result
 for i=1,n do
  result=P.shift(g)
  if not result or #result.events>0 or g.finished then return true,'Stopped after '..i..' shift(s): '..(result and table.concat(result.events,', ') or 'finished') end
 end
 return true,'Completed '..n..' production shift(s)'
end
function A.deliver(g)
 local contract=C.contracts[g.currentContract]
 if not contract or g.contractStatus~='OPEN' then return false,'No active delivery contract' end
 local ok,res,n=U.cost(g.warehouse,contract.needs)
 if not ok then return false,'Delivery needs '..n..' '..res end
 U.pay(g.warehouse,contract.needs);U.add(g.warehouse,contract.reward)
 g.reputation=g.reputation+contract.reputation;g.delivered=g.delivered+1;g.contractStatus='DONE'
 S.log(g,'Delivered '..contract.title..' (+'..contract.reputation..' reputation)')
 return true,'Contract fulfilled. Warehouse rewarded.'
end
function A.travel(g,choice)
 if g.finished then return false,'Run finished' end
 choice=math.floor(choice or 0);local route=g.routeChoices[choice]
 if not route then return false,'Select a valid railway route' end
 local ok,res,n=U.cost(g.warehouse,route.cost)
 if not ok then return false,'Need '..n..' '..res..' for rails' end
 U.pay(g.warehouse,route.cost)
 U.add(g.warehouse,route.reward)
 g.routeHistory[#g.routeHistory+1]=route.id;g.reputation=g.reputation+2
 S.log(g,'Railway extended to '..route.title..': '..route.event)
 g.chapter=g.chapter+1;g.unlocked=math.max(g.unlocked,math.min(2,g.chapter-1))
 g.contractAge=0;g.contractStatus='OPEN'
 g.currentContract=({[2]=1,[3]=3,[4]=2,[5]=5})[g.chapter] or 1
 g.contractLimit=16+g.chapter*3
 if g.chapter>g.totalChapters then
  g.finished=true;g.won=true;S.log(g,'Frontier capital connected! Expedition completed.')
 else S.refreshRoutes(g) end
 return true,g.finished and 'VICTORY! The frontier railway is complete.' or ('Reached '..route.title..'. New blueprints unlocked.')
end
function A.score(g)
 return g.reputation*100+g.delivered*50+g.totalManufactured*4-g.shift*2-g.penalty*35+g.chapter*100
end
return A
