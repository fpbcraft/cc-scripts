-- One current V5 ruleset. Historical IDs are accepted only as migration inputs.
local Rules = { current = "balance5", default = "balance5" }
local savedIDs = {
	baseline = true,
	p1 = true,
	balance1 = true,
	balance2 = true,
	balance3 = true,
	balance4 = true,
	balance5 = true,
}
function Rules.migrateId(id)
	if id == nil or savedIDs[id] then
		return Rules.current
	end
	return nil, "Unsupported saved ruleset: " .. tostring(id)
end
function Rules.isRedesign()
	return true
end
function Rules.hasDevelopment()
	return true
end
function Rules.hasBuilders()
	return true
end
function Rules.startsWithSettler()
	return true
end
function Rules.hasSpecialties()
	return true
end
function Rules.available(record)
	return not record.retiredByBuilders
end
function Rules.usesP1Economy()
	return true
end
function Rules.label()
	return "SPECIALIZATION V5"
end
function Rules.ability(record)
	if record.healer then
		return "Adjacent owned resting allies recover +10 HP; no self-support or stacking. Acting allies do not recover."
	end
	return record.ability
end
function Rules.validate(id)
	assert(id == Rules.current, "Only the current ruleset is supported")
end
function Rules.unitCost(id, record)
	if id == "scout" then
		return 15, 0
	end
	if id == "warrior" then
		return 20, 0
	end
	if id == "settler" then
		return 28, 8
	end
	return record.production or math.ceil((record.wood or 8) * 2.5), record.productionStep or 0
end
return Rules
