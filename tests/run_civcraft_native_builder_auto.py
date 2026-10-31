"""Exercise Builder auto-work through the native CivCraft UI in two fresh processes."""
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
parser.add_argument("--gui", action="store_true", help="Use the native GUI terminal")
parser.add_argument("--monitor", action="store_true", help="Use a real emulated monitor and monitor_touch (requires --gui)")
parser.add_argument("--installed-ref", help="Install this published Git ref before the native workflow")
args = parser.parse_args()
if args.monitor and not args.gui:
    parser.error("--monitor requires --gui")
repo = Path(__file__).resolve().parents[1]
profile = Path(tempfile.mkdtemp(prefix="civcraft-builder-auto-"))
print(f"Isolated profile: {profile}", flush=True)
root = profile / "computer/0"
(root / "tests").mkdir(parents=True)
if args.installed_ref:
    shutil.copyfile(repo / "installers/civcraft.lua", root / "bootstrap.lua")
else:
    shutil.copytree(repo / "games/civcraft", root / "games/civcraft", ignore=shutil.ignore_patterns("data"))
    shutil.copytree(repo / "lib/fpb", root / "games/civcraft/_lib/fpb", dirs_exist_ok=True)
shutil.copyfile(
    repo / "tests/civcraft_craftos_builder_auto.lua",
    root / "tests/civcraft_craftos_builder_auto.lua",
)

for resume in (False, True):
    script = '''local ok, why = pcall(function()
  local env = dofile("/games/civcraft/_lib/fpb/loader.lua").environment("/games/civcraft", _ENV, "game.lua")
  assert(loadfile("/tests/civcraft_craftos_builder_auto.lua", "t", env))(%s)
end)
local f = assert(fs.open("/builder-auto-return.txt", "w"))
f.write(ok and "PASS" or tostring(why)); f.close(); os.shutdown()''' % (
        json.dumps("--resume" if resume else "--new") + (', "--monitor"' if args.monitor else "")
    )
    if args.installed_ref and not resume:
        install = "assert(shell.run(\"/bootstrap.lua\", %s, \"--no-startup\"), \"Installer failed\")\n" % json.dumps(args.installed_ref)
        script = script.replace("local ok, why = pcall(function()\n", "local ok, why = pcall(function()\n" + install, 1)
    (root / "builder-auto-return.txt").unlink(missing_ok=True)
    command = [args.craftos, "--directory", str(profile), "--exec", script]
    if not args.gui:
        command.insert(1, "--headless")
    log_path = profile / ("resume.log" if resume else "first.log")
    with log_path.open("w") as console:
        subprocess.run(command, stdout=console, stderr=subprocess.STDOUT, check=True, timeout=300 if args.installed_ref else 180)
    result = root / "builder-auto-return.txt"
    content = result.read_text() if result.exists() else "NO RESULT"
    print(content)
    if content != "PASS":
        raise SystemExit(1)
print(f"Native Builder auto-work session passed: {root}")
