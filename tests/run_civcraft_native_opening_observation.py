"""Run the bounded real-mainloop UI observation; this does not complete M0's opening gates."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--craftos", default=shutil.which("craftos") or "/Applications/CraftOS-PC.app/Contents/MacOS/craftos")
parser.add_argument("--gui", action="store_true", help="Use native GUI terminal rendering")
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
profile = Path(tempfile.mkdtemp(prefix="civcraft-opening-observation-"))
root = profile / "computer/0"
(root / "tests").mkdir(parents=True)
shutil.copytree(repo / "games/civcraft", root / "games/civcraft", ignore=shutil.ignore_patterns("data"))
shutil.copytree(repo / "lib/fpb", root / "games/civcraft/_lib/fpb", dirs_exist_ok=True)
shutil.copyfile(repo / "tests/civcraft_craftos_opening_observation.lua", root / "tests/civcraft_craftos_opening_observation.lua")
revision = subprocess.run(["git", "rev-parse", "HEAD"], cwd=repo, check=True, capture_output=True, text=True).stdout.strip()
script = '''local env = dofile("/games/civcraft/_lib/fpb/loader.lua").environment("/games/civcraft", _ENV, "game.lua")
env.__openingSourceRevision = %s
local ok, why = pcall(function()
  assert(loadfile("/tests/civcraft_craftos_opening_observation.lua", "t", env))()
end)
local result = assert(fs.open("/opening-observation-return.txt", "w"))
result.write(ok and "PASS" or tostring(why)); result.close(); os.shutdown()''' % json.dumps(revision)
command = [args.craftos, "--directory", str(profile), "--exec", script]
if not args.gui:
    command.insert(1, "--headless")
console = profile / "native-console.log"
print(f"Isolated profile: {profile}", flush=True)
with console.open("w") as output:
    subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, check=True, timeout=300)
result = root / "opening-observation-return.txt"
content = result.read_text() if result.exists() else "NO RESULT"
print(content)
records = root / "opening-observation.jsonl"
if records.exists():
    print(f"Observation log: {records}")
raise SystemExit(0 if content == "PASS" else 1)
