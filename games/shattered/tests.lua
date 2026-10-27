-- SHATTERED: KINGDOMS v2.1 offline integration and regression tests
-- Usage: texlua tests.lua  (requires no CC:Tweaked runtime)
local path = (arg and arg[0] or "tests.lua"):match("^(.*[/\\])") or "./"
local A = assert(loadfile(path .. "shattered.lua"))("--test-api")
local checks = 0
local function ck(cond, why)
	checks = checks + 1
	if not cond then
		error("FAILED #" .. checks .. " " .. why, 2)
	end
end
local function mock(w, h)
	local m = { w = w, h = h, rows = {}, blits = 0 }
	function m.getSize()
		return m.w, m.h
	end
	function m.setCursorPos(x, y)
		ck(x == 1 and y >= 1 and y <= m.h, "blit cursor off screen")
		m.cy = y
	end
	function m.blit(c, f, bg)
		ck(#c == m.w and #f == m.w and #bg == m.w, "bad width")
		ck(c:find("[^ -~]") == nil, "control or non-ascii char")
		ck(f:find("[^0-9a-f]") == nil and bg:find("[^0-9a-f]") == nil, "invalid colour code")
		m.rows[m.cy] = { c, f, bg }
		m.blits = m.blits + 1
	end
	return m
end
local sizes = {
	{ 48, 35, "compact 3x3" },
	{ 57, 38, "3x3" },
	{ 65, 50, "compact 4x4" },
	{ 78, 52, "4x4" },
	{ 82, 63, "compact 5x5" },
	{ 98, 68, "5x5" },
}
local function findButton(ui, label)
	for _, bt in ipairs(ui.buttons) do
		if bt.tag == label then
			return bt
		end
	end
	return nil
end
local function click(ui, label)
	local bt = findButton(ui, label)
	ck(bt ~= nil, "missing button " .. label .. " on " .. tostring(ui.page))
	return A.touch(ui, bt.x + math.floor((bt.w - 1) / 2), bt.y + math.floor((bt.h - 1) / 2))
end
local function redraw(m, ui)
	A.render(m, ui, A.clock())
	for _, bt in ipairs(ui.buttons) do
		ck(
			bt.x >= 1 and bt.y >= 1 and bt.x + bt.w - 1 <= m.w and bt.y + bt.h - 1 <= m.h,
			"offscreen button " .. bt.tag .. " on " .. ui.page .. " at " .. m.w .. "x" .. m.h
		)
	end
end
local function isKind(t)
	return ({ water = true, forest = true, plain = true, hill = true, mountain = true })[t.kind]
end
local function findClaim(g)
	for y = 1, g.h do
		for x = 1, g.w do
			if A.legal(g, "claim", x, y) then
				return x, y
			end
		end
	end
end
-- Generate at varied dimensions and seeds: terrain symmetry and game economy.
for seed = 1, 100 do
	for _, style in ipairs({ "land", "isles" }) do
		local w = 10 + seed % 9
		local h = 9 + seed % 9
		local g = A.makeGame(9123 * seed, w, h, { "Alice", "Bob" }, style, 30)
		ck(A.validSave(g), "fresh game save validation")
		local holdings = { 0, 0 }
		for y = 1, h do
			for x = 1, w do
				local t = A.tile(g, x, y)
				local mirror = A.tile(g, w + 1 - x, h + 1 - y)
				ck(isKind(t), "bad terrain")
				ck(t.kind == mirror.kind, "asymmetric terrain at " .. x .. "," .. y)
				if t.owner > 0 then
					holdings[t.owner] = holdings[t.owner] + 1
				end
			end
		end
		ck(holdings[1] == 3 and holdings[2] == 3, "unequal initial territory")
		local a, b = A.income(g, 1), A.income(g, 2)
		ck(
			a.food == b.food and a.wood == b.wood and a.stone == b.stone,
			"unequal opening production"
		)
		ck(a.score == b.score, "unequal initial prestige")
		ck(findClaim(g) ~= nil, "no opening expansion option")
	end
end
-- Rules: resources, turn progression, invalid actions, and battle.
do
	local g = A.makeGame(700, 11, 11, { "Alice", "Bob" }, "land", 20)
	local x, y = findClaim(g)
	local ap = g.ap
	ck(not A.legal(g, "claim", 1, 1, 2, 2), "invalid distant claim")
	ck(not A.act(g, "claim", 1, 1, 2, 2), "invalid action was accepted")
	ck(g.ap == ap, "invalid action consumed action point")
	ck(A.act(g, "claim", x, y), "legal claim failed")
	ck(g.ap == ap - 1 and A.tile(g, x, y).owner == 1, "claim did not change province")
	local ap2 = g.ap
	ck(A.act(g, "found", x, y), "found settlement failed")
	ck(g.ap == ap2 - 1 and A.tile(g, x, y).city == 1, "found did not change state")
	A.endTurn(g)
	ck(g.turn == 2 and g.round == 1, "red-to-blue turn progression")
	A.endTurn(g)
	ck(g.turn == 1 and g.round == 2, "round rollover")
	ck(g.score[1] >= 2 and g.score[2] >= 2, "no round prestige")
	g.ap = 3
	g.stock[1].food = 20
	local from = A.tile(g, 5, 5)
	local to = A.tile(g, 6, 5)
	from.owner = 1
	from.kind = "plain"
	from.army = 9
	to.owner = 2
	to.kind = "plain"
	to.army = 0
	to.fort = 0
	to.city = 0
	to.capital = false
	ck(A.legal(g, "attack", 5, 5, 6, 5), "combat should be legal")
	ck(A.act(g, "attack", 5, 5, 6, 5), "legal combat failed")
	ck(to.owner == 1, "superior force did not capture empty tile")
	ck(not A.legal(g, "attack", 5, 5, 9, 5), "nonadjacent attack allowed")
	local bad = A.copy(g)
	bad.version = 1
	ck(not A.validSave(bad), "wrong version accepted")
end
-- Integrated monitor and player flow on three monitor block sizes (plus compact variants).
for _, sz in ipairs(sizes) do
	local w, h = sz[1], sz[2]
	local m = mock(w, h)
	local ui = A.newUI(w, h)
	redraw(m, ui)
	click(ui, "NEW KINGDOMS")
	ck(ui.page == "setup", "new game didn't open setup")
	redraw(m, ui)
	-- Completely touch-enter both player names, including CLEAR, NEXT and SPACE.
	click(ui, "CLEAR")
	redraw(m, ui)
	click(ui, "A")
	redraw(m, ui)
	click(ui, "D")
	redraw(m, ui)
	click(ui, "A")
	ck(ui.setup.names[1] == "ADA", "touch keyboard P1 name")
	redraw(m, ui)
	click(ui, "NEXT")
	redraw(m, ui)
	click(ui, "CLEAR")
	redraw(m, ui)
	click(ui, "B")
	redraw(m, ui)
	click(ui, "E")
	redraw(m, ui)
	click(ui, "N")
	ck(ui.setup.names[2] == "BEN", "touch keyboard P2 name")
	redraw(m, ui)
	click(ui, "ISLANDS")
	redraw(m, ui)
	click(ui, "SWIFT / 20")
	redraw(m, ui)
	click(ui, "START GAME")
	ck(ui.page == "game" and ui.game and A.validSave(ui.game), "new match not created")
	ck(ui.game.names[1] == "ADA" and ui.game.names[2] == "BEN", "name transfer")
	local mw, mh = A.mapSize(w, h)
	ck(ui.game.w == mw and ui.game.h == mh, "world dimension incorrect on " .. sz[3])
	ck(ui.game.style == "isles" and ui.game.target == 20, "setup choices not applied")
	redraw(m, ui)
	local tx, ty = findClaim(ui.game)
	local px, py = A.tcenter(ui.game, tx, ty, w, h)
	ck(py > 3, "claim candidate under header")
	A.touch(ui, px, py)
	ck(ui.sel and ui.sel.x == tx and ui.sel.y == ty, "tap didn't select tile")
	redraw(m, ui)
	ck(findButton(ui, "CLAIM F1 W1") ~= nil, "claim button missing")
	click(ui, "CLAIM F1 W1")
	ck(ui.game.ap == 2 and A.tile(ui.game, tx, ty).owner == 1, "claim touch didn't act")
	redraw(m, ui)
	click(ui, "MENU")
	ck(ui.page == "menu", "menu from game failed")
	redraw(m, ui)
	click(ui, "CONTINUE")
	ck(ui.page == "game", "continue failed")
	redraw(m, ui)
	click(ui, "END TURN")
	ck(ui.game.turn == 2 and ui.game.ap == 3, "END TURN failed")
	redraw(m, ui)
	click(ui, "MENU")
	redraw(m, ui)
	click(ui, "NEW KINGDOMS")
	redraw(m, ui)
	click(ui, "START GAME")
	ck(ui.page == "confirm", "saved-match confirmation missing")
	redraw(m, ui)
	click(ui, "KEEP SAVE")
	ck(ui.page == "setup" and ui.game.turn == 2, "keep-save failed")
	redraw(m, ui)
	click(ui, "START GAME")
	redraw(m, ui)
	click(ui, "REPLACE")
	ck(ui.page == "game" and ui.game.turn == 1, "replace save failed")
	-- Fresh game can tap the full bottom edge, not blocked by permanent footer.
	redraw(m, ui)
	local rx, ry = A.tcenter(ui.game, ui.game.w, ui.game.h, w, h)
	A.touch(ui, rx, h)
	ck(ui.sel and ui.sel.y == ui.game.h, "last board row not selectable")
	-- Resizing stretches the existing map and regenerates touch geometry.
	m.w, m.h = w + 6, h + 4
	redraw(m, ui)
	ck(ui.size[1] == w + 6 and ui.size[2] == h + 4, "resize not reflected")
	ck(A.validSave(ui.game), "resize damaged game state")
end
print("SHATTERED KINGDOMS v2.1: " .. checks .. " independent checks passed")
