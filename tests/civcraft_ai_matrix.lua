-- Manual long-run validation; use generated data in an isolated CraftOS profile.
local arguments = { ... }
local rounds = tonumber(arguments[1]) or 100
local cases = {
	{ seed = 75123, civilization = "forge", opponent = "forge" },
	{ seed = 95117, civilization = "scholar", opponent = "iron" },
	{ seed = 18731, civilization = "iron", opponent = "scholar" },
	{ seed = 47771, civilization = "merchant", opponent = "sentinel" },
	{ seed = 99119, civilization = "nomad", opponent = "mariner" },
	{ seed = 61283, civilization = "wild", opponent = "highland" },
}
local report = { rounds = rounds, cases = {} }
local path = fs
		and fs.exists("/tests/civcraft_ai_tournament.lua")
		and "/tests/civcraft_ai_tournament.lua"
	or "tests/civcraft_ai_tournament.lua"
for _, scenario in ipairs(cases) do
	print(
		"CASE " .. scenario.seed .. " " .. scenario.civilization .. " versus " .. scenario.opponent
	)
	local result =
		assert(loadfile(path))(rounds, scenario.seed, scenario.civilization, "", scenario.opponent)
	report.cases[#report.cases + 1] = result
	if fs and textutils then
		local file = assert(fs.open("/civcraft-ai-matrix.txt", "w"))
		file.write(textutils.serialize(report))
		file.close()
	end
end
assert(#report.cases == 6)
print("CIVCRAFT: sixty swapped-seat simulations across six seeds completed.")
return report
