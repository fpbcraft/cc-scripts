"""Run bounded Huge/Vast Founders late-state UI and save checks in disposable CraftOS-PC."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument(
    "--craftos",
    default=shutil.which("craftos") or "/Applications/CraftOS-PC.app/Contents/MacOS/craftos",
)
parser.add_argument(
    "--backend",
    choices=("text", "gui", "monitor"),
    default="text",
    help="Use the native text terminal, GUI terminal, or emulated Advanced Monitor",
)
parser.add_argument("--timeout", type=int, default=600, help="Maximum native run time in seconds")
args = parser.parse_args()
if args.timeout <= 0:
    parser.error("--timeout must be positive")

repo = Path(__file__).resolve().parents[1]
profile = Path(tempfile.mkdtemp(prefix="civcraft-founders-stress-"))
root = profile / "computer/0"
(root / "tests").mkdir(parents=True)
shutil.copytree(
    repo / "games/civcraft",
    root / "games/civcraft",
    ignore=shutil.ignore_patterns("data"),
)
shutil.copytree(repo / "lib/fpb", root / "games/civcraft/_lib/fpb", dirs_exist_ok=True)
shutil.copyfile(
    repo / "tests/civcraft_craftos_founders_stress.lua",
    root / "tests/civcraft_craftos_founders_stress.lua",
)

backend_arg = json.dumps(args.backend)
script = '''local ok, result = pcall(function()
local env = dofile("/games/civcraft/_lib/fpb/loader.lua")
    .environment("/games/civcraft", _ENV, "game.lua")
return assert(loadfile("/tests/civcraft_craftos_founders_stress.lua", "t", env))(%s)
end)
local output = { ok = ok }
if ok then
    output.report = result
else
    output.error = tostring(result)
end
local file = assert(fs.open("/civcraft-founders-stress-result.json", "w"))
file.write(textutils.serializeJSON(output))
file.close()
os.shutdown()''' % backend_arg
command = [args.craftos, "--directory", str(profile), "--exec", script]
if args.backend == "text":
    command.insert(1, "--headless")

console_path = profile / "native-console.log"
print(f"Isolated profile: {profile}", flush=True)
with console_path.open("w") as console:
    subprocess.run(
        command,
        stdout=console,
        stderr=subprocess.STDOUT,
        check=True,
        timeout=args.timeout,
    )

result_path = root / "civcraft-founders-stress-result.json"
if not result_path.exists():
    print(f"NO RESULT; native console: {console_path}")
    raise SystemExit(1)
result = json.loads(result_path.read_text())
if not result.get("ok"):
    print(json.dumps(result, indent=2, sort_keys=True))
    print(f"Native console: {console_path}")
    raise SystemExit(1)

report = result["report"]
expected = {
    ("founders-v4", "huge"),
    ("founders-v4", "vast"),
    ("specialization-v5", "huge"),
    ("specialization-v5", "vast"),
}
actual = {(item["profile"], item["size"]) for item in report["scenarios"]}
assert actual == expected, "Native report is missing a fixed profile/map-size case"
for item in report["scenarios"]:
    assert item["cities"] == 40 and item["units"] == 200 and item["round"] == 100
    assert item["frames"] >= 4 and item["savedBytes"] > 0
print(json.dumps(report, indent=2, sort_keys=True))
print(f"Evidence: {result_path}")
