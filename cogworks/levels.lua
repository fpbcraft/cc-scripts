-- COGWORKS / curated construction puzzles, six columns by five rows.
-- Build references are solutions, NOT preplaced machinery. Only locked source,
-- target machines and stone obstacles are on the board when a level begins.
-- Port rotations: 0=N, 1=E, 2=S, 3=W.
-- Speed controller: its local NORTH is the input, SOUTH is the output.
local function p(kind,x,y,r)return {kind=kind,x=x,y=y,r=r}end
local function s(x,y,dir)return p("S",x,y,dir)end
local function m(x,y,dir,rpm,sign)
 local v=p("M",x,y,dir);v.speed=rpm;v.sign=sign or 1;return v
end
local function level(name,tip,source,goals,blocks,build,spares)
 local stock={}
 for _,v in ipairs(build)do stock[v.kind]=(stock[v.kind] or 0)+1 end
 for k,v in pairs(spares or {})do stock[k]=(stock[k] or 0)+v end
 return {name=name,tip=tip,source=source,goals=goals,blocks=blocks,
  build=build,stock=stock}
end
return {
 level("POWER LINE","BUILD SHAFTS FROM THE ENGINE TO THE PRESS.",
  s(1,3,1),{m(5,3,3,1,1)},{{2,2},{3,2},{4,2}},
  {p("I",2,3,1),p("I",3,3,1),p("I",4,3,1)}),
 level("THE DETOUR","ROUTE AROUND THE STONE. ELBOWS TURN POWER.",
  s(1,2,1),{m(5,4,3,1,1)},{{4,2},{4,3},{2,3}},
  {p("I",2,2,1),p("L",3,2,2),p("I",3,3,0),p("L",3,4,0),p("I",4,4,1)}),
 level("NARROW PASS","A LONGER DETOUR TAKES FEWER PARTS THAN A JAM.",
  s(1,3,1),{m(4,3,1,1,1)},{{3,3},{3,2},{4,2},{4,4}},
  {p("L",2,3,3),p("I",2,2,0),p("L",2,1,1),p("I",3,1,1),
   p("I",4,1,1),p("L",5,1,2),p("I",5,2,0),p("L",5,3,3)}),
 level("TWO PRESSES","SPLIT ONE ENGINE INTO TWO POWERED ROUTES.",
  s(1,3,1),{m(5,3,3,1,1),m(5,4,3,1,1)},{{1,4},{1,5}},
  {p("T",2,3,2),p("I",3,3,1),p("I",4,3,1),p("L",2,4,0),
   p("I",3,4,1),p("I",4,4,1)}),
 level("WRONG WAY","THE PRESS NEEDS REVERSE ROTATION. USE A GEAR.",
  s(1,2,1),{m(6,2,3,1,-1)},{{2,3},{3,3},{4,3},{5,3}},
  {p("I",2,2,1),p("G",3,2,1),p("I",4,2,1),p("I",5,2,1)}),
 level("DOUBLE POWER","DIRECT 1X RPM THROUGH A 2X CONTROLLER.",
  s(1,2,1),{m(4,5,0,2,1)},{{3,3},{5,3}},
  {p("I",2,2,1),p("B",3,2,3),p("L",4,2,2),
   p("I",4,3,0),p("I",4,4,0)}),
 level("TWO SPEEDS","THE UPPER PRESS NEEDS 1X; LOWER NEEDS 2X.",
  s(1,2,1),{m(5,2,3,1,1),m(2,5,0,2,1)},{{4,3},{4,4}},
  {p("T",2,2,2),p("I",3,2,1),p("I",4,2,1),
   p("B",2,3,0),p("I",2,4,0)}),
 level("MIXED DIRECTIONS","SPLIT POWER: REVERSE ONLY THE UPPER LINE.",
  s(1,3,1),{m(6,3,3,1,-1),m(5,4,3,1,1)},{{4,5},{5,5}},
  {p("T",2,3,2),p("G",3,3,1),p("I",4,3,1),p("I",5,3,1),
   p("L",2,4,0),p("I",3,4,1),p("I",4,4,1)}),
 level("WORKSHOP MAZE","BOTH THE SPEED AND DIRECTION MUST BE CORRECT.",
  s(1,4,1),{m(5,4,0,2,-1)},{{3,4},{4,4},{3,3},{4,3}},
  {p("L",2,4,3),p("I",2,3,0),p("L",2,2,1),p("B",3,2,3),
   p("G",4,2,1),p("L",5,2,2),p("I",5,3,0)}),
 level("TRIPLE CONTRACT","THREE PRESSES NEED THREE DIFFERENT FEEDS.",
  s(1,3,1),{m(6,3,3,2,1),m(3,1,2,1,-1),m(5,4,3,1,-1)},{{1,4},{1,5},{4,5}},
  {p("T",2,3,2),p("T",3,3,0),p("B",4,3,3),p("I",5,3,1),
   p("G",3,2,0),p("T",2,4,1),p("G",3,4,1),p("I",4,4,1)}),
 level("COUNTERFLOW","GEAR FIRST, THEN BOOST. THE OTHER BRANCH STAYS 1X.",
  s(1,2,1),{m(6,2,3,2,-1),m(5,3,3,1,1)},{{1,4},{2,5},{3,5}},
  {p("T",2,2,2),p("G",3,2,1),p("B",4,2,3),p("I",5,2,1),
   p("L",2,3,0),p("I",3,3,1),p("I",4,3,1)}),
 level("MASTER ENGINEER","GEAR BEFORE THE SPLIT, THEN CORRECT THE LOWER FEED.",
  s(1,3,1),{m(6,3,3,2,-1),m(3,5,0,1,1)},{{4,4},{5,4},{6,4},{1,4}},
  {p("G",2,3,1),p("T",3,3,2),p("B",4,3,3),p("I",5,3,1),
   p("G",3,4,0)}),
}
