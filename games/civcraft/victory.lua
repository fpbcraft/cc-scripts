local Rails=dofile('/games/civcraft/railways.lua')
local V={}
function V.score(state,p)
 local score=0
 for _,c in ipairs(state.cities)do if c.owner==p.id then
  score=score+20+(c.population or 2)*2
  for _,built in pairs(c.buildings or {})do if built then score=score+3 end end
 end end
 for _,known in pairs(p.techs or {})do if known then score=score+8 end end
 return score
end
function V.status(state,p)
 local network=Rails.network(state,p);local largest=0;local industrial=false;local dragon=false
 for _,city in ipairs(state.cities)do if city.owner==p.id then
  dragon=dragon or (city.buildings or {}).dragon==true
  local n=network[city.id]
  if n then
   largest=math.max(largest,n.size);local developed=0
   for _,c in ipairs(n.cities)do if (c.buildings or {}).bank then developed=developed+1 end end
   if developed>=3 then industrial=true end
  end
 end end
 return {industrial=industrial,dragon=dragon,connected=largest,industryTurns=p.industryTurns or 0,score=V.score(state,p)}
end
function V.check(state,advance)
 if state.ruleset~='create' or state.phase~='game'then return end
 local qualifiers={};local reasons={}
 for _,p in ipairs(state.players)do
  local status=V.status(state,p)
  if advance and p.victoryRound~=state.round then
   p.victoryRound=state.round;p.industryTurns=status.industrial and (p.industryTurns or 0)+1 or 0
  end
  local capitals=0;local own=0
  for _,c in ipairs(state.cities)do if c.capitalOf then capitals=capitals+1;if c.owner==p.id then own=own+1 end end end
  local reason=capitals>=2 and own==capitals and 'CONQUEST' or status.dragon and 'END EXPEDITION' or (p.industryTurns or 0)>=10 and 'INDUSTRIAL'
  if reason then qualifiers[#qualifiers+1]=p;reasons[#reasons+1]=reason end
 end
 if #qualifiers==0 and state.round>=(state.roundLimit or 180)then
  local best=-1
  for _,p in ipairs(state.players)do
   local score=V.score(state,p)
   if score>best then best=score;qualifiers={p};reasons={'SCORE'}elseif score==best then qualifiers[#qualifiers+1]=p;reasons[#reasons+1]='SCORE'end
  end
 end
 if #qualifiers>0 then
  local names={};state.winnerIDs={}
  for _,p in ipairs(qualifiers)do names[#names+1]=p.name;state.winnerIDs[#state.winnerIDs+1]=p.id end
  state.winner=table.concat(names,' & ');state.victoryReason=table.concat(reasons,' / ');state.phase='over'
 end
end
return V
