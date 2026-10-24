-- Run from repository root: lua ironspire/tests/run.lua
package.path="./ironspire/?.lua;"..package.path
local api=assert(loadfile("ironspire/main.lua"))("--test-api")
assert(api and api.new and api.play and api.endTurn)
math.randomseed(42)
local s=api.new()
assert(#s.deck==10 and s.hp==72 and s.energy==nil)
assert(#s.map==9 and s.map[9][2].kind=="boss")
assert(api.Map.reachable(s,1,1) and api.Map.reachable(s,1,3))
assert(not api.Map.reachable(s,2,2))
assert(api.advance(s,"battle",2))
assert(not api.Map.reachable(s,2,0))
assert(not api.Map.reachable(s,2,4))
assert(not api.advance(s,"battle",1))
assert(s.screen=="combat" and s.turn==1 and #s.hand==5 and s.energy==3)
local played=false
for i,key in ipairs(s.hand)do
 local c=api.cards[key]
 if c.cost<=s.energy then
  local before=#s.hand
  api.play(s,i)
  assert(s.screen~="combat" or #s.hand<=before+1)
  played=true;break
 end
end
assert(played)
if s.screen=="combat"then
 api.endTurn(s)
 assert(s.turn==2 or s.screen=="defeat","exactly one enemy turn must advance")
end
local shop=api.new()
shop.map[1][2].kind="shop"
assert(api.advance(shop,"shop",2))
assert(shop.screen=="shop" and #shop.shop==9)
local m={}
function m.getSize()return 80,54 end
function m.setBackgroundColor()end
function m.setTextColor()end
function m.setCursorPos()end
function m.write()end
local legacy=api.new();legacy.map=nil;legacy.lane=nil
api.Map.migrate(legacy)
assert(#legacy.map==9 and legacy.lane==2)
local screens={"map","rest","shop","event","reward","victory","defeat","combat"}
for _,screen in ipairs(screens)do
 local state=api.new()
 state.screen=screen
 if screen=="combat"then api.startFight(state,false)end
 if screen=="shop"then state.shop={"jab",false,"heavy"}end
 if screen=="reward"then state.rewards={"jab","brace","heavy"}end
 local ui=api.UI.new(m,state)
 ui:draw();ui:close()
end
print("IRONSPIRE smoke checks passed")
