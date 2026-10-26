"""Run the generated-data three-computer CraftOS integration in a fresh profile."""
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--craftos", default=shutil.which("craftos") or "/Applications/CraftOS-PC.app/Contents/MacOS/craftos")
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
profile = Path(tempfile.mkdtemp(prefix="civcraft-network-"))
print(f"Isolated profile: {profile}", flush=True)
for identity in range(3):
    root = profile / "computer" / str(identity)
    (root / "tests").mkdir(parents=True)
    shutil.copytree(repo / "games/civcraft", root / "games/civcraft", ignore=shutil.ignore_patterns("data"))
    shutil.copytree(repo / "lib/fpb", root / "games/civcraft/_lib/fpb", dirs_exist_ok=True)
    shutil.copyfile(repo / "tests/civcraft_craftos_network.lua", root / "tests/civcraft_craftos_network.lua")
    (root / "startup.lua").write_text('dofile("/tests/civcraft_craftos_network.lua")\n')
with (profile / "native-console.log").open("w") as console:
    subprocess.run(
        [args.craftos, "--headless", "--directory", str(profile), "--exec", 'dofile("/tests/civcraft_craftos_network.lua")'],
        stdout=console, stderr=subprocess.STDOUT, check=True, timeout=90,
    )
failed = False
for identity in range(3):
    result = profile / "computer" / str(identity) / "civcraft-network-test.txt"
    content = result.read_text() if result.exists() else "NO RESULT"
    passed = re.search(r"\bpassed\s*=\s*true\b", content) is not None
    print(f"Computer {identity}: {'PASS' if passed else 'FAIL'}; {result}")
    if not passed:
        failed = True
        print(content)
raise SystemExit(1 if failed else 0)
