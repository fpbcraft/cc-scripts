-- Data-driven balance: technology graph tiers/lanes drive research AND UI.
local C={}
C.civs={
 {id="verdant",name="VERDANT LEAGUE",bonus="Farms +1 food"},
 {id="iron",name="IRON DOMINION",bonus="Mines +1 wood"},
 {id="scholar",name="ASTRAL ACADEMY",bonus="Libraries +1 science"},
 {id="nomad",name="DUST NOMADS",bonus="Scouts +1 move"},
 {id="mariner",name="TIDAL REPUBLIC",bonus="Ships +1 move"},
 {id="forge",name="EMBER FORGE",bonus="Workshops +2 wood"},
 {id="highland",name="HIGHLAND CLANS",bonus="Hills combat +1"},
 {id="merchant",name="GOLDEN CONCORD",bonus="Markets +2 food"},
 {id="sentinel",name="STONE WARDENS",bonus="City defense +1"},
 {id="wild",name="WILDBORN CIRCLE",bonus="Forest movement free"},
}
-- Node tiers are vertical stages; lanes identify visible prerequisite branches.
-- Short settlement names keep map labels on a single line.
C.cityNames={
 verdant={'OAKVALE','FERNWOOD','MOSSBANK','ELMHAVEN','WILLOW','BLOOM','GREENWAY','LEAFREST','IVYGLEN','CEDAR','ROOTVALE','BIRCH'},
 iron={'IRONHOLD','ANVIL','RIVET','STEELTON','OREGATE','BLACKPIT','HAMMER','SLAGFORD','CINDER','BOLTKEEP','IRONVALE','BRASS'},
 scholar={'ASTRA','LYRA','NOVA','LUMEN','VEGA','ORION','QUILL','SCRIBE','PRISM','ZENITH','ARCANA','SOLIS'},
 nomad={'DUNEREST','OASIS','SUNVALE','DUSTWELL','MIRAGE','SANDSEA','REDMESA','WAYSTONE','STARWELL','SILT','DRYFORD','WINDBEND'},
 mariner={'TIDEPORT','CORAL','SEABREAK','PEARL','FOAMREST','REEF','SALTQUAY','DRIFT','COVE','GULLBAY','ANCHOR','BLUEFIN'},
 forge={'EMBER','ASHFALL','FIREGATE','COALFORD','SPARK','SMELTER','HEARTH','REDANVIL','KILN','PYRE','FLARE','CHARVALE'},
 highland={'CAIRN','BENMORE','GLENCOE','BRAEMAR','TORHOLD','CRAGFORD','HEATHER','LOCHREST','HIGHLAND','STAGGLEN','DUNROCK','THISTLE'},
 merchant={'GILT','COINPORT','GOLDVALE','SILKROAD','BAZAAR','AMBER','MINT','TRADEWAY','SCALE','COPPER','GEMFORD','CROWN'},
 sentinel={'BASTION','STONEGAP','WARDEN','RAMPART','GRANITE','WATCH','GATEKEEP','RUNEWALL','SHIELD','BEDROCK','TOWER','FLINT'},
 wild={'BRAMBLE','FOXGLEN','WOLFDEN','THORN','FERN','BADGER','WILDROOT','BOARREST','HAWKNEST','STAGWOOD','BEARVALE','YEW'},
}
C.techs={
 agriculture={name="AGRICULTURE",cost=24,requires={},unlock="farm",tier=1,lane=1},
 mining={name="MINING",cost=24,requires={},unlock="mine",tier=1,lane=3},
 sailing={name="SAILING",cost=30,requires={},unlock="shipyard / galley",tier=1,lane=5},
 writing={name="WRITING",cost=30,requires={"agriculture"},unlock="library",tier=2,lane=1},
 bronze={name="BRONZE WORKING",cost=36,requires={"mining"},unlock="spearman",tier=2,lane=3},
 masonry={name="MASONRY",cost=36,requires={"mining"},unlock="walls",tier=2,lane=4},
 horseback={name="HORSEBACK RIDING",cost=45,requires={"agriculture"},unlock="horseman",tier=2,lane=2},
 navigation={name="NAVIGATION",cost=45,requires={"sailing"},unlock="navigator / embarkation",tier=2,lane=5},
 engineering={name="ENGINEERING",cost=54,requires={"bronze","masonry"},unlock="workshop / catapult",tier=3,lane=3},
 philosophy={name="PHILOSOPHY",cost=54,requires={"writing"},unlock="academy",tier=3,lane=1},
 archery={name="ARCHERY",cost=51,requires={"bronze"},unlock="archer",tier=3,lane=2},
 currency={name="CURRENCY",cost=51,requires={"writing"},unlock="market",tier=3,lane=4},
 cartography={name="CARTOGRAPHY",cost=66,requires={"navigation","writing"},unlock="explorer",tier=3,lane=5},
 fortification={name="FORTIFICATION",cost=72,requires={"masonry","engineering"},unlock="fortress",tier=4,lane=3},
 education={name="EDUCATION",cost=72,requires={"philosophy"},unlock="university",tier=4,lane=1},
 tactics={name="MILITARY TACTICS",cost=72,requires={"archery","horseback"},unlock="ranger",tier=4,lane=2},
 commerce={name="COMMERCE",cost=69,requires={"currency","engineering"},unlock="bazaar",tier=4,lane=4},
 shipbuilding={name="SHIPBUILDING",cost=75,requires={"cartography","engineering"},unlock="frigate",tier=4,lane=5},
 metallurgy={name="METALLURGY",cost=90,requires={"fortification"},unlock="swordsman",tier=5,lane=3},
 astronomy={name="ASTRONOMY",cost=90,requires={"education","cartography"},unlock="observatory",tier=5,lane=1},
 logistics={name="LOGISTICS",cost=90,requires={"tactics","commerce"},unlock="stable",tier=5,lane=2},
 economics={name="ECONOMICS",cost=90,requires={"commerce"},unlock="bank",tier=5,lane=4},
 navalwarfare={name="NAVAL WARFARE",cost=96,requires={"shipbuilding","metallurgy"},unlock="flagship",tier=5,lane=5},
 enlightenment={name="ENLIGHTENMENT",cost=120,requires={"astronomy","economics"},unlock="grandacademy",tier=6,lane=2},
}
C.techOrder={"agriculture","mining","sailing","writing","bronze","masonry","horseback",
 "navigation","engineering","philosophy","archery","currency","cartography",
 "fortification","education","tactics","commerce","shipbuilding","metallurgy",
 "astronomy","logistics","economics","navalwarfare","enlightenment"}
