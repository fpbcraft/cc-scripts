"""Run focused Lua rule regressions in isolated native CraftOS environments."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--craftos',default='/Applications/CraftOS-PC.app/Contents/MacOS/craftos')
parser.add_argument('--tests',nargs='+',default=['civcraft_hostile_capture_test.lua','civcraft_p1_test.lua'])
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
for name in args.tests:
    if Path(name).name!=name or not (root/'tests'/name).is_file():
        parser.error('Choose existing test filenames inside tests/')
profile=Path(tempfile.mkdtemp(prefix='civcraft-native-rules-'))
computer=profile/'computer/0'
computer.mkdir(parents=True)
shutil.copytree(root/'games/civcraft',computer/'games/civcraft',ignore=shutil.ignore_patterns('data','__pycache__'))
# Focused UI/save fixtures use the same read-only helper modules as standalone Lua.
for helper_dir in ('helpers', 'support'):
    source = root/'tests'/helper_dir
    if source.is_dir():
        shutil.copytree(source, computer/'tests'/helper_dir)
# Installed-save fixtures execute the real installer against local source files.
for source_dir in ('installers', 'lib'):
    shutil.copytree(root/source_dir, computer/source_dir)
for name in args.tests:
    shutil.copyfile(root/'tests'/name,computer/name)
files='{'+','.join(json.dumps('/'+name) for name in args.tests)+'}'
script='''local function run(path)
 local env=setmetatable({}, {__index=_G});env._G=env
 local nativeLoadfile=loadfile
 env.loadfile=function(file,mode,scope)
  return nativeLoadfile(file,mode or "t",scope or env)
 end
 env.dofile=function(file)
  local chunk,why=env.loadfile(file)
  assert(chunk,why)
  return chunk()
 end
 local probePath="/tests/support/native_loadfile_probe.lua"
 env.loadfileProbe=env
 assert(assert(env.loadfile(probePath,"t"))()==env,"Default loadfile environment is isolated")
 local explicit={loadfileProbe=true}
 assert(assert(env.loadfile(probePath,"t",explicit))()==true,"Explicit loadfile environment is preserved")
 local binaryOnly,modeError=env.loadfile(probePath,"b",explicit)
 assert(not binaryOnly and modeError,"Explicit loadfile mode is preserved")
 env.dofile(path)
end
local results={}
for _,path in ipairs(%s) do
 os.queueEvent("native_rule_boundary");os.pullEvent("native_rule_boundary")
 local ok,why=pcall(run,path)
 results[#results+1]={test=path,ok=ok,error=tostring(why)}
end
local f=assert(fs.open("/rule-results.json","w"));f.write(textutils.serializeJSON({host=_HOST,results=results}));f.close();os.shutdown()'''%files
with (profile/'console.log').open('w') as log:
    subprocess.run([args.craftos,'--headless','--directory',str(profile),'--exec',script],stdout=log,stderr=log,timeout=90,check=True)
record=json.loads((computer/'rule-results.json').read_text())
record['profile']=str(profile)
print(json.dumps(record))
raise SystemExit(not all(row['ok'] for row in record['results']))
