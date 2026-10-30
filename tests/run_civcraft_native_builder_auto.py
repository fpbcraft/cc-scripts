"""Exercise Builder auto-work through the native CivCraft UI in two fresh processes."""
import argparse
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
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
profile = Path(tempfile.mkdtemp(prefix="civcraft-builder-auto-"))
root = profile / "computer/0"
(root / "tests").mkdir(parents=True)
shutil.copytree(repo / "games/civcraft", root / "games/civcraft", ignore=shutil.ignore_patterns("data"))
shutil.copytree(repo / "lib/fpb", root / "games/civcraft/_lib/fpb", dirs_exist_ok=True)
shutil.copyfile(
    repo / "tests/civcraft_craftos_builder_auto.lua",
    root / "tests/civcraft_craftos_builder_auto.lua",
)

for resume in (False, True):
    script = '''local ok, why = pcall(function()
  assert(loadfile("/tests/civcraft_craftos_builder_auto.lua", "t", _ENV))(%s)
end)
local f = assert(fs.open("/builder-auto-return.txt", "w"))
f.write(ok and "PASS" or tostring(why)); f.close(); os.shutdown()''' % (
        '"--resume"' if resume else '"--new"'
    )
    command = [args.craftos, "--directory", str(profile), "--exec", script]
    if not args.gui:
        command.insert(1, "--headless")
    log_path = profile / ("resume.log" if resume else "first.log")
    with log_path.open("w") as console:
        subprocess.run(command, stdout=console, stderr=subprocess.STDOUT, check=True, timeout=180)
    result = root / "builder-auto-return.txt"
    content = result.read_text() if result.exists() else "NO RESULT"
    print(content)
    if content != "PASS":
        raise SystemExit(1)
print(f"Native Builder auto-work session passed: {root}")
