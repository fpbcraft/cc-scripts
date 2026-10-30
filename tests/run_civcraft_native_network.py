"""Run the generated-data three-computer CraftOS integration in a fresh profile."""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--craftos", default=shutil.which("craftos") or "/Applications/CraftOS-PC.app/Contents/MacOS/craftos")
parser.add_argument("--reverse-race", action="store_true", help="Let client 2 win the initial collision")
parser.add_argument("--timings", action="store_true", help="Observe independent command acknowledgement and updated snapshot timings")
parser.add_argument("--v5-opening", action="store_true", help="Observe natural generated V5 host/guest/AI founding and network orders")
args = parser.parse_args()
if args.v5_opening and args.reverse_race:
    parser.error("--reverse-race belongs to the controlled V3 fixture")
if args.v5_opening:
    args.timings = True
repo = Path(__file__).resolve().parents[1]
profile = Path(tempfile.mkdtemp(prefix="civcraft-network-"))
print(f"Isolated profile: {profile}", flush=True)
flags = (["--reverse-race"] if args.reverse_race else []) + (["--timings"] if args.timings else [])
lua_test = "civcraft_craftos_opening_network.lua" if args.v5_opening else "civcraft_craftos_network.lua"
computer_count = 2 if args.v5_opening else 3
boot = 'assert(loadfile("/tests/' + lua_test + '"))(' + ", ".join(map(json.dumps, flags)) + ")"
for identity in range(computer_count):
    root = profile / "computer" / str(identity)
    (root / "tests").mkdir(parents=True)
    shutil.copytree(repo / "games/civcraft", root / "games/civcraft", ignore=shutil.ignore_patterns("data"))
    shutil.copytree(repo / "lib/fpb", root / "games/civcraft/_lib/fpb", dirs_exist_ok=True)
    shutil.copyfile(repo / "tests" / lua_test, root / "tests" / lua_test)
    (root / "startup.lua").write_text(boot + "\n")
with (profile / "native-console.log").open("w") as console:
    subprocess.run(
        [args.craftos, "--headless", "--directory", str(profile), "--exec", boot],
        stdout=console, stderr=subprocess.STDOUT, check=True, timeout=90,
    )
failed = False
for identity in range(computer_count):
    result = profile / "computer" / str(identity) / "civcraft-network-test.txt"
    content = result.read_text() if result.exists() else "NO RESULT"
    passed = re.search(r"\bpassed\s*=\s*true\b", content) is not None
    print(f"Computer {identity}: {'PASS' if passed else 'FAIL'}; {result}")
    if not passed:
        failed = True
        print(content)
if args.timings:
    metadata_file = profile / "computer/0/civcraft-network-metadata.json"
    if not metadata_file.exists():
        failed = True
        print("Missing network campaign metadata")
    else:
        print("Campaign metadata:", metadata_file.read_text())
    timing_file = profile / ("computer/1/civcraft-network-timings.json" if args.v5_opening else "computer/2/civcraft-network-timings.json")
    if timing_file.exists():
        timing = json.loads(timing_file.read_text())
        samples = timing.get("samples", {})
        tokens = ("naturalOpeningMove", "naturalOpeningRound") if args.v5_opening else ("spendBeforeMerge", "peacefulConcurrentMove")
        for token in tokens:
            sample = samples.get(token, {})
            if not all(isinstance(sample.get(key), (int, float)) for key in ("ackMillis", "snapshotMillis")):
                failed = True
        print("Client timing observations:", json.dumps(timing, sort_keys=True))
    else:
        failed = True
        print("Missing client timing observations")
raise SystemExit(1 if failed else 0)
