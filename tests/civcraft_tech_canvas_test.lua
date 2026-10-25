local nativeDofile = dofile
dofile = function(path)
	if path:sub(1, 16) == "/games/civcraft/" then
		return nativeDofile(path:sub(2))
	end
	return nativeDofile(path)
end
local S = assert(loadfile("games/civcraft/systems.lua"))()
local Tree = assert(loadfile("games/civcraft/tech_tree.lua"))()
local player = { techs = {}, science = 100 }
local buttons, strokes = {}, 0
local r = { buttons = buttons }
function r:fill(...)
	strokes = strokes + 1
end
function r:outline(...)
	strokes = strokes + 1
end
function r:icon(...)
	strokes = strokes + 1
end
function r:text(...) end
function r:button(x, y, w, h, label, fn)
	buttons[#buttons + 1] = { x = x, y = y, w = w, h = h, label = label, fn = fn }
end
local picked, closed = nil, false
local model = {}
local viewport = { x = 5, y = 5, w = 480, h = 268 }
Tree.draw(r, S, player, viewport, model, function(id)
	picked = id
end, function()
	closed = true
end)
assert(#S.techOrder >= 20, "Expanded prerequisite graph")
assert(strokes > 100, "Graph renders actual links and nodes")
local node
for _, b in ipairs(buttons) do
	if b.label == "agriculture" then
		node = b
		break
	end
end
assert(node, "A starting technology appears as a clickable graph node")
node.fn()
assert(model.selected == "agriculture")
buttons = {}
r.buttons = buttons
Tree.draw(r, S, player, viewport, model, function(id)
	picked = id
end, function()
	closed = true
end)
local research
for _, b in ipairs(buttons) do
	if b.label == "RESEARCH" then
		research = b
	end
end
assert(research, "Available technology has a research button")
research.fn()
assert(picked == "agriculture")
local right
for _, b in ipairs(buttons) do
	if b.label == "RIGHT" then
		right = b
	end
end
assert(right, "Panning arrows appear")
right.fn()
assert(model.panX > 0, "Graph can pan to late technologies")
local zoom
for _, b in ipairs(buttons) do
	if b.label == "ZOOM+" then
		zoom = b
	end
end
assert(zoom)
zoom.fn()
assert(model.zoom > 1, "Technology canvas supports zoom")
local Details = dofile("/games/civcraft/research_details.lua")
for _, id in ipairs(S.techOrder) do
	local paragraphs = Details.paragraphs(S, id)
	assert(#paragraphs >= 3 and #paragraphs[1] >= 50, "Every technology explains its purpose")
	for _, entry in ipairs(Details.unlocks(S, id)) do
		assert(entry.record.tech == id and entry.category and entry.id)
	end
end
function r:textWidth(value)
	return #tostring(value) * 4
end
for _, mode in ipairs({ "text", "graphics" }) do
	r.mode = mode
	local small = { x = 3, y = 3, w = 96, h = 51 }
	local compact = { selected = "agriculture" }
	local function redraw()
		buttons = {}
		r.buttons = buttons
		Tree.draw(r, S, player, small, compact, function(id)
			picked = id
		end, function() end, function(category, id)
			picked = category .. ":" .. id
		end)
	end
	redraw()
	assert(compact.dragMode == "graph", "Small screens retain a connected graph")
	local detailButton, graphNode, rightButton
	for _, button in ipairs(buttons) do
		assert(button.x >= small.x and button.x + button.w <= small.x + small.w)
		assert(button.y >= small.y and button.y + button.h <= small.y + small.h)
		if button.label == "DETAILS" then
			detailButton = button
		end
		if button.label == "agriculture" then
			graphNode = button
		end
		if button.label == "RIGHT" then
			rightButton = button
		end
	end
	assert(
		graphNode and detailButton and rightButton,
		"Graph nodes, details and pan remain reachable"
	)
	rightButton.fn()
	assert(compact.panX > 0)
	detailButton.fn()
	redraw()
	assert(
		compact.detail and compact.dragMode == "list",
		"Only the detailed description scrolls as text"
	)
	local found = false
	for offset = 0, compact.pageMax do
		compact.offset = offset
		redraw()
		for _, button in ipairs(buttons) do
			if button.label == "CODEX WHEAT FARM" then
				button.fn()
				assert(
					picked == "buildings:farm",
					"Unlock link opens the corresponding Codex entry"
				)
				found = true
			end
		end
	end
	assert(found, "Technology details provide actual project links")
end
print("CIVCRAFT: scrollable technology graph, prerequisites, research buttons and zoom passed.")
