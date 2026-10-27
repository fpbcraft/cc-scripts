-- Prepared native benchmark.  This file is intentionally not launched by the
-- offline comparison driver; the parent task should run it inside the same
-- CraftOS/Lua environment as the live controller after an explicit signal.
-- Policies are generated in formats/*.lua and expose predict(features, legal).

-- Keep each timed chunk below the CraftOS watchdog window. The launcher may
-- invoke this script once per format in a fresh process; this harness also
-- yields between 4-second chunks for safety.
-- Five chunks are the bounded comparison run. Increase only after a native
-- host confirms the same watchdog-safe behavior; a single 120-second busy
-- process is intentionally not treated as valid evidence.
local batchMs, batches = 4000, 5
local policyName = POLICY_NAME or "actual_weights"
local policyPath = POLICY_PATH or ("/research/lab/formats/" .. policyName .. ".lua")

local featureRows = {
  {0.02,0.17,0.125,0.09,0.12,0.08,0.20,0.33,0.03,0.04,0.08,0.12,0.13,0.06,0.8},
  {0.38,0.50,0.375,0.32,0.65,0.72,0.41,0.70,0.40,0.29,0.29,0.47,0.00,0.45,0.6},
  {0.74,0.83,0.625,0.68,0.90,0.45,0.08,0.18,0.73,0.63,0.58,0.94,0.13,0.81,0.5},
  {0.91,1.00,0.875,0.93,0.44,0.83,0.82,0.88,0.97,0.79,0.79,0.56,0.25,0.32,0.4},
}
local legalRows = {
  {"production:bank", "production:mine", "production:station", "research:writing"},
  {"production:settler", "production:warrior", "research:mining", "research:sailing"},
  {"production:library", "production:station", "research:agriculture", "research:writing"},
  {"production:bank", "production:library", "production:warrior", "research:sailing"},
}

local function now()
  if os.epoch then return os.epoch("utc") end
  return math.floor(os.clock() * 1000)
end

local function load(path)
  if not fs.exists(path) then return nil, "missing " .. path end
  local ok, value = pcall(dofile, path)
  if not ok then return nil, value end
  return value
end

local replayRows = {}
if fs.exists("/research/lab/actual_holdout_vectors.lua") then
  replayRows = dofile("/research/lab/actual_holdout_vectors.lua")
end
local output = {schema = "observer-ranked-decision-v1", status = "native_benchmark", durationMs = batchMs * batches, batchMs = batchMs, batches = batches, formats = {}}
do
  local name, path = policyName, policyPath
  local policy, err = load(path)
  if policy then
    collectgarbage("collect")
    local before = collectgarbage("count")
    local started = now()
    local calls, fallbacks, maxMs = 0, 0, 0
    local firstAction, agreement, replayCalls = nil, 0, 0
    for batch = 1, batches do
      local batchStarted = now()
      while now() - batchStarted < batchMs do
        local replay = replayRows[(calls % #replayRows) + 1]
        local row = replay and replay.features or featureRows[(calls % #featureRows) + 1]
        local legal = replay and replay.actions or legalRows[(calls % #legalRows) + 1]
        local candidates = replay and replay.candidates or nil
        local callStart = now()
        local action, fallback = policy.predict(row, legal, candidates)
        local elapsed = now() - callStart
        if elapsed > maxMs then maxMs = elapsed end
        firstAction = firstAction or action
        if fallback then fallbacks = fallbacks + 1 end
        if replay then
          replayCalls = replayCalls + 1
          if action == replay.expected[name] then agreement = agreement + 1 end
        end
        calls = calls + 1
        if calls % 32 == 0 then
          -- CraftOS instruction watchdog requires frequent cooperative yields
          -- for the 68-action weights table; these are outside the measured
          -- single-call latency and are counted in total throughput.
          os.queueEvent("policy_benchmark_yield")
          os.pullEvent("policy_benchmark_yield")
        end
      end
      pcall(collectgarbage, "collect")
    end
    local after = collectgarbage("count")
    output.formats[name] = {
      path = path,
      bytes = fs.getSize(path),
      calls = calls,
      elapsedMs = now() - started,
      callsPerSecond = calls / math.max(0.001, (now() - started) / 1000),
      maxSingleCallMs = maxMs,
      fallbackRate = fallbacks / math.max(1, calls),
      replayRecords = #replayRows,
      replayCalls = replayCalls,
      replayAgreement = agreement / math.max(1, replayCalls),
      replayMismatches = replayCalls - agreement,
      firstAction = firstAction,
      heapDeltaKB = after - before,
    }
  else
    output.formats[name] = {path = path, status = "error", error = tostring(err)}
  end
end
local resultText = textutils.serializeJSON(output)
local resultFile = fs.open("/native_benchmark_result.json", "w")
resultFile.write(resultText)
resultFile.close()
print(resultText)
