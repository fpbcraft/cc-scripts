-- Exhaustive bounded ballot audit using the actual election and victory modules.
local Council = dofile("/games/civcraft/council.lua")
local Systems = dofile("/games/civcraft/systems.lua")
local Actions = dofile("/games/civcraft/actions.lua")
local Victory = dofile("/games/civcraft/victory.lua")
local Diplomacy = dofile("/games/civcraft/diplomacy.lua")
local Audit = {}

local function fixture(count, mask)
	local state = {
		phase = "game",
		round = 4,
		campaignID = "council-reachability",
		ruleset = "create",
		victoryRulesVersion = 2,
		gameSpeed = "standard",
		roundLimit = 180,
		players = {},
		cities = {},
		units = {},
		diplomacy = Diplomacy.new(),
		world = { width = 20, height = 14, tiles = {}, resources = {}, landmarks = {}, rails = {} },
	}
	for y = 1, 14 do
		for x = 1, 20 do
			state.world.tiles[x .. ":" .. y] = "plains"
		end
	end
	local council = Council.ensure(state)
	for id = 0, count - 1 do
		state.players[#state.players + 1] = {
			id = id,
			name = "Member " .. id,
			civ = "forge",
			ready = true,
			gold = 100,
			techs = { currency = true, commerce = true, bronze = true },
		}
		state.cities[#state.cities + 1] = {
			id = id + 1,
			owner = id,
			capitalOf = id,
			x = (id + 1) * 4,
			y = 6,
			population = 2,
			buildings = { market = true, councilhall = true },
		}
		if math.floor(mask / 2 ^ id) % 2 == 1 then
			local villageId = 100 + id
			local owner = -1000 - villageId
			state.cities[#state.cities + 1] = {
				id = villageId,
				owner = owner,
				villageOwner = owner,
				village = true,
				x = 3 + id * 4,
				y = 10,
				population = 2,
				buildings = {},
				influence = { [id] = 60 },
			}
			council.loyalty[villageId] = { owner = id, since = 1 }
		end
	end
	Systems.migrate(state)
	Council.advance(state)
	assert(state.council.session and #state.council.session.members == count)
	for index, member in ipairs(state.council.session.members) do
		assert(member.delegates == 2 + math.floor(mask / 2 ^ (index - 1)) % 2)
	end
	return state
end

function Audit.run(checkpoint)
	local output = { schemaVersion = 1, totalCases = 0, profiles = {}, outcomeDigest = 0 }
	for count = 2, 4 do
		local summary = {
			players = count,
			delegateProfiles = 2 ^ count,
			cases = 0,
			wins = 0,
			leaderships = 0,
			noConsentForZeroCases = 0,
			zeroWinsWithoutConsent = 0,
			selfOrAbstainCases = 0,
			selfOrAbstainWins = 0,
			unanimousZeroControls = 0,
			unanimousZeroWins = 0,
			profiles = {},
		}
		for mask = 0, 2 ^ count - 1 do
			local profile = { mask = mask, delegates = {}, cases = 0, wins = 0 }
			for id = 0, count - 1 do
				profile.delegates[id + 1] = 2 + math.floor(mask / 2 ^ id) % 2
			end
			for encoded = 0, (count + 1) ^ count - 1 do
				local state, remaining, ballots = fixture(count, mask), encoded, {}
				local noConsent, selfOrAbstain, unanimous = true, true, true
				for id = 0, count - 1 do
					local value = remaining % (count + 1)
					remaining = math.floor(remaining / (count + 1))
					local candidate = value > 0 and value - 1 or false
					ballots[id + 1] = candidate
					local ok, why = Actions.apply(state, id, {
						action = "councilVote",
						session = state.council.session.id,
						candidate = candidate,
					}, Systems)
					assert(ok, why)
					if id ~= 0 and candidate == 0 then
						noConsent = false
					end
					if candidate ~= false and candidate ~= id then
						selfOrAbstain = false
					end
					if candidate ~= 0 then
						unanimous = false
					end
				end
				state.round = state.council.session.closesRound
				Council.advance(state)
				Victory.check(state, false)
				local winner = (state.winnerIDs or {})[1]
				local leader = state.council.leader
				local win = state.phase == "over" and state.victoryReason == "DIPLOMATIC"
				if win then
					assert(winner ~= nil)
				end
				profile.cases, summary.cases = profile.cases + 1, summary.cases + 1
				if win then
					profile.wins, summary.wins = profile.wins + 1, summary.wins + 1
				end
				if leader ~= nil then
					summary.leaderships = summary.leaderships + 1
				end
				if noConsent then
					summary.noConsentForZeroCases = summary.noConsentForZeroCases + 1
					if win and winner == 0 then
						summary.zeroWinsWithoutConsent = summary.zeroWinsWithoutConsent + 1
					end
				end
				if selfOrAbstain then
					summary.selfOrAbstainCases = summary.selfOrAbstainCases + 1
					if win then
						summary.selfOrAbstainWins = summary.selfOrAbstainWins + 1
					end
				end
				if unanimous then
					summary.unanimousZeroControls = summary.unanimousZeroControls + 1
					if win and winner == 0 then
						summary.unanimousZeroWins = summary.unanimousZeroWins + 1
					end
				end
				output.outcomeDigest = (
					output.outcomeDigest * 131
					+ (winner or count + 1) * 7
					+ (leader or count + 1)
				) % 2147483647
				output.totalCases = output.totalCases + 1
				if checkpoint and output.totalCases % 64 == 0 then
					checkpoint()
				end
			end
			summary.profiles[#summary.profiles + 1] = profile
		end
		assert(summary.zeroWinsWithoutConsent == 0 and summary.selfOrAbstainWins == 0)
		assert(summary.unanimousZeroWins == summary.delegateProfiles)
		output.profiles[#output.profiles + 1] = summary
	end
	return output
end

return Audit
