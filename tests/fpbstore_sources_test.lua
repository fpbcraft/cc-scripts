-- Regression tests for PR/branch installs and independent package update status.
package.path = "./?.lua;./?/init.lua;" .. package.path
local disk = dofile("tests/support/craftos.lua").new()
disk.install("fpbstore", "main", "--no-startup")
disk.withoutRuntime()

local P = dofile("lib/fpb/packages.lua")
local A, B, C, D =
	string.rep("a", 40), string.rep("b", 40), string.rep("c", 40), string.rep("d", 40)
local heads = { main = A, pr = B, branch = C }
local state = { changedCog = false, changedPR = false }
local function tree(sha)
	local entries = {}
	local seen = {}
	for _, spec in pairs(P.packages) do
		local paths = {}
		for _, file in ipairs(spec.files) do
			paths[#paths + 1] = spec.source .. "/" .. file
		end
		for _, lib in ipairs(spec.libraries) do
			paths[#paths + 1] = "lib/fpb/" .. lib .. ".lua"
		end
		for _, path in ipairs(paths) do
			if not seen[path] then
				seen[path] = true
				local blob = A
				if path == "games/cogworks/levels.lua" then
					if sha == D and state.changedCog then
						blob = D
					elseif sha == D and state.changedPR then
						blob = B
					end
				end
				entries[#entries + 1] = { path = path, type = "blob", sha = blob }
			end
		end
	end
	return { tree = entries, truncated = false }
end

local responses = {}
local original = disk.env.http.get
disk.env.http.get = function(url, ...)
	if url:find("api.github.com", 1, true) then
		local body
		if url:find("/pulls/52", 1, true) then
			body = "pr"
			responses.pr =
				{ head = { sha = heads.pr, repo = { full_name = "fpbcraft/cc-scripts" } } }
		elseif url:find("/commits/feature%2Fexperiment", 1, true) then
			body = "branch"
			responses.branch = { sha = heads.branch }
		elseif url:find("/commits/main", 1, true) then
			body = "main"
			responses.main = { sha = heads.main }
		else
			local sha = url:match("/git/trees/([a-f0-9]+)")
			if sha then
				body = "tree:" .. sha
				responses[body] = tree(sha)
			end
		end
		if not body then
			return nil, "Unexpected API request: " .. url
		end
		return {
			getResponseCode = function()
				return 200
			end,
			readAll = function()
				return body
			end,
			close = function() end,
		}
	end
	return original(url, ...)
end
disk.env.textutils.unserializeJSON = function(body)
	return responses[body]
end

local manager = disk.run("fpbstore", "--test-api")
local cog = assert(manager.get("cogworks"))
local rail = assert(manager.get("railbreak"))

local pr = manager.parseSource("https://github.com/fpbcraft/cc-scripts/pull/52")
assert(pr.kind == "pr" and pr.value == "52")
assert(manager.parseSource("#52").kind == "pr")
assert(manager.parseSource("feature/experiment").kind == "branch")
assert(not pcall(manager.parseSource, "https://github.com/other/project/pull/52"))
assert(not pcall(manager.parseSource, "../broken", "branch"))

assert(manager.refreshVersions())
assert(manager.install(cog))
assert(manager.install(rail))
assert(manager.status(cog).source.kind == "main")
assert(not manager.status(cog).updateAvailable)
assert(not manager.status(rail).updateAvailable)

-- A Store-only/repository-wide head change cannot mark unchanged apps as outdated.
heads.main = B
assert(manager.refreshVersions())
assert(not manager.status(cog).updateAvailable, "Unchanged Cogworks must not show UPDATE")
assert(not manager.status(rail).updateAvailable, "Unchanged Railbreak must not show UPDATE")

-- Changing only Cogworks' files flags Cogworks but never Railbreak.
heads.main = D
state.changedCog = true
assert(manager.refreshVersions())
assert(manager.status(cog).updateAvailable, "Cogworks code change should be detected")
assert(not manager.status(rail).updateAvailable, "Other apps must remain up-to-date")

-- Selecting a PR pins the commit and updates that app's source metadata.
assert(manager.install(cog, pr))
assert(manager.installedSource(cog).label == "PR #52")
assert(manager.installedRevision(cog) == B)
assert(not manager.status(cog).updateAvailable)
assert(not manager.status(rail).updateAvailable)
heads.pr = D
state.changedCog = false
state.changedPR = true
assert(manager.refreshVersions())
assert(manager.status(cog).updateAvailable, "Later PR commits must be detected")
assert(not manager.status(rail).updateAvailable)
assert(manager.install(cog), "Normal reinstall must preserve the PR source")
assert(manager.installedRevision(cog) == D)
assert(manager.installedSource(cog).kind == "pr")
assert(not manager.status(cog).updateAvailable)

-- A named branch is independently tracked; users can switch back to main.
assert(manager.install(cog, "feature/experiment"))
assert(manager.installedSource(cog).value == "feature/experiment")
assert(manager.installedRevision(cog) == C)
assert(manager.install(cog, manager.parseSource("main")))
assert(manager.installedSource(cog).kind == "main")
assert(manager.installedRevision(cog) == D)

-- Unavailable GitHub metadata must never pretend PR content is main.
local oldGet = disk.env.http.get
disk.env.http.get = function(url, ...)
	if url:find("api.github.com", 1, true) then
		return nil, "Offline"
	end
	return oldGet(url, ...)
end
assert(not pcall(manager.install, cog, "pr/53"), "PR installs require verified head commit")
print("Store source regression: PR, branch, file-level updates, and main switch passed")
