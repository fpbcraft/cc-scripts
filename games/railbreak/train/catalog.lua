-- Railbreak Train-first Edition. Game data is deliberately separate from rules and UI.
local C={}
C.stations={
 {id=1,name='IRON JUNCTION',short='IRON JCT',x=.16,y=.59,kind='junction',bonus='parts',prices={ore=5,coal=4,logs=5}},
 {id=2,name='PINE RIDGE',short='PINE RIDGE',x=.39,y=.26,kind='forest',bonus='planks',prices={logs=3,planks=4}},
 {id=3,name='STONEBRIDGE',short='STONEBRIDGE',x=.50,y=.62,kind='quarry',bonus='ore',prices={ore=3,parts=8}},
 {id=4,name='RED VALLEY',short='RED VALLEY',x=.72,y=.42,kind='forge',bonus='sheets',prices={ore=4,sheets=6}},
 {id=5,name='EASTPORT',short='EASTPORT',x=.91,y=.72,kind='capital',bonus='passengers',prices={passengers=4,food=4}},
 {id=6,name='NORTHMILL',short='NORTHMILL',x=.61,y=.13,kind='mill',bonus='planks',prices={logs=3,planks=4}},
 {id=7,name='RIVERWATCH',short='RIVERWATCH',x=.29,y=.82,kind='river',bonus='food',prices={food=3,coal=4}},
}
C.edges={
 {1,2,1,1},{1,3,1,1},{1,7,1,1},{2,3,1,1},{2,6,1,2},{3,4,2,1},{3,7,1,1},{4,6,1,1},{4,5,2,2},{6,5,2,1},{7,5,2,2},
} -- {station a, station b, fuel cost, track-parts cost when first traversed}
C.goods={
 {id='logs',hint='SAWMILL INPUT',name='LOGS',icon='wood',base=5},
 {id='planks',hint='BRIDGES / JOBS',name='PLANKS',icon='wood',base=7},
 {id='ore',hint='PRESS / FOUNDRY',name='IRON ORE',icon='ore',base=6},
 {id='sheets',hint='BRIDGES / JOBS',name='SHEETS',icon='sheet',base=11},
 {id='parts',hint='TRACK / REPAIRS',name='PARTS',icon='parts',base=13},
 {id='coal',hint='DEPOT > FUEL',name='COAL',icon='coal',base=5},
 {id='food',hint='RIDERS / RELIEF',name='FOOD',icon='food',base=6},
 {id='passengers',hint='PASSENGER JOBS',name='RIDERS',icon='people',base=7},
}
C.goodsById={};for _,g in ipairs(C.goods)do C.goodsById[g.id]=g end
C.wagons={
 {id='cargo',summary='+8 CAP; +4 PER LV',name='CARGO WAGON',icon='box',cost=58,cap=8,description='+8 goods capacity'},
 {id='passenger',summary='+4 CAP; +2 PER LV',name='PASSENGER',icon='people',cost=60,cap=4,description='+4 cargo capacity; +2 per level'},
 {id='fuel',summary='+8 FUEL TANK, +2 CAP',name='FUEL TENDER',icon='coal',cost=55,cap=2,description='+8 fuel capacity'},
 {id='crane',summary='ROCKSLIDES FREE, +2 CAP',name='CRANE WAGON',icon='crane',cost=95,cap=2,description='Clear obstructions cheaply'},
}
C.wagonById={};for _,w in ipairs(C.wagons)do C.wagonById[w.id]=w end
C.modules={
 {id='sawmill',name='SAWMILL',icon='saw',cost=38,from='logs',input=1,to='planks',output=2,desc='1 LOG -> 2 PLANKS'},
 {id='press',name='PRESS SHOP',icon='press',cost=42,from='ore',input=1,to='sheets',output=2,desc='1 ORE -> 2 SHEETS'},
 {id='foundry',name='FOUNDRY',icon='foundry',cost=55,from='ore',input=1,to='parts',output=2,desc='1 ORE -> 2 PARTS'},
 {id='fuel_yard',name='FUEL DEPOT',icon='coal',cost=40,from='coal',input=1,to='fuel',output=3,desc='1 COAL -> 3 FUEL'},
 {id='workshop',name='ASSEMBLY BAY',icon='parts',cost=65,from='parts',input=2,to='sheets',output=3,desc='2 PARTS -> 3 SHEETS'},
 {id='ticket',name='TICKET OFFICE',icon='people',cost=42,from='food',input=1,to='passengers',output=2,desc='1 FOOD -> 2 RIDERS'},
}
C.moduleById={};for _,m in ipairs(C.modules)do C.moduleById[m.id]=m end
C.upgrades={
 {id='brass',name='BRASS CONTROLS',icon='parts',cost=55,desc='FORECAST NEXT HAZARD'},
 {id='burner',name='EFF. BURNER',icon='coal',cost=70,desc='-1 FUEL ON LONG ROUTES'},
 {id='loader',name='AUTO LOADER',icon='box',cost=62,desc='+5 CARGO SLOTS'},
 {id='relay',name='SIGNAL RELAY',icon='signal',cost=65,desc='SIGNAL REPAIRS FREE'},
 {id='whistle',name='STEAM WHISTLE',icon='train',cost=40,desc='+2 CARGO SLOTS'},
 {id='armor',name='REINFORCEMENT',icon='wrench',cost=52,desc='+30 MAX HULL; REPAIR 30'},
}
C.upgradeById={};for _,u in ipairs(C.upgrades)do C.upgradeById[u.id]=u end
C.contracts={
 {id=1,name='LUMBER ORDER',item='planks',count=3,origin=1,destination=2,reward=65,rep=1},
 {id=2,name='ORE SHIPMENT',item='ore',count=2,origin=1,destination=3,reward=45,rep=1},
 {id=3,name='GEAR DELIVERY',item='parts',count=2,origin=1,destination=4,reward=80,rep=2},
 {id=4,name='MILL MACHINERY',item='sheets',count=3,origin=2,destination=6,reward=75,rep=1},
 {id=5,name='RIVER RELIEF',item='food',count=3,origin=1,destination=7,reward=54,rep=1},
 {id=6,name='EASTPORT RIDERS',item='passengers',count=3,origin=3,destination=5,reward=85,rep=2},
 {id=7,name='VALLEY REPAIRS',item='parts',count=3,origin=3,destination=4,reward=92,rep=2},
 {id=8,name='NORTHERN TIMBER',item='planks',count=4,origin=6,destination=5,reward=110,rep=2},
 {id=9,name='HARBOR PLATING',item='sheets',count=3,origin=4,destination=5,reward=85,rep=2},
}
C.contractById={};for _,v in ipairs(C.contracts)do C.contractById[v.id]=v end
C.events={
 {id='rocks',name='ROCKSLIDE',desc='FALLEN STONE BLOCKS THE TRACK.',choices={{label='USE PARTS',icon='parts',desc='COST: 2 PARTS',cost={parts=2}},{label='DETOUR',icon='map',desc='COST: 1 TURN + 12 HULL',turns=1,damage=12}}},
 {id='bridge',name='BROKEN BRIDGE',desc='A BRIDGE NEEDS TEMPORARY BRACING.',choices={{label='USE SHEETS',icon='sheet',desc='COST: 2 SHEETS',cost={sheets=2}},{label='CAREFUL CROSSING',icon='train',desc='COST: 12 HULL',damage=12}}},
 {id='signal',name='SIGNAL FAILURE',desc='A REDSTONE SIGNAL HAS JAMMED.',choices={{label='REPAIR',icon='wrench',desc='COST: 1 PART',cost={parts=1}},{label='WAIT',icon='clock',desc='COST: 1 TURN',turns=1}}},
 {id='raiders',name='CARGO RAIDERS',desc='RAIDERS DEMAND A TRACK TOLL.',choices={{label='PAY TOLL',icon='coin',desc='COST: 18 COINS',coins=18},{label='PUSH THROUGH',icon='train',desc='COST: 10 HULL',damage=10}}},
}
C.eventById={};for _,v in ipairs(C.events)do C.eventById[v.id]=v end
return C
