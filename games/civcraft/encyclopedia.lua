local Sites = dofile("/games/civcraft/specialty_sites.lua")
local ContentRules = dofile("/games/civcraft/content_rules.lua")
local CampaignRules = dofile("/games/civcraft/campaign_rules.lua")
-- Content-derived entries stay in sync with the simulation's costs and unlocks.
local Systems = dofile("/games/civcraft/systems.lua")
local Panels = dofile("/games/civcraft/panels.lua")
local ResearchDetails = dofile("/games/civcraft/research_details.lua")
local Works = dofile("/games/civcraft/tile_improvements.lua")
local Projects = dofile("/games/civcraft/civilian_projects.lua")
local E = {}
local mechanics = {
	{
		id = "citybanners",
		name = "CITY MAP BANNERS",
		text = "The number beside a city name is its population. A crown marks an original capital. D is defense strength; green and blue bars show city health and walls. Owned cities show G (turns to population growth), -P (turns to starvation loss), and P (turns to production completion). IDLE needs a production choice; PAUSE is deliberate idle; REPEAT runs a civilian project; WAIT needs Settler population. An exclamation mark warns that Settlement Capacity limits growth. Click the banner to select its city. Small maps simplify indicators; the inspector retains details. Remembered cities use only last-observed public information and show no private growth or production.",
	},
	{
		id = "builders",
		name = "BUILDERS AND TILE WORK",
		text = "Landwork V3 Builders cost 22 industry, have two movement and three charges with no upkeep. Wheat Fields require Wheat Farming and fertile open flat land (+1 food); Quarries require Stone Tools and clear hills or stone (+1 industry); Lumber Camps require Crafting and woods or jungle (+1 industry). Only worked tiles produce yields. Oak fields add one food and Iron quarries add one industry. One successful improvement spends one charge and remaining movement; the final charge removes the Builder. Plan work from its inspector, choose a cyan tile, review yields and charges, then confirm. Append adds tasks up to remaining charges. Queued work pauses on visible threats, lost ownership, occupied or invalid routes. Resume or cancel in the inspector. Manual movement replaces work. Capture preserves charges and clears orders. Harvesting and feature removal are not included. City Farm/Quarry bonuses are retired; Homesteads unlock Tend Crops. Older profiles keep their original rules.",
	},
	{
		id = "turns",
		name = "TURNS AND VICTORY",
		text = "Issue orders, then end your turn. Production, research and movement reset after every player is ready. New campaigns: conquer all rival capitals, sustain three industrial cities connected by rail for ten rounds, or complete the three End expedition projects. Score decides after round 180. Simultaneous qualifiers share victory. Legacy campaigns keep eight cities / round 90 rules.",
	},
	{
		id = "population",
		name = "POPULATION AND JOBS",
		text = "Jobs and worked hexes share one population pool. Minus unworks a tile of that type. Plus assigns an idle citizen to an available owned tile of that type. Food, industry and science jobs follow the tile's strongest yield. No free matching tile means no new assignment. Population grows from surplus food.",
	},
	{
		id = "tiles",
		name = "WORKED HEXES",
		text = "A city works its center automatically. Each additional citizen can work one owned hex within three steps. Gold-framed worker badges mark staffed hexes. Open TILES and tap a worked hex to unassign it, or an available hex to work it. The JOBS controls automatically choose tiles; TILES lets you pick them manually. Both change the same assignments.",
	},
	{
		id = "territory",
		name = "CITY TERRITORY",
		text = "Cities receive a short name from a civilization-themed pool, displayed above the city and retained in saves. New cities claim their center and six neighboring hexes. Borders then acquire one adjacent unclaimed hex at a time, up to three hexes away. Border growth takes 6 plus one turn per four claimed tiles. Population no longer claims entire rings. The nearest city claims each hex, with stable ties. Borders trace the actual sides of hexes. A new city must be at least three hexes from another city. Strategic deposits must connect to your territory.",
	},
	{
		id = "yields",
		name = "FOOD INDUSTRY SCIENCE",
		text = "Worked terrain and deposits provide yields. City-center tiles show two base food, one industry and one science, plus building and civilization bonuses. Add the worked tiles to get the inspector total. Each citizen eats two food per round. Surplus fills local storage. Growth requires 20 plus 8 times population in stored food and at least four rounds since the last population change. Zero surplus stagnates. An empty food store and three hungry rounds lose one citizen, down to a minimum population of one. New citizens automatically work an available owned tile. If none is free, they stay idle.",
	},
	{
		id = "production",
		name = "CITY PRODUCTION",
		text = "Open an owned city, choose PROD, then UNITS or BUILDS. Select an unlocked project. Industry is added each round; stored industry is not spent to buy it instantly. Switching retains project progress. NO PRODUCTION pauses work and reminders until you select a new project. Scouts cost five industry. Settlers start at twelve industry and cost five more for each settler the empire has finished training. Queueing or switching does not increase that count; settling or losing a settler does not reduce it. A finished unit waits if no valid spawn hex is free.",
	},
	{
		id = "research",
		name = "RESEARCH",
		text = "Select a technology in TECH TREE, then start research. Required technologies must be completed first. Drag the research canvas to pan; compact research details scroll by dragging. Your cities add science every round until the cost is met. Named research milestones advance your empire through Survival, Iron, Redstone & Diamond, Rotation, Brass, and Steam & Rail. Branch technologies remain available. Selecting a different target retains earlier progress.",
	},
	{
		id = "movement",
		name = "MOVEMENT",
		text = "Select an owned unit, then press MOVE / ATTACK in the inspector to show legal destinations. Cyan dotted borders and numbered badges show reachable movement costs; outlined red crosses mark attacks. Choose a destination to preview its route, then click it again or press the confirm icon. Queue Moves and Add Waypoint can target unexplored tiles. A selected unit shows its saved route: gold solid lines are the committed known path, blue dots continue through fog, and muted dashes estimate later waypoints. Square markers show each destination. Queued steps are checked as terrain and units are discovered; blocked routes pause without attacking. Gold pips identify awake units that can still move. Clicking the unit again deselects it. Cancel leaves your orders unchanged. Open land in any biome costs one movement point; woods, dense jungle, marshes and hills cost two. Settlers have three movement points and pay one on ordinary land, but need movement remaining to found a city. Valid orders wake sleeping units. Scouts and rangers cross forests for one. Mountains block land units.",
	},
	{
		id = "settlement",
		name = "SETTLEMENT SITES",
		text = "Select one of your settlers to see up to three legal settlement sites ranked from your explored map. Markers show the same canonical hex on every visible copy of a wrapped map. Natural tile food and industry before founding, observed water capacity and known resources explain each site. City-center output follows separate rules; conditional specialty opportunities are suggestions only. Fog may hide better terrain, rivals or resources, so estimates can be incomplete. Opening a suggestion keeps the settler selected and never moves it or founds a city. Founding still requires the separate FOUND CITY action.",
	},
	{
		id = "combat",
		name = "COMBAT AND RANGE",
		text = "Only highlighted enemy hexes can be attacked. Strength, defense, city defenses, terrain and unit abilities affect deterministic combat. Ranged attacks do not move the attacker into the target hex and consume its remaining movement. Units have 100 HP. Melee exchanges damage; ranged strikes do not take immediate retaliation and cannot capture cities. Damage depends on effective strength, terrain, health and levels. A unit at zero HP is removed. Resting or fortifying restores 20 HP per round only inside owned territory. Healer support restores 10 HP to adjacent owned units in any territory, including neutral or enemy land.",
	},
	{
		id = "naval",
		name = "NAVAL UNITS",
		text = "Ships travel on water rather than land. Build them in a coastal city with a shipyard beside a free water hex. Navigation permits embarkation at two movement points per water hex on a land-start turn. A unit starting a new round at sea receives at least six movement points and spends one per water hex. Landing spends the remaining allowance. Embarked combat units, including archers, use adjacent melee attacks against land and receive retaliation. Land melee cannot initiate attacks against units on water; land ranged units can fire at embarked targets without Navigation. Sea movement is not refreshed by loading or a Surprise War response. Settlers cannot found cities while embarked. Some ships require an owned strategic deposit and research. Mariner ships receive one extra movement point each round.",
	},
	{
		id = "fog",
		name = "EXPLORATION AND FOG",
		text = "Visible hexes show current units. Explored hexes retain terrain but hide unseen enemies. Unexplored terrain and deposits stay concealed. Vision comes from cities and units. Hotseat handoffs conceal the previous player, and network views filter private information.",
	},
	{
		id = "maps",
		name = "MAP TYPES",
		text = "Choose map size, Continents, Archipelago, Pangaea or Highlands, and horizontal wrap in the lobby. Wrapped maps join west and east while north and south stay bounded. New games default to horizontal wrap; saved maps keep their recorded topology. A fixed seed reproduces the same world. Scouts reveal land; settlers expand into new territory.",
	},
	{
		id = "saving",
		name = "SAVES AND MULTIPLAYER",
		text = "Local hotseat uses three campaign slots and a private handoff screen. Network hosting and joining use modem connections and a separate match save. Save from the pause menu. Updating code preserves campaigns. Main Menu returns to the title; Exit closes the game.",
	},
	{
		id = "controls",
		name = "MAP AND INSPECTOR",
		text = "Click the narrow map edges, or drag or scroll inside the map, to pan. Wrapped maps repeat west and east continuously; clicks on any copy select the same canonical hex. Use + and - in the left sidebar to zoom. Its bottom fullscreen icon opens the fog-aware world overview; click a region to jump there. Resources, yields and territory are independent overlay toggles, off by default. TERRAIN clears overlays. YIELDS zooms in for readable drumstick, cog and flask symbols. Yields up to five repeat the symbol; higher yields show a number, and zero yields are omitted. Builder actions use a food icon for a Wheat Field, ore for a Quarry and wood for a Lumber Camp. A plus badge marks PLAN; an outlined target marks the HERE action. The right inspector stays visible. Use its scrollbar or PREV and NEXT to reach long lists. Modal screens block map input until closed.",
	},
}
mechanics[#mechanics + 1] = {
	id = "standby",
	name = "SLEEP AND TURN CHECKS",
	text = "SLEEP UNIT keeps a unit on standby across rounds. Valid new orders wake it automatically. SKIP TURN ignores a unit only for its current turn without spending movement; accepted new orders clear that skip. The single footer button guides Unit Orders, Production and Research before becoming End Turn. No Production satisfies an idle city. A Surprise War response uses a fresh reminder window and only unspent actions.",
}
mechanics[#mechanics + 1] = {
	id = "reports",
	name = "TURN REPORTS",
	text = "Each turn begins with a private report of your economy, completed research and buildings, city growth, recruited or lost units, and damaged units. REPORT opens it again. Hotseat camera and selection reset when passing the screen to another player.",
}
mechanics[#mechanics + 1] = {
	id = "empire",
	name = "EMPIRE AND IDLE UNITS",
	text = "EMPIRE at the top right lists your units and cities and centers the map on a selection. The primary Unit Orders button cycles through awake units with movement left, excluding skipped and auto-exploring units. Navigation only selects; Move / Attack activates orders. City and Unit in the inspector switch between a city and its garrison.",
}
mechanics[#mechanics + 1] = {
	id = "icons",
	name = "ACTION BAR ICONS",
	text = "The single button below the inspector guides remaining unit, production and research decisions, then becomes End Turn. Left sidebar: plus/minus zoom and fullscreen opens World Overview. Very short terminals place these controls and overlays in Map Tools. Top right: Tech Tree, Factions, Empire, Codex, Report, Event Log, Council and Pause. Status feedback appears below the map. City tabs separate Info, Jobs, Tiles and Production.",
}
mechanics[#mechanics + 1] = {
	id = "gold",
	name = "GOLD AND UPKEEP",
	text = "Each city earns two gold plus its population each round. Markets add three, bazaars three and banks five. Every unit pays its listed upkeep. A treasury can temporarily cover negative income, but unpaid units disband if gold runs out. DISBAND in the unit inspector lets you reduce upkeep voluntarily after confirmation. The top bar shows stocks and projected changes; click it for the full ledger. Owned iron, horses and saltpeter deposits add one stock per round; specialized units consume two stock on completion.",
}
mechanics[#mechanics + 1] = {
	id = "settlercapture",
	name = "SETTLER CAPTURE AND PROTECTION",
	text = "A melee attacker reaching an unprotected settler captures it immediately without a damage exchange. Ranged attacks damage settlers normally. One settler and one protecting unit can share a hex. The protector always takes combat first, regardless of which unit was placed there first. A winning melee attack captures the remaining settler; a ranged kill leaves it unprotected. Captured settlers retain their identity and health but have no fresh movement. Select Settler / Select Guard changes the unit being ordered.",
}
mechanics[#mechanics + 1] = {
	id = "zonecontrol",
	name = "ZONE OF CONTROL",
	text = "Visible hostile melee land units control adjacent passable land; combat ships control adjacent water, and hostile cities control both. Ordinary ranged land units and civilians do not exert control. Entering control stops further movement for this turn, but a military unit may still attack with remaining movement. Civilian and support units spend their remaining movement on entry. Mounted units ignore control. A new turn may leave a zone it started in. Amber movement rings mark stopping tiles. Newly discovered hostile control may interrupt an otherwise valid route; only actual travel is charged and replayed. Current maps do not model river-edge control exceptions.",
}
mechanics[#mechanics + 1] = {
	id = "health",
	name = "HEALTH LEVELS AND HEALING",
	text = "Units have 100 HP. Combat grants XP: attacks give three, defending gives two, defeating a unit adds five, and city attacks give four. Each ten total XP per level increases level and adds two strength. Injuries reduce effective strength. FORTIFY / HEAL skips orders and restores 20 HP per round only in owned territory. Units that did not act also recover only on owned land. Healers restore 10 HP per round to adjacent owned units even outside owned territory. A valid movement or attack order wakes a sleeping unit.",
}
mechanics[#mechanics + 1] = {
	id = "citycombat",
	name = "CITY COMBAT AND SIEGE",
	text = "Cities have 200 HP. Walls provide 100 outer defense HP and fortresses 200. Ordinary melee deals 35 percent and ordinary ranged 25 percent damage against walls; siege units deal full damage. Only a surviving melee unit can capture a city reduced to zero HP. Cities recover 15 HP per round unless all adjacent land escape routes are controlled by enemy melee units. Walls recover after three quiet rounds. Functioning walls permit one visible ranged strike within two hexes each round.",
}
mechanics[#mechanics + 1] = {
	id = "explore",
	name = "AUTO EXPLORE",
	text = "Scouts and explorers can automatically search for unexplored territory using legal, non-attacking routes. AUTO EXPLORE moves immediately if points remain and continues each new round. STOP EXPLORING or a manual order cancels it. It stops when no safe route or unexplored territory remains.",
}
mechanics[#mechanics + 1] = {
	id = "audio",
	name = "AUDIO",
	text = "A connected speaker plays short interaction, movement, research, production and turn effects. The title screen plays an original note-based melody. Toggle AUDIO in the pause menu to mute or restore sound; the setting persists. No speaker means silent play.",
}
mechanics[#mechanics + 1] = {
	id = "create",
	name = "CREATE PRODUCTION",
	text = "City machinery forms local prerequisite chains. Water Wheel -> Mechanical Press -> Belt Logistics and Crushing Wheels. Nether Portal -> Blaze Burner; combine with a press to build a Heated Mixer. After Brassworking, each mixer converts one copper and one zinc to two brass each round. Deployers and assembly workshops lead to mechanical crafting and steam plants. Routine fuel and intermediate parts are included in industry costs.",
}
mechanics[#mechanics + 1] = {
	id = "materials",
	name = "MATERIALS AND TRADE",
	text = "Iron, copper, zinc, redstone and diamond deposits produce one stock per round once claimed and researched. Brass comes from heated mixing. Specialized units consume two stock on completion. A trading hall, or a discovered independent village with 20 influence, enables material purchases in the resource ledger: 20 gold per stock. Research the material technology first.",
}
mechanics[#mechanics + 1] = {
	id = "rails",
	name = "RAILWAYS",
	text = "After Railways, select an engineer and BUILD RAIL. Choose its current or an adjacent eligible owned land hex, then confirm. A segment costs two iron and all remaining movement. Both ends of a rail move must be railed and friendly: each edge costs one-quarter movement point. Stations must have rail on their city center. Connecting two or more stations grants each city two industry and two gold once, independent of loops. Three connected industrial complexes sustained for ten rounds win.",
}
mechanics[#mechanics + 1] = {
	id = "mobs",
	name = "HOSTILE SPAWNERS",
	text = "Choose Off, Standard or Dangerous in the lobby. Spawners start at least five hexes from starting capitals. After round five, Standard spawns every five rounds, Dangerous every three. Each camp supports at most three living mobs; the global cap is one per twenty map hexes. Zombies, skeletons and spiders appear first; creepers and pillagers arrive later. Mobs attack nearby targets, including villages, but only raid cities. Occupy a camp with surviving melee infantry to clear it permanently for 25 gold.",
}
mechanics[#mechanics + 1] = {
	id = "villages",
	name = "VILLAGER CITY-STATES",
	text = "Independent farmer, librarian and toolsmith villages have guards and face hostile raids. They use no player slots. Defeat a mob within three hexes to earn ten influence. Send an envoy for 25 gold to gain ten influence, once per five rounds. At 20 influence trade becomes available. The highest influence at or above 40 earns the alliance, with player ID breaking ties. Farmers grant two food, librarians two science, toolsmiths two industry to the ally's oldest city. Villages can be conquered; conquered villages become normal cities and stop giving alliance benefits.",
}
mechanics[#mechanics + 1] = {
	id = "wonders",
	name = "SPECIAL TILES AND WONDERS",
	text = "Natural landmarks are seeded map tiles that reward citizens working them. City production has a WONDER category: select a unique constructed wonder and choose a highlighted empty city-owned land hex. Finish it through ordinary industry. A competing completion ends your queue while preserving invested progress. Its benefits belong to the city controlling that tile. Wonders cannot overlap cities, other landmarks or rails.",
}
mechanics[#mechanics + 1] = {
	id = "council",
	name = "COUNCIL OF CIVILIZATIONS",
	text = "The Council forms when two civilizations have cities and one researches Currency. Sessions open every ten speed-scaled rounds, with three rounds to vote. Every civilization receives two delegates; an independent village allied at 60 influence for three rounds grants one extra delegate, capped at one. Allocations are fixed for the session. Ballots stay private until closing. A strict majority elects the leader; diplomatic victory needs two-thirds of all allocated delegates, support from another living civilization, Stock Logistics and a Council Hall. The lobby must enable this victory. Each member may propose one resolution during the opening round. Trade facilitation, embargo, peace and censure need a strict majority and last ten speed-scaled rounds. Council peace also suspends military attacks. Conversation requests can create a voluntary voting pledge: cast the actual ballot separately; honoring earns 10 trust, breaking costs 25 trust and 15 grievances for 30 rounds. Ready members may still vote. Unmet civilizations remain unnamed and cannot be contacted through the Council. Recent Results publishes ballots, AI reasons and tallies.",
}
mechanics[#mechanics + 1] = {
	id = "difficulty",
	name = "AI DIFFICULTY",
	text = "The host selects each AI difficulty in Campaign Options before starting. Settler and Chieftain use shorter planning and sometimes choose near-best options; they initiate fewer wars. Prince is the competent baseline. King and Deity search more legal tactical choices, anticipate exposure, plan cooperative follow-up attacks and consider observed future city yields. Difficulty does not grant gold, supplies, combat strength, extra moves, instant production or unexplored map knowledge. Fixed civilization personality still governs preferences. Hostile-mob difficulty is a separate setting. Existing campaigns default to Prince.",
}
mechanics[#mechanics + 1] = {
	id = "specialties",
	name = "SPECIALTY SITES AND FOCUS",
	text = "In Specialization V5, city production > SITES places Create Works (W), Ponder Campus (K) or Freight Yard (F) on owned explored land within three hexes. One completed or reserved site uses one focus slot; population 1-3 allows one, 4-6 two, 7+ three. Basics, defenses and ordinary improvements use none. Population loss keeps existing sites and queued work; only new slots wait for growth. Sites cost 30 base industry, scaled by speed. Each gives one city yield plus at most one local bonus; inspect the placement preview. Sites keep the ordinary worked tile yield but cannot share a Builder improvement or wonder. Redevelopment costs 45 base industry. The old site operates until replacement; changing role discards the old family buildings and saved family construction without refund. Moving the same role retains them. Canceling site construction forfeits invested industry, releases its reservation and retains any redevelopment source. Ponder, Tend and Trade remain available without a site. End Staging requires Nether Portal, not a Knowledge site, until the later End redesign. Hostile occupation or invalid terrain/ownership pauses output; recovery restores it. No SU or Trader routes are created by a site.",
}
local function title(id)
	return id:gsub("_", " "):upper()
end
function E.entries(category, context)
	if category == "mechanics" then
		local result = {}
		for _, entry in ipairs(mechanics) do
			if entry.id ~= "specialties" or Sites.enabled(context) then
				result[#result + 1] = entry
			end
		end
		return result
	end
	local source = category == "specialties"
			and (Sites.enabled(context) and Sites.definitions or {})
		or category == "improvements" and Works.definitions
		or category == "wonders" and Systems.wonders
		or category == "projects" and Systems.projects
		or category == "sites" and Systems.naturalWonders
		or category == "units" and Systems.units
		or category == "buildings" and Systems.buildings
		or Systems.techs
	local result = {}
	for id, record in pairs(source) do
		if ContentRules.available(record, context) then
			result[#result + 1] = { id = id, name = record.name or title(id), record = record }
		end
	end
	table.sort(result, function(a, b)
		return a.name < b.name
	end)
	return result
end
function E.describe(category, entry, player, state)
	local function terrainYieldDetails(lines)
		if
			state
			and state.world
			and state.world.terrainYieldVersion == "civ6-1"
			and entry.id == "yields"
		then
			lines[#lines + 1] =
				"Civ VI tile yields: Plains 1 food / 1 production; Grassland 2 / 0; Desert, Badlands and Snow 0 / 0; Tundra 1 / 0. Hills add 1 production; Woods add 1 production; Rainforest and Marsh add 1 food. Coast gives 1 food / 1 gold; Ocean 1 food. Resources and Builder improvements add their yields. Existing saves migrate automatically."
		end
		return lines
	end
	if player and state and state.contentRules ~= player.contentRules then
		local context = {}
		for key, value in pairs(player) do
			context[key] = value
		end
		context.contentRules = state.contentRules
		player = context
	end
	if entry.text then
		if Sites.enabled(state or player) and entry.id == "create" then
			return {
				"Advanced industry requires an active Create Works site. The V5 short chains are: Press -> Crushing/Belt Logistics; Nether Portal -> Blaze Burner -> Heated Mixer -> Deployer -> Assembly -> Crafter or Steam Plant. Mixer brass conversion and Forge workshop bonuses require an active Works. Basics such as Furnace and Smithy do not need a site. SU, fuel and machine priorities arrive in a later milestone.",
			}
		end
		if Sites.enabled(state or player) and entry.id == "production" then
			return {
				entry.text,
				"Specialty construction is in SITES. One site uses one focus slot. Placement and paid redevelopment show costs, local bonuses and losses before confirmation. Paused sites keep their hex and focus reservation; cancel explicitly to release them.",
				"Ponder Research needs basic Library, Tend Crops basic Homesteads and Trade Contract basic Trading Hall, with separate unchanged remainders. End Staging needs Nether Portal without a specialty requirement.",
			}
		end
		if ContentRules.startsWithSettler(state or player) and entry.id == "territory" then
			return {
				"You start with one Settler and one Stone Guard. No city or borders are pre-founded. Explore with either unit, move your Settler if desired, then choose FOUND CAPITAL on a legal land tile with movement remaining. Your first founded city becomes your original capital. The starting Settler is free and does not count as a trained Settler. New cities use the current population and growth rules. Later Settlers consume population when trained. "
					.. entry.text,
			}
		end
		if ContentRules.hasDevelopment(state or player) then
			if entry.id == "population" then
				return {
					entry.text,
					"Settlement Capacity starts at 4, gains 1 beside water, 2 from Homesteads, 2 from Water Services and 1 from a Trading Hall. Positive growth food is 100% at least two citizens below capacity, 50% one below, 25% at capacity or one above, and 12.5% two or more above. Minimum growth time increases by the same factor. Food consumption and starvation remain unchanged. Completing a Settler consumes one citizen after growth resolves; a city needs at least two citizens.",
				}
			elseif entry.id == "yields" then
				return terrainYieldDetails({
					entry.text,
					"Development V2: Settlement Capacity scales positive growth food and the minimum growth time. The city inspector shows the effective food gain and forecast. Food consumption and starvation are unchanged. See POPULATION AND JOBS for the capacity curve.",
				})
			elseif entry.id == "production" then
				return {
					"Scouts cost 15 industry; Guards cost 20. Settlers start at 28 industry, adding 8 for each previously completed Settler. Completion consumes one citizen and requires at least two population. Growth and starvation resolve before recruitment. A queued Settler waits without new progress below two population; blocked placement spends no citizen. Switching retains construction progress. Civilian projects convert industry to research, food or gold each round. Homesteads and Water Services increase Settlement Capacity without creating food or citizens.",
				}
			end
		end
		if ContentRules.isRedesign(state or player) then
			if entry.id == "turns" then
				return {
					"Redesign V1: Conquest captures every rival capital. End Expedition completes the existing Eyes, Equipment and Dragon projects until its later redesign. Score always resolves the deadline at round "
						.. ((state or {}).roundLimit or CampaignRules.rounds(player))
						.. ". Industrial and Diplomatic victories are retired. Simultaneous qualifiers share victory.",
				}
			elseif entry.id == "health" or entry.id == "combat" then
				local retained = entry.id == "health" and entry.text:match("^(.-) FORTIFY / HEAL")
					or entry.text:match("^(.-) Resting or fortifying")
				return {
					retained or "Units have 100 HP.",
					"Rest without moving, attacking or spending an action: recover 20 HP on owned land, 15 with active Open Borders, 10 on neutral or other peaceful land, and 5 on enemy land. One adjacent owned healer adds 10 HP; additional healers do not stack and a healer does not support itself. Acting prevents all recovery, even after FORTIFY / HEAL. Health is capped at 100. A valid new order wakes a sleeping unit.",
				}
			elseif entry.id == "council" then
				return {
					"Council leadership and resolutions remain available for trade, embargoes, peace and censure. Elections never award victory in Redesign V1 and do not require a Council Hall. Ballots, pledges, trust and village delegates retain their normal rules.",
				}
			elseif entry.id == "rails" then
				return {
					"Rails retain their movement and connected-city production benefits. An engineer pays two iron and remaining movement to build rail. Linked stations grant industry and gold; connected industry supports your economy and does not award a separate victory.",
				}
			end
		end
		if entry.id == "production" and player and ContentRules.usesP1Economy(player) then
			return {
				entry.text
					:gsub("UNITS or BUILDS", "UNITS, BUILDS, WONDER or PROJECTS")
					:gsub("Scouts cost five industry%.", "Scouts cost fifteen industry.")
					:gsub(
						"Settlers start at twelve industry and cost five more",
						"Settlers start at forty industry and cost twelve more"
					),
				"Civilian projects use industry each round instead of construction. Ponder Research converts 4:1 to current research; Tend Crops and Trade Contract convert 2:1 to city food and gold. Each project retains only its own conversion remainder. Ponder pauses without unfinished research.",
			}
		end
		return terrainYieldDetails({ entry.text })
	end
	local record = entry.record
	local lines = {}
	if category == "specialties" then
		return {
			"One focus slot. 30 base industry, scaled by speed; +1 "
				.. record.output
				.. " plus at most one local bonus.",
			dofile("/games/civcraft/specialty_view.lua").bonuses[entry.id],
			"Owned explored land within three hexes, excluding improvements, wonders and other sites. No citizen needed for site output; the tile remains workable.",
			"Redevelopment costs 45 base industry. Role changes discard family buildings/progress; same-role moves retain them. See SPECIALTY SITES AND FOCUS in HELP.",
		}
	end
	if category == "improvements" then
		local placement = entry.id == "farm" and "Fertile open flat land"
			or entry.id == "quarry" and "Clear hill or stone deposit"
			or "Woods or jungle; feature retained"
		return {
			"Builder charge cost: 1; spends remaining movement.",
			placement,
			"Worked tile: +"
				.. record.food
				.. " food / +"
				.. record.industry
				.. " industry. Oak fields and Iron quarries add one matching yield.",
			"Requires "
				.. Systems.techs[record.tech].name
				.. ". Owned land outside city centers and landmarks. Tile ownership transfers benefits. No yield without a worker.",
		}
	end
	if category == "projects" then
		return {
			record.description,
			"Requires " .. Systems.label("building", Projects.building(player, entry.id)),
			"Runs until changed. Conversion remainders are retained separately for each project. Uses this city's industry instead of construction.",
		}
	end
	if category == "sites" then
		return {
			record.description,
			"Natural landmark: work the tile with a citizen to collect its bonus.",
		}
	end
	if category == "wonders" then
		return {
			"Industry cost: " .. Systems.projectCost("wonder", entry.id, player),
			record.description,
			"Research: " .. Systems.techs[record.tech].name,
			"Unique across the world. Choose an owned land hex outside a city center. Completion replaces any tile improvement. Benefits follow tile ownership. Capturing a wonder transfers its benefits.",
		}
	end
	if category == "units" then
		if record.hostile then
			return {
				record.ability,
				"Movement "
					.. record.move
					.. " / attack "
					.. record.strength
					.. " / defense "
					.. record.defense
					.. " / range "
					.. record.range,
				"Spawns in the wilderness. Cannot own cities or be recruited.",
			}
		end
		lines = {
			"Industry cost: " .. Systems.projectCost("unit", entry.id, player),
			"Attack " .. (10 + record.strength * 5) .. " / defense " .. (10 + record.defense * 5),
			"HP 100 / upkeep " .. (record.upkeep or 1) .. " gold per round",
			"Movement "
				.. record.move
				.. " / vision "
				.. record.vision
				.. " / range "
				.. record.range,
			record.naval and "Domain: water" or "Domain: land",
			ContentRules.ability(record, state or player) or "",
		}
	elseif category == "buildings" then
		lines = {
			"Industry cost: " .. Systems.projectCost("building", entry.id, player),
			record.description or "",
			"One of this building per city.",
		}
		if ContentRules.hasDevelopment(state or player) and (record.capacity or 0) > 0 then
			lines[#lines + 1] = "Settlement Capacity +"
				.. record.capacity
				.. "; no automatic citizens."
		end
		if entry.id == "councilhall" and ContentRules.isRedesign(state or player) then
			lines[2] =
				"Retired in Redesign V1. Council leadership and resolutions do not require this building. Original and P1 campaigns retain its diplomatic-victory role."
		end
		if entry.id == "farm" and player and ContentRules.usesP1Economy(player) then
			lines[2] = (player.techs or {}).agriculture and "+2 food"
				or "+1 food until Wheat Farming"
			lines[#lines + 1] = "Available immediately: +1 food. Wheat Farming adds a second food."
		end
	else
		lines = {
			"Science cost: " .. Systems.techCost(entry.id, player),
			(entry.id == "agriculture" and player and ContentRules.usesP1Economy(player))
					and "Improves: Wheat Farm +1 food"
				or ("Unlock: " .. title(record.unlock or "none")),
		}
		for _, paragraph in ipairs(ResearchDetails.paragraphs(Systems, entry.id, player)) do
			lines[#lines + 1] = paragraph
		end
		local needs = {}
		for _, id in ipairs(record.requires or {}) do
			needs[#needs + 1] = (Systems.techs[id] or {}).name or title(id)
		end
		lines[#lines + 1] = "Prerequisites: "
			.. (#needs > 0 and table.concat(needs, ", ") or "none")
	end
	if category == "units" and entry.id == "settler" then
		local base, step = ContentRules.unitCost("settler", record, player)
		lines[#lines + 1] = "Starts at "
			.. base
			.. " industry; +"
			.. step
			.. " for each Settler trained by your empire, including those later lost or settled. Game speed scales these costs."
		if ContentRules.hasDevelopment(state or player) then
			lines[#lines + 1] =
				"Requires at least two population. Completion consumes one citizen after growth resolves; blocked placement consumes none."
		end
	end
	if record.age then
		lines[#lines + 1] = "Age: " .. Systems.ages[record.age].name
	end
	if category == "buildings" and Sites.enabled(state or player) then
		local family = Sites.families[entry.id]
		lines[#lines + 1] = family
				and ("Requires active " .. Sites.definitions[family].name .. "; no extra focus slot.")
			or "Basic or End building: no specialty slot."
		if entry.id == "observatory" then
			lines[#lines + 1] =
				"Temporary End bridge: Nether Portal only; no Enchanting Room or specialty required."
		end
	end
	for _, need in
		ipairs(category == "buildings" and Sites.prerequisites(state or player, entry.id) or {})
	do
		lines[#lines + 1] = "Required building: " .. Systems.label("building", need)
	end
	if
		record.tech
		and not (
			category == "buildings"
			and entry.id == "farm"
			and player
			and ContentRules.usesP1Economy(player)
		)
	then
		lines[#lines + 1] = "Research: " .. Systems.techs[record.tech].name
	end
	if record.resource then
		lines[#lines + 1] = "Needs two " .. title(record.resource) .. " stock on completion"
	end
	if record.building then
		lines[#lines + 1] = "Required city building: " .. title(record.building)
	end
	if record.coastal then
		lines[#lines + 1] = "Coastal cities only"
	end
	if record.unique then
		lines[#lines + 1] = "Civilization: " .. Systems.civ(record.unique).name
	end
	return lines
end
function E.draw(ui, rect)
	local player
	for _, p in ipairs(ui.state.players or {}) do
		if p.id == ui.playerID then
			player = p
			break
		end
	end
	local r = ui.r
	local model = ui.codex or { category = "units" }
	ui.codex = model
	local x, y, w, h = rect.x, rect.y, rect.w, rect.h
	r:fill(x, y, w, h, 1)
	r:outline(x, y, w, h, 8)
	r:text(x + 4, y + 3, "ENCYCLOPEDIA", 8, 1, w - 46)
	r:button(x + w - 37, y + 1, 35, 11, "CLOSE", function()
		ui.panel = "context"
	end)
	local categories = { "units", "buildings", "techs", "wonders", "sites", "mechanics" }
	local labels = { "UNITS", "BUILDS", "TECH", "WONDER", "SITES", "HELP" }
	local width = math.floor((w - 14) / 6)
	for i, category in ipairs(categories) do
		r:button(x + 2 + (i - 1) * (width + 2), y + 13, width, 11, labels[i], function()
			model.category = category
			model.entry = nil
			model.offset = 0
		end, { selected = model.category == category })
	end
	if ContentRules.hasBuilders(ui.state) then
		r:button(
			x + math.floor(w / 2) + 1,
			y + 24,
			math.floor((w - 6) / 2),
			10,
			"TILE WORK",
			function()
				model.category = "improvements"
				model.entry = nil
				model.offset = 0
			end,
			{ selected = model.category == "improvements" }
		)
	end
	local projectRow = ContentRules.usesP1Economy(ui.state) and 11 or 0
	if projectRow > 0 then
		local projectsWidth = ContentRules.hasBuilders(ui.state) and math.floor((w - 6) / 2)
			or w - 4
		r:button(x + 2, y + 24, projectsWidth, 10, "PROJECTS", function()
			model.category = "projects"
			model.entry = nil
			model.offset = 0
		end, { selected = model.category == "projects" })
	end
	local body = { x = x + 3, y = y + 24 + projectRow, w = w - 6, h = h - 26 - projectRow }
	local rows = {}
	if model.entry then
		rows[#rows + 1] = {
			buttons = {
				{
					label = "BACK TO LIST",
					run = function()
						model.entry = nil
						model.offset = 0
					end,
				},
			},
		}
		for _, line in ipairs(Panels.wrap(r, model.entry.name, body.w - 4)) do
			rows[#rows + 1] = { text = line, color = 8 }
		end
		for _, paragraph in ipairs(E.describe(model.category, model.entry, player, ui.state)) do
			for _, line in ipairs(Panels.wrap(r, paragraph, body.w - 4)) do
				rows[#rows + 1] = { text = line }
			end
		end
	else
		for _, entry in ipairs(E.entries(model.category, ui.state)) do
			rows[#rows + 1] = {
				buttons = {
					{
						label = entry.name,
						run = function()
							model.entry = entry
							model.offset = 0
						end,
					},
				},
			}
		end
	end
	Panels.rows(r, body, rows, model)
end
return E
