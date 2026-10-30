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
parser.add_argument("--gui", action="store_true", help="Use the native GUI terminal instead of headless text")
profile = parser.add_mutually_exclusive_group()
profile.add_argument("--specialization", action="store_true", help="Select Specialization V5 in the native lobby")
profile.add_argument(
    "--default-specialization",
    action="store_true",
    help="Verify a fresh campaign defaults to V5 without changing its lobby profile",
)
profile.add_argument("--landwork", action="store_true", help="Select Landwork V3 in the native lobby")
profile.add_argument("--development", action="store_true", help="Select Development V2 in the native lobby")
parser.add_argument("--seed", type=int, help="Use an explicit generated campaign seed for reproducible correctness checks")
parser.add_argument("--host", action="store_true", help="Test a host/AI session instead of hotseat/AI")
parser.add_argument("--contact-hud", action="store_true", help="Click the known-civilization HUD badge through native mouse events")
parser.add_argument("--installed-ref", help="Download this published revision through the real GitHub installer before testing")
parser.add_argument("--quick-research", action="store_true", help="Choose available research through native mouse events")
parser.add_argument("--unit-badges", action="store_true", help="Select a map unit badge through native mouse events")
parser.add_argument("--unit-actions", action="store_true", help="Exercise a unit action through queued native mouse input")
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
profile = Path(tempfile.mkdtemp(prefix="civcraft-session-"))
root = profile / "computer/0"
(root / "tests").mkdir(parents=True)
fixture = '{version=6,name="UPGRADE FIXTURE",phase="lobby",round=7,players={},cities={},units={}}'
if args.installed_ref:
    shutil.copyfile(repo / "installers/civcraft.lua", root / "bootstrap.lua")
    legacy = root / "civcraft/data"
    legacy.mkdir(parents=True)
    (legacy / "slot-2.dat").write_text(fixture)
else:
    shutil.copytree(repo / "games/civcraft", root / "games/civcraft", ignore=shutil.ignore_patterns("data"))
    shutil.copytree(repo / "lib/fpb", root / "games/civcraft/_lib/fpb", dirs_exist_ok=True)
shutil.copyfile(repo / "tests/civcraft_craftos_session.lua", root / "tests/civcraft_craftos_session.lua")
if args.specialization or args.default_specialization:
    shutil.copyfile(
        repo / "tests/civcraft_craftos_specialization_session.lua",
        root / "tests/civcraft_craftos_specialization_session.lua",
    )
flags = [
    "--settings", "--research", "--campaign", "--conversation", "--routes",
    "--history", "--council", "--map-tools", "--difficulty", "--civilization",
]
flags += ["--host-ai"] if args.host else ["--ai", "--war"]
if args.contact_hud:
    flags.append("--contact-hud")
if args.specialization:
    flags.append("--specialization")
if args.default_specialization:
    flags.append("--default-specialization")
elif args.landwork:
    flags.append("--landwork")
elif args.development:
    flags.append("--development")
if args.quick_research:
    flags.append("--quick-research")
if args.unit_badges:
    flags.append("--unit-badges")
if args.unit_actions:
    flags.append("--unit-actions")
if args.monitor:
    flags.append("--touch-monitor")
if args.seed is not None:
    flags.append(f"--seed={args.seed}")
arguments = ", ".join(json.dumps(flag) for flag in flags)
install = ""
if args.installed_ref:
    install = 'assert(shell.run("/bootstrap.lua", %s, "--no-startup"), "Installer failed")' % json.dumps(args.installed_ref)
specialization = ""
if args.specialization or args.default_specialization:
    for resume in (False, True):
        flags = (["--host"] if args.host else []) + (["--resume"] if resume else [])
        specialization += (
            '\nlocal specialEnv = dofile("/games/civcraft/_lib/fpb/loader.lua")'
            '.environment("/games/civcraft", _ENV, "game.lua")\n'
            'assert(loadfile("/tests/civcraft_craftos_specialization_session.lua", "t", '
            'specialEnv))(%s)\n'
        ) % ", ".join(json.dumps(flag) for flag in flags)
script = '''local ok, why = pcall(function()
%s
local env = dofile("/games/civcraft/_lib/fpb/loader.lua").environment("/games/civcraft", _ENV, "game.lua")
assert(loadfile("/tests/civcraft_craftos_session.lua", "t", env))(%s)
%s
end)
local file = assert(fs.open("/session-return.txt", "w"))
file.write(ok and "PASS" or tostring(why)); file.close(); os.shutdown()''' % (install, arguments, specialization)
command = [args.craftos, "--directory", str(profile), "--exec", script]
if not (args.monitor or args.gui):
    command.insert(1, "--headless")
print(f"Isolated profile: {profile}", flush=True)
with (profile / "native-console.log").open("w") as console:
    subprocess.run(
        command,
        stdout=console,
        stderr=subprocess.STDOUT,
        check=True,
        timeout=240 if args.installed_ref else 180 if args.specialization or args.default_specialization else 90,
    )
result = root / "session-return.txt"
content = result.read_text() if result.exists() else "NO RESULT"
print(content)
if content == "PASS" and (args.specialization or args.default_specialization):
    pending = json.loads((root / "specialty-session-pending.json").read_text())
    resumed = json.loads((root / "specialty-session-resumed.json").read_text())
    assert pending["campaign"] == resumed["campaign"]
    assert pending["redevelopmentPreview"]["verified"]
    assert pending["redevelopmentPreview"]["confirmButtonRendered"]
    assert pending["redevelopmentPreview"]["cost"] == 45
    assert pending["redevelopmentPreview"]["focusBefore"] == 1
    assert pending["redevelopmentPreview"]["focusAfter"] == 1
    assert pending["redevelopmentPreview"]["allowance"] == 1
    assert pending["focus"]["primary"]["used"] == 1
    assert pending["focus"]["primary"]["reserved"] == 1
    assert pending["focus"]["secondary"]["used"] == 1
    assert resumed["restoredCheckpoint"]["progress"] > 0
    assert resumed["primary"]["sites"]["freight"]["id"] == resumed["restoredCheckpoint"]["projectId"]
    assert resumed["secondary"]["sites"]["knowledge"]["id"] == pending["secondary"]["sites"]["knowledge"]["id"]
    assert resumed["focus"]["primary"]["used"] == 1
    assert resumed["focus"]["secondary"]["used"] == 1
    print(
        json.dumps(
            {
                "specialtySession": resumed["mode"],
                "savedRound": pending["round"],
                "resumedRound": resumed["round"],
                "checkpoint": resumed["restoredCheckpoint"],
                "distinctOutputs": resumed["effects"],
                "acceptedAIWorks": pending["acceptedAIWorks"] or resumed["acceptedAIWorks"],
                "evidence": str(root),
            }
        )
    )
if content == "PASS" and args.installed_ref:
    assert (root / "games/civcraft/data/slot-2.dat").read_text() == fixture
    assert (root / "civcraft/data/slot-2.dat").read_text() == fixture
    assert not (root / "startup.lua").exists()
    print("Installed runtime passed; migrated and original campaign fixtures remain intact.")
raise SystemExit(0 if content == "PASS" else 1)
