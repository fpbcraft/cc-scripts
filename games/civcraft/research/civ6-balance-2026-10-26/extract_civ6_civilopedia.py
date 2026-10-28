#!/usr/bin/env python3
"""Extract structured, factual Civ VI Gathering Storm reference data.

The Civilopedia is server-rendered HTML. This intentionally stores only labels,
numbers, links, and short trait strings; it omits historical/flavour prose.
Run with Python 3.11+ and network access:
  python3 extract_civ6_civilopedia.py
"""
from __future__ import annotations

import html
import json
import re
import argparse
import csv
import time
import urllib.request
from pathlib import Path

BASE = "https://www.civilopedia.net/en-US/gathering-storm"
OUT = Path(__file__).resolve().parent
SECTIONS = ("technologies", "civics", "units", "buildings", "districts", "wonders")
KINDS = {"technologies": "technology", "civics": "civic", "units": "unit", "buildings": "building", "districts": "district", "wonders": "wonder"}
HEADERS = {"User-Agent": "CivCraft-balance-research/2026-10-26"}


def get(url: str) -> str:
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=30) as response:
        return response.read().decode("utf-8", "replace")


def plain(source: str) -> str:
    # Civilopedia text is static HTML; removing tags gives a robust, auditable
    # fallback when its CSS class names change.
    source = re.sub(r"<script\b.*?</script>", " ", source, flags=re.I | re.S)
    source = re.sub(r"<style\b.*?</style>", " ", source, flags=re.I | re.S)
    source = re.sub(r"<[^>]+>", " ", source)
    return re.sub(r"\s+", " ", html.unescape(source)).strip()


def links(source: str, section: str) -> list[str]:
    seen: set[str] = set()
    found: list[str] = []
    pat = re.compile(rf'href="(/en-US/gathering-storm/{section}/[^"#?]+/)"')
    for href in pat.findall(source):
        if href.endswith("/intro/"):
            continue
        if href not in seen:
            seen.add(href)
            found.append(href)
    return found


def first_int(pattern: str, text: str) -> int | None:
    m = re.search(pattern, text, flags=re.I)
    return int(m.group(1)) if m else None


def index_eras(source: str, section: str) -> dict[str, str]:
    """Use explicit index groups, never the first era in page navigation."""
    groups = list(re.finditer(r'<div\b[^>]*data-page-group="true"[^>]*data-group-name="([^"]+)"[^>]*>', source))
    result = {}
    for index, group in enumerate(groups):
        label = html.unescape(group.group(1))
        era = re.fullmatch(r'(Ancient|Classical|Medieval|Renaissance|Industrial|Modern|Atomic|Information|Future) Era', label)
        if not era:
            continue
        end = groups[index + 1].start() if index + 1 < len(groups) else len(source)
        for path in links(source[group.end():end], section):
            result.setdefault(path.rstrip('/').rsplit('/', 1)[-1], era.group(1))
    return result


def article_section(source: str, label: str) -> str:
    """Return the first article subsection after the h1, excluding the sidebar."""
    start = source.find("<h1")
    if start < 0:
        start = 0
    marker = re.search(r">" + re.escape(label) + r"<\s*/div>", source[start:], flags=re.I)
    if not marker:
        return ""
    begin = start + marker.end()
    labels = ("Upgrades To", "Upgrade From", "Required Technologies", "Required Civics", "Leads to Technologies", "Leads to Civics", "Technology", "District", "Building", "Production Cost", "Purchase Cost", "Maintenance Cost", "Research Cost", "Culture Cost", "Description", "Historical Context")
    endings = []
    for other in labels:
        m = re.search(r">" + re.escape(other) + r"<\s*/div>", source[begin:], flags=re.I)
        if m:
            endings.append(begin + m.start())
    end = min(endings) if endings else len(source)
    return source[begin:end]


def article_links(fragment: str, allowed: tuple[str, ...] | None = None) -> list[dict]:
    out = []
    seen: set[str] = set()
    for match in re.finditer(r'<a[^>]+href="([^"]+)"[^>]*>(.*?)</a>', fragment, flags=re.I | re.S):
        href = html.unescape(match.group(1))
        if href.endswith("/intro/") or href in seen:
            continue
        sections = allowed or ("technologies", "civics", "units", "buildings", "districts", "wonders")
        if not any(f"/{section}/" in href for section in sections):
            continue
        label = plain(match.group(2))
        if label:
            seen.add(href)
            out.append({"label": label, "path": href})
    return out


