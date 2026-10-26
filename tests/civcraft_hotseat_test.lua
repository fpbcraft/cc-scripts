-- Executes real CIVCRAFT rules in one-computer hotseat mode.
local files, dirs, versions = {}, { ["/"] = true }, {}
local last
fs = {}
function fs.exists(p)
	return files[p] ~= nil or dirs[p] == true
end
function fs.getSize(p)
	return #(files[p] or "")
end
function fs.makeDir(p)
	dirs[p] = true
end
function fs.getDir(p)
	return p:match("^(.*)/[^/]+$") or "/"
end
function fs.delete(p)
	files[p] = nil
	dirs[p] = nil
end
function fs.move(a, b)
	assert(files[a])
	files[b] = files[a]
	files[a] = nil
end
function fs.open(p, mode)
	if mode == "r" then
		if files[p] == nil then
			return nil
		end
		return {
			readAll = function()
				return files[p]
			end,
			close = function() end,
		}
	end
	local result = mode == "a" and (files[p] or "") or ""
	return {
		write = function(s)
			result = result .. s
		end,
		writeLine = function(s)
			result = result .. s .. "\n"
		end,
		close = function()
			files[p] = result
			if p:match("/slot%-%d+%.dat%.tmp$") then
				local parse = assert(load("return " .. result, "saved campaign", "t", {}))
				last = parse()
			end
		end,
	}
end
textutils = {
	serialize = function(data)
		local id = "saved-" .. (#versions + 1)
		local function copy(obj)
			if type(obj) ~= "table" then
				return obj
			end
			local out = {}
			for k, v in pairs(obj) do
				out[k] = copy(v)
			end
			return out
		end
		versions[#versions + 1] = copy(data)
		last = versions[#versions]
		return id
	end,
	unserialize = function(id)
		local i = tonumber(id:match("^saved%-(%d+)$"))
		if i then
			return versions[i]
		end
		local parse = load("return " .. id, "campaign", "t", {})
		return parse and parse() or nil
	end,
}
peripheral = {
	getNames = function()
		return {}
	end,
}
rednet = {}
term = {
	current = function()
		return {}
	end,
}
os.getComputerID = function()
	return 9
end
keys = { q = 16, escape = 1 }
local frames, stage = 0, 0
local progress = {}
local aiName
local originalDofile = dofile
dofile = function(path)
	if path:sub(1, 16) == "/games/civcraft/" and path ~= "/games/civcraft/ui.lua" then
		local module = originalDofile(path:sub(2))
		if path == "/games/civcraft/systems.lua" then
			local aiTurn = module.aiTurn
			module.aiTurn = function(state, player, hex)
				local shown = progress[#progress]
				assert(
					shown and shown.title == "AI TAKING ITS TURN" and shown.detail == player.name,
					"AI waiting screen must render before AI work starts"
				)
				return aiTurn(state, player, hex)
			end
		end
		return module
	end
	if path ~= "/games/civcraft/ui.lua" then
		return originalDofile(path)
	end
	return {
		new = function(_, callback)
			return {
				message = function() end,
				turnProgress = function(self, title, detail)
					progress[#progress + 1] = { title = title, detail = detail }
				end,
				draw = function(self, s, id, opt)
					if opt.screen ~= "title" then
						assert(opt.slots == nil, "Gameplay redraws must not reload campaign slots")
					end
					frames = frames + 1
					stage = stage + 1
					if stage == 1 then
						callback("newGame")
						assert(s.phase == "lobby" and #s.players == 2 and opt.localMode)
						callback("addPlayer")
					elseif stage == 2 then
						assert(#s.players == 3)
						callback("toggleAI", { player = 3 })
					elseif stage == 3 then
						assert(#s.players == 3 and s.players[3].ai)
						aiName = s.players[3].name
						for _, size in ipairs({ "large", "huge", "vast", "compact", "standard" }) do
							callback("mapSize")
							callback("save")
							assert(
								last.mapSize == size,
								"Lobby must expose every supported world size"
							)
						end
						callback("start")
					elseif stage == 4 then
						assert(s.phase == "game" and s.round == 1)
						assert(id == s.players[1].id)
						local unit = s.units[1]
						callback("standby", { x = unit.x, y = unit.y, value = true })
						callback("save")
						assert(
							last.units[1].standby,
							"Sleep command persists on the authoritative unit"
						)
						assert(
							not unit.standby,
							"A displayed frame remains detached after commands"
						)
						callback("standby", { x = unit.x, y = unit.y, value = false })
						callback("save")
						assert(not last.units[1].standby, "Wake command restores active orders")
						callback("end")
					elseif stage == 5 then
						assert(opt.handoff and id == s.players[2].id)
						callback("reveal")
					elseif stage == 6 then
						assert(not opt.handoff)
						-- The third player was configured through the actual lobby command.
						callback("end")
						assert(
							progress[1].title == "AI TAKING ITS TURN"
								and progress[1].detail == aiName,
							"Waiting screen identifies the AI player"
						)
						assert(
							progress[2].title == "PROCESSING ROUND",
							"Waiting screen covers round processing"
						)
						callback("save")
					elseif stage == 7 then
						assert(
							s.round == 2 and opt.handoff and id == s.players[1].id,
							"Turn rotation and handoff across rounds"
						)
						assert(
							s.players[1].turnReport and s.players[1].reportRound == 2,
							"Round produces a private turn report"
						)
						callback("reveal")
					elseif stage == 8 then
						assert(s.round == 2 and not opt.handoff)
						callback("exit")
					end
				end,
				resize = function() end,
				tap = function() end,
				close = function() end,
				animating = function()
					return false
				end,
			}
		end,
	}
end
local originalPull = os.pullEvent
local count = 0
os.pullEvent = function()
	count = count + 1
	if count >= 8 then
		return "timer", 0
	end
	return "term_resize"
end
local ok, err = pcall(function()
	assert(loadfile("games/civcraft/game.lua"))("local", "--new", "--debug")
end)
os.pullEvent = originalPull
dofile = originalDofile
assert(ok, err)
assert(frames == 8, "Should render through complete hotseat sequence")
assert(last.round == 2 and #last.players == 3, "Round persists with correct player count")
assert(last.activeIndex == 1, "Current player persisted")
assert(files["/games/civcraft/data/slot-1.dat"], "Separate local save exists")
assert(not files["/games/civcraft/data/save.dat"], "Network save untouched")
local diagnostic = files["/games/civcraft/data/debug.log"]
assert(
	diagnostic
		and diagnostic:find("ai.begin " .. aiName, 1, true)
		and diagnostic:find("ai.end " .. aiName, 1, true)
		and diagnostic:find("draw.end", 1, true),
	"Debug mode persists operation boundaries"
)
print("CIVCRAFT: hotseat lobby, turn ownership, privacy handoff, 2nd round and save passed.")