C.units={
 catapult={food=4,wood=18,move=2,vision=2,strength=5,defense=2,range=2,tech="engineering",siege=true,ability="Siege damage against city walls"},
 warrior={food=0,wood=5,move=2,vision=2,strength=2,defense=2,range=1,ability="Balanced frontline"},
 settler={food=8,wood=8,production=12,productionStep=5,move=2,vision=1,strength=0,defense=1,range=0,ability="Found cities"},
 scout={food=2,wood=4,production=5,move=4,vision=4,strength=1,defense=1,range=1,ability="Explore; ignores forest cost"},
 spearman={food=2,wood=9,move=2,vision=2,strength=3,defense=4,range=1,tech="bronze",ability="+2 vs mounted"},
 horseman={food=5,wood=12,move=4,vision=3,strength=5,defense=2,range=1,tech="horseback",resource="horses",ability="Fast plains movement / requires horses"},
 archer={food=3,wood=10,move=2,vision=3,strength=3,defense=1,range=2,tech="archery",ability="Attack at 2 hexes"},
 explorer={food=4,wood=9,move=5,vision=5,strength=1,defense=1,range=1,tech="cartography",ability="Long-range reconnaissance"},
 ranger={food=4,wood=14,move=3,vision=4,strength=5,defense=3,range=2,tech="tactics",ability="Forest specialist; ranged"},
 swordsman={food=5,wood=16,move=2,vision=2,strength=7,defense=5,range=1,tech="metallurgy",resource="iron",ability="Heavy infantry / requires iron"},
 galley={food=3,wood=11,move=3,vision=3,strength=2,defense=2,range=1,tech="sailing",naval=true,ability="Cross water"},
 navigator={food=4,wood=13,move=4,vision=5,strength=2,defense=2,range=1,tech="navigation",naval=true,ability="Reveal distant coasts"},
 frigate={food=6,wood=18,move=4,vision=4,strength=6,defense=4,range=2,tech="shipbuilding",naval=true,resource="iron",ability="Naval ranged fire / requires iron"},
 flagship={food=9,wood=25,move=5,vision=5,strength=9,defense=7,range=2,tech="navalwarfare",naval=true,resource="saltpeter",ability="Capital warship / requires saltpeter"},
}
C.buildings={
 shipyard={wood=12,tech="sailing",coastal=true,description="Coastal city only; enables ship production"},
 farm={wood=6,tech="agriculture",description="+2 food"},
 mine={wood=7,tech="mining",description="+2 wood"},
 library={wood=9,tech="writing",description="+2 science"},
 walls={wood=8,tech="masonry",description="+1 defense"},
 workshop={wood=12,tech="engineering",description="+1 wood"},
 academy={wood=15,tech="philosophy",description="+3 science"},
 market={wood=12,tech="currency",description="+2 food"},
 fortress={wood=18,tech="fortification",description="+2 defense"},
 university={wood=20,tech="education",description="+4 science"},
 bazaar={wood=19,tech="commerce",description="+3 wood"},
 observatory={wood=22,tech="astronomy",description="+4 science"},
 bank={wood=25,tech="economics",description="+3 wood"},
 grandacademy={wood=30,tech="enlightenment",description="+6 science"},
}
for id,unit in pairs(C.units)do
 unit.upkeep=math.max(1,math.ceil((unit.wood or 5)/7))
 if unit.naval then unit.building='shipyard'end
end
return C