def fields(kind: str, url: str, source: str) -> dict:
    h1 = re.search(r"<h1[^>]*>(.*?)</h1>", source, flags=re.I | re.S)
    text = plain(source[h1.start():] if h1 else "")
    name = plain(h1.group(1)) if h1 else None
    row: dict = {
        "id": url.rstrip("/").rsplit("/", 1)[-1],
        "name": name,
        "kind": "project" if url.rstrip('/').rsplit('/', 1)[-1].startswith('project_') else kind,
        "source_url": BASE + url[len('/en-US/gathering-storm'):],
        "era": None,
        "era_source": None,
        "production_cost": None,
        "research_cost": None,
        "culture_cost": None,
        "purchase_cost": None,
        "maintenance_cost": None,
        "resource_cost": None,
        "resource_cost_deprecated": True,
        "resource_upfront_cost": None,
        "resource_upfront_name": None,
        "resource_maintenance_per_turn": None,
        "resource_maintenance_name": None,
        "movement": None,
        "melee_strength": None,
        "ranged_strength": None,
        "bombard_strength": None,
        "range": None,
        "resource_name": None,
        "boost": None,
        "traits": [],
        "linked_pages": [],
        "linked_prerequisites": [],
        "linked_successors": [],
        "upgrades_to": [],
        "upgrades_from": [],
    }
    # The labels are repeated once in the SSR HTML; collecting all values and
    # taking the first is deterministic for the current site.
    row["production_cost"] = first_int(r"Production Cost Base Cost:\s*(\d+)", text)
    row["research_cost"] = first_int(r"Research Cost Base Cost:\s*(\d+)", text)
    row["culture_cost"] = first_int(r"Culture Cost Base Cost:\s*(\d+)", text)
    row["purchase_cost"] = first_int(r"Purchase Cost Base Cost:\s*(\d+)", text)
    row["maintenance_cost"] = first_int(r"Maintenance Cost Base Cost:\s*(\d+)", text)
    row["resource_cost"] = first_int(r"Base Resource Cost:\s*(\d+)", text)
    row["movement"] = first_int(r"(\d+) Movement Points", text)
    row["melee_strength"] = first_int(r"(\d+) Melee Strength", text)
    row["ranged_strength"] = first_int(r"(\d+) Ranged Strength", text)
    row["bombard_strength"] = first_int(r"(\d+) Bombard Strength", text)
    row["range"] = first_int(r"(\d+) Range\b", text)
    resource = re.search(r"Base Resource Cost:\s*\d+\s+([A-Za-z][A-Za-z -]*?)\s*\(on Standard Speed\)", text)
    row["resource_name"] = resource.group(1).strip() if resource else None
    consumes = re.search(r"Consumes:\s*(\d+)\s+([A-Za-z][A-Za-z -]*?)\s+per turn", text, flags=re.I)
    if consumes:
        row["resource_maintenance_per_turn"] = int(consumes.group(1))
        row["resource_maintenance_name"] = consumes.group(2).strip()
    elif row["resource_cost"] is not None:
        row["resource_upfront_cost"] = row["resource_cost"]
        row["resource_upfront_name"] = row["resource_name"]
    boost = re.search(r"Boosts?\s+(.{1,180}?)(?:\s+Progression\b|\s+Description\b|\s+Historical Context\b)", text, flags=re.I)
    row["boost"] = boost.group(1).strip() if boost else None
    # A short description can explicitly name a unit's era. Historical prose
    # and navigation are not availability metadata; leave unsupported eras null.
    description = plain(article_section(source, 'Description'))
    era = re.search(r'\b(Ancient|Classical|Medieval|Renaissance|Industrial|Modern|Atomic|Information|Future) era\b', description, flags=re.I)
    if era:
        row['era'], row['era_source'] = era.group(1).capitalize(), 'article-description'
    # Keep only short, factual trait lines. The headings are visible in text;
    # historical context is deliberately excluded by this bounded extraction.
    trait_match = re.search(r"Traits (.*?) Requirements ", text)
    if trait_match:
        chunk = trait_match.group(1)
        row["traits"] = [x for x in re.split(r" (?=[+\-]?\d|Allows |Cannot |Requires |Enables )", chunk) if x][:20]
    # Article links are sectioned so successors and unit upgrade direction are
    # not confused with the sidebar's full navigation list.
    prereqs = []
    for label in ("Required Technologies", "Required Civics", "Technology", "District", "Building"):
        prereqs.extend(article_links(article_section(source, label)))
    row["linked_prerequisites"] = list({x["path"]: x for x in prereqs}.values())
    row["linked_successors"] = article_links(article_section(source, "Leads to Technologies")) + article_links(article_section(source, "Leads to Civics"))
    row["upgrades_to"] = article_links(article_section(source, "Upgrades To"), ("units",))
    row["upgrades_from"] = article_links(article_section(source, "Upgrade From"), ("units",))
    # All linked Civilopedia pages in the article are retained for auditing.
    seen: set[str] = set()
    article_start = source.find("<h1")
    for match in re.finditer(r'<a[^>]+href="([^"]+)"[^>]*>(.*?)</a>', source, flags=re.I | re.S):
        if article_start >= 0 and match.start() < article_start:
            continue
        href, label = match.group(1), match.group(2)
        href = html.unescape(href)
        if not href.startswith("/en-US/gathering-storm/") or href.endswith("/intro/"):
            continue
        if not any(f"/{section}/" in href for section in ("technologies", "civics", "units", "buildings", "districts", "wonders")):
            continue
        label = plain(label)
        if not label or href in seen:
            continue
        seen.add(href)
        link = {"label": label, "path": href}
        row["linked_pages"].append(link)
    return row


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--local-root", type=Path, help="parse pages previously downloaded under this directory")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    result = {
        "metadata": {
            "ruleset": "Gathering Storm",
            "locale": "en-US",
            "processed_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "retrieved_utc": None if args.local_root else time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "input_mode": "offline-cache" if args.local_root else "live-http",
            "retrieval_note": "Original download time is not recorded by the page cache." if args.local_root else "UTC start of HTTP retrieval batch.",
            "source_index": "https://www.civilopedia.net/en-US/gathering-storm/",
            "scope": "All links listed by the selected Civilopedia section indexes, including unique and mode entries; missing fields are null.",
            "parser": "extract_civ6_civilopedia.py",
        },
        "sections": {},
    }
    for section in SECTIONS:
        index_url = f"{BASE}/{section}/"
        try:
            if args.local_root:
                index_source = (args.local_root / f"{section}-index.html").read_text()
            else:
                index_source = get(index_url)
        except Exception as exc:
            result["sections"][section] = {"index_url": index_url, "error": str(exc), "entries": []}
            continue
        paths = links(index_source, section)
        eras = index_eras(index_source, section)
        entries: list[dict] = []
        errors: list[dict] = []
        for path in paths:
            url = "https://www.civilopedia.net" + path
            try:
                if args.local_root:
                    source = (args.local_root / section / (path.rstrip("/").rsplit("/", 1)[-1] + ".html")).read_text()
                else:
                    source = get(url)
                entry = fields(KINDS[section], path, source)
                entry['index_section'] = section
                if entry['id'] in eras:
                    entry['era'], entry['era_source'] = eras[entry['id']], 'index-group'
                entries.append(entry)
            except Exception as exc:
                errors.append({"path": path, "url": url, "error": str(exc)})
            if not args.local_root:
                time.sleep(0.04)
        result["sections"][section] = {"index_url": index_url, "indexed": len(paths), "parsed": len(entries), "errors": errors, "entries": entries}
    (OUT / "civ6_gathering_storm_catalog.json").write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
    for section, payload in result["sections"].items():
        entries = payload.get("entries", [])
        if not entries:
            continue
        columns = [k for k, v in entries[0].items() if not isinstance(v, (list, dict))]
        columns += ["traits", "linked_pages", "linked_prerequisites", "linked_successors", "upgrades_to", "upgrades_from"]
        with (OUT / f"{section}.csv").open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=columns, extrasaction="ignore", lineterminator="\n")
            writer.writeheader()
            for entry in entries:
                row = dict(entry)
                for key in columns:
                    if isinstance(row.get(key), (list, dict)):
                        row[key] = json.dumps(row[key], ensure_ascii=False)
                writer.writerow(row)
    counts = {k: {x: v.get(x, 0) for x in ("indexed", "parsed")} for k, v in result["sections"].items()}
    readme = """# Civ VI Gathering Storm balance catalog

Generated by `extract_civ6_civilopedia.py`; rerun to refresh. Source URLs and retrieval metadata are embedded in the JSON. The catalog stores numeric costs/stats, era labels, short traits, boosts, and article links; it intentionally excludes historical/flavour prose.

This is a public Gathering Storm Civilopedia snapshot, not a dump of the installed `Gameplay.sqlite` or every modifier/table. It includes the entries listed by the six selected section indexes, including unique units, unique buildings/districts, optional-mode entries, and late-game projects exposed by the Wonders index. Empty or unavailable fields remain `null`; they must not be interpreted as zero. `linked_pages` is limited to links in the article body (sidebar navigation is excluded). Research entries separate `linked_prerequisites` and `linked_successors`; unit entries separate `upgrades_to` and `upgrades_from`. `resource_cost` is retained as a deprecated raw value; use `resource_upfront_*` and `resource_maintenance_*` instead.

Era labels come from explicit index groups or a bounded article description, with `era_source` recorded; unknown values remain null. In particular, a page's sidebar is never used as its article era. `kind=project` distinguishes project IDs listed by the Wonders index, while `index_section` preserves that source grouping.

The parser supports offline reruns after downloading pages: `python3 extract_civ6_civilopedia.py --local-root /path/to/downloaded-pages`. It emits one CSV per section for spreadsheet analysis. Run `python3 verify_catalog.py` after extraction; it checks coverage and representative prerequisite, successor, upgrade-direction, cost, era, project-kind, and aircraft-resource facts. A live network run may be blocked by the execution sandbox.

Counts from the last run:

```json
""" + json.dumps(counts, indent=2) + """
```
"""
    (OUT / "README.md").write_text(readme)
    print(json.dumps(counts, indent=2))


if __name__ == "__main__":
    main()
