"""Run CivCraft wrapped-map UI checks in a fresh, disposable CraftOS profile."""
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
mode = parser.add_mutually_exclusive_group(required=True)
mode.add_argument("--monitor", action="store_true", help="Use an emulated advanced monitor and monitor_touch")
mode.add_argument("--gui", action="store_true", help="Use the native GUI terminal and mouse events")
args = parser.parse_args()

repo = Path(__file__).resolve().parents[1]
profile = Path(tempfile.mkdtemp(prefix="civcraft-wrap-session-"))
root = profile / "computer/0"
(root / "tests").mkdir(parents=True)
shutil.copytree(
    repo / "games/civcraft",
    root / "games/civcraft",
    ignore=shutil.ignore_patterns("data"),
)
shutil.copytree(repo / "lib/fpb", root / "games/civcraft/_lib/fpb", dirs_exist_ok=True)
shutil.copyfile(
    repo / "tests/civcraft_craftos_wrap_session.lua",
    root / "tests/civcraft_craftos_wrap_session.lua",
)

fixture_arg = '"--monitor"' if args.monitor else '"--gui"'
script = '''local ok, result = pcall(function()
local env = dofile("/games/civcraft/_lib/fpb/loader.lua")
    .environment("/games/civcraft", _ENV, "game.lua")
assert(loadfile("/tests/civcraft_craftos_wrap_session.lua", "t", env))(%s)
end)
if not ok then
    local file = assert(fs.open("/civcraft-wrap-session-result.json", "w"))
    file.write(textutils.serializeJSON({ ok = false, error = tostring(result) }))
    file.close()
end
os.shutdown()''' % fixture_arg
command = [args.craftos, "--directory", str(profile), "--exec", script]
print(f"Isolated profile: {profile}", flush=True)
console_path = profile / "native-console.log"
with console_path.open("w") as console:
    subprocess.run(command, stdout=console, stderr=subprocess.STDOUT, check=True, timeout=180)

result_path = root / "civcraft-wrap-session-result.json"
if not result_path.exists():
    print(f"NO RESULT; native console: {console_path}")
    raise SystemExit(1)
result = json.loads(result_path.read_text())
print(json.dumps(result, sort_keys=True))
if not result.get("ok"):
    print(f"Native console: {console_path}")
    raise SystemExit(1)
assert result["mode"] == ("monitor" if args.monitor else "gui")
assert result["renderer"] == "graphics"
assert result["cityCopies"] > 1 and result["unitCopies"] > 1
assert result["move"]["toX"] == result["move"]["eventCanonical"]
assert result["savedWrap"] is True and result["legacyWrap"] is False
print(f"Evidence: {result_path}")
