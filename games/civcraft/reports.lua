-- Reports contain only the receiving empire's possessions and economy.
local R={}
function R.capture(state,p)
 local s={food=p.food or 0,wood=p.wood or 0,science=p.science or 0,cities={},units={},techs={}}
 for id,value in pairs(p.techs or {})do if value then s.techs[id]=true end end
 for _,c in ipairs(state.cities or {})do if c.owner==p.id then
  local b={};for id,value in pairs(c.buildings or {})do if value then b[id]=true end end
  s.cities[c.x..','..c.y]={population=c.population or 2,buildings=b}
 end end
 for _,u in ipairs(state.units or {})do if u.owner==p.id then
  s.units[tostring(u.id or (u.kind..':'..u.x..','..u.y))]={kind=u.kind,hp=u.hp}
 end end
 return s
end
function R.build(state,p,before)
 local now=R.capture(state,p);local lines={}
 if not before then return {'Your empire is ready. Inspect cities to assign citizens and choose production.',
  'Select a unit, then use MOVE / ATTACK to issue an order.'}end
 for _,field in ipairs({'food','wood','science'})do
  local delta=now[field]-before[field]
  lines[#lines+1]=(field=='wood' and 'INDUSTRY' or field:upper())..' '..(delta>=0 and '+' or '')..delta..' (TOTAL '..now[field]..')'
 end
 local ids={};for id in pairs(now.techs)do if not before.techs[id]then ids[#ids+1]=id end end
 table.sort(ids);for _,id in ipairs(ids)do lines[#lines+1]='Research completed: '..id end
 local coords={};for key in pairs(now.cities)do coords[#coords+1]=key end;table.sort(coords)
 for _,key in ipairs(coords)do
  local city,old=now.cities[key],before.cities[key]
  if not old then lines[#lines+1]='City gained at '..key
  else
   if city.population~=old.population then lines[#lines+1]='City '..key..' population '..old.population..' -> '..city.population end
   local built={};for id in pairs(city.buildings)do if not old.buildings[id]then built[#built+1]=id end end
   table.sort(built);for _,id in ipairs(built)do lines[#lines+1]='City '..key..' completed '..id end
  end
 end
 for key in pairs(before.cities)do if not now.cities[key]then lines[#lines+1]='City lost at '..key end end
 for id,u in pairs(now.units)do
  local old=before.units[id]
  if not old then lines[#lines+1]='Unit recruited: '..u.kind
  elseif old.hp and u.hp and u.hp<old.hp then lines[#lines+1]=u.kind..' damaged: '..u.hp..' HP' end
 end
 for id,u in pairs(before.units)do if not now.units[id]then lines[#lines+1]='Unit lost: '..u.kind end end
 return lines
end
return R
