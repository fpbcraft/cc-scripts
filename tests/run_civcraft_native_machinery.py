"""Exercise machinery controls using native CraftOS rendering and queued mouse input."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--craftos", default="/Applications/CraftOS-PC.app/Contents/MacOS/craftos")
parser.add_argument("--gui", action="store_true")
parser.add_argument("--monitor", action="store_true", help="Use a native emulated monitor and monitor_touch (requires --gui)")
args = parser.parse_args()
if args.monitor and not args.gui:
    parser.error("--monitor requires --gui")
repo = Path(__file__).resolve().parents[1]
profile = Path(tempfile.mkdtemp(prefix="civcraft-machinery-session-"))
root = profile / "computer/0"
(root / "tests").mkdir(parents=True)
shutil.copytree(repo / "games/civcraft", root / "games/civcraft", ignore=shutil.ignore_patterns("data", "__pycache__"))
shutil.copytree(repo / "lib/fpb", root / "games/civcraft/_lib/fpb")
shutil.copyfile(repo / "tests/civcraft_craftos_machinery_session.lua", root / "tests/civcraft_craftos_machinery_session.lua")
script = """local ok,why=pcall(function()
local env=dofile('/games/civcraft/_lib/fpb/loader.lua').environment('/games/civcraft',_ENV,'game.lua')
assert(loadfile('/tests/civcraft_craftos_machinery_session.lua','t',env))(MONITOR_ARGUMENT)
end)
local f=assert(fs.open('/machinery-return.txt','w'));f.write(ok and 'PASS' or tostring(why));f.close();os.shutdown()"""
script = script.replace("MONITOR_ARGUMENT", json.dumps("--monitor") if args.monitor else "")
command = [args.craftos, "--directory", str(profile), "--exec", script]
if not args.gui:
    command.insert(1, "--headless")
print("Isolated profile:", profile, flush=True)
with (profile / "native-console.log").open("w") as log:
    subprocess.run(command, stdout=log, stderr=log, timeout=120, check=True)
result = (root / "machinery-return.txt").read_text()
print(result)
if result != "PASS":
    raise SystemExit(1)
print(json.dumps(json.loads((root / "machinery-results.json").read_text())))
