-- One current V5 ruleset. Historical IDs are accepted only as migration inputs.
local Rules = {
	baseline = "baseline",
	current = "p1",
	redesign = "balance1",
	development = "balance2",
	landwork = "balance3",
	opening = "balance4",
	specialization = "balance5",
	default = "balance5",
}
function Rules.migrateId(id)
	if id == nil or id == Rules.baseline or id == Rules.current or id == Rules.redesign
		or id == Rules.development or id == Rules.landwork or id == Rules.opening
		or id == Rules.specialization
	then
		return Rules.specialization
	end
	return nil, "Unsupported content economy: " .. tostring(id)
end
function Rules.isP1()
	return true
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
function Rules.available(record, context)
	if record.tileDevelopment and not Rules.hasBuilders(context) then
		return false
	end
	if record.retiredByBuilders and Rules.hasBuilders(context) then
		return false
	end
	return not record.development or Rules.hasDevelopment(context)
end
function Rules.usesP1Economy(context)
	return true
end
function Rules.label(context)
	return "SPECIALIZATION V5"
end
function Rules.ability(record, context)
	if record.healer then
		return "Adjacent owned resting allies recover +10 HP; no self-support or stacking. Acting allies do not recover."
	end
	return record.ability
end
function Rules.validate(id)
	local migrated, reason = Rules.migrateId(id)
	assert(migrated, reason)
end
function Rules.unitCost(id, record, player)
	local base, step =
		record.production or math.ceil((record.wood or 8) * 2.5), record.productionStep or 0
	if Rules.usesP1Economy(player) then
		if id == "scout" then
			base = 15
		end
		if id == "warrior" then
			base = 20
		end
		if id == "settler" then
			base, step =
				Rules.hasDevelopment(player) and 28 or 40, Rules.hasDevelopment(player) and 8 or 12
		end
	end
	return base, step
end
return Rules
