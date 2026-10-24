local path=(arg and arg[0]) or 'tests/ai_only.lua'
local dir=path:match('^(.*)/tests/[^/]+$') or '.'
_G.EXPANSE_ROOT=dir..'/expanse'
local sim=dofile(_G.EXPANSE_ROOT..'/sim.lua')
local wins={0,0,0,0};local scores={0,0,0,0};local modes={}
for seed=1,60 do
 local g=sim.new({seed=2347*seed+67,humans={false,false,false,false},rounds=24})
 local it=0
 while not g.ended and it<30 do sim.advanceAI(g);it=it+1 end
 assert(g.ended,seed..' failed to finish')
 wins[g.winner]=wins[g.winner]+1;modes[g.reason]=(modes[g.reason] or 0)+1
 for i=1,4 do scores[i]=scores[i]+sim.score(g,i)end
end
for i=1,4 do print(i,'wins',wins[i],'avgscore',math.floor(scores[i]/60))end
for a,b in pairs(modes)do print('route',a,b)end