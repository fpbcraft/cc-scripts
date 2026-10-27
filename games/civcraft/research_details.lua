local ContentRules = dofile("/games/civcraft/content_rules.lua")
local Details = {}
local purposes = {
	agriculture = "Secure a food surplus so cities can grow and staff more worked tiles.",
	mining = "Develop industry to finish buildings and train units sooner.",
	sailing = "Establish coastal production and begin exploring water routes.",
	archery = "Add ranged fire to support melee units without occupying the enemy hex.",
	crafting = "Build the basic workshops that support a growing settlement economy.",
	husbandry = "Improve food production and open the route to mounted units.",
	bronze = "Begin using claimed iron deposits and replace basic equipment with metal tools.",
	writing = "Invest in science to reach later technology branches sooner.",
	masonry = "Protect important cities with walls before committing to distant expansion.",
	horseback = "Use mobile mounted troops to cross open ground and reinforce threatened positions.",
	navigation = "Explore beyond the starting coast and enable land units to embark.",
	currency = "Build a trading economy and exchange gold for researched strategic materials.",
	metallurgy = "Strengthen metalworking and field an improved infantry force.",
	cartography = "Extend exploration and find promising settlement sites and distant civilizations.",
	deepmining = "Reach deeper deposits and expand the material supply for advanced equipment.",
	diamondworking = "Turn diamond access into stronger equipment and prepare for enchanting and portals.",
	redstone = "Develop circuit-based industry and prepare the engineering and brass branches.",
	philosophy = "Improve scientific development through enchanting and prepare later Ponder research.",
	nether = "Connect the Nether branch to potion brewing and heated industrial mixing.",
	brewing = "Field potion support and prepare the supplies needed for End exploration.",
	tactics = "Improve ranged troops with crossbows to support a more capable field army.",
	engineering = "Begin Create machinery, build infrastructure and support attacks on defended cities.",
	waterpower = "Power early machinery with water wheels and prepare mechanical pressing.",
	windpower = "Develop another source of mechanical power for city industry.",
	pressing = "Expand mechanical production and open crushing, transport and heated mixing.",
	crushing = "Invest in heavier processing machinery to increase industrial capacity.",
	belts = "Improve material transport and prepare precision assembly and railway connections.",
	fortification = "Reinforce important cities and recruit golems for defense.",
	shipbuilding = "Upgrade the fleet with mechanical patrol boats before later naval weapons.",
	heatedmixing = "Use blaze heat for mixing and prepare brassworking and steam power.",
	brassworking = "Convert copper and zinc into brass using a functioning heated mixer.",
	deployers = "Automate workshop tasks and open the path to precision mechanisms.",
	precision = "Build precision industry and prepare steam, mechanical crafting and Ponder research.",
	mechanicalcrafting = "Scale up machinery and siege equipment for advanced industry and warfare.",
	commerce = "Develop stock logistics and prepare the trading side of train schedules.",
	education = "Accelerate research with Ponder and prepare the scientific route to the End.",
	shipcannons = "Add dispenser weapons to naval forces for stronger coastal operations.",
	steampower = "Power late industry and unlock the routes to railways and steam fleets.",
	railways = "Connect cities with railway infrastructure; stations benefit from completed links.",
	logistics = "Develop freight and support infrastructure along the rail network.",
	economics = "Build industrial complexes as part of an Industrial victory economy.",
	astronomy = "Establish the staging and expedition forces needed to prepare for the End.",
	netherite = "Field late-game heavy infantry and complete a prerequisite for the End Expedition.",
	enlightenment = "Unlock the three ordered End projects that culminate in an expedition victory.",
	navalwarfare = "Field steam flagships for late-game naval operations.",
}

function Details.unlocks(systems, id)
	local entries = {}
	for _, category in ipairs({ "buildings", "units", "wonders" }) do
		local keys = {}
		for key, record in pairs(systems[category] or {}) do
			if record.tech == id and not record.hostile then
				keys[#keys + 1] = key
			end
		end
		table.sort(keys)
		for _, key in ipairs(keys) do
			entries[#entries + 1] =
				{ category = category, id = key, record = systems[category][key] }
		end
	end
	return entries
end

function Details.paragraphs(systems, id, player)
	local tech = systems.techs[id]
	local paragraphs =
		{ purposes[id] or "Expand the technologies and projects available to your civilization." }
	if id == "economics" and ContentRules.isRedesign(player) then
		paragraphs[1] =
			"Develop Industrial Complexes to support productive cities and your remaining victory races."
	end
	if id == "agriculture" and player and ContentRules.usesP1Economy(player) then
		paragraphs[#paragraphs + 1] =
			"IMPROVES: Wheat Farms from +1 to +2 food. Farms are already available."
	else
		paragraphs[#paragraphs + 1] = "UNLOCKS: " .. tech.unlock .. "."
	end
	for _, entry in ipairs(Details.unlocks(systems, id)) do
		local record = entry.record
		if not (ContentRules.isRedesign(player) and entry.id == "councilhall") then
			local benefit = record.description or record.ability or ""
			if entry.category == "units" then
				benefit = record.description or ContentRules.ability(record, player) or ""
				benefit = benefit
					.. " Movement "
					.. record.move
					.. "; range "
					.. record.range
					.. "."
			end
			paragraphs[#paragraphs + 1] = record.name .. ": " .. benefit
		end
	end
	return paragraphs
end

return Details
