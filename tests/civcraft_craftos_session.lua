--[[
	Manual full-session test for a dedicated CraftOS computer. Save slot 1 is
	overwritten. Rendering and input handling are real. The UI is instrumented to enqueue and
	acknowledge mouse events at actual button coordinates.
]]
local includeAI, includeSettings, includeResearch, includeCampaign = false, false, false, false
local includeWar = false
local touchMonitor = false
local includeHost = false
local includeQuickResearch, quickResearchVerified = false, false
local includeUnitBadges, unitBadgesVerified = false, false
local includeDevelopment = false
local developmentProfile = "balance2"
local includeDefaultSpecialization = false
local defaultSpecializationVerified = false
local includeConversation = false
local includeContactHUD, contactBadgeStep, contactBadgeVerified = false, 0, false
local contactFactionPages = 0
local includeHistory = false
local includeUnitActions, unitActionsVerified, unitActionUnitID = false, false, nil
local includeDifficulty = false
local includeCivilization, civilizationStep = false, 0
local includeMapTools, mapToolsVerified = false, false
local includeCouncil, councilVerified = false, false
local historyVerified = false
local includeRoutes = false
local routeRecord
local routeResumed = false
for _, argument in ipairs({ ... }) do
	if argument == "--specialization" then
		includeDevelopment = true
		developmentProfile = "balance5"
	end
	if argument == "--default-specialization" then
		includeDefaultSpecialization = true
	end
	if argument == "--landwork" then
		includeDevelopment = true
		developmentProfile = "balance3"
	end
	if argument == "--development" then
		includeDevelopment = true
	end
	if argument == "--civilization" then
		includeCivilization = true
	end
	if argument == "--touch-monitor" then
		touchMonitor = true
	end
	if argument == "--difficulty" then
		includeDifficulty, includeAI = true, true
	end
	if argument == "--map-tools" then
		includeMapTools = true
	end
	if argument == "--council" then
		includeCouncil = true
	end
	if argument == "--history" then
		includeHistory = true
	end
	if argument == "--unit-badges" then
		includeUnitBadges = true
	end
	if argument == "--unit-actions" then
		includeUnitActions = true
	end
	if argument == "--routes" then
		includeRoutes = true
	end
	if argument == "--ai" then
		includeAI = true
	end
	if argument == "--settings" then
		includeSettings = true
	end
	if argument == "--quick-research" then
		includeQuickResearch = true
	end
	if argument == "--research" then
		includeResearch = true
	end
	if argument == "--campaign" then
		includeCampaign = true
	end
	if argument == "--war" then
		includeWar = true
	end
	if argument == "--host-ai" then
		includeHost, includeAI = true, true
	end
	if argument == "--conversation" then
		includeConversation, includeAI = true, true
	end
	if argument == "--contact-hud" then
		includeContactHUD, includeConversation, includeAI = true, true, true
	end
end
assert(
	not (includeHost and includeWar),
	"The host AI scenario has one human; use hotseat for defender reactions"
)
if touchMonitor then
	assert(_G.periphemu.create("top", "monitor"), "Use a fresh profile for monitor testing")
