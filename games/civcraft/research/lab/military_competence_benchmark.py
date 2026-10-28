#!/usr/bin/env python3
"""Research-only military competence benchmark.

The full-game arm keeps the real ActorLifecycle/Systems.aiTurn path and adds a
bounded, quality-aware ranking hook around the existing Production.ranked
function. It does not inject orders, resources, units, declarations or
movement. The fixture arm only prepares a controlled state; all measured
orders still pass through Engine.pump and Engine.applyAction.

Importing this module does not run a match. Expensive modes are explicit.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import platform
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools/civcraft_lab"))


def source_manifest():
    from runner import source_manifest as manifest

    return manifest()


def _driver_hash() -> str:
    return hashlib.sha256(Path(__file__).read_bytes()).hexdigest()


class MilitaryHookRuntime:
    """Runtime subclass that only re-ranks already legal AI production."""

    def __new__(cls, config, *args, **kwargs):
        from runtime import Runtime

        runtime = Runtime(config, *args, **kwargs)
        cls._install_hook(runtime, config)
        return runtime

    @staticmethod
    def _install_hook(runtime, config=None) -> None:
        # AI.lua retains this same module table in its local Production upvalue.
        # Bracket access avoids Python's class-scope name mangling for the
        # double-underscore Lua global.
        cache = runtime.lua.globals()["__civcraftModuleCache"]
        production = cache["/games/civcraft/ai_production.lua"]
        original = production.ranked
        wrapper = runtime.lua.eval(
            """function(original)
                return function(view, player, city, systems, canExpand)
                    local choices, context = original(view, player, city, systems, canExpand)
                    local plan = player.aiPlan or {}
                    local campaign = plan.campaign or {}
                    if plan.primary ~= "conquest" or campaign.kind ~= "city" then
                        return choices, context
                    end
                    for _, choice in ipairs(choices) do
                        if choice.kind == "unit" then
                            local stats = systems.units[choice.id] or {}
                            local bonus = 0
                            local noTarget = true
                            for _, knownCity in ipairs(view.cities or {}) do
                                if knownCity.owner ~= player.id and not knownCity.village then noTarget = false end
                            end
                            if noTarget and (choice.id == "scout" or choice.id == "explorer") then
                                -- A visible-state exploration intervention: the
                                -- normal candidate and normal recruit validator
                                -- still decide whether a scout can be queued.
                                bonus = 100
                            end
                            -- Preserve the live one-siege policy, but avoid a
                            -- legal siege candidate losing to a small speed gain.
                            if stats.siege and campaign.needsSiege then
                                bonus = math.max(bonus, 35)
                            elseif stats.siege then
                                bonus = math.max(bonus, 8)
                            elseif not stats.naval and not stats.engineer
                                and choice.id ~= "settler" then
                                -- Bounded quality signal; original affordability,
                                -- upkeep, resource, tech and quota checks remain.
                                bonus = math.max(bonus, math.min(12,
                                    (stats.strength or 0) * 0.35
                                        + (stats.defense or 0) * 0.2))
                            end
                            choice.score = choice.score + bonus
                        end
                    end
                    -- Production.ranked intentionally omits a legal unit when
                    -- the old soldier quota is full (unitValue == 0). For a
                    -- conquest campaign, append only the best *already legal*
                    -- modern-quality recruit so this offline hook can test
                    -- quality transition rather than merely more bodies.
                    local quota = math.min(8, (context.cities or 0) + 3)
                    local soldiers = 0
                    local seen = {}
                    for _, choice in ipairs(choices) do
                        seen[choice.kind .. ":" .. choice.id] = true
                    end
                    for _, unit in ipairs(view.units or {}) do
                        if unit.owner == player.id then
                            local stats = systems.units[unit.kind] or {}
                            if not stats.naval and not stats.engineer
                                and not stats.healer and unit.kind ~= "settler"
                            then soldiers = soldiers + 1 end
                        end
                    end
                    local best, bestQuality
                    if soldiers >= quota then
                        local Hex = __civcraftModuleCache["/games/civcraft/hex.lua"]
                        for id, stats in pairs(systems.units) do
                            local quality = (stats.strength or 0) + (stats.defense or 0)
                            local modern = quality >= 12 and not stats.naval
                                and not stats.engineer and not stats.healer
                                and not stats.siege and id ~= "settler"
                            local legal = modern and not seen["unit:" .. id]
                                and systems.canRecruit(player, id, view, Hex, city)
                                and (context.treasury.net >= (stats.upkeep or 1)
                                    or (player.gold or 0) >= math.max(20,
                                        ((stats.upkeep or 1) - context.treasury.net) * 8))
                            if legal and (not bestQuality or quality > bestQuality
                                or quality == bestQuality and id < best) then
                                best, bestQuality = id, quality
                            end
                        end
                    end
                    if best then
                        local stats = systems.units[best]
                        local cost = systems.projectCost("unit", best, player)
                        local turns = math.max(1, math.ceil(cost /
                            math.max(1, context.yields.industry)))
                        choices[#choices + 1] = {kind="unit", id=best,
                            score=(180 + bestQuality * 12) / (2 + turns), turns=turns}
                    end
                    table.sort(choices, function(a, b)
                        if a.score ~= b.score then return a.score > b.score end
                        return a.kind .. ":" .. a.id < b.kind .. ":" .. b.id
                    end)
                    return choices, context
                end
            end"""
        )
        production.ranked = wrapper(original)
        campaigns = cache["/games/civcraft/ai_campaigns.lua"]
        original_campaigns = campaigns.update
        campaign_wrapper = runtime.lua.eval(
            """function(original)
                return function(view, player, systems)
                    local plan = player.aiPlan or {}
                    local previous = plan.campaign
                    local remembered = plan.__militaryLastEnemyCampaign
                    if previous and previous.kind == "city"
                        and previous.owner ~= player.id
                    then
                        remembered = previous
                        remembered.__rememberedRound = view.round
                        plan.__militaryLastEnemyCampaign = remembered
                    end
                    local roles = original(view, player, systems)
                    local current = plan.campaign
                    -- Cities do not move. Preserve a recently observed enemy
                    -- target through fog for a bounded period, using only the
                    -- AI's existing memory record; no hidden map is read.
                    if plan.primary == "conquest" and remembered
                        and remembered.owner ~= player.id
                        and current and current.kind == "explore"
                        and view.round - (remembered.__rememberedRound
                            or remembered.seenRound or view.round) <= 40
                        and player.contacts and player.contacts[remembered.owner]
                    then
                        current.kind = "city"
                        current.targetID = remembered.targetID
                        current.owner = remembered.owner
                        current.x, current.y = remembered.x, remembered.y
                        current.wallHP = remembered.wallHP or 0
                        current.seenRound = remembered.seenRound
                        current.phase = (current.strength or 0) < 1 and "muster" or "approach"
                        current.muster = remembered.muster or current.muster
                        current.corridor = remembered.corridor or current.corridor
                        current.needsSiege = (current.wallHP or 0) > 0
                        plan.campaign = current
                    end
                    return roles
                end
            end"""
        )
        campaigns.update = campaign_wrapper(original_campaigns)
        if (config or {}).get("timelySiegeResearch"):
            research = cache["/games/civcraft/ai_research.lua"]
            original_research = research.ranked
            research_wrapper = runtime.lua.eval(
                """function(original)
                    return function(view, player, systems)
                        local choices = original(view, player, systems)
                        local plan = player.aiPlan or {}
                        local campaign = plan.campaign or {}
                        local remembered = plan.__militaryLastEnemyCampaign
                        local siegeTarget = campaign.needsSiege and campaign
                        if not siegeTarget and remembered
                            and remembered.owner ~= player.id
                            and (remembered.wallHP or 0) > 0
                            and view.round - (remembered.__rememberedRound
                                or remembered.seenRound or view.round) <= 40
                        then
                            -- Keep researching the observed siege dependency
                            -- while a temporary defensive campaign is active.
                            siegeTarget = remembered
                        end
                        -- Research-only intervention: the ordinary ranked
                        -- candidates, prerequisites and canResearch checks
                        -- remain authoritative. When the live campaign has
                        -- observed fortified target walls, make the existing
                        -- engineering dependency route win the next legal
                        -- choice instead of granting research for free.
                        if plan.primary == "conquest" and siegeTarget
                            and (siegeTarget.wallHP or 0) > 0
                        then
                            for _, choice in ipairs(choices) do
                                if choice.id == "engineering" then
                                    choice.score = choice.score + 100
                                elseif choice.id == "redstone" then
                                    choice.score = choice.score + 80
                                elseif choice.id == "deepmining" then
                                    -- Engineering's live prerequisite chain is
                                    -- deepmining -> redstone -> engineering.
                                    choice.score = choice.score + 60
                                end
                            end
                            table.sort(choices, function(a, b)
                                if a.score ~= b.score then return a.score > b.score end
                                return a.id < b.id
                            end)
                        end
                        return choices
                    end
                end"""
            )
            research.ranked = research_wrapper(original_research)
        tactics = cache["/games/civcraft/ai_tactics.lua"]
        original_tactics = tactics.ranked
        tactics_wrapper = runtime.lua.eval(
            """function(original)
                local Hex = __civcraftModuleCache["/games/civcraft/hex.lua"]
                local Routes = __civcraftModuleCache["/games/civcraft/ai_routes.lua"]
                local function frontierTarget(view, unit, systems)
                    local known = view.world and view.world.tiles or {}
                    local routes = Routes.from(view, unit, systems,
                        {ignoreFriendly=true, maxCost=64})
                    local best, distance
                    for key in pairs(known) do
                        local sx, sy = string.match(key, "^(%-?%d+):(%-?%d+)$")
                        local x, y = tonumber(sx), tonumber(sy)
                        if x and y then
                            for _, point in ipairs(Hex.neighbours(x, y, view)) do
                                if not known[point.x .. ":" .. point.y]
                                    and key ~= (unit.x .. ":" .. unit.y)
                                    and routes.costs[key]
                                then
                                    local d = routes.costs[key]
                                    if not distance or d < distance
                                        or d == distance and (y < best.y
                                            or y == best.y and x < best.x) then
                                        best, distance = {x=x, y=y}, d
                                    end
                                end
                            end
                        end
                    end
                    return best, distance, best and routes.pathTo(best.x, best.y) or nil
                end
                return function(view, player, unit, systems)
                    local choices = original(view, player, unit, systems)
                    local noTarget = true
                    for _, city in ipairs(view.cities or {}) do
                        if city.owner ~= player.id and not city.village then noTarget = false end
                    end
                    local scout = unit.kind == "scout" or unit.kind == "explorer"
                    if not noTarget or not scout then return choices end
                    local target, before, path = frontierTarget(view, unit, systems)
                    if not target then return choices end
                    for _, choice in ipairs(choices) do
                        local request = choice.request or {}
                        if request.action == "move" and not choice.forecast then
                            local nextPoint = path and path[2]
                            -- Reuse the legal reachable list from original
                            -- Tactics; only visible-frontier progress changes.
                            if nextPoint and choice.x == nextPoint.x and choice.y == nextPoint.y then
                                choice.score = choice.score + 100
                            else
                                local nextRoutes = Routes.from(view,
                                    {x=choice.x, y=choice.y, kind=unit.kind,
                                     owner=unit.owner}, systems,
                                    {ignoreFriendly=true, maxCost=64})
                                local next = nextRoutes.costs[target.x .. ":" .. target.y]
                                if next then
                                    choice.score = choice.score + (before - next) * 24
                                else
                                    choice.score = choice.score - 20
                                end
                            end
                        end
                    end
                    table.sort(choices, function(a, b)
                        if a.score ~= b.score then return a.score > b.score end
                        return a.request.action .. ":" .. tostring(a.request.x) .. ":"
                            .. tostring(a.request.y) < b.request.action .. ":"
                            .. tostring(b.request.x) .. ":" .. tostring(b.request.y)
                    end)
                    return choices
                end
            end"""
        )
        tactics.ranked = tactics_wrapper(original_tactics)
        if (config or {}).get("siegeAttackHook"):
            siege_base = tactics.ranked
            siege_wrapper = runtime.lua.eval(
                """function(original)
                    return function(view, player, unit, systems)
                        local choices = original(view, player, unit, systems)
                        if unit.kind == "catapult" or unit.kind == "heavysiege" then
                            for _, choice in ipairs(choices) do
                                local forecast = choice.forecast or {}
                                if (forecast.wallDamage or 0) > 0 then
                                    -- Research-only tactical ablation: preserve
                                    -- the legal forecast/action, but make a
                                    -- positive wall-damage shot beat standby.
                                    choice.score = choice.score + 120
                                end
                            end
                            table.sort(choices, function(a, b)
                                if a.score ~= b.score then return a.score > b.score end
                                return a.request.action .. ":" .. tostring(a.request.x) .. ":"
                                    .. tostring(a.request.y) < b.request.action .. ":"
                                    .. tostring(b.request.x) .. ":" .. tostring(b.request.y)
                            end)
                        end
                        return choices
                    end
                end"""
            )
            tactics.ranked = siege_wrapper(siege_base)


def _base_runtime():
    from runtime import Runtime

    return Runtime


def _configs(seeds: list[int]) -> list[dict]:
    configs = []
    for seed in seeds:
        for conquest_seat in (0, 1):
            players = [
                {"civilization": "forge", "ai": True,
                 "policy": {"version": 1, "goal": "industrial"}},
                {"civilization": "forge", "ai": True,
                 "policy": {"version": 1, "goal": "industrial"}},
            ]
            players[conquest_seat]["policy"] = {"version": 1, "goal": "conquest"}
            configs.append({
                "seed": seed, "mapSize": "compact", "mapType": "pangaea",
                "hostileMode": "off", "maxRounds": 180,
                "telemetryEvery": 5, "trace": True,
                "players": players, "conquestSeat": conquest_seat,
            })
    return configs


def run_full_match(config: dict, hooked: bool) -> dict:
    """Run one arm through the ordinary lab runner."""
    import runner

    saved = runner.Runtime
    runner.Runtime = MilitaryHookRuntime if hooked else _base_runtime()
    try:
        result = runner.play(config)
    finally:
        runner.Runtime = saved
    result["arm"] = "production_hook" if hooked else "baseline_live_ai"
    return result


# Fixture setup is intentionally isolated from gameplay modules. It creates a
# deterministic wartime state, then the real actor/action pipeline is measured.
_FIXTURE_LUA = r'''
function(state, scenario)
    local Systems = __civcraftModuleCache["/games/civcraft/systems.lua"]
    local Scheduler = __civcraftModuleCache["/games/civcraft/turn_scheduler.lua"]
    local World = __civcraftModuleCache["/games/civcraft/world.lua"]
    local Hex = __civcraftModuleCache["/games/civcraft/hex.lua"]
    local p0, p1 = state.players[1], state.players[2]
    local c0, c1
    for _, c in ipairs(state.cities) do
        if c.owner == p0.id and c.capitalOf == p0.id then c0 = c end
        if c.owner == p1.id and c.capitalOf == p1.id then c1 = c end
    end
    assert(c0 and c1, "fixture capitals missing")
    local function prime(p)
        p.techs = {mining=true, archery=true, bronze=true, metallurgy=true,
            tactics=true, engineering=true, deepmining=true, diamondworking=true,
            steampower=true, netherite=true}
        p.gold = 250
        p.stockpile = {iron=8, horses=8, brass=8, diamond=8,
            saltpeter=8, copper=8, zinc=8, redstone=8}
        p.ai = true
        p.visible = p.visible or {}
        p.visible[World.key(c0.x, c0.y)] = true
        p.visible[World.key(c1.x, c1.y)] = true
    end
    prime(p0); prime(p1)
    -- Setup declares war so contacts/declaration policy is not a confound.
    state.diplomacy.wars = {{a=p0.id, b=p1.id, active=true, kind="fixture",
        declaredRound=state.round, activatesRound=state.round}}
    Scheduler.rebuild(state, state.diplomacy.wars)
    state.units = {}
    local nextID = state.nextId
    local function add(owner, kind, x, y)
        local u = {id=nextID, owner=owner, kind=kind, x=x, y=y,
            hp=100, maxHP=100, xp=0, level=1, movesLeft=0, moved=false}
        state.units[#state.units + 1] = u
        nextID = nextID + 1
        return u
    end
    local function neighbours(c)
        local result = {}
        for _, point in ipairs(Hex.neighbours(c.x, c.y, state)) do
            if Hex.passable(point.x, point.y, state,
                {kind="warrior", owner=p0.id}, Systems) then
                local occupied = false
                for _, u in ipairs(state.units) do
                    occupied = occupied or u.x == point.x and u.y == point.y
                end
                if not occupied then result[#result + 1] = point end
            end
        end
        return result
    end
    local near0, near1 = neighbours(c0), neighbours(c1)
    assert(#near0 >= 1 and #near1 >= 1, "fixture needs passable neighbours")
    c0.buildings, c1.buildings = {}, {walls=true}
    c1.maxWalls, c1.wallHP = 100, 100
    c0.maxWalls, c0.wallHP = 0, 0
    if scenario == "capture_breach" then
        -- Positive combat/capture control: keep all ordinary action and
        -- combat validation, but start the observed enemy city already
        -- breached so the fixture can test the final melee capture step.
        c1.buildings = {}
        c1.maxWalls, c1.wallHP = 0, 0
    end
    if scenario == "siege_breach" then
        add(p0.id, "catapult", near1[1].x, near1[1].y)
        add(p0.id, "swordsman", near1[2] and near1[2].x or near0[1].x,
            near1[2] and near1[2].y or near0[1].y)
        add(p0.id, "warrior", near1[3] and near1[3].x or near0[1].x,
            near1[3] and near1[3].y or near0[1].y)
        add(p1.id, "warrior", near1[#near1].x, near1[#near1].y)
    elseif scenario == "fortified_capture" then
        -- Strong controlled siege group: three legal siege pieces and three
        -- legal melee units, all adjacent to the visible fortified city.
        -- This is deliberately a scenario budget, not a full-game grant.
        add(p0.id, "catapult", near1[1].x, near1[1].y)
        add(p0.id, "catapult", near1[2].x, near1[2].y)
        add(p0.id, "catapult", near1[3].x, near1[3].y)
        add(p0.id, "swordsman", near1[4].x, near1[4].y)
        add(p0.id, "swordsman", near1[5].x, near1[5].y)
        add(p0.id, "warrior", near1[6].x, near1[6].y)
        add(p1.id, "warrior", near0[#near0].x, near0[#near0].y)
    elseif scenario == "capital_defense" then
        add(p0.id, "warrior", near0[1].x, near0[1].y)
        add(p0.id, "swordsman", near0[2] and near0[2].x or near0[1].x,
            near0[2] and near0[2].y or near0[1].y)
        add(p1.id, "warrior", near0[#near0].x, near0[#near0].y)
        add(p1.id, "swordsman", near0[2] and near0[2].x or near0[#near0].x,
            near0[2] and near0[2].y or near0[#near0].y)
    elseif scenario == "settler_protection" then
        local escort = add(p0.id, "warrior", near0[1].x, near0[1].y)
        local settler = add(p0.id, "settler", near0[2] and near0[2].x or near0[1].x,
            near0[2] and near0[2].y or near0[1].y)
        escort.moved, settler.moved = false, false
        add(p1.id, "warrior", near0[#near0].x, near0[#near0].y)
    elseif scenario == "capture_breach" then
        add(p0.id, "catapult", near1[1].x, near1[1].y)
        add(p0.id, "swordsman", near1[2] and near1[2].x or near0[1].x,
            near1[2] and near1[2].y or near0[1].y)
        add(p0.id, "warrior", near1[3] and near1[3].x or near0[1].x,
            near1[3] and near1[3].y or near0[1].y)
        add(p1.id, "warrior", near1[#near1].x, near1[#near1].y)
        -- Keep one defender so the positive control exercises real combat
        -- damage before ownership transfer, while walls/research remain out
        -- of scope for this final melee-capture gate.
    else
        error("unknown fixture scenario: " .. tostring(scenario))
    end
    state.nextId = nextID
    for _, u in ipairs(state.units) do
        u.movesLeft = (Systems.units[u.kind] or {}).move or 1
        u.moved = false
    end
    World.reveal(state, Hex, Systems)
    return true
end
'''


def _fixture_setup(runtime, scenario: str) -> None:
    setup = runtime.lua.eval(_FIXTURE_LUA)
    runtime.call(setup, runtime.state, scenario)


def _fixture_snapshot(runtime) -> dict:
    from runtime import from_lua

    state = runtime.state
    cities = from_lua(state.cities)
    units = from_lua(state.units)
    return {
        "round": int(state.round),
        "cities": [
            {"id": c["id"], "owner": c.get("owner"), "wallHP": c.get("wallHP", 0),
             "hp": c.get("hp", 0)}
            for c in cities if c.get("owner") in (0, 1) and not c.get("village")
        ],
        "units": [
            {"id": u["id"], "owner": u.get("owner"), "kind": u.get("kind"),
             "x": u.get("x"), "y": u.get("y"), "hp": u.get("hp", 0)}
            for u in units if u.get("owner") in (0, 1)
        ],
    }


def run_fixture(config: dict, scenario: str, hooked: bool, horizon: int = 8) -> dict:
    from runtime import Runtime

    runtime = MilitaryHookRuntime(config) if hooked else Runtime(config)
    telemetry = runtime.lua.globals().dofile("/lab/telemetry.lua").install(
        runtime.lua.table_from({"actionBudget": config.get("actionBudget", 4096), "trace": True})
    )
    _fixture_setup(runtime, scenario)
    snapshots = [_fixture_snapshot(runtime)]
    error = None
    started = time.perf_counter()
    try:
        for _ in range(horizon):
            if runtime.finished():
                break
            runtime.pump()  # ActorLifecycle -> Systems.aiTurn -> Actions.apply
            snapshots.append(_fixture_snapshot(runtime))
            if runtime.finished():
                break
            runtime.advance()
    except Exception as exc:
        error = f"{type(exc).__name__}: {exc}"
    from runtime import from_lua

    return {"scenario": scenario,
            "arm": "production_hook" if hooked else "baseline_live_ai",
            "status": "error" if error else "finished",
            "error": error, "snapshots": snapshots,
            "dispatches": from_lua(telemetry),
            "elapsedSeconds": time.perf_counter() - started}


def _diagnostic_snapshot(runtime, player_id: int) -> dict:
    """Privileged post-turn checkpoint; never passed to an AI policy."""
    from runtime import from_lua

    state = runtime.state
    players = from_lua(state.players)
    cities = from_lua(state.cities)
    units = from_lua(state.units)
    player = next(p for p in players if p["id"] == player_id)
    raw_contacts = player.get("contacts") or {}
    if isinstance(raw_contacts, list):
        contacts = [index for index, value in enumerate(raw_contacts) if value]
    else:
        contacts = [int(k) for k, value in raw_contacts.items() if value]
    visible = player.get("visible") or {}
    enemy_cities = []
    for city in cities:
        if city.get("owner") != player_id and not city.get("village") \
                and visible.get(f"{city['x']}:{city['y']}"):
            enemy_cities.append({"id": int(city["id"]), "owner": int(city["owner"]),
                                 "x": int(city["x"]), "y": int(city["y"]),
                                 "wallHP": int(city.get("wallHP") or 0)})
    unit_kinds = {}
    unit_positions = []
    military_units = []
    for unit in units:
        if unit.get("owner") == player_id:
            unit_kinds[unit["kind"]] = unit_kinds.get(unit["kind"], 0) + 1
            if unit.get("kind") not in ("settler", "scout", "explorer"):
                military_units.append({"id": int(unit["id"]), "kind": unit["kind"],
                                       "x": int(unit["x"]), "y": int(unit["y"]),
                                       "hp": int(unit.get("hp") or 0),
                                       "movesLeft": int(unit.get("movesLeft") or 0),
                                       "role": (unit.get("aiRole") or {}).get("name")})
            if unit.get("kind") in ("scout", "explorer"):
                unit_positions.append({"id": int(unit["id"]), "kind": unit["kind"],
                                       "x": int(unit["x"]), "y": int(unit["y"]),
                                       "movesLeft": int(unit.get("movesLeft") or 0),
                                       "moved": bool(unit.get("moved"))})
    plan = player.get("aiPlan") or {}
    techs = sorted(str(key) for key, value in (player.get("techs") or {}).items() if value)
    recruit_checks = {}
    actual_player = next(state.players[index] for index in range(1, len(state.players) + 1)
                         if state.players[index].id == player_id)
    actual_city = next((state.cities[index] for index in range(1, len(state.cities) + 1)
                        if state.cities[index].owner == player_id
                        and state.cities[index].capitalOf == player_id), None)
    if actual_city is not None:
        cache = runtime.lua.globals()["__civcraftModuleCache"]
        systems = cache["/games/civcraft/systems.lua"]
        hex_module = cache["/games/civcraft/hex.lua"]
        for unit_id in ("swordsman", "diamondguard", "golem", "netherguard",
                        "catapult", "heavysiege"):
            allowed = runtime.call(systems.canRecruit, actual_player, unit_id,
                                   state, hex_module, actual_city)
            recruit_checks[unit_id] = bool(allowed[0] if isinstance(allowed, tuple) else allowed)
    return {
        "round": int(state.round),
        "contacts": contacts,
        "visibleEnemyCities": enemy_cities,
        "primary": plan.get("primary"),
        "campaign": plan.get("campaign"),
        "unitKinds": unit_kinds,
        "militaryUnits": military_units,
        "scoutPositions": unit_positions,
        "techs": techs,
        "recruitChecks": recruit_checks,
        "gold": int(player.get("gold") or 0),
        "stockpile": player.get("stockpile") or {},
        "cities": sum(1 for city in cities if city.get("owner") == player_id),
        "cityProjects": [
            {"id": int(city["id"]), "kind": city["project"]["kind"],
             "projectID": city["project"]["id"]}
            for city in cities
            if city.get("owner") == player_id and city.get("project")
        ],
    }


def run_diagnostic(config: dict, player_id: int = 0, hooked: bool = False) -> dict:
    """Run one failed case and retain contact/campaign checkpoints."""
    from runtime import Runtime, from_lua

    runtime = MilitaryHookRuntime(config) if hooked else Runtime(config)
    telemetry = runtime.lua.globals().dofile("/lab/telemetry.lua").install(
        runtime.lua.table_from({"actionBudget": config.get("actionBudget", 4096), "trace": True})
    )
    checkpoints = []
    first_contact = None
    started = time.perf_counter()
    error = None
    try:
        while not runtime.finished() and runtime.state.round <= config.get("maxRounds", 180):
            runtime.pump()
            checkpoint = _diagnostic_snapshot(runtime, player_id)
            if first_contact is None and checkpoint["contacts"]:
                first_contact = checkpoint["round"]
            if checkpoint["round"] == 1 or checkpoint["round"] % 10 == 0 \
                    or checkpoint["contacts"] or checkpoint["campaign"]:
                checkpoints.append(checkpoint)
            if runtime.finished() or runtime.state.round >= config.get("maxRounds", 180):
                break
            runtime.advance()
    except Exception as exc:
        error = f"{type(exc).__name__}: {exc}"
    data = from_lua(telemetry)
    cutoff = (first_contact + 2) if first_contact is not None else 30
    trace_window = [item for item in data.get("trace", []) if item.get("round", 0) <= cutoff]
    result = {
        "status": "error" if error else ("finished" if runtime.finished() else "censored"),
        "error": error,
        "round": int(runtime.state.round),
        "firstContactRound": first_contact,
        "checkpoints": checkpoints,
        "traceThroughRound": cutoff,
        "traceWindow": trace_window,
        "dispatches": {key: value for key, value in data.items() if key != "trace"},
        "elapsedSeconds": time.perf_counter() - started,
    }
    return result


def describe() -> None:
    print((HERE / "military_scenarios.json").read_text())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["describe", "fixtures", "diagnostic", "full-games"], default="describe")
    parser.add_argument("--seeds", default="75123,95117,18731")
    parser.add_argument("--output", type=Path, default=Path("/tmp/civcraft-military-competence.raw.json"))
    args = parser.parse_args()
    if args.mode == "describe":
        describe()
        return
    seeds = [int(value) for value in args.seeds.split(",") if value.strip()]
    base = {
        "mapSize": "compact", "mapType": "pangaea", "hostileMode": "off",
        "maxRounds": 30,
        "players": [
            {"civilization": "forge", "ai": True, "policy": {"version": 1, "goal": "conquest"}},
            {"civilization": "forge", "ai": True, "policy": {"version": 1, "goal": "industrial"}},
        ],
    }
    if args.mode == "diagnostic":
        diagnostic_config = {
            "seed": seeds[0], "mapSize": "compact", "mapType": "pangaea",
            "hostileMode": "off", "maxRounds": 180, "trace": True,
            "players": [
                {"civilization": "forge", "ai": True,
                 "policy": {"version": 1, "goal": "conquest"}},
                {"civilization": "forge", "ai": True,
                 "policy": {"version": 1, "goal": "industrial"}},
            ],
        }
        result = run_diagnostic(diagnostic_config, 0)
        record = {"schemaVersion": 1, "purpose": "Failed conquest contact/campaign checkpoint",
                  "source": source_manifest(), "driverSha256": _driver_hash(),
                  "config": diagnostic_config, "diagnostic": result}
    elif args.mode == "fixtures":
        record = {"schemaVersion": 2, "purpose": "Research-only real-action fixture diagnostics",
                  "source": source_manifest(), "driverSha256": _driver_hash(), "fixtures": []}
        for seed in seeds[:1]:
            config = dict(base, seed=seed)
            for scenario in ("siege_breach", "capture_breach", "fortified_capture", "capital_defense", "settler_protection"):
                record["fixtures"].append(run_fixture(config, scenario, False))
                record["fixtures"].append(run_fixture(config, scenario, True))
    else:
        configs = _configs(seeds)
        started = time.perf_counter()
        before = source_manifest()
        matches = []
        for config in configs:
            matches.append(run_full_match(config, False))
            matches.append(run_full_match(config, True))
        after = source_manifest()
        record = {"schemaVersion": 2, "purpose": "Live-AI production-ranking hook comparison",
                  "source": before, "driverSha256": _driver_hash(),
                  "host": {"machine": platform.machine(), "python": platform.python_version()},
                  "matches": matches, "elapsedSeconds": time.perf_counter() - started}
        record["sourceChangedDuringRun"] = before != after
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(record, indent=2, sort_keys=True, allow_nan=False) + "\n")
    print(json.dumps({"mode": args.mode, "output": str(args.output),
                      "records": len(record.get("matches", record.get("fixtures", [])))}))


if __name__ == "__main__":
    main()
