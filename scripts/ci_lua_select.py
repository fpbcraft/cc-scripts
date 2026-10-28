#!/usr/bin/env python3
"""Conservative, dependency-aware Lua regression selection for GitHub Actions.

PRs run affected tests plus cheap smoke checks. Pushes to main and scheduled
runs execute everything. Unknown changes and analysis failures select all tests.
No third-party dependencies; callable locally with --changed for inspection.
"""
import argparse
from collections import defaultdict
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys

from ci_lua_tests import CONTROLS, SECONDS

DEFAULT_SMOKE = ("core_test.lua", "loader_test.lua", "packages_test.lua")
MAX_SHARDS = 9
TARGET_SECONDS = 90

# Changes to shared infrastructure can affect any test, including indirect
# users. Changes to core game modules affect too many systems to narrow safely.
GLOBAL_RISK = (".github/", "scripts/", "lib/", "tests/support/", "tests/helpers/")
CORE_MODULES = {
    "actions.lua", "content.lua", "cooperative.lua", "game.lua",
    "module_cache.lua", "render.lua", "systems.lua", "ui.lua",
    "world.lua", "state_writer.lua",
}
DOC_SUFFIXES = {".md", ".mdx", ".rst"}

# Match literal Lua imports as well as textual paths used by test fixtures.
IMPORT = re.compile(
    r"""\b(?:dofile|loadfile|require|native|oldDofile)\s*\(\s*['"]([^'"]+)['"]"""
)
PATH_LITERAL = re.compile(
    r"""['"]/?((?:games|apps|lib|installers)/[a-zA-Z0-9_./-]+\.lua)['"]"""
)
DYNAMIC_LOAD = re.compile(
    r"""\b(?:dofile|loadfile|require)\s*\(\s*(?!['"])"""
)


def test_files(root):
    return sorted((root / "tests").glob("*_test.lua"))


