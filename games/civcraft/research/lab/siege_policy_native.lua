local cases = dofile("/siege_cases.lua")
local output = { host = _G._HOST, cases = {} }
for _, case in ipairs(cases) do
	local environment = setmetatable({}, { __index = _G })
	environment._G = environment
	environment.dofile = function(path)
		local file = assert(fs.open(path, "r"))
		local source = file.readAll()
		file.close()
		return assert(load(source, "@" .. path, "t", environment))()
	end
	environment.dofile("/games/civcraft/module_cache.lua").install(environment)
	local Engine = environment.dofile("/lab/engine.lua")
	local Canonical = environment.dofile("/lab/canonical.lua")
	environment.dofile("/lab/policies.lua").install(case.config.players)
	local state = Engine.newGame(case.config)
	if case.coordinated then
		environment
			.dofile("/games/civcraft/research/lab/coordinated_siege_policy.lua")
			.install(case.parameters)
	end
	environment.dofile("/siege_setup.lua")(state, case.scenario)
	local result = { states = { Canonical.encode(state) }, observations = {} }
	for _ = 1, 8 do
		Engine.pump(state)
		result.states[#result.states + 1] = Canonical.encode(state)
		result.observations[#result.observations + 1] = {
			Canonical.encode(Engine.observe(state, 0)),
			Canonical.encode(Engine.observe(state, 1)),
		}
		if Engine.isFinished(state) then
			break
		end
		Engine.advance(state)
	end
	result.finalState = Canonical.encode(state)
	output.cases[#output.cases + 1] = result
end
local file = assert(fs.open("/siege_policy_native.json", "w"))
file.write(textutils.serializeJSON(output))
file.close()
return true
