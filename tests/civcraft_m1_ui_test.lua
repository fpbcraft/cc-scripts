-- Check actual campaign-panel row generation/paging; native sessions cover rendering/input.
local native = dofile
dofile = function(path)
	return native(path:gsub("^/games/civcraft/", "games/civcraft/"))
end
dofile("/games/civcraft/module_cache.lua").install(_ENV)
local Options = dofile("/games/civcraft/campaign_options.lua")
local Lifecycle = dofile("/games/civcraft/match_lifecycle.lua")
for _, version in ipairs({ "baseline", "p1", "balance1" }) do
	local state = Lifecycle.newLobby("m1-ui", version)
	state.players = { { id = 0, name = "PLAYER" } }
	local labels, text = {}, {}
	local r = { w = 102, h = 57, buttons = {} }
	function r:fill() end
	function r:textWidth(value)
		return #tostring(value) * 4
	end
	function r:text(_, _, value)
		text[#text + 1] = value
	end
	function r:button(_, _, _, _, label, run)
		self.buttons[#self.buttons + 1] = { label = label, fn = run }
		labels[label] = true
	end
	local ui = { r = r }
	function ui:command(action, args)
		self.last = { action = action, args = args }
	end
	for offset = 0, 50 do
		ui.campaignOffset = offset
		r.buttons = {}
		Options.draw(ui, state)
	end
	if version == "balance1" then
		assert(labels["ECONOMY REDESIGN V1"] and labels["SCORE DEADLINE"])
		assert(labels["CONQUEST ON"] and labels["END EXPEDITION ON"])
		assert(
			not labels["INDUSTRIAL OFF"]
				and not labels["INDUSTRIAL ON"]
				and not labels["DIPLOMATIC OFF"]
		)
		assert(not table.concat(text, " "):find("game ends in a draw", 1, true))
	else
		assert(labels["INDUSTRIAL ON"] and labels["DIPLOMATIC ON"] and labels["SCORE ON"])
	end
end
print("PASS: all campaign versions expose their correct victory controls and deadline help")
