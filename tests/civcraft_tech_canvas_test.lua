local nativeDofile=dofile
dofile=function(path)
 if path:sub(1,10)=="/civcraft/"then return nativeDofile(path:sub(2))end
 return nativeDofile(path)
end
local S=assert(loadfile("civcraft/systems.lua"))()
local Tree=assert(loadfile("civcraft/tech_tree.lua"))()
local player={techs={},science=100}
local buttons,strokes={},0
local r={buttons=buttons}
function r:fill(...)strokes=strokes+1 end
function r:outline(...)strokes=strokes+1 end
function r:icon(...)strokes=strokes+1 end
function r:text(...)end
function r:button(x,y,w,h,label,fn)
 buttons[#buttons+1]={x=x,y=y,w=w,h=h,label=label,fn=fn}
end
local picked,closed=nil,false
local model={}
local viewport={x=5,y=5,w=480,h=268}
Tree.draw(r,S,player,viewport,model,function(id)picked=id end,function()closed=true end)
assert(#S.techOrder>=20,"Expanded prerequisite graph")
assert(strokes>100,"Graph renders actual links and nodes")
local node
for _,b in ipairs(buttons)do
 if b.label=="agriculture"then node=b;break end
end
assert(node,"A starting technology appears as a clickable graph node")
node.fn()
assert(model.selected=="agriculture")
buttons={}
r.buttons=buttons
Tree.draw(r,S,player,viewport,model,function(id)picked=id end,function()closed=true end)
local research
for _,b in ipairs(buttons)do if b.label=="RESEARCH"then research=b end end
assert(research,"Available technology has a research button")
research.fn()
assert(picked=="agriculture")
local right
for _,b in ipairs(buttons)do if b.label=="RIGHT"then right=b end end
assert(right,"Panning arrows appear")
right.fn()
assert(model.panX>0,"Graph can pan to late technologies")
local zoom
for _,b in ipairs(buttons)do if b.label=="ZOOM+"then zoom=b end end
assert(zoom)
zoom.fn()
assert(model.zoom>1,"Technology canvas supports zoom")
print("CIVCRAFT: scrollable technology graph, prerequisites, research buttons and zoom passed.")
