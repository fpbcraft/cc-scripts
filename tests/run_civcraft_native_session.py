"""Run a complete CivCraft session in a fresh, disposable CraftOS profile."""
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
parser.add_argument("--monitor", action="store_true", help="Use a real emulated monitor and monitor_touch; requires GUI")
parser.add_argument("--host", action="store_true", help="Test a host/AI session instead of hotseat/AI")
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
profile = Path(tempfile.mkdtemp(prefix="civcraft-session-"))
root = profile / "computer/0"
(root / "tests").mkdir(parents=True)
shutil.copytree(repo / "games/civcraft", root / "games/civcraft", ignore=shutil.ignore_patterns("data"))
shutil.copytree(repo / "lib/fpb", root / "games/civcraft/_lib/fpb", dirs_exist_ok=True)
shutil.copyfile(repo / "tests/civcraft_craftos_session.lua", root / "tests/civcraft_craftos_session.lua")
flags = [
    "--settings", "--research", "--campaign", "--conversation", "--routes",
    "--history", "--council", "--map-tools", "--difficulty", "--civilization",
]
flags += ["--host-ai"] if args.host else ["--ai", "--war"]
if args.monitor:
    flags.append("--touch-monitor")
arguments = ", ".join(json.dumps(flag) for flag in flags)
script = '''local env = dofile("/games/civcraft/_lib/fpb/loader.lua").environment("/games/civcraft", _ENV, "game.lua")
local ok, why = pcall(assert(loadfile("/tests/civcraft_craftos_session.lua", "t", env)), %s)
local file = assert(fs.open("/session-return.txt", "w"))
file.write(ok and "PASS" or tostring(why)); file.close(); os.shutdown()''' % arguments
command = [args.craftos, "--directory", str(profile), "--exec", script]
if not args.monitor:
    command.insert(1, "--headless")
print(f"Isolated profile: {profile}", flush=True)
with (profile / "native-console.log").open("w") as console:
    subprocess.run(command, stdout=console, stderr=subprocess.STDOUT, check=True, timeout=90)
result = root / "session-return.txt"
content = result.read_text() if result.exists() else "NO RESULT"
print(content)
raise SystemExit(0 if content == "PASS" else 1)
