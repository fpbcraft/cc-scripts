"""Run generated cityless V5 multiplayer correctness with real emulated rednet."""
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from civcraft_native_process import NativeProcessTimeout, run_native_process

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--craftos", default=shutil.which("craftos") or "/Applications/CraftOS-PC.app/Contents/MacOS/craftos")
parser.add_argument("--reverse-race", action="store_true")
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
profile = Path(tempfile.mkdtemp(prefix="civcraft-specialty-network-"))
print(f"Isolated profile: {profile}", flush=True)
fixture = "civcraft_craftos_specialty_network.lua"
boot = f'assert(loadfile("/tests/{fixture}"))(' + ('"--reverse-race"' if args.reverse_race else "") + ")"
for identity in range(3):
    root = profile / "computer" / str(identity)
    (root / "tests").mkdir(parents=True)
    shutil.copytree(repo / "games/civcraft", root / "games/civcraft", ignore=shutil.ignore_patterns("data"))
    shutil.copytree(repo / "lib/fpb", root / "games/civcraft/_lib/fpb", dirs_exist_ok=True)
    shutil.copyfile(repo / "tests" / fixture, root / "tests" / fixture)
    (root / "startup.lua").write_text(boot + "\n")
command = [args.craftos, "--headless", "--directory", str(profile), "--exec", boot]
process_report = None
timed_out = False
with (profile / "native-console.log").open("w") as console:
    try:
        process_report = run_native_process(command, profile, console, timeout=120)
    except NativeProcessTimeout as error:
        process_report = error.report
        timed_out = True
        print(f"Native process timed out: {process_report}", flush=True)
if not timed_out:
    print(f"Native process exited: {process_report}", flush=True)
failed = timed_out or process_report["returnCode"] != 0
for identity in range(3):
    result = profile / "computer" / str(identity) / "civcraft-specialty-network.txt"
    content = result.read_text() if result.exists() else "NO RESULT"
    passed = re.search(r"\bpassed\s*=\s*true\b", content) is not None
    print(f"Computer {identity}: {'PASS' if passed else 'FAIL'}; {result}")
    if not passed:
        failed = True
        print(content)
raise SystemExit(1 if failed else 0)