end
local native = dofile
local stage = 0
local settingsExpectedSpeed, settingsExpectedDisplay
local responseSaved = false
local renderer
local queued = false
local function tap(view, label)
	for _, button in ipairs(view.r.buttons) do
		if button.label == label then
			local x, y = button.x + button.w / 2, button.y + button.h / 2
			if view.r.mode == "graphics" then
				x, y = view.r.ox + x * view.r.sx, view.r.oy + y * view.r.sy
			else
				x, y = x / 2 + 1, y / 3 + 1
			end
			local px, py = math.floor(x), math.floor(y)
			local vx, vy = view.r:touch(px, py)
			local hits = {}
			for _, candidate in ipairs(view.r.buttons) do
				if
					vx
					and vx >= candidate.x
					and vx < candidate.x + candidate.w
					and vy >= candidate.y
					and vy < candidate.y + candidate.h
				then
					hits[#hits + 1] = tostring(candidate.label)
				end
			end
			local trace = assert(fs.open("/session-input.log", "a"))
			local available = {}
			for _, candidate in ipairs(view.r.buttons) do
				available[#available + 1] = candidate.label
			end
			trace.writeLine(textutils.serialize({
				stage = stage,
				techSelected = view.techModel and view.techModel.selected,
				techOffset = view.techModel and view.techModel.offset,
				techPageMax = view.techModel and view.techModel.pageMax,
				available = available,
				label = label,
				mode = view.r.mode,
				width = view.r.w,
				height = view.r.h,
				x = px,
				y = py,
				vx = vx,
				vy = vy,
				hits = hits,
			}))
			trace.close()
			queued = true
			if touchMonitor then
				os.queueEvent("monitor_touch", "top", math.floor(x), math.floor(y))
			else
				os.queueEvent("mouse_click", 1, math.floor(x), math.floor(y))
				os.queueEvent("mouse_up", 1, math.floor(x), math.floor(y))
			end
			os.queueEvent("civcraft_test_input_complete")
			return true
		end
	end
	return false
end

local function completeDecisions(view)
	if view.panel == "context" then
		local label = view:turnAction()
		if label == "PRODUCTION" and tap(view, "NO PRODUCTION") then
			return false
		end
		if label == "UNIT ORDERS" and tap(view, "SKIP TURN") then
			return false
		end
		if tap(view, label) then
			return label == "END TURN"
		end
	elseif view.panel == "inspector" then
		if view.selected.kind == "unit" then
			if not tap(view, "SKIP TURN") then
				tap(view, "NEXT")
			end
		else
			local resolved = false
			for _, city in ipairs(view.state.cities) do
				if city.x == view.selected.x and city.y == view.selected.y then
					resolved = city.productionIdle or city.project
				end
			end
			if resolved then
				tap(view, "CLOSE")
			elseif not tap(view, "NO PRODUCTION") then
				tap(view, "NEXT")
			end
		end
	elseif view.panel == "quickResearch" then
		local researching
		for _, player in ipairs(view.state.players) do
			if player.id == view.playerID then
				researching = player.researchTarget
			end
		end
		if researching then
			tap(view, "CLOSE")
		else
			for _, button in ipairs(view.r.buttons) do
				if button.label and button.label:find("^RESEARCH ") then
					tap(view, button.label)
					return false
				end
			end
			tap(view, "NEXT")
		end
	elseif view.panel == "tech" then
		local researching = false
		for _, player in ipairs(view.state.players) do
			if player.id == view.playerID then
				researching = player.researchTarget
			end
		end
		if researching then
			tap(view, "CLOSE")
		elseif view.techModel and view.techModel.detail then
			if not tap(view, "RESEARCH") then
				tap(view, "NEXT")
			end
		elseif
			not tap(view, "RESEARCH")
			and not tap(view, "DETAILS")
			and not tap(view, "DETAILS / CODEX")
		then
			tap(view, "WHEAT FARMING")
		end
	end
	return false
end

dofile = function(path)
	local module = native(path)
	if includeCouncil and path == "/games/civcraft/council.lua" then
		local advance = module.advance
		module.advance = function(state)
			-- An explicit Currency-era test fixture; all ballots still use normal commands.
			if state.phase == "game" then
				state.players[1].techs.currency = true
			end
			return advance(state)
		end
	end
	if path == "/games/civcraft/world.lua" and (includeConversation or includeWar) then
		local generate = module.generate
		module.generate = function(...)
			local world = generate(...)
			-- A contact scenario: nearby capitals are actually seen by normal revelation.
			-- No contact flags or diplomacy validation are bypassed.
			local positions =
				{ { x = 4, y = 6 }, { x = 6, y = 6 }, { x = 5, y = 8 }, { x = 7, y = 8 } }
			for index = 1, #world.starts do
				world.starts[index] = positions[index]
			end
			for y = 4, 10 do
				for x = 3, 9 do
					world.tiles[module.key(x, y)] = "plains"
				end
			end
			return world
		end
	end
	if path ~= "/games/civcraft/ui.lua" then
		return module
	end
	local construct = module.new
	module.new = function(display, dispatch)
		local view = construct(display, dispatch)
		local pull = view.r.pullEvent
		view.r.pullEvent = function(canvas)
			local event = table.pack(pull(canvas))
			if event[1] == "civcraft_test_input_complete" then
				queued = false
				os.queueEvent("term_resize")
			end
			return (table.unpack or unpack)(event, 1, event.n)
		end
		local draw = view.draw
		local aiConfigured = false
		local settingsStep = 0
		local difficultyStep = 0
		local researchStep = 0
		local quickResearchStep, quickPages = 0, 0
		local researchNavigation = 0
		local campaignStep = 0
		local openingFocus = {}
		local warStep, responseStep = 0, 0
		local historyStep, historySeq = 0, nil
		local councilStep = 0
		local mapToolsStep = 0
		local conversationStep = 0
		local unitActionsStep = 0
		local routeStep, routeUnit, routeGoal = 0, nil, nil
		local badgeStep, badgeUnit = 0, nil
		view.draw = function(self, state, observer, options)
			draw(self, state, observer, options)
			renderer = self.r.mode
			if queued then
				return
			end
			if
				includeSettings
				and stage == 0
				and options.screen == "title"
				and settingsStep < 5
			then
				local label
				if settingsStep == 0 then
					settingsExpectedDisplay = self.animationPreferences.display
					label = "SETTINGS"
				elseif settingsStep == 1 then
					settingsExpectedSpeed = ({ normal = "fast", fast = "off", off = "normal" })[self.animationPreferences.speed]
					label = "ANIMATIONS " .. self.animationPreferences.speed:upper()
				elseif settingsStep == 2 then
					label = "DISPLAY " .. self.animationPreferences.display:upper()
				elseif settingsStep == 3 then
					label = "DISPLAY " .. self.animationPreferences.display:upper()
				else
					label = "CLOSE"
				end
				if tap(self, label) then
					settingsStep = settingsStep + 1
				else
					tap(self, "NEXT")
				end
				return
			end
			if includeDefaultSpecialization and stage == 1 and state.phase == "lobby" then
				assert(
					state.contentRules == "balance5",
					"A fresh native campaign lobby defaults to Specialization V5 without profile selection"
				)
				defaultSpecializationVerified = true
			end
			if
				includeDevelopment
				and stage == 1
				and state.phase == "lobby"
				and state.contentRules ~= developmentProfile
			then
				self:command("contentRules")
				os.queueEvent("term_resize")
				return
			end
			if includeAI and not aiConfigured and stage == 1 and state.phase == "lobby" then
				if includeHost then
					if tap(self, "+ AI") then
						aiConfigured = true
					else
						tap(self, "NEXT")
					end
				else
					self:command("addPlayer")
					self:command("toggleAI", { player = 3 })
					aiConfigured = true
					os.queueEvent("term_resize")
				end
				return
			end
			if
				includeDifficulty
				and stage == 1
				and state.phase == "lobby"
				and difficultyStep < 4
			then
				local target
				for _, player in ipairs(state.players) do
					if player.ai then
						target = player
						break
					end
				end
				assert(target, "Native difficulty scenario needs an AI")
				local labels = {
					"CAMPAIGN OPTIONS",
					target.name .. " PRINCE",
					target.name .. " KING",
					"CLOSE",
				}
				if tap(self, labels[difficultyStep + 1]) then
					difficultyStep = difficultyStep + 1
				else
					tap(self, difficultyStep == 0 and "PREV" or "NEXT")
				end
				return
			end
			if includeCampaign and stage == 1 and state.phase == "lobby" and campaignStep < 5 then
				local labels = {
					"CAMPAIGN OPTIONS",
					"LENGTH STANDARD",
					"LENGTH EPIC",
					dofile("/games/civcraft/content_rules.lua").isRedesign(state)
							and "SCORE DEADLINE"
						or "SCORE ON",
					"CLOSE",
				}
				if tap(self, labels[campaignStep + 1]) then
					campaignStep = campaignStep + 1
				else
					tap(self, campaignStep == 0 and "PREV" or "NEXT")
				end
				return
			end
			if self.panel == "recap" and not options.handoff then
				tap(self, "SKIP")
				return
			end
			if
				state.phase == "game"
				and not options.paused
				and not options.handoff
				and self.panel == "report"
			then
				tap(self, "CLOSE")
				return
			end
			if
				state.phase == "game"
				and not options.handoff
				and not options.paused
				and (stage == 2 or stage == 5)
				and dofile("/games/civcraft/content_rules.lua").startsWithSettler(state)
			then
				local me
				for _, player in ipairs(state.players) do
					if player.id == self.playerID then
						me = player
					end
				end
				if me and not me.capitalFounded then
					local traveler
					for _, unit in ipairs(state.units) do
						if unit.owner == me.id and unit.kind == "settler" then
							traveler = unit
							break
						end
					end
					assert(traveler, "Native opening must retain its initial Settler")
					local settlement = dofile("/games/civcraft/ai_settlement.lua")
					if not settlement.value(state, me, traveler.x, traveler.y, traveler) then
						local request = settlement.order(
							state,
							me,
							traveler,
							dofile("/games/civcraft/systems.lua")
						)
						assert(
							request and request.action == "move",
							"Contact fixture needs a legal first-city location within starting movement"
						)
						self:command(request.action, request)
						return
					end
					if not openingFocus[me.id] then
						self:focus("unit", traveler)
						self.panel = "inspector"
						openingFocus[me.id] = true
						return
					end
					if tap(self, "FOUND CAPITAL") then
						self.panel = "context"
					else
						tap(self, "NEXT")
					end
					return
				end
			end
			if includeUnitBadges and stage == 2 and not options.handoff and badgeStep < 3 then
				if self:animating() then
					return
				end
				if badgeStep == 0 then
					for _, actor in ipairs(state.units) do
						if actor.owner == observer then
							badgeUnit = actor
							break
						end
					end
					assert(badgeUnit, "Native badge scenario needs an owned formation")
					self:focus("unit", badgeUnit)
					badgeStep = 1
					os.queueEvent("term_resize")
				elseif badgeStep == 1 then
					local target
					for _, badge in ipairs(self.unitBadgeTargets or {}) do
						if badge.unit.id == badgeUnit.id then
							target = badge
							break
						end
					end
					assert(target, "Focused visible formation has a badge")
					local x, y = target.x + target.w / 2, target.y + target.h / 2
					if self.r.mode == "graphics" then
						x, y = self.r.ox + x * self.r.sx, self.r.oy + y * self.r.sy
					else
						x, y = x / 2 + 1, y / 3 + 1
					end
					self:deselect()
					queued = true
					if touchMonitor then
						os.queueEvent("monitor_touch", "top", math.floor(x), math.floor(y))
					else
						os.queueEvent("mouse_click", 1, math.floor(x), math.floor(y))
						os.queueEvent("mouse_up", 1, math.floor(x), math.floor(y))
					end
					os.queueEvent("civcraft_test_input_complete")
					badgeStep = 2
				else
					assert(
						self.selected.kind == "unit" and self.selected.unitID == badgeUnit.id,
						"Normal-program queued badge click selects exact formation"
					)
					unitBadgesVerified = true
					badgeStep = 3
				end
				return
			end
			if
				includeUnitActions
				and stage == 2
				and not options.handoff
				and unitActionsStep < 3
			then
				if self:animating() then
					return
				end
				if unitActionsStep == 0 then
					local actor
					for _, unit in ipairs(state.units) do
						if unit.owner == observer and unit.kind == "warrior" then
							actor = unit
							break
						end
					end
					assert(actor, "Native unit-action scenario needs an owned warrior")
					unitActionUnitID = actor.id
					self:focus("unit", actor)
					unitActionsStep = 1
					os.queueEvent("term_resize")
				elseif unitActionsStep == 1 then
					if tap(self, "MOVE / ATTACK") then
						unitActionsStep = 2
					elseif not tap(self, "DETAILS") then
						assert(
							tap(self, "NEXT"),
							"Native unit action is reachable through the inspector"
						)
					end
				else
					assert(
						self.source
							and self.source.unitID == unitActionUnitID
							and #self.reachable > 0,
						"Queued native action click arms legal movement"
					)
					assert(self.panel == "context", "Unit action returns to the normal game view")
					unitActionsVerified = true
					unitActionsStep = 3
				end
				return
			end
			if includeRoutes and stage == 2 and not options.handoff and routeStep < 5 then
				if routeStep == 0 then
					local Hex = dofile("/games/civcraft/hex.lua")
					local Routes = dofile("/games/civcraft/queued_routes.lua")
					local Systems = dofile("/games/civcraft/systems.lua")
					for _, unit in ipairs(state.units) do
						if unit.owner == observer and unit.kind == "warrior" then
							for y = 1, state.world.height do
								for x = 1, state.world.width do
									if Hex.distance(unit.x, unit.y, x, y) == 3 then
										local path =
											Routes.preview(state, unit, x, y, false, Systems)
										if path and #path > unit.movesLeft + 1 then
											routeUnit, routeGoal = unit.id, { x = x, y = y }
											break
										end
									end
								end
								if routeGoal then
									break
								end
							end
							if routeGoal then
								self:focus("unit", unit)
								break
							end
						end
					end
					assert(
						routeGoal,
						"Native route scenario needs a known distant land destination"
					)
					routeStep = 1
					os.queueEvent("term_resize")
				elseif routeStep == 1 then
					if tap(self, "QUEUE MOVES") then
						routeStep = 2
					elseif not tap(self, "DETAILS") then
						tap(self, "NEXT")
					end
				elseif routeStep == 2 then
					self:tile(routeGoal.x, routeGoal.y)
					assert(self.pendingMove and self.pendingMove.queued)
					routeStep = 3
					os.queueEvent("term_resize")
				elseif routeStep == 3 then
					if tap(self, "CONFIRM") then
						routeStep = 4
					end
				else
					for _, unit in ipairs(state.units) do
						if unit.id == routeUnit then
							assert(
								unit.moveQueue
									and unit.moveQueue.goals[1].x == routeGoal.x
									and unit.moveQueue.goals[1].y == routeGoal.y
									and #unit.moveQueue.path >= 2,
								"Queued route retains its future goal, including a higher-cost step wait"
							)
							routeRecord = { id = unit.id, x = unit.x, y = unit.y, goal = routeGoal }
						end
					end
					assert(routeRecord, "Native route command must retain a future leg")
					routeStep = 5
					os.queueEvent("term_resize")
				end
				return
			end
			if includeCivilization and stage == 1 and civilizationStep < 2 then
				local label = civilizationStep == 0 and "CIV" or "DESERT WANDERERS"
				if tap(self, label) then
					civilizationStep = civilizationStep + 1
				else
					tap(self, "NEXT")
				end
				return
			end
			if includeCivilization and stage == 1 and civilizationStep == 2 then
				assert(
					options.hasSave,
					"Saved lobby choices must require overwrite confirmation later"
				)
			end
			if
				includeQuickResearch
				and stage == 2
				and not options.handoff
				and quickResearchStep < 4
			then
				if quickResearchStep == 0 then
					assert(tap(self, "QUICK RESEARCH"), "Science strip opens quick selection")
					quickResearchStep = 1
				elseif quickResearchStep == 1 then
					assert(self.panel == "quickResearch", "Queued input opens eligible research")
					if tap(self, "RESEARCH mining") then
						quickResearchStep = 2
					else
						assert(
							quickPages < 64 and tap(self, "NEXT"),
							"Available technology remains reachable"
						)
						quickPages = quickPages + 1
					end
				elseif quickResearchStep == 2 then
					local target
					for _, candidate in ipairs(state.players) do
						if candidate.id == observer then
							target = candidate
						end
					end
					assert(
						target and target.researchTarget == "mining",
						"Queued quick choice reaches research authority"
					)
					assert(tap(self, "TECH TREE"), "Full tree remains available")
					quickResearchStep = 3
				else
					assert(
						self.panel == "tech" and tap(self, "CLOSE"),
						"Quick selection retains full-tree navigation"
					)
					quickResearchStep = 4
					quickResearchVerified = true
				end
				return
			end
			if includeResearch and stage == 2 and not options.handoff and researchStep < 7 then
				local labels = {
					"TECH TREE",
					"agriculture",
					dofile("/games/civcraft/content_rules.lua").hasBuilders(state)
							and "CODEX WHEAT FIELD"
						or "CODEX WHEAT FARM",
					"CLOSE",
					"TECH TREE",
					"RESEARCH",
					"CLOSE",
				}
				local label = labels[researchStep + 1]
				if tap(self, label) or label == "DETAILS" and tap(self, "DETAILS / CODEX") then
					researchStep = researchStep + 1
				else
					if label == "agriculture" then
						researchNavigation = researchNavigation + 1
						assert(
							researchNavigation <= 64,
							"Full tree must retain access to Agriculture after switching research"
						)
						tap(self, researchNavigation % 2 == 0 and "LEFT" or "UP")
					else
						tap(self, label == "RESEARCH" and "PREV" or "NEXT")
					end
				end
				return
			end
			if
				includeContactHUD
				and stage == 2
				and not options.handoff
				and contactBadgeStep < 3
			then
				local target = state.players[includeHost and 2 or 3]
				assert(target, "Native contact HUD scenario needs its conversation target")
				assert(
					self.playerID == observer,
					"Contact navigation begins under the current human observer"
				)
				if contactBadgeStep == 0 then
					local label
					for _, candidate in ipairs(self.r.buttons) do
						if
							candidate.label == "KNOWN CIVILIZATIONS"
							or candidate.label
								and candidate.label:find("^MORE KNOWN CIVILIZATIONS")
						then
							label = candidate.label
							break
						end
					end
					assert(
						label and tap(self, label),
						"Native compact HUD shows a known-civilization contact entry"
					)
					contactBadgeStep = 1
				elseif contactBadgeStep == 1 then
					assert(self.panel == "factions", "The queued HUD event opens known Factions")
					local talk = "TALK " .. target.name
					if tap(self, talk) then
						contactBadgeStep = 2
					else
						assert(
							tap(self, "NEXT") and contactFactionPages < 64,
							"The known contact stays reachable through Factions pagination"
						)
						contactFactionPages = contactFactionPages + 1
					end
				else
					assert(
						self.panel == "conversation"
							and self.conversationTarget == target.id
							and self.playerID == observer,
						"Queued mouse events open the known contact under the active human"
					)
					contactBadgeVerified = true
					contactBadgeStep = 3
					conversationStep = 2
				end
				return
			end
			if
				includeConversation
				and stage == 2
				and not options.handoff
				and conversationStep < 14
			then
				local labels = {
					"FACTIONS",
					includeHost and "TALK AI 2" or "TALK PLAYER 3",
					"GREET",
					"AGREEMENTS",
					"PROPOSE",
					"COMMERCE",
					"VIEW",
					"SEND OFFER",
					"DEALS",
					"REVIEW TRADE",
					"SEND TRADE",
					"TALK",
					"CLOSE",
					"CLOSE",
				}
				if tap(self, labels[conversationStep + 1]) then
					conversationStep = conversationStep + 1
				else
					tap(self, "NEXT")
				end
				return
			end
			if includeMapTools and stage == 2 and not options.handoff and mapToolsStep < 7 then
				local labels = {
					"MAP TOOLS",
					"ZOOM IN",
					"MAP TOOLS",
					"ZOOM OUT",
					"MAP TOOLS",
					"WORLD OVERVIEW",
					"CLOSE",
				}
				if self.r.h >= 100 then
					mapToolsStep, mapToolsVerified = 7, true
				elseif tap(self, labels[mapToolsStep + 1]) then
					mapToolsStep = mapToolsStep + 1
					mapToolsVerified = mapToolsStep == 7
				else
					tap(self, "NEXT")
				end
				return
			end
			if includeCouncil and stage == 2 and not options.handoff and councilStep < 6 then
				local labels = { "COUNCIL", "ELECTION", "ABSTAIN", "AGENDA", "STATUS", "CLOSE" }
				if councilStep == 3 then
					assert(
						state.council.session.ownElection.candidate == false,
						"Native Council ballot must reach the host"
					)
					councilVerified = true
				end
				if tap(self, labels[councilStep + 1]) then
					councilStep = councilStep + 1
				else
					tap(self, "NEXT")
				end
				return
			end
			if includeHistory and stage == 2 and not options.handoff and historyStep < 3 then
				local labels = { "EVENT LOG", "RECENT", "CLOSE" }
				if historyStep == 1 then
					assert(self.panel == "history" and #self.historyPage.entries > 0)
					historySeq = self.historyPage.lastSeq
				elseif historyStep == 2 then
					assert(
						not self.historyLoading and self.historyPage.lastSeq == historySeq,
						"The host serves private history without creating an action or changing the turn"
					)
					historyVerified = true
				end
				if tap(self, labels[historyStep + 1]) then
					historyStep = historyStep + 1
				else
					tap(self, "NEXT")
				end
				return
			end
			if includeWar and stage == 5 and not options.handoff and warStep < 3 then
				local labels = { "FACTIONS", "SURPRISE WAR: " .. state.players[1].name, "CLOSE" }
				if tap(self, labels[warStep + 1]) then
					warStep = warStep + 1
				else
					tap(self, "NEXT")
				end
				return
			end
			if includeWar and stage == 7 and state.round == 1 then
				local label = options.handoff and "READY TO PLAY"
					or responseStep == 1 and "PAUSE"
					or options.paused and responseStep == 2 and "SAVE"
					or options.paused and responseStep == 3 and "RESUME"
					or self.endConfirm and "END ANYWAY"
					or "END TURN"
				if options.paused and responseStep == 3 then
					local saved = native("/games/civcraft/saves.lua").load(1)
					assert(
						saved.round == 1
							and saved.players[1].ready
							and saved.scheduler.reactions[saved.players[1].id],
						"Mid-response save retains the Ready defender's window"
					)
					responseSaved = true
				end
				if not options.handoff then
					assert(
						state.players[1].ready and state.scheduler.reactions[state.players[1].id],
						"Ended defender must receive an unspent-action response before the round closes"
					)
				end
				if label == "END TURN" then
					if completeDecisions(self) then
						responseStep = responseStep + 1
					end
				elseif tap(self, label) then
					responseStep = responseStep + 1
				end
				return
			end
			if
				(stage == 2 or stage == 5)
				and state.phase == "game"
				and not options.handoff
				and not options.paused
			then
				if completeDecisions(self) then
					stage = stage + 2
				end
				return
			end
			local label
			if stage == 0 and options.screen == "title" then
				if self.titleMenu == "new" then
					label = "CREATE CAMPAIGN"
				else
					tap(self, "NEW CAMPAIGN")
					return
				end
			elseif stage == 1 and state.phase == "lobby" then
				label = "START GAME"
			elseif stage == 2 and state.phase == "game" and not options.handoff then
				label = "END TURN"
			elseif stage == 3 and self.endConfirm then
				label = "END ANYWAY"
			elseif includeHost and stage == 4 and state.round == 2 then
				label = "PAUSE"
			elseif includeHost and stage == 5 and options.paused then
				label = "SAVE"
			elseif includeHost and stage == 6 and options.paused then
				label = "EXIT"
			elseif stage == 4 and options.handoff then
				label = "READY TO PLAY"
			elseif stage == 5 and not options.handoff then
				label = "END TURN"
			elseif stage == 6 and self.endConfirm then
				label = "END ANYWAY"
			elseif stage == 7 and options.handoff and state.round == 2 then
				label = "READY TO PLAY"
			elseif stage == 8 and not options.handoff and state.round == 2 then
				if self.panel == "report" then
					tap(self, "CLOSE")
					return
				end
				label = "PAUSE"
			elseif stage == 9 and options.paused then
				label = "SAVE"
			elseif stage == 10 and options.paused then
				label = "EXIT"
			end
			if label and tap(self, label) then
				stage = stage + 1
			elseif label then
				tap(self, "NEXT")
			end
		end
		return view
	end
	return module
end
local completed = false
local timeout = os.startTimer(45)
local success, reason = pcall(function()
	parallel.waitForAny(function()
		assert(loadfile("/games/civcraft/game.lua", "t", _ENV))(
			includeHost and "host" or "local",
			"--new",
			"--debug"
		)
		completed = true
	end, function()
		while true do
			local event, timer = os.pullEvent()
			if event == "timer" and timer == timeout then
				error("Native game session timed out at stage " .. stage)
			end
		end
	end)
end)
dofile = native
if term.setGraphicsMode then
	pcall(term.setGraphicsMode, 0)
end
if touchMonitor then
	_G.periphemu.remove("top")
end
assert(success, reason)
assert(
	completed and stage == (includeHost and 7 or 11),
	"Session did not complete its turns and return to round two"
)
local state
if includeHost then
	local file = assert(fs.open("/games/civcraft/data/save.dat", "r"))
	state = textutils.unserialize(file.readAll())
	file.close()
else
	state = native("/games/civcraft/saves.lua").load(1)
end
assert(
	state
		and state.round == 2
		and (includeHost or state.activeIndex == (includeWar and 2 or 1))
		and state.campaignID
)
if includeWar then
	assert(responseSaved, "The native response scenario must save during the response window")
	assert(
		#state.diplomacy.wars == 1 and state.diplomacy.wars[1].active,
		"Native Surprise War must survive response, round rotation and save reload"
	)
	assert(
		state.scheduler.groups[1].active == state.players[2].id,
		"The defending group's starting player rotates at the global boundary"
	)
end
if includeDevelopment then
	assert(
		state.contentRules == developmentProfile,
		"Development profile must survive native save/reload"
	)
end
if includeDefaultSpecialization then
	assert(
		state.contentRules == "balance5"
			and state.players[1].contentRules == "balance5"
			and state.players[2].contentRules == "balance5",
		"The V5 default must reach the started campaign and every player record"
	)
end
if includeCampaign then
	assert(
		state.gameSpeed == "quick"
			and state.roundLimit == (dofile("/games/civcraft/content_rules.lua").isRedesign(state) and 167 or 120)
			and (
				dofile("/games/civcraft/content_rules.lua").isRedesign(state)
					and dofile("/games/civcraft/campaign_rules.lua").enabled(state, "score")
				or state.victories.score == false
			),
		"Native lobby options must survive round processing and save reload"
	)
	assert(state.players[1].gameSpeed == "quick", "The campaign pace must reach gameplay costs")
end
if includeResearch then
	assert(
		state.players[1].researchTarget == "agriculture" or state.players[1].techs.agriculture,
		"Native graph, details and Codex flow must preserve the selected research order"
	)
end
if includeAI then
	local ai = state.players[includeHost and 2 or 3]
	assert(
		ai.ai and ai.aiPlan and ai.aiPlan.version == 1,
		"Native game session must execute and persist the third player's economic AI"
	)
end
if includeConversation then
	local acceptedTrade, commerce = false, false
	for _, offer in ipairs(state.diplomacy.offers) do
		acceptedTrade = acceptedTrade or offer.kind == "trade" and offer.status == "accepted"
	end
	for _, treaty in ipairs(state.diplomacy.treaties) do
		commerce = commerce or treaty.kind == "commerce" and treaty.status == "active"
	end
	assert(
		acceptedTrade and commerce,
		"Native conversations must execute their actual trade and commerce terms"
	)
end
assert(
	not includeContactHUD or contactBadgeVerified,
	"Native compact contact entry uses queued input and continues the conversation flow"
)
if includeSettings then
	local preferences = native("/games/civcraft/animation_preferences.lua").load()
	assert(
		preferences.display == settingsExpectedDisplay
			and preferences.speed == settingsExpectedSpeed,
		"Native settings must persist across renderer recreation"
	)
end

for _, participant in ipairs(state.players) do
	if not participant.ai then
		assert(
			participant.researchTarget or next(participant.techs),
			"Human turn workflow assigns research"
		)
		local skipped = false
		local routed = false
		for _, unit in ipairs(state.units) do
			if unit.owner == participant.id and unit.skippedTurn then
				skipped = true
			end
			if
				includeRoutes
				and routeRecord
				and unit.owner == participant.id
				and unit.id == routeRecord.id
			then
				routed = true
			end
		end
		assert(skipped or routed, "Human turn workflow saves an actual Skip Turn or route order")
		for _, city in ipairs(state.cities) do
			if city.owner == participant.id then
				assert(city.project or city.productionIdle, "Human cities resolve production")
			end
		end
	end
end
if includeRoutes then
	assert(routeRecord)
	local resumed = false
	for _, unit in ipairs(state.units) do
		if unit.id == routeRecord.id then
			local eligible = native("/games/civcraft/turn_scheduler.lua").canAct(state, unit.owner)
			if eligible then
				assert(
					unit.x ~= routeRecord.x or unit.y ~= routeRecord.y,
					"The host must resume a saved movement route when the next eligible turn starts"
				)
				routeResumed = true
			else
				assert(
					unit.moveQueue and unit.movesLeft > 0,
					"A route waits for its war-group activation without spending the new round budget"
				)
			end
			assert(unit.x == routeRecord.goal.x and unit.y == routeRecord.goal.y or unit.moveQueue)
			resumed = true
		end
	end
	assert(resumed, "Native queued actor survives the save reload")
end
if includeDifficulty then
	local found
	for _, player in ipairs(state.players) do
		if player.ai then
			assert(player.aiDifficulty == "deity")
			found = true
			break
		end
	end
	assert(found, "AI difficulty must survive the full session and save reload")
end
assert(not includeMapTools or mapToolsVerified, "Native short-screen map tools must complete")
assert(
	not includeDefaultSpecialization or defaultSpecializationVerified,
	"Native new-campaign flow must verify the unmodified Specialization V5 default"
)
assert(not includeCouncil or councilVerified, "Native Council ballot must complete")
if includeCouncil then
	assert(state.council.lastRound == state.round, "Council advances at the real round boundary")
	assert(
		state.council.session.election[state.players[1].id].candidate == false,
		"Council ballot survives saving and reloading"
	)
end
assert(not includeHistory or historyVerified, "Native history refresh must complete")
local Events = native("/games/civcraft/events.lua")
if includeCivilization then
	assert(state.players[1].civ == "nomad", "Dropdown selection must persist in the campaign save")
end
assert(Events.forPlayer(state, state.players[1].id).lastSeq > 0)
assert(Events.forPlayer(state, state.players[2].id).lastSeq > 0)
assert(not includeQuickResearch or quickResearchVerified, "Requested quick research input must run")
assert(not includeUnitBadges or unitBadgesVerified, "Requested normal-program badge input must run")
assert(
	not includeUnitActions or unitActionsVerified,
	"Requested normal-program unit-action input must run"
)
local output = assert(fs.open("/civcraft-native-session.txt", "w"))
output.write(textutils.serialize({
	host = _G._HOST,
	renderer = renderer,
	stages = stage,
	round = state.round,
	contentRules = state.contentRules,
	defaultSpecialization = defaultSpecializationVerified,
	roundLimit = state.roundLimit,
	industrialEnabled = dofile("/games/civcraft/campaign_rules.lua").enabled(state, "industrial"),
	diplomaticEnabled = dofile("/games/civcraft/campaign_rules.lua").enabled(state, "diplomatic"),
	scoreEnabled = dofile("/games/civcraft/campaign_rules.lua").enabled(state, "score"),
	saveReload = true,
	turnTasks = true,
	aiPlanReload = includeAI,
	settingsReload = includeSettings,
	researchFlow = includeResearch,
	quickResearchFlow = quickResearchVerified,
	campaignOptions = includeCampaign,
	warResponse = includeWar,
	responseSaved = responseSaved,
	hostModeAI = includeHost,
	conversationFlow = includeConversation,
	contactHUDFlow = contactBadgeVerified,
	queuedRouteFlow = includeRoutes,
	unitBadgeFlow = unitBadgesVerified,
	unitActionFlow = unitActionsVerified,
	eventHistoryFlow = historyVerified,
	councilFlow = councilVerified,
	mapToolsFlow = mapToolsVerified,
	difficultyFlow = includeDifficulty,
	queuedRouteResumed = routeResumed,
}))
output.close()
print(
	"CIVCRAFT native session: real mouse queue, full host loop, two hotseat turns, reports, pause, save and exit passed."
)
