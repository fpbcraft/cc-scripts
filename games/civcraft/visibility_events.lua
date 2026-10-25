--[[
	Project action-time observations before retaining or transmitting events.
	Neither later exploration nor a final snapshot may reconstruct hidden paths.
]]
local VisibilityEvents = {}

function VisibilityEvents.actor(entity)
	if not entity then
		return nil
	end
	return {
		id = entity.id,
		name = type(entity.name) == "string" and entity.name or nil,
		owner = entity.owner,
		kind = type(entity.kind) == "string" and entity.kind or "city",
		hp = entity.hp,
		level = entity.level,
	}
end

function VisibilityEvents.frame(state, entity)
	local visible = {}
	for _, player in ipairs(state.players or {}) do
		if player.id == entity.owner or (player.visible or {})[entity.x .. ":" .. entity.y] then
			visible[player.id] = true
		end
	end
	return { x = entity.x, y = entity.y, visible = visible }
end

local function point(frame)
	return { x = frame.x, y = frame.y }
end

local function projectMove(event, observer)
	local paths = {}
	local current
	for _, frame in ipairs(event.frames or {}) do
		if frame.visible[observer] then
			if not current then
				current = {}
				paths[#paths + 1] = current
			end
			current[#current + 1] = point(frame)
		else
			current = nil
		end
	end
	if #paths == 0 then
		return nil
	end
	return {
		type = "move",
		actor = VisibilityEvents.actor(event.actor),
		paths = paths,
		ownAutoExplore = event.autoExplore == true and event.actor.owner == observer or nil,
	}
end

local function projectCombat(event, observer)
	local seesActor = event.start.visible[observer] == true
	local seesTarget = event.target.visible[observer] == true
	if not seesActor and not seesTarget then
		return nil
	end
	local result = event.result
	if seesActor and seesTarget then
		return {
			type = event.type,
			actor = VisibilityEvents.actor(event.actor),
			start = point(event.start),
			target = point(event.target),
			defender = VisibilityEvents.actor(event.defender),
			result = {
				attackerHP = result.attackerHP,
				defenderHP = result.defenderHP,
				cityHP = result.cityHP,
				wallHP = result.wallHP,
				ranged = result.ranged,
				captured = result.captured,
				capturedSettler = result.capturedSettler,
				attackerDied = result.attackerDied,
				defenderDied = result.defenderDied,
			},
		}
	end
	if seesTarget then
		return {
			type = "impact",
			target = point(event.target),
			defender = VisibilityEvents.actor(event.defender),
			result = {
				defenderHP = result.defenderHP,
				cityHP = result.cityHP,
				wallHP = result.wallHP,
				defenderDied = result.defenderDied,
				captured = result.captured,
				capturedSettler = result.capturedSettler,
			},
		}
	end
	return {
		type = "activity",
		actor = VisibilityEvents.actor(event.actor),
		start = point(event.start),
		result = { attackerHP = result.attackerHP, attackerDied = result.attackerDied },
	}
end

local notices = {
	contact = true,
	found = true,
	disband = true,
	rail = true,
	spawn = true,
	building = true,
	wonder = true,
	landmark = true,
	research = true,
	order = true,
}

function VisibilityEvents.project(event, observer)
	if event.type == "move" then
		return projectMove(event, observer)
	end
	if event.type == "combat" or event.type == "cityStrike" then
		return projectCombat(event, observer)
	end
	if not notices[event.type] then
		return nil
	end
	if (event.type == "research" or event.type == "order") and not event.recipient then
		return nil
	end
	if event.recipient then
		if event.recipient ~= observer then
			return nil
		end
	elseif not event.target or not event.target.visible[observer] then
		return nil
	end
	return {
		type = event.type,
		actor = VisibilityEvents.actor(event.actor),
		target = event.target and point(event.target),
		content = type(event.content) == "string" and event.content or nil,
	}
end

return VisibilityEvents
