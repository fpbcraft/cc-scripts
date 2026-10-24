-- COGWORKS: each part is [kind, x, y, solved rotation, scramble offset, target speed, target sign].
-- Rotations: 0 north, 1 east, 2 south, 3 west.
-- B (speed controller) has an input at its local north port and output at south.
-- All puzzles are authored with an explicitly valid reference solution.
local function t(kind,x,y,r,offset,speed,sign)
 return {kind=kind,x=x,y=y,solution=r or 0,offset=offset or 1,speed=speed,sign=sign}
end
return {
 {name="FIRST SPIN", tip="TURN THE SHAFTS TO POWER THE PRESS.", parts={
  t("S",1,2,1),t("I",2,2,1),t("L",3,2,2),t("I",3,3,0),
  t("M",3,4,0,0,1,1)}},
 {name="AROUND THE BEND", tip="ELBOWS CARRY POWER AROUND CORNERS.", parts={
  t("S",1,2,1),t("I",2,2,1),t("L",3,2,2),t("L",3,3,0),
  t("I",4,3,1),t("M",5,3,3,0,1,1)}},
 {name="SPLIT DECISION", tip="TEE SHAFTS POWER TWO MACHINES.", parts={
  t("S",1,2,1),t("T",2,2,2),t("I",3,2,1),t("M",4,2,3,0,1,1),
  t("L",2,3,0),t("I",3,3,1),t("M",4,3,3,0,1,1)}},
 {name="REVERSE ENGINEER", tip="A GEAR REVERSES THE SPIN DIRECTION.", parts={
  t("S",1,2,1),t("I",2,2,1),t("G",3,2,1),t("I",4,2,1),
  t("M",5,2,3,0,1,-1)}},
 {name="DOUBLE TIME", tip="SPEED CONTROLLERS DOUBLE RPM IN THE ARROW DIRECTION.", parts={
  t("S",1,2,1),t("B",2,2,3),t("L",3,2,2),t("I",3,3,0),
  t("M",3,4,0,0,2,1)}},
 {name="OPPOSING GEARS", tip="SPLIT POWER INTO NORMAL AND REVERSED LINES.", parts={
  t("S",1,2,1),t("T",2,2,2),t("G",3,2,1),t("M",4,2,3,0,1,-1),
  t("I",2,3,0),t("M",2,4,0,0,1,1)}},
 {name="POWER DIVIDER", tip="EACH BRANCH MAY NEED A DIFFERENT SPEED.", parts={
  t("S",1,2,1),t("I",2,2,1),t("T",3,2,2),t("M",4,2,3,0,1,1),
  t("B",3,3,0),t("M",3,4,0,0,2,1)}},
 {name="WORKSHOP WIRING", tip="ONE BRANCH REVERSES; THE OTHER DOUBLES.", parts={
  t("S",1,2,1),t("T",2,2,2),t("G",3,2,1),t("M",4,2,3,0,1,-1),
  t("L",2,3,0),t("B",3,3,3),t("M",4,3,3,0,2,1)}},
 {name="BACKFEED", tip="KEEP BOTH OUTPUTS POWERED BY THE SAME SOURCE.", parts={
  t("S",1,3,1),t("L",2,3,3),t("T",2,2,2),t("M",1,2,1,0,1,1),
  t("G",3,2,1),t("M",4,2,3,0,1,-1)}},
 {name="MASTER MECHANIC", tip="REVERSE THE LOWER LINE AND SPEED UP THE UPPER.", parts={
  t("S",1,2,1),t("T",2,2,2),t("B",3,2,3),t("M",4,2,3,0,2,1),
  t("G",2,3,0),t("M",2,4,0,0,1,-1)}},
}
