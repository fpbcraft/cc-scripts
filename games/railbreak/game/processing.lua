local S = require("games.railbreak.game.state")
local K = require("games.railbreak.game.kinetics")
local C = require("games.railbreak.content.catalog")
local U = require("games.railbreak.core.util")
local P = {}
local function target(x, y, t)
	local d = C.dirs[t.face]
	return x + d[1], y + d[2]
end
local function accepts(t, item)
	if t.id == "chest" then
		return true
	end
	if t.id == "belt" then
		return t.item == nil
	end
	local recipe = C.recipes[t.id]
	return recipe and recipe.input[item] and (t.slot[item] or 0) < recipe.input[item] * 3
end
local function push(t, item, amount)
	if t.id == "belt" then
		t.item = { id = item, n = amount }
	else
		t.slot[item] = (t.slot[item] or 0) + amount
	end
end
function P.advanceClock(g, events)
	g.shift = g.shift + 1
	g.contractAge = g.contractAge + 1
	local contract = C.contracts[g.currentContract]
	if contract and g.contractStatus == "OPEN" and g.contractAge > g.contractLimit then
		g.reputation = math.max(-10, g.reputation - 1)
		g.contractStatus = "MISSED"
		S.log(g, "Late contract: " .. contract.title .. " (-1 reputation)")
		events[#events + 1] = "CONTRACT DEADLINE MISSED"
	end
end
function P.shift(g)
	if g.finished then
		return nil, "The expedition is finished"
	end
	local k = K.analyze(g)
	local events = {}
	local before = U.copy(g.warehouse)
	-- 1. Move loaded conveyor packets to another belt, compatible machine or collecting chest.
	-- Snapshot makes each packet advance at most one tile per shift.
	local moves = {}
	local reserved = {}
	for y = 1, S.H do
		for x = 1, S.W do
			local t = S.get(g, x, y)
			if t.id == "belt" and t.item then
				local nx, ny = target(x, y, t)
				local destination = S.get(g, nx, ny)
				local packet = t.item
				local key = U.key(nx, ny)
				if destination and accepts(destination, packet.id) and not reserved[key] then
					reserved[key] = true
					moves[#moves + 1] = { from = t, to = destination, packet = packet }
				end
			end
		end
	end
	for _, move in ipairs(moves) do
		if move.to.id == "chest" then
			U.add(g.warehouse, { [move.packet.id] = move.packet.n })
		else
			push(move.to, move.packet.id, move.packet.n)
		end
		move.from.item = nil
	end
	-- 2. Machine products leave via the facing output side, when unblocked.
	for y = 1, S.H do
		for x = 1, S.W do
			local t = S.get(g, x, y)
			local recipe = C.recipes[t.id]
			if recipe then
				for item, amount in pairs(t.output) do
					if amount > 0 then
						local nx, ny = target(x, y, t)
						local out = S.get(g, nx, ny)
						if out and accepts(out, item) then
							push(out, item, amount)
							t.output[item] = nil
							-- Ordinary product delivery is not an interruption for batched shifts.
						end
					end
				end
			end
		end
	end
	-- 3. Input depots load packets into an outward-facing conveyor, if available.
	for y = 1, S.H do
		for x = 1, S.W do
			local t = S.get(g, x, y)
			if t.id == "depot" then
				local nx, ny = target(x, y, t)
				local out = S.get(g, nx, ny)
				local item = t.filter
				if
					out
					and out.id == "belt"
					and out.face == t.face
					and not out.item
					and (g.warehouse[item] or 0) > 0
				then
					g.warehouse[item] = g.warehouse[item] - 1
					out.item = { id = item, n = 1 }
				end
			end
		end
	end
	-- 4. Machines process their own input buffer; no processing without rotation.
	local made = 0
	for y = 1, S.H do
		for x = 1, S.W do
			local t = S.get(g, x, y)
			local recipe = C.recipes[t.id]
			if recipe then
				local info = k.connections[U.key(x, y)]
				if info and info.powered then
					local can = true
					for item, amount in pairs(recipe.input) do
						if (t.slot[item] or 0) < amount then
							can = false
						end
					end
					if can then
						-- Hold output in a buffer until the downstream belt/storage can receive it.
						local outputBusy = false
						for _, n in pairs(t.output) do
							if n > 0 then
								outputBusy = true
							end
						end
						if not outputBusy then
							t.work = t.work + info.rpm / 16
							if t.work >= recipe.work then
								for item, amount in pairs(recipe.input) do
									t.slot[item] = t.slot[item] - amount
								end
								U.add(t.output, recipe.output)
								t.work = t.work - recipe.work
								made = made + 1
								g.totalManufactured = g.totalManufactured + 1
							end
						end
					else
						t.work = 0
					end
				end
			end
		end
	end
	-- 5. Running steam generators use one coal per shift, with a deterministic fuel cutoff.
	for _, network in ipairs(k.networks) do
		if network.active then
			for _ = 1, #network.engines do
				if g.warehouse.coal > 0 then
					g.warehouse.coal = g.warehouse.coal - 1
				end
			end
		end
	end
	P.advanceClock(g, events)
	if k.overstressed then
		events[#events + 1] = "KINETIC NETWORK OVERSTRESSED"
	end
	local delta = {}
	for _, res in ipairs(C.resources) do
		local diff = g.warehouse[res] - before[res]
		if diff ~= 0 then
			delta[res] = diff
		end
	end
	g.production =
		{ crafted = made, delta = delta, events = events, capacity = k.capacity, load = k.load }
	if made > 0 then
		S.log(g, "Manufactured " .. made .. " batch(es).")
	end
	return g.production
end
return P
