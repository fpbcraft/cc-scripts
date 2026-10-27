-- Minecraft/Create content; stable legacy IDs keep existing campaigns readable.
local C = { techs = {}, techOrder = {}, units = {}, buildings = {} }
C.ages = {
	{ name = "SURVIVAL", milestone = "agriculture" },
	{ name = "IRON", milestone = "bronze" },
	{ name = "REDSTONE & DIAMOND", milestone = "deepmining" },
	{ name = "ROTATION", milestone = "engineering" },
	{ name = "BRASS", milestone = "brassworking" },
	{ name = "STEAM & RAIL", milestone = "steampower" },
}
C.civs = {
	{ id = "verdant", name = "OAK VILLAGERS", bonus = "Wheat farms +1 food" },
	{ id = "iron", name = "DEEPSLATE MINERS", bonus = "Quarries +1 industry" },
	{ id = "scholar", name = "ENCHANTERS GUILD", bonus = "Cities +2 science" },
	{ id = "nomad", name = "DESERT WANDERERS", bonus = "Scouts +1 move" },
	{ id = "mariner", name = "OCEAN EXPLORERS", bonus = "Ships +1 move" },
	{ id = "forge", name = "ANDESITE ENGINEERS", bonus = "Belt workshops +2 industry" },
	{ id = "highland", name = "MOUNTAIN BUILDERS", bonus = "Hill defenders +3 power" },
	{ id = "merchant", name = "EMERALD TRADERS", bonus = "Trading halls +2 food" },
	{ id = "sentinel", name = "GOLEM KEEPERS", bonus = "City defense +3 power" },
	{ id = "wild", name = "TAIGA RANGERS", bonus = "Forest movement costs one" },
}
C.cityNames = {
	verdant = {
		"OAKVALE",
		"FERNWOOD",
		"MOSSBANK",
		"ELMHAVEN",
		"WILLOW",
		"BLOOM",
		"GREENWAY",
		"LEAFREST",
		"IVYGLEN",
		"CEDAR",
		"ROOTVALE",
		"BIRCH",
	},
	iron = {
		"IRONHOLD",
		"ANVIL",
		"RIVET",
		"STEELTON",
		"OREGATE",
		"BLACKPIT",
		"HAMMER",
		"SLAGFORD",
		"CINDER",
		"BOLTKEEP",
		"IRONVALE",
		"BRASS",
	},
	scholar = {
		"ENCHANT",
		"LAPIS",
		"AMETHYST",
		"QUARTZ",
		"ENDER",
		"PONDER",
		"QUILL",
		"SCRIBE",
		"PRISM",
		"PORTAL",
		"ARCANA",
		"RUNE",
	},
	nomad = {
		"DUNEREST",
		"OASIS",
		"SUNVALE",
		"DUSTWELL",
		"MIRAGE",
		"SANDSEA",
		"REDMESA",
		"WAYSTONE",
		"STARWELL",
		"SILT",
		"DRYFORD",
		"WINDBEND",
	},
	mariner = {
		"TIDEPORT",
		"CORAL",
		"SEABREAK",
		"PEARL",
		"FOAMREST",
		"REEF",
		"SALTQUAY",
		"DRIFT",
		"COVE",
		"GULLBAY",
		"ANCHOR",
		"BLUEFIN",
	},
	forge = {
		"EMBER",
		"ASHFALL",
		"FIREGATE",
		"COALFORD",
		"SPARK",
		"SMELTER",
		"HEARTH",
		"REDANVIL",
		"KILN",
		"PYRE",
		"FLARE",
		"CHARVALE",
	},
	highland = {
		"TUFF",
		"ANDESITE",
		"CALCITE",
		"GRANITE",
		"DIORITE",
		"DEEPSLAT",
		"BASALT",
		"REDSTONE",
		"COPPER",
		"EMERALD",
		"DRIPSTON",
		"PEAK",
	},
	merchant = {
		"GILT",
		"COINPORT",
		"GOLDVALE",
		"SILKROAD",
		"BAZAAR",
		"AMBER",
		"MINT",
		"TRADEWAY",
		"SCALE",
		"COPPER",
		"GEMFORD",
		"CROWN",
	},
	sentinel = {
		"BASTION",
		"STONEGAP",
		"WARDEN",
		"RAMPART",
		"GRANITE",
		"WATCH",
		"GATEKEEP",
		"RUNEWALL",
		"SHIELD",
		"BEDROCK",
		"TOWER",
		"FLINT",
	},
	wild = {
		"BRAMBLE",
		"FOXGLEN",
		"WOLFDEN",
		"THORN",
		"FERN",
		"BADGER",
		"WILDROOT",
		"BOARREST",
		"HAWKNEST",
		"STAGWOOD",
		"BEARVALE",
		"YEW",
	},
}
local function tech(id, name, age, needs, unlock)
	local lane = 1
	for _, t in pairs(C.techs) do
		if t.age == age then
			lane = lane + 1
		end
	end
	C.techs[id] = {
		name = name:upper(),
		cost = ({ 24, 32, 50, 70, 100, 130 })[age],
		requires = needs,
		unlock = unlock,
		tier = age,
		lane = lane,
		age = age,
	}
	C.techOrder[#C.techOrder + 1] = id
end
tech("agriculture", "Wheat Farming", 1, {}, "wheat farm")
tech("mining", "Stone Tools", 1, {}, "quarry")
tech("sailing", "Boating", 1, {}, "dock / boat")
tech("archery", "Bow Crafting", 1, { "mining" }, "bow archer")
tech("crafting", "Crafting", 1, {}, "crafting hall")
tech("husbandry", "Animal Husbandry", 1, { "agriculture" }, "animal pens")
tech("bronze", "Iron Smelting", 2, { "mining" }, "furnace / shield guard / iron stock")
tech("writing", "Books & Maps", 2, { "agriculture" }, "library")
tech("masonry", "Stone Masonry", 2, { "mining" }, "stone walls")
tech("horseback", "Horse Riding", 2, { "husbandry" }, "horse rider")
tech("navigation", "Ocean Exploration", 2, { "sailing" }, "survey boat / embarkation")
tech("currency", "Village Trading", 2, { "writing" }, "trading hall / material exchange")
tech("metallurgy", "Ironworking", 2, { "bronze" }, "iron swordsman / smithy")
tech("cartography", "Cartography", 2, { "navigation", "writing" }, "expedition scout")
tech(
	"deepmining",
	"Deep Mining",
	3,
	{ "bronze", "masonry" },
	"deep mine / diamond, copper and zinc deposits"
)
tech("diamondworking", "Diamond Equipment", 3, { "deepmining" }, "diamond swordsman")
tech("redstone", "Redstone Circuits", 3, { "deepmining" }, "redstone workshop / redstone stock")
tech("philosophy", "Enchanting", 3, { "diamondworking", "writing" }, "enchanting room")
tech("nether", "Nether Portals", 3, { "diamondworking" }, "Nether portal")
tech("brewing", "Potion Brewing", 3, { "nether" }, "brewing stand / potion support")
tech("tactics", "Crossbow Crafting", 3, { "archery", "metallurgy" }, "crossbow guard")
tech(
	"engineering",
	"Andesite Engineering",
	4,
	{ "bronze", "masonry", "redstone" },
	"engineer / belt workshop / siege contraption"
)
tech("waterpower", "Water Wheels", 4, { "engineering" }, "water wheel")
tech("windpower", "Windmills", 4, { "engineering" }, "windmill")
tech("pressing", "Mechanical Pressing", 4, { "waterpower" }, "mechanical press")
tech("crushing", "Crushing Wheels", 4, { "pressing" }, "crushing wheels")
tech("belts", "Belt Transport", 4, { "pressing" }, "belt logistics")
tech(
	"fortification",
	"Golem Defenses",
	4,
	{ "masonry", "engineering" },
	"golem fortress / iron golem"
)
tech(
	"shipbuilding",
	"Mechanical Boats",
	4,
	{ "cartography", "engineering" },
	"mechanical patrol boat"
)
tech("heatedmixing", "Heated Mixing", 5, { "pressing", "nether" }, "blaze burner / heated mixer")
tech(
	"brassworking",
	"Brassworking",
	5,
	{ "heatedmixing", "redstone" },
	"brass stock / armored engineer"
)
tech("deployers", "Deployers", 5, { "brassworking" }, "deployer workshop")
tech("precision", "Precision Mechanisms", 5, { "deployers", "belts" }, "assembly workshop")
tech(
	"mechanicalcrafting",
	"Mechanical Crafting",
	5,
	{ "precision" },
	"mechanical crafter / heavy siege"
)
tech("commerce", "Stock Logistics", 5, { "brassworking", "currency" }, "stock exchange")
tech("education", "Ponder Research", 5, { "precision", "philosophy" }, "Ponder hall")
tech("shipcannons", "Dispenser Batteries", 5, { "shipbuilding", "redstone" }, "dispenser barge")
tech("steampower", "Steam Power", 6, { "precision", "heatedmixing" }, "steam plant")
tech(
	"railways",
	"Railways",
	6,
	{ "steampower", "belts" },
	"train station / railway engineer / rails"
)
tech("logistics", "Train Schedules", 6, { "railways", "commerce" }, "freight depot / supply crew")
tech(
	"economics",
	"Industrial Logistics",
	6,
	{ "logistics", "mechanicalcrafting" },
	"industrial complex"
)
tech(
	"astronomy",
	"End Preparation",
	6,
	{ "education", "brewing" },
	"End staging ground / expedition company"
)
tech("netherite", "Netherite Smithing", 6, { "diamondworking", "steampower" }, "netherite guard")
tech(
	"enlightenment",
	"End Expedition",
	6,
	{ "astronomy", "netherite" },
	"Eyes of Ender / equipment / dragon expedition"
)
tech("navalwarfare", "Steam Navigation", 6, { "shipbuilding", "steampower" }, "steam flagship")
local function unit(id, name, tech, production, move, attack, defense, range, extra)
	local u = {
		name = name:upper(),
		tech = tech,
		production = production,
		wood = math.ceil(production / 2.5),
		move = move,
		vision = 3,
		strength = attack,
		defense = defense,
		range = range,
		upkeep = math.max(1, math.ceil(production / 30)),
		ability = "Minecraft equipment",
	}
	for k, v in pairs(extra or {}) do
		u[k] = v
	end
	C.units[id] = u
end
unit("warrior", "Stone Guard", nil, 13, 2, 2, 2, 1, { ability = "Inexpensive early defense" })
unit(
	"settler",
	"Settler",
	nil,
	12,
	3,
	0,
	1,
	0,
	{ productionStep = 5, vision = 1, ability = "Found a village" }
)
unit(
	"scout",
	"Scout",
	nil,
	5,
	4,
	1,
	1,
	1,
	{ vision = 4, ability = "Forest exploration; auto explore" }
)
unit(
	"archer",
	"Bow Archer",
	"archery",
	25,
	2,
	3,
	1,
	2,
	{ ability = "Ranged fire without retaliation" }
)
unit(
	"spearman",
	"Shield Guard",
	"bronze",
	23,
	2,
	3,
	4,
	1,
	{ ability = "+2 strength against mounted units" }
)
unit("swordsman", "Iron Swordsman", "metallurgy", 40, 2, 7, 5, 1, { resource = "iron" })
unit(
	"horseman",
	"Horse Rider",
	"horseback",
	30,
	4,
	5,
	2,
	1,
	{ mounted = true, ability = "Fast open-ground movement" }
)
unit("explorer", "Expedition Scout", "cartography", 23, 5, 1, 1, 1, { vision = 5 })
unit(
	"ranger",
	"Crossbow Guard",
	"tactics",
	35,
	3,
	5,
	3,
	2,
	{ ability = "Forest movement and ranged fire" }
)
unit(
	"diamondguard",
	"Diamond Swordsman",
	"diamondworking",
	65,
	2,
	9,
	8,
	1,
	{ resource = "diamond" }
)
unit(
	"alchemist",
	"Potion Support",
	"brewing",
	45,
	2,
	3,
	4,
	2,
	{ healer = true, ability = "Heals adjacent friendly units by 10 HP after each round" }
)
unit(
	"engineer",
	"Engineer",
	"engineering",
	40,
	3,
	1,
	3,
	1,
	{ engineer = true, ability = "Build rails after Railways research" }
)
unit(
	"golem",
	"Iron Golem",
	"fortification",
	75,
	2,
	9,
	11,
	1,
	{ resource = "iron", building = "fortress", ability = "Slow, durable settlement defender" }
)
unit(
	"catapult",
	"Siege Contraption",
	"engineering",
	45,
	2,
	5,
	2,
	2,
	{ siege = true, ability = "Full damage against walls" }
)
unit(
	"brassengineer",
	"Armored Engineer",
	"brassworking",
	65,
	3,
	5,
	6,
	1,
	{ engineer = true, resource = "brass" }
)
unit(
	"heavysiege",
	"Deployer Siege",
	"mechanicalcrafting",
	95,
	2,
	11,
	5,
	2,
	{ siege = true, resource = "brass" }
)
unit(
	"railengineer",
	"Railway Engineer",
	"railways",
	70,
	4,
	4,
	6,
	1,
	{ engineer = true, resource = "iron" }
)
unit(
	"supplycrew",
	"Supply Crew",
	"logistics",
	65,
	3,
	3,
	5,
	1,
	{ healer = true, ability = "Heals adjacent allies by 10 HP per round" }
)
unit(
	"netherguard",
	"Netherite Guard",
	"netherite",
	110,
	2,
	13,
	12,
	1,
	{ resource = "diamond", building = "smithy" }
)
unit("expedition", "Expedition Company", "astronomy", 95, 3, 10, 8, 2, { resource = "diamond" })
unit("galley", "Oak Boat", "sailing", 28, 3, 2, 2, 1, { naval = true })
unit("navigator", "Survey Boat", "navigation", 33, 4, 2, 2, 1, { naval = true, vision = 5 })
unit(
	"frigate",
	"Mechanical Patrol",
	"shipbuilding",
	55,
	4,
	6,
	4,
	2,
	{ naval = true, resource = "iron" }
)
unit(
	"dispenserbarge",
	"Dispenser Barge",
	"shipcannons",
	80,
	4,
	8,
	5,
	2,
	{ naval = true, resource = "redstone" }
)
unit(
	"flagship",
	"Steam Flagship",
	"navalwarfare",
	100,
	5,
	11,
	8,
	2,
	{ naval = true, resource = "brass" }
)
for _, u in pairs(C.units) do
	if u.naval then
		u.building = "shipyard"
	end
end
local function building(id, name, tech, cost, effects, needs, extra)
	local b = {
		name = name:upper(),
		tech = tech,
		production = cost,
		effects = effects or {},
		requires = needs or {},
	}
	for k, v in pairs(extra or {}) do
		b[k] = v
	end
	local description = {}
	for _, k in ipairs({ "food", "industry", "science", "gold" }) do
		if b.effects[k] then
			description[#description + 1] = "+" .. b.effects[k] .. " " .. k
		end
	end
	b.description = b.description or table.concat(description, ", ")
	C.buildings[id] = b
end
building("farm", "Wheat Farm", "agriculture", 15, { food = 2 })
building("mine", "Quarry", "mining", 18, { industry = 2 })
building("craftinghall", "Crafting Hall", "crafting", 15, { industry = 1 })
building("pens", "Animal Pens", "husbandry", 22, { food = 2 })
building("housing", "Homesteads", "crafting", 24, {}, nil, {
	development = true,
	capacity = 2,
	description = "Settlement Capacity +2; no extra food or automatic citizens",
})
building("well", "Water Services", "masonry", 28, {}, nil, {
	development = true,
	capacity = 2,
	description = "Settlement Capacity +2; retains food consumption",
})
building(
	"shipyard",
	"Dock",
	"sailing",
	30,
	{},
	nil,
	{ coastal = true, description = "Enables naval recruitment; coastal city only" }
)
building("furnace", "Furnace", "bronze", 25, { industry = 2 })
building("smithy", "Smithy", "metallurgy", 35, { industry = 1 }, { "furnace" })
building("library", "Bookshelf Library", "writing", 23, { science = 2 })
building(
	"walls",
	"Stone Walls",
	"masonry",
	20,
	{},
	nil,
	{ description = "100 wall HP; enables ranged city strikes" }
)
building("market", "Trading Hall", "currency", 30, { food = 2, gold = 3 })
C.buildings.market.capacity = 1
building("councilhall", "Council Hall", "commerce", 90, {}, { "market" }, {
	description = "Qualifies your civilization for diplomatic victory through Council elections. Requires two-thirds of all allocated delegates and another civilization's support. Does not create extra delegates.",
})
building("deepmine", "Deep Mine", "deepmining", 40, { industry = 2 }, { "furnace" })
building("academy", "Enchanting Room", "philosophy", 38, { science = 3 })
building("redstoneworkshop", "Redstone Workshop", "redstone", 40, { science = 2 })
building("portal", "Nether Portal", "nether", 45, { science = 2 })
building("brewery", "Brewing Stand", "brewing", 40, { food = 1, science = 1 }, { "portal" })
building("workshop", "Belt Workshop", "engineering", 30, { industry = 1 })
building("waterwheel", "Water Wheel", "waterpower", 35, { industry = 2 })
building("windmill", "Windmill", "windpower", 45, { food = 2, industry = 2 })
building("press", "Mechanical Press", "pressing", 45, { industry = 3 }, { "waterwheel" })
building("crusher", "Crushing Wheels", "crushing", 55, { industry = 3 }, { "press" })
building("beltlogistics", "Belt Logistics", "belts", 50, { industry = 2 }, { "press" })
building(
	"fortress",
	"Golem Fortress",
	"fortification",
	65,
	{},
	nil,
	{ description = "200 wall HP; enables iron golems" }
)
building("burner", "Blaze Burner", "heatedmixing", 45, { industry = 1 }, { "portal" })
building("mixer", "Heated Mixer", "heatedmixing", 60, { industry = 2 }, { "press", "burner" }, {
	description = "+2 industry; after Brassworking converts 1 copper + 1 zinc into 2 brass per round",
})
building("deployer", "Deployer Workshop", "deployers", 65, { industry = 3 }, { "mixer" })
building(
	"assembly",
	"Assembly Workshop",
	"precision",
	80,
	{ industry = 4, science = 2 },
	{ "deployer", "beltlogistics" }
)
building(
	"crafter",
	"Mechanical Crafter",
	"mechanicalcrafting",
	90,
	{ industry = 5 },
	{ "assembly" }
)
building("bazaar", "Stock Exchange", "commerce", 48, { industry = 3, gold = 3 }, { "market" })
building("university", "Ponder Hall", "education", 60, { science = 4 }, { "academy" })
building("steamplant", "Steam Plant", "steampower", 100, { industry = 6 }, { "mixer", "assembly" })
building(
	"station",
	"Train Station",
	"railways",
	65,
	{},
	nil,
	{ description = "Rail-connected stations: +2 industry and +2 gold per city" }
)
building("freight", "Freight Depot", "logistics", 80, { gold = 4 }, { "station" })
building(
	"bank",
	"Industrial Complex",
	"economics",
	130,
	{ industry = 3, gold = 5 },
	{ "steamplant", "crafter", "freight" }
)
building(
	"observatory",
	"End Staging Ground",
	"astronomy",
	85,
	{ science = 4 },
	{ "portal", "academy" }
)
building(
	"eyes",
	"Eyes of Ender",
	"enlightenment",
	140,
	{},
	{ "observatory" },
	{ description = "First End expedition project" }
)
building(
	"equipment",
	"Expedition Equipment",
	"enlightenment",
	180,
	{},
	{ "eyes" },
	{ description = "Second End expedition project" }
)
building(
	"dragon",
	"Dragon Expedition",
	"enlightenment",
	240,
	{},
	{ "equipment" },
	{ description = "Complete to win an End expedition victory" }
)
building("grandacademy", "End Archive", "enlightenment", 90, { science = 6 }, { "observatory" })
C.resources = {
	iron = { tech = "bronze" },
	copper = { tech = "deepmining" },
	zinc = { tech = "deepmining" },
	redstone = { tech = "redstone" },
	diamond = { tech = "deepmining" },
	brass = { tech = "brassworking" },
	horses = {},
	saltpeter = {},
}
C.resourceOrder = { "iron", "copper", "zinc", "redstone", "diamond", "brass" }
C.naturalWonders = {
	lushcavern = {
		name = "LUSH CAVERN",
		food = 3,
		science = 1,
		description = "Worked tile: +3 food, +1 science",
	},
	amethyst = { name = "AMETHYST GEODE", science = 4, description = "Worked tile: +4 science" },
	mushroom = { name = "MUSHROOM ISLAND", food = 4, description = "Worked tile: +4 food" },
	ice_spikes = {
		name = "ICE SPIKES",
		science = 2,
		industry = 2,
		description = "Worked tile: +2 science, +2 industry",
	},
	dripstone = { name = "DRIPSTONE CAVE", industry = 4, description = "Worked tile: +4 industry" },
	ancientcity = {
		name = "ANCIENT CITY",
		science = 3,
		industry = 1,
		description = "Worked tile: +3 science, +1 industry",
	},
}
C.wonders = {
	beacon = {
		name = "BEACON PYRAMID",
		tech = "diamondworking",
		production = 160,
		effects = { food = 2, science = 3 },
		description = "City +2 food, +3 science",
	},
	clockwork = {
		name = "GREAT CLOCKWORK",
		tech = "precision",
		production = 220,
		effects = { industry = 6 },
		description = "City +6 industry",
	},
	greattree = {
		name = "GREAT OAK SANCTUARY",
		tech = "husbandry",
		production = 100,
		effects = { food = 4 },
		description = "City +4 food",
	},
	monument = {
		name = "PRISMARINE MONUMENT",
		tech = "navigation",
		production = 140,
		coastal = true,
		effects = { gold = 5, science = 2 },
		description = "Coastal city +5 gold, +2 science",
	},
	vault = {
		name = "ENCHANTED VAULT",
		tech = "philosophy",
		production = 170,
		effects = { science = 5 },
		description = "City +5 science",
	},
	railhub = {
		name = "GRAND TERMINAL",
		tech = "logistics",
		production = 240,
		effects = { industry = 3, gold = 6 },
		description = "City +3 industry, +6 gold",
	},
}
C.hostiles = {
	zombie = {
		name = "ZOMBIE",
		move = 2,
		vision = 4,
		strength = 2,
		defense = 2,
		range = 1,
		hostile = true,
		upkeep = 0,
	},
	skeleton = {
		name = "SKELETON",
		move = 2,
		vision = 4,
		strength = 3,
		defense = 1,
		range = 2,
		hostile = true,
		upkeep = 0,
	},
	spider = {
		name = "SPIDER",
		move = 3,
		vision = 4,
		strength = 3,
		defense = 2,
		range = 1,
		hostile = true,
		forest = true,
		upkeep = 0,
	},
	creeper = {
		name = "CREEPER",
		move = 2,
		vision = 4,
		strength = 7,
		defense = 1,
		range = 1,
		hostile = true,
		explosive = true,
		upkeep = 0,
	},
	pillager = {
		name = "PILLAGER",
		move = 2,
		vision = 5,
		strength = 6,
		defense = 3,
		range = 2,
		hostile = true,
		upkeep = 0,
	},
}
for id, u in pairs(C.hostiles) do
	u.production = 0
	u.ability = "Hostile mob; cannot be recruited"
	C.units[id] = u
end
return C
