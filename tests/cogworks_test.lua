package.path="./?.lua;./?/init.lua;"..package.path
local E=require("cogworks.engine")
local function eq(actual,expected,msg)
 assert(actual==expected,(msg or "Mismatch")..": expected "..tostring(expected)..", got "..tostring(actual))
end
eq(#E.levels,30,"Puzzle campaign size")
local totalGoals=0
for index,data in ipairs(E.levels)do
 local game=E.new(index)
 local initial=E.evaluate(game)
 assert(not initial.win,"Puzzle "..index.." must start unsolved")
 eq(game.moves,0,"Empty board move count")
 assert(not E.rotate(game,1,1),"Cannot rotate an empty cell")
 assert(not E.remove(game,data.source.x,data.source.y),"Cannot remove source")
 assert(not E.place(game,data.source.x,data.source.y,"I"),"Cannot replace source")
 assert(not E.place(game,0,1,"I"),"Cannot build out of bounds")
 assert(not E.place(game,8,2,"I"),"Cannot build out of bounds")
 assert(not E.place(game,2,2,"banana"),"Unknown part rejected")
 for _,wall in ipairs(data.blocks)do
  local t=E.get(game,wall[1],wall[2])
  assert(t and t.kind=="X" and t.fixed,"Permanent wall present")
  assert(not E.place(game,wall[1],wall[2],"I"),"Cannot build in stone")
 end
 local solved=E.new(index,true)
 local result=E.evaluate(solved)
 assert(result.win,"Reference solution invalid for level "..index..
  " (goals "..result.correct.."/"..result.goals..", jam="..tostring(result.jam)..")")
 totalGoals=totalGoals+result.goals
 local options=E.challenges(solved,result)
 if index>=2 then assert(#options>0,"Most levels need bonus contracts")end
 for _,challenge in ipairs(options)do
  assert(challenge.earned,"Canonical solution earns "..challenge.id.." at stage "..index)
 end
 if index<=3 then assert(not data.fullNetwork,"Tutorial stages should stay relaxed")end
 if index>=4 then
  assert(data.fullNetwork,"Advanced stages should track full network metrics for bonuses")
  eq(result.openPorts,0,"Solved level has no dangling ports: "..index)
  eq(result.unpowered,0,"Solved level has no unpowered parts: "..index)
  eq(result.remaining,0,"Solved level has no unused stock: "..index)
  if index>=11 then assert(result.goals>=3,"Intermediate levels have three outputs")end
  if index>=19 then assert(result.goals>=4,"Advanced levels have four outputs")end
  if index>=27 then assert(result.goals>=5,"Final levels have five outputs")end
  if index>=12 or (index>=8 and index<=10) then assert((data.stock.G or 0)>0 or (data.stock.B or 0)>0,
   "Level "..index.." has power transformation")end
 end
 local total=0
 for kind,stock in pairs(data.stock)do
  eq(stock,solved.stock[kind],"Reference stock for "..kind)
  total=total+stock
 end
 eq(#E.snapshot(solved),#data.build,"Reference uses all parts")
 assert(total>=#data.build,"No shortage in level inventory")
 local manual=E.new(index)
 for _,t in ipairs(data.build)do
  assert(E.place(manual,t.x,t.y,t.kind,t.r),"Cannot place solution tile "..t.kind.." in "..index)
 end
 assert(E.evaluate(manual).win,"Manual construction failed in "..index)
 eq(#E.snapshot(manual),#data.build,"Snapshot includes all placements")
 assert(not E.place(manual,data.build[1].x,data.build[1].y,"I"),
  "Cannot stack a second part on a tile")
 local saved=E.snapshot(manual)
 local restored=E.new(index)
 assert(E.restore(restored,saved),"Valid session restored")
 assert(E.evaluate(restored).win,"Restored solution should stay solved")
 local before=E.snapshot(restored)
 assert(not E.restore(restored,{{x=0,y=1,kind="I",r=0}}),
  "Reject invalid stored part")
 eq(#E.snapshot(restored),#before,"Invalid session cannot change board")
 local first=data.build[1]
 assert(E.remove(manual,first.x,first.y),"Placed part can be removed")
 assert(E.place(manual,first.x,first.y,first.kind,first.r),"Refunded stock reused")
 assert(E.evaluate(manual).win,"Salvage/replace retains solution")
 local bad=E.new(index)
 if #data.build>0 then
  local firstPiece=data.build[1]
  assert(E.place(bad,firstPiece.x,firstPiece.y,firstPiece.kind,0),"Place part for rotation")
  assert(E.rotate(bad,firstPiece.x,firstPiece.y),"Rotate a movable part")
  assert(E.remove(bad,firstPiece.x,firstPiece.y),"Reclaim part")
 end

end
-- Check inventory includes the ten distinct construction tools.
eq(#E.order,9,"Construction inventory excludes nonessential clutch")
local actual={}
for _,kind in ipairs(E.order)do actual[kind]=true;assert(E.parts[kind])end
for _,kind in ipairs({"Q","O","V","D"})do
 assert(actual[kind],"New mechanism is selectable: "..kind)
end
local g=E.new(1)
-- A placed component rotates clockwise and cannot be rotated when locked.
assert(E.place(g,2,3,"I",0),"Place a new shaft")
assert(E.rotate(g,2,3),"Rotate constructed part")
eq(E.get(g,2,3).r,1,"Rotation 90 degrees")
assert(not E.rotate(g,1,3),"Generator orientation locked")
-- Main progress is independent of optional full-network contracts.
local advanced=E.new(20,true)
local complete=E.evaluate(advanced)
assert(complete.win and complete.complete,"Reference advanced board complete")
advanced.remaining.I=(advanced.remaining.I or 0)+1
local incomplete=E.evaluate(advanced)
eq(incomplete.correct,incomplete.goals,"Power still reaches every machine")
assert(incomplete.win and not incomplete.complete,
 "Main objective wins even when optional stock has not been used")
eq(incomplete.remaining,1,"Leftover piece identified")
local bonus={}
for _,challenge in ipairs(E.challenges(advanced,incomplete))do bonus[challenge.id]=challenge.earned end
assert(bonus.sealed and not bonus.master,
 "Leaving spare stock only blocks master bonus")
advanced.remaining.I=advanced.remaining.I-1
advanced.moves=1000
advanced.moves=1000
local precision={}
for _,challenge in ipairs(E.challenges(advanced,E.evaluate(advanced)))do
 precision[challenge.id]=challenge.earned
end
assert(precision.master and not precision.precision,
 "Unoptimized wins should not earn precision bonus")
assert(E.evaluate(advanced).win,"Mastery contracts must never prevent level completion")
-- Verify requirements derive from reversing gears and speed controllers.
local hadReverse,hadBoost=false,false
for i=8,#E.levels do
 local solved=E.new(i,true)
 local lights=E.evaluate(solved).lights
 for _,p in ipairs(solved.tiles)do
  if p.kind=="M"then
   local actual=lights[p.id].ports[p.r]
   if p.sign==-1 then
    eq(actual.sign,-1,"Gear direction at target")
    hadReverse=true
   end
   if p.speed>1 then
    eq(actual.rate,p.speed,"Controller RPM at target")
    hadBoost=true
   end
  end
 end
end
assert(hadReverse and hadBoost,"Advanced campaign exercises gears and RPM")
print("COGWORKS: "..#E.levels.." levels and "..totalGoals..
 " goals validated for inventory, full networks, construction and kinetics.")
