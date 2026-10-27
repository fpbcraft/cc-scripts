local Rules = dofile("/games/civcraft/content_rules.lua")
local Projects = {
	definitions = {
		ponder = {
			name = "PONDER RESEARCH",
			building = "library",
			divisor = 4,
			output = "science",
			description = "Every 4 industry supplies 1 science to the selected unfinished technology. Pauses without research.",
		},
		tend = {
			name = "TEND CROPS",
			building = "farm",
			divisor = 2,
			output = "food",
			description = "Every 2 industry adds 1 food to this city's food store.",
		},
		trade = {
			name = "TRADE CONTRACT",
			building = "market",
			divisor = 2,
			output = "gold",
			description = "Every 2 industry supplies 1 gold.",
		},
	},
}
function Projects.available(player, city, id)
	local record = Projects.definitions[id]
	return Rules.usesP1Economy(player)
		and record ~= nil
		and (city.buildings or {})[record.building] == true
end
function Projects.preview(player, city, industry, systems, id)
	local result = { food = 0, science = 0, gold = 0, active = false }
	local project = id and { kind = "project", id = id } or city.project
	if
		not project
		or project.kind ~= "project"
		or not Projects.available(player, city, project.id)
	then
		return result
	end
	local record = Projects.definitions[project.id]
	if
		project.id == "ponder"
		and (not player.researchTarget or not systems.canResearch(player, player.researchTarget))
	then
		return result
	end
	local remainder = (city.projectRemainders or {})[project.id] or 0
	local total = math.max(0, math.floor(industry)) + remainder
	result[record.output] = math.floor(total / record.divisor)
	result.remainder, result.active = total % record.divisor, true
	return result
end
function Projects.commit(city, output)
	if output.active then
		city.projectRemainders = city.projectRemainders or {}
		city.projectRemainders[city.project.id] = output.remainder
	end
end
return Projects
