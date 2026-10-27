local Content = dofile("/games/civcraft/content.lua")
local Summary = {}
local labels =
	{ cityStrike = "CITY STRIKE", found = "CITY FOUNDED", research = "RESEARCH COMPLETED" }
local orders = {
	researchTech = "Research selected",
	queue = "Production selected",
	workTile = "Worked tile changed",
	assign = "Citizens reassigned",
	standby = "Unit sleep order",
	autoExplore = "Exploration order",
	skipTurn = "Unit skipped this turn",
	heal = "Fortify/heal order",
	envoy = "Envoy sent",
	["end"] = "Turn ended",
}
function Summary.text(event)
	local actor, result = event.actor or event.defender, event.result or {}
	local unit = actor and Content.units[actor.kind]
	local name = actor and (actor.name or unit and unit.name or actor.kind) or ""
	local label = result.capturedSettler and "SETTLER CAPTURE"
		or result.captured and "CITY CAPTURE"
		or labels[event.type]
		or event.type:upper()
	local content = event.content
	if event.type == "order" then
		content = orders[content] or content
	end
	local entry = event.type == "research" and Content.techs[content]
	if entry then
		content = entry.name
	end
	local point = event.target
		or event.start
		or event.paths and event.paths[1] and event.paths[1][1]
	if event.type == "move" and point then
		local path = event.paths[#event.paths]
		local last = path[#path]
		return label
			.. " "
			.. name
			.. " @ "
			.. point.x
			.. ","
			.. point.y
			.. " TO "
			.. last.x
			.. ","
			.. last.y
	end
	return label
		.. " "
		.. name
		.. (content and " " .. content or "")
		.. (point and " @ " .. point.x .. "," .. point.y or "")
end
function Summary.compact(event)
	return { seq = event.seq, round = event.round, text = Summary.text(event):sub(1, 320) }
end
return Summary
