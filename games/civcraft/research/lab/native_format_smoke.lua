-- Short diagnostic companion to the long native benchmark. Uses actual heldout
-- vectors and one cooperative 2-second batch; useful for validating mounts.
local policy = assert(dofile(_G.POLICY_PATH))
local rows = assert(dofile("/research/lab/actual_holdout_vectors.lua"))
local start = os.epoch("utc")
local calls, agreement, fallback = 0, 0, 0
while os.epoch("utc") - start < 2000 do
	local row = rows[(calls % #rows) + 1]
	local action, usedFallback = policy.predict(row.features, row.actions, row.candidates)
	if action == row.expected[_G.POLICY_NAME] then
		agreement = agreement + 1
	end
	if usedFallback then
		fallback = fallback + 1
	end
	calls = calls + 1
end
print(textutils.serializeJSON({
	status = "native_smoke",
	format = _G.POLICY_NAME,
	calls = calls,
	agreement = agreement / math.max(1, calls),
	fallbackRate = fallback / math.max(1, calls),
	bytes = fs.getSize(_G.POLICY_PATH),
}))
os.shutdown()