def repository_changes(base):
    """Use the checked-out PR merge commit and its true base (no API limits)."""
    if not re.fullmatch(r"[0-9a-fA-F]{40}", base or ""):
        raise ValueError("Missing or invalid PR base commit")
    result = subprocess.run(
        ["git", "diff", "--no-renames", "--name-only", "-z", base, "HEAD"],
        check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    return [name.decode("utf-8") for name in result.stdout.split(b"\0") if name]


def dependencies(root, file):
    """Return statically resolvable paths referenced by a Lua source file."""
    source = file.read_text(encoding="utf-8")
    candidates = set(PATH_LITERAL.findall(source))
    candidates.update(IMPORT.findall(source))
    resolved = set()
    for name in candidates:
        name = name.lstrip("/")
        variants = (name, name + ".lua", name.replace(".", "/") + ".lua")
        for variant in variants:
            for path in (root / variant, file.parent / variant):
                if path.is_file() and path.suffix == ".lua":
                    resolved.add(path.relative_to(root).as_posix())
    return resolved


def import_graph(root):
    graph = {}
    for directory in ("games", "apps", "lib", "installers", "tests"):
        folder = root / directory
        if folder.exists():
            for lua in folder.rglob("*.lua"):
                graph[lua.relative_to(root).as_posix()] = dependencies(root, lua)
    return graph


def transitive(graph, path, memo, stack=None):
    if path in memo:
        return memo[path]
    stack = stack or set()
    if path in stack:
        return set()
    children = set(graph.get(path, ()))
    for child in graph.get(path, ()):
        children.update(transitive(graph, child, memo, stack | {path}))
    memo[path] = children
    return children


def scope(path):
    parts = Path(path).parts
    if len(parts) >= 2 and parts[0] == "games":
        return parts[1]
    if len(parts) >= 2 and parts[0] == "apps":
        return parts[1]
    if len(parts) == 2 and parts[0] == "installers":
        return Path(parts[1]).stem
    return None


def select(root, changes, all_tests=None):
    """Return (selected filenames, reason map, full reason or None).

    A readable but unresolved game module broadens to its whole application.
    A shared/unknown change broadens to the full suite rather than risking gaps.
    """
    tests = all_tests if all_tests is not None else test_files(root)
    available = {f.name: f for f in tests}
    if not tests:
        raise ValueError("No Lua tests found")
    if not changes:
        return set(available), {}, "No reliable change list"
    if all(Path(p).suffix.lower() in DOC_SUFFIXES for p in changes):
        return set(), {}, None

    selected = set()
    reasons = defaultdict(set)
    try:
        graph = import_graph(root)
        closure = {}
        for test in tests:
            path = test.relative_to(root).as_posix()
            closure[test.name] = transitive(graph, path, {})
    except (OSError, UnicodeError, ValueError) as error:
        return set(available), {}, f"Dependency analysis failed: {error}"

    for changed in changes:
        file = root / changed
        if Path(changed).suffix.lower() in DOC_SUFFIXES:
            continue
        if changed.startswith(GLOBAL_RISK):
            return set(available), {}, f"Shared or CI infrastructure changed: {changed}"
        if changed.startswith("tests/"):
            name = Path(changed).name
            if changed.count("/") != 1 or not name.endswith("_test.lua"):
                return set(available), {}, f"Non-isolated test infrastructure changed: {changed}"
            if name not in available:
                return set(available), {}, f"Deleted or moved test: {changed}"
            selected.add(name)
            reasons[name].add(f"Test changed: {changed}")
            continue

        domain = scope(changed)
        if not domain:
            return set(available), {}, f"Unclassified source/configuration: {changed}"
        matching = {name for name in available if name.startswith(domain + "_")}
        # App tests may have generic names and cross-domain dependencies; inspect
        # the transitive graph independently, rather than only using name prefixes.
        if changed.startswith("installers/"):
            matching.update(name for name in available if name.startswith("fpbstore_"))
        if not matching:
            return set(available), {}, f"No recognizable tests for {changed}"

        if not file.is_file() or file.suffix != ".lua" or file.name in CORE_MODULES:
            hits = matching
            why = "Broad application-level impact"
        else:
            try:
                source = file.read_text(encoding="utf-8")
            except (OSError, UnicodeError):
                hits = matching
                why = "Unreadable source"
            else:
                if DYNAMIC_LOAD.search(source):
                    hits = matching
                    why = "Runtime-computed imports"
                else:
                    hits = {
                        name for name in available
                        if changed in closure[name]
                        or name == Path(changed).stem + "_test.lua"
                    }
                    if not hits:
                        hits = matching
                        why = "No static dependents; conservative application fallback"
                    else:
                        why = "Direct or transitive Lua dependency"

        for name in hits:
            selected.add(name)
            reasons[name].add(f"{changed}: {why}")

    if selected:
        for smoke in DEFAULT_SMOKE:
            if smoke in available:
                selected.add(smoke)
                reasons[smoke].add("Mandatory cross-application smoke check")
    return selected, reasons, None


def shard_count(names, maximum):
    if not names:
        return 0
    if CONTROLS in names:
        # Each of the 18 control layouts must be distributed over all nine
        # workers; reducing the count would make that test several minutes long.
        return min(maximum, 9)
    predicted = sum(SECONDS.get(name, 1) for name in names)
    return max(1, min(maximum, len(names), math.ceil(predicted / TARGET_SECONDS)))


def plan(root, selected, reasons, full_reason, max_shards):
    count = shard_count(selected, max_shards)
    return {
        "run_tests": bool(selected),
        "full": full_reason is not None,
        "reason": full_reason or "Dependency impact selection",
        "tests": sorted("tests/" + name for name in selected),
        "shards": count,
        # The skipped regression job still receives a valid matrix shape.
        "matrix": {"include": [
            {"shard": index, "shards": count} for index in range(count)
        ] if count else [{"shard": 0, "shards": 1}]},
        "details": {name: sorted(reasons[name]) for name in sorted(reasons)},
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", help="Pull request base commit SHA")
    parser.add_argument("--full", action="store_true", help="Run all tests")
    parser.add_argument("--changed", nargs="+", help="Explicit paths for local inspection")
    parser.add_argument("--max-shards", type=int, default=MAX_SHARDS)
    parser.add_argument("--output", help="GitHub Actions GITHUB_OUTPUT file")
    args = parser.parse_args()
    if not 1 <= args.max_shards <= 9:
        parser.error("max-shards must be between 1 and 9")

    root = Path.cwd()
    available = test_files(root)
    try:
        if args.full:
            selected, reasons, why = {f.name for f in available}, {}, "Full run requested"
        else:
            paths = args.changed if args.changed is not None else repository_changes(args.base)
            selected, reasons, why = select(root, paths, available)
    except (OSError, subprocess.CalledProcessError, ValueError) as error:
        # An unavailable base or malformed diff must never silently skip tests.
        selected, reasons, why = {f.name for f in available}, {}, f"Fail-open full suite: {error}"

    outcome = plan(root, selected, reasons, why, args.max_shards)
    print(json.dumps(outcome, indent=2))
    if args.output:
        with open(args.output, "a", encoding="utf-8") as out:
            for name in ("run_tests", "full", "tests", "shards", "matrix"):
                value = json.dumps(outcome[name], separators=(",", ":"))
                out.write(f"{name}={value}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
