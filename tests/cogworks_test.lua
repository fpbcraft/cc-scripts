package.path="./?.lua;./?/init.lua;"..package.path
local E=require("cogworks.engine")
local function eq(a,b,why)assert(a==b,why..": expected "..tostring(b)..", got "..tostring(a))end
eq(#E.levels,10,"Puzzle count")
for index=1,#E.levels do
 local solved=E.new(index,true)
 local good=E.evaluate(solved)
 assert(good.win,"Unsolvable author reference for level "..index..
  " (correct "..good.correct.."/"..good.goals..", jam="..tostring(good.jam)..")")
 local scrambled=E.new(index)
 assert(not E.evaluate(scrambled).win,"Level "..index.." must start unsolved")
 local initialMoves=scrambled.moves
 assert(not E.rotate(scrambled,0,0),"Empty space cannot rotate")
 eq(scrambled.moves,initialMoves,"No move for empty space")
 local count=0
 while E.hint(scrambled)do
  count=count+1
  assert(count<=#scrambled.tiles,"Hint loop")
 end
 assert(E.evaluate(scrambled).win,"Hints must solve level "..index)
 eq(scrambled.hints,count,"Hint count")
 -- End-to-end manual rotation test: rotate every unsolved part to its reference.
 local manual=E.new(index)
 for _,tile in ipairs(manual.tiles)do
  while tile.r~=tile.solution do
   assert(E.rotate(manual,tile.x,tile.y),"Rotating movable component")
  end
 end
 assert(E.evaluate(manual).win,"Manual rotations must solve level "..index)
end
-- Confirm that the gear and controller have meaningful directional effects.
local gear=E.evaluate(E.new(4,true))
local target
for _,p in ipairs(E.new(4,true).tiles)do
 if p.kind=="M"then target=p end
end
eq(gear.lights[target.id].ports[target.r].sign,-1,"Gear reverses sign")
local speedGame=E.new(5,true)
local speed=E.evaluate(speedGame)
for _,p in ipairs(speedGame.tiles)do
 if p.kind=="M"then
  eq(speed.lights[p.id].ports[p.r].rate,2,"Controller doubles speed")
 end
end
print("COGWORKS: all "..#E.levels.." authored puzzles, hints, gears and controller tests passed.")
