#!/usr/bin/env python3
"""Regression checks for the extracted public Civ VI catalog."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
data = json.loads((ROOT / "civ6_gathering_storm_catalog.json").read_text())
for section in ("technologies", "civics", "units", "buildings", "districts", "wonders"):
    payload = data["sections"][section]
    assert payload["indexed"] == payload["parsed"] and not payload["errors"], section


def get(section, ident):
    return next(x for x in data["sections"][section]["entries"] if x["id"] == ident)


writing = get("technologies", "tech_writing")
assert writing["kind"] == "technology"
assert [x["label"] for x in writing["linked_prerequisites"]] == ["Pottery"]
assert [x["label"] for x in writing["linked_successors"]] == ["Currency"]

craftsmanship = get("civics", "civic_craftsmanship")
assert craftsmanship["culture_cost"] == 40
assert [x["label"] for x in craftsmanship["linked_prerequisites"]] == ["Code of Laws"]
assert [x["label"] for x in craftsmanship["linked_successors"]] == ["Military Tradition", "State Workforce"]

swordsman = get("units", "unit_swordsman")
assert [x["label"] for x in swordsman["upgrades_to"]] == ["Man-At-Arms", "Samurai", "Berserker", "Khevsur"]
assert [x["label"] for x in swordsman["upgrades_from"]] == ["Warrior", "Eagle Warrior", "Sabum Kibittum"]

biplane = get("units", "unit_biplane")
assert biplane["resource_upfront_cost"] is None
assert biplane["resource_maintenance_per_turn"] == 1
assert biplane["resource_maintenance_name"] == "Oil"

assert get('technologies', 'tech_rocketry')['era'] == 'Atomic'
assert get('technologies', 'tech_writing')['era'] == 'Ancient'
assert get('civics', 'civic_globalization')['era'] == 'Information'
assert get('wonders', 'project_launch_exoplanet_expedition')['kind'] == 'project'
assert get('wonders', 'project_launch_exoplanet_expedition')['era'] is None
assert get('wonders', 'project_launch_exoplanet_expedition')['index_section'] == 'wonders'
assert len({row['era'] for row in data['sections']['technologies']['entries']}) >= 8

print("catalog verification passed")
