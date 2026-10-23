-- Data-driven Create-inspired machines and contracts. Costs are balanced for this game.
local C={}
C.dirs={{1,0},{0,1},{-1,0},{0,-1}}
C.resources={"iron","logs","cobble","coal","iron_sheet","plank","gravel","track","bridge"}
C.spec={
 empty={name="Clear tile",icon="."},
 wheel={name="Water Wheel",icon="W",cost={logs=3,cobble=1},power=32,category="generator",help="Generate 32 SU of rotational capacity. Connect to shafts and machines."},
 steam={name="Steam Engine",icon="E",cost={iron_sheet=4,cobble=4,coal=2},power=80,category="generator",help="Generate 80 SU while supplied with coal. Burns one coal per production shift."},
 shaft={name="Shaft",icon="+",cost={logs=1},category="kinetic",help="Transmit rotation between generators and processing machinery."},
 gear={name="Speed Gear",icon="G",cost={iron_sheet=2,plank=1},category="kinetic",help="Increase connected machine RPM to 32. Doubled RPM doubles stress demand."},
 press={name="Mechanical Press",icon="P",cost={iron=3,logs=2},stress=12,category="machine",recipe="press",help="Press iron ingots into metal sheets. Requires rotation and input/output routing."},
 saw={name="Mechanical Saw",icon="S",cost={iron=2,logs=2},stress=8,category="machine",recipe="saw",help="Cut logs into planks. Must have a powered kinetic connection."},
 crusher={name="Crushing Wheels",icon="C",cost={iron=4,cobble=2},stress=16,category="machine",recipe="crusher",help="Crush cobblestone into gravel. Faster with higher RPM, higher stress demand."},
 mixer={name="Mechanical Mixer",icon="M",cost={iron_sheet=3,plank=2},stress=20,category="machine",recipe="mixer",help="Mix gravel and sheets into track kits. Needs both ingredients and rotation."},
 assembler={name="Deployer Assembly",icon="A",cost={iron_sheet=3,plank=3},stress=18,category="machine",recipe="assembler",help="Combine planks and metal sheets into bridge sections."},
 belt={name="Conveyor Belt",icon=">",cost={logs=1},category="transport",help="Carry one material stack one tile per shift. Direction matters; tap Rotate."},
 depot={name="Input Depot",icon="I",cost={logs=2},category="logistics",help="Pull its selected resource from warehouse onto a belt facing away from it."},
 chest={name="Storage Interface",icon="O",cost={logs=2},category="logistics",help="Collect incoming belt items into the shared warehouse."},
}
C.recipes={
 press={input={iron=1},output={iron_sheet=1},work=2},
 saw={input={logs=1},output={plank=2},work=2},
 crusher={input={cobble=1},output={gravel=2},work=2},
 mixer={input={gravel=1,iron_sheet=1},output={track=2},work=3},
 assembler={input={plank=2,iron_sheet=1},output={bridge=1},work=3},
}
C.routes={
 {id="woodland",title="TIMBER VALLEY",detail="Abundant timber, little ore",reward={logs=9,coal=3,cobble=3},cost={iron_sheet=3,plank=2},event="Fallen trees block the line. The sawmill crew clears a path."},
 {id="quarry",title="THE IRON CUT",detail="Rich ore and stone; longer climbs",reward={iron=8,cobble=7,coal=2},cost={iron_sheet=4,gravel=2},event="Rockslide! Reinforcement is needed for the mountain cutting."},
 {id="canal",title="CANAL JUNCTION",detail="Trading docks and a river crossing",reward={logs=6,iron=5,coal=4},cost={track=2,bridge=1},event="A crossing demands an engineered bridge section."},
 {id="furnace",title="FURNACE HIGHLANDS",detail="Coal mines and worn-out locomotives",reward={iron=6,coal=8,cobble=3},cost={track=3,iron_sheet=2},event="A mechanical signal fails. Your rail crew repairs the pointwork."},
 {id="orchard",title="BRASSWOOD GROVE",detail="Plenty of timber and a salvage yard",reward={logs=9,iron=3,coal=3},cost={track=3,plank=3},event="You salvage a useful gearbox from an abandoned machine."},
 {id="viaduct",title="THE VIADUCT",detail="High-value contract across a ravine",reward={iron=9,cobble=5,coal=4},cost={track=3,bridge=2},event="A narrow bridge tests the strength of your construction."},
}
C.contracts={
 {title="RAIL SUPPLY",needs={track=2},reward={iron=4,coal=2},reputation=2},
 {title="CARPENTER",needs={plank=5},reward={logs=6,iron=2},reputation=2},
 {title="BRIDGEWORKS",needs={bridge=2},reward={iron=5,cobble=4},reputation=3},
 {title="SHEET METAL",needs={iron_sheet=4},reward={iron=5,coal=2},reputation=2},
 {title="CRUSHED STONE",needs={gravel=6},reward={cobble=7,logs=3},reputation=2},
}
C.unlocks={press=0,saw=0,crusher=0,mixer=1,assembler=2,gear=1,steam=2}
C.buildOrder={"shaft","wheel","press","belt","depot","chest","saw","crusher","gear","mixer","assembler","steam"}
return C
