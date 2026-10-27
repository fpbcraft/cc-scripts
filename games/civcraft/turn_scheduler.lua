-- Only active war components are sequential; peaceful civilizations are independent.
local Scheduler = {}
local function player(state, id)
	for _, candidate in ipairs(state.players or {}) do
		if candidate.id == id then
			return candidate
		end
	end
end

function Scheduler.new()
	return { version = 1, groups = {}, reactions = {}, reactionGranted = {} }
end

function Scheduler.group(state, id)
	for _, group in ipairs(state.scheduler and state.scheduler.groups or {}) do
		for _, member in ipairs(group.order) do
			if member == id then
				return group
			end
		end
	end
end

function Scheduler.canAct(state, id)
	local participant = player(state, id)
	if not participant then
		return false, "You are not registered"
	end
	local schedule = state.scheduler
	if participant.ready and not (schedule and schedule.reactions[id]) then
		return false, "Already ended turn"
	end
	local group = Scheduler.group(state, id)
	if group and group.active ~= id then
		return false, "Waiting for your war group turn"
	end
	return true
end

local function advance(state, group)
	group.active = nil
	for _, id in ipairs(group.order) do
		local participant = player(state, id)
		if participant and (not participant.ready or state.scheduler.reactions[id]) then
			group.active = id
			break
		end
	end
end

function Scheduler.rebuild(state, wars, first, defender)
	state.scheduler = state.scheduler or Scheduler.new()
	local schedule = state.scheduler
	assert(schedule.version == 1, "Unsupported turn scheduler version")
	local adjacency = {}
	for _, participant in ipairs(state.players) do
		adjacency[participant.id] = {}
	end
	for _, war in ipairs(wars or {}) do
		if adjacency[war.a] and adjacency[war.b] and war.active then
			adjacency[war.a][#adjacency[war.a] + 1] = war.b
			adjacency[war.b][#adjacency[war.b] + 1] = war.a
		end
	end
	local visited, groups = {}, {}
	for _, participant in ipairs(state.players) do
		local id = participant.id
		if not visited[id] then
			local members, queue = {}, { id }
			visited[id] = true
			local head = 1
			while head <= #queue do
				local current = queue[head]
				head = head + 1
				members[current] = true
				for _, neighbor in ipairs(adjacency[current]) do
					if not visited[neighbor] then
						visited[neighbor] = true
						queue[#queue + 1] = neighbor
					end
				end
			end
			if #queue > 1 then
				local group = { order = {} }
				if first and members[first] then
					group.order[1] = first
					local target = player(state, defender)
					if
						target
						and members[defender]
						and target.ready
						and schedule.reactionGranted[defender] ~= state.round
					then
						schedule.reactions[defender] = true
						schedule.reactionGranted[defender] = state.round
					end
				end
				local ordered = {}
				for _, member in ipairs(state.players) do
					if members[member.id] then
						ordered[#ordered + 1] = member.id
					end
				end
				local rotation = ((state.round or 1) - 1) % #ordered
				for index = 1, #ordered do
					local member = ordered[(index + rotation - 1) % #ordered + 1]
					if members[member] and member ~= group.order[1] then
						group.order[#group.order + 1] = member
					end
				end
				-- An unrelated war component keeps its active participant mid-round.
				if not (first and members[first]) then
					local old = Scheduler.group(state, id)
					if old and old.active and members[old.active] then
						for index, member in ipairs(group.order) do
							if member == old.active then
								table.remove(group.order, index)
								table.insert(group.order, 1, member)
								break
							end
						end
					end
				end
				advance(state, group)
				groups[#groups + 1] = group
			end
		end
	end
	schedule.groups = groups
end

function Scheduler.beginRound(state, wars)
	state.scheduler = Scheduler.new()
	Scheduler.rebuild(state, wars)
end

function Scheduler.finish(state, id)
	local allowed, reason = Scheduler.canAct(state, id)
	if not allowed then
		return false, reason
	end
	local participant = player(state, id)
	participant.ready = true
	if state.scheduler then
		state.scheduler.reactions[id] = nil
	end
	local group = Scheduler.group(state, id)
	if group then
		advance(state, group)
	end
	return true
end

function Scheduler.complete(state)
	for _, participant in ipairs(state.players) do
		if
			not participant.ready
			or state.scheduler and state.scheduler.reactions[participant.id]
		then
			return false
		end
	end
	return true
end

function Scheduler.public(state)
	if not state.scheduler then
		return nil
	end
	local result = Scheduler.new()
	for _, group in ipairs(state.scheduler.groups) do
		local copy = { active = group.active, order = {} }
		for _, id in ipairs(group.order) do
			copy.order[#copy.order + 1] = id
		end
		result.groups[#result.groups + 1] = copy
	end
	for id, active in pairs(state.scheduler.reactions) do
		result.reactions[id] = active
	end
	return result
end

return Scheduler
