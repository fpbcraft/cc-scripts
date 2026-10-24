local S=require('games.railbreak.game.state')
local C=require('games.railbreak.content.catalog')
local K={}
local function powerTile(tile) return tile and (C.spec[tile.id].category=='generator' or C.spec[tile.id].category=='kinetic' or C.spec[tile.id].category=='machine') end
function K.analyze(g)
 local visited={}
 local nodes={};local capacity,load=0,0;local allStable=true
 local rpmInfo={}
 for y=1,S.H do for x=1,S.W do
  local t=S.get(g,x,y);local key=x..':'..y
  if powerTile(t) and not visited[key] then
   local queue={{x,y}};local index=1;visited[key]=true;local component={}
   local cap,required=0,0;local machines={};local engines={};local geared=false
   while queue[index] do
    local a,b=queue[index][1],queue[index][2];index=index+1
    local nt=S.get(g,a,b);component[#component+1]={x=a,y=b,t=nt}
    if nt.id=='wheel' then cap=cap+32 elseif nt.id=='steam' and g.warehouse.coal>=1 then cap=cap+80;engines[#engines+1]=nt end
    if nt.id=='gear' then geared=true end
    if C.spec[nt.id].category=='machine' then machines[#machines+1]=nt end
    for _,d in ipairs(C.dirs) do
     local nx,ny=a+d[1],b+d[2];local ne=S.get(g,nx,ny);local nk=nx..':'..ny
     if powerTile(ne) and not visited[nk] then visited[nk]=true;queue[#queue+1]={nx,ny} end
    end
   end
   local rpm=geared and 32 or 16
   for _,machine in ipairs(machines) do required=required+C.spec[machine.id].stress*(rpm/16) end
   local running=cap>0 and required<=cap
   if cap>0 and required>cap then allStable=false end
   for _,node in ipairs(component) do
    rpmInfo[node.x..':'..node.y]={powered=running,rpm=cap>0 and rpm or 0,networkLoad=required,capacity=cap}
   end
   nodes[#nodes+1]={capacity=cap,load=required,rpm=rpm,active=running,engines=engines,machines=machines}
   capacity=capacity+cap;load=load+required
  end
 end end
 local status={capacity=capacity,load=load,active=allStable and capacity>0,rpm=16,
  connections=rpmInfo,networks=nodes,overstressed=not allStable}
 g.machineStatus={capacity=status.capacity,load=status.load,active=status.active,rpm=status.rpm,connections=status.connections,overstressed=status.overstressed}
 return status
end
return K
