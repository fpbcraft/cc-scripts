package.path="./?.lua;./?/init.lua;"..package.path
local E=require("games.cogworks.engine")
local B=require("games.cogworks.briefing")
local goalCount=0
for number,level in ipairs(E.levels)do
 local brief=B.forLevel(number)
 assert(brief.number==number and brief.name==level.name,
  "Level name and number must match the source data")
 assert(brief.tip==level.tip,"Instruction must come from the level")
 assert(#brief.targets==#level.goals and #brief.targets>0,
  "Show every machine objective")
 for i,goal in ipairs(brief.targets)do
  local machine=level.goals[i]
  assert(goal.number==i and goal.x==machine.x and goal.y==machine.y,
   "Objective location")
  assert(goal.spin==(machine.sign<0 and "CCW" or "CW"),
   "Objective rotation is authoritative")
  assert(goal.rpm==machine.speed,"Objective RPM is authoritative")
  goalCount=goalCount+1
 end
 local expectedStock,total=0,0
 for _,kind in ipairs(E.order)do
  local count=level.stock[kind] or 0
  if count>0 then expectedStock=expectedStock+1 end
  total=total+count
 end
 assert(#brief.stock==expectedStock and brief.stockTotal==total,
  "Stock summary must match the inventory")
 for _,part in ipairs(brief.stock)do
  assert(part.count==level.stock[part.kind] and E.parts[part.kind],
   "Listed parts are actually usable in the puzzle")
 end
 assert(brief.bonus.sealed==(number>=2) and
  brief.bonus.fullFactory==(number>=3) and
  brief.bonus.precision==(number>=5),
  "Optional challenges must match their introduction levels")
end
assert(goalCount==93,"All authored goals represented in level cards")
assert(B.forLevel(6).stockTotal>0 and #B.forLevel(6).targets==2,
 "The Switchback shows its two presses and available parts")
print("COGWORKS: all 30 mission briefs match 93 authored goals and stock lists.")
