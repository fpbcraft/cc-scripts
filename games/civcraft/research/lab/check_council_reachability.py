#!/usr/bin/env python3
"""Native/Lupa exhaustive election audit; no approximate election simulator."""
import json
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0,str(ROOT/'tools/civcraft_lab'))
from runtime import Runtime, from_lua
from runner import source_manifest
from coordinated_siege_study import hash_file


def main():
    source = source_manifest()
    files = (Path(__file__), HERE/'council_reachability.lua', HERE/'council_reachability_native.lua')
    hashes = {str(p.relative_to(ROOT)):hash_file(p) for p in files}
    runtime = Runtime({'seed':75123,'hostileMode':'off', 'players':[
        {'civilization':'forge','ai':False},{'civilization':'forge','ai':False}]})
    audit = runtime.lua.globals().dofile('/games/civcraft/research/lab/council_reachability.lua')
    started = time.perf_counter()
    # Hook the coroutine itself: a hook on the resuming main thread alone
    # would not budget work performed inside this independently created thread.
    resume = runtime.lua.eval('''function(audit, budget)
        local thread = coroutine.create(function() return audit.run(coroutine.yield) end)
        return function()
            local spent = 0
            debug.sethook(thread,function()
                spent = spent+10000
                if spent > budget then error('COUNCIL_AUDIT_INSTRUCTION_BUDGET') end
            end,'',10000)
            local ok,result = coroutine.resume(thread)
            debug.sethook(thread)
            assert(ok,result)
            return coroutine.status(thread) == 'dead', result
        end
    end''')(audit, runtime.instruction_budget)
    while True:
        done, result = runtime.call(resume)
        if done:
            offline = from_lua(result)
            break
    offline_seconds = time.perf_counter()-started
    assert offline['totalCases'] == 10548
    profile = Path(tempfile.mkdtemp(prefix='civcraft-council-reachability-'))
    computer = profile/'computer/0'
    computer.mkdir(parents=True)
    shutil.copyfile(HERE/'council_reachability_native.lua',computer/'council_reachability_native.lua')
    command = ['/Applications/CraftOS-PC.app/Contents/MacOS/craftos','--headless',
        '--directory',str(profile),'--mount-ro',f'/repo={ROOT}','--exec',
        'fs.copy("/repo/games/civcraft","/games/civcraft");'
        'shell.run("/council_reachability_native.lua");os.shutdown()']
    started = time.perf_counter()
    with (profile/'console.log').open('w') as log:
        completed = subprocess.run(command,stdout=log,stderr=log,timeout=120)
    output = computer/'council_reachability_native.json'
    if not output.exists():
        raise RuntimeError(f'Native output missing, exit {completed.returncode}: {profile}')
    native = json.loads(output.read_text())
    native_seconds = time.perf_counter()-started
    unchanged = source == source_manifest() and hashes == {
        str(p.relative_to(ROOT)):hash_file(p) for p in files}
    record = {'purpose':'Exhaustive bounded Council ballot/reachability audit',
        'sourceManifest':source,'researchHashes':hashes,'sourceUnchanged':unchanged,
        'nativeResultEqual':offline == native['result'],'result':offline,
        'nativeHost':native['host'],'nativeExitCode':completed.returncode,'profile':str(profile),
        'offlineSeconds':offline_seconds,'nativeSeconds':native_seconds,
        'limits':['Enumerates one-session ballot choices for every 2/3-delegate profile with all members alive and eligible.',
                  'Fixture village loyalty, commerce and halls are supplied preconditions, not agent accomplishments.',
                  'Enumerated ballot proportions are not policy win probabilities or a distribution over rational play.',
                  'This is not an enumeration of wars, elimination histories, treaty negotiation or every faction combination.']}
    destination = HERE/'results/council_reachability.json'
    destination.write_text(json.dumps(record,indent=2,sort_keys=True)+'\n')
    print(json.dumps({'output':str(destination),'nativeResultEqual':record['nativeResultEqual'],
        'sourceUnchanged':unchanged,'totalCases':offline['totalCases'],
        'profiles':[{k:p[k] for k in ('players','cases','wins','noConsentForZeroCases',
            'zeroWinsWithoutConsent','selfOrAbstainCases','selfOrAbstainWins','unanimousZeroWins')}
                    for p in offline['profiles']]}))
    if completed.returncode or not unchanged or not record['nativeResultEqual']:
        raise SystemExit('Council audit failed source/native parity checks')


if __name__ == '__main__':
    main()
