#!/usr/bin/env python3
"""Build only Lupa's optional LuaJIT module into the active virtual environment.

Requires a prebuilt LuaJIT source tree, the official Lupa 2.8 source archive,
Cython and setuptools. Does not replace existing Lua 5.x extensions.
"""
import argparse
import hashlib
import importlib.util
import json
import shutil
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

LUPA_SHA256 = 'd8022641b9ec8ecf2c5ecbe9f47e5a70e0b87c4b5ae921b92cb02a638e0acd08'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--luajit-source', type=Path, required=True)
    parser.add_argument('--lupa-archive', type=Path, required=True)
    args = parser.parse_args()
    if sys.prefix == sys.base_prefix:
        parser.error('Activate a temporary virtual environment first')
    if hashlib.sha256(args.lupa_archive.read_bytes()).hexdigest() != LUPA_SHA256:
        parser.error('Expected the official Lupa 2.8 source archive SHA256')
    source = args.luajit_source.resolve()
    library = source / 'src/libluajit.a'
    if not library.is_file() or not (source / 'src/lua.h').is_file():
        parser.error('Build LuaJIT first; expected src/libluajit.a and src/lua.h')
    import lupa
    destination = Path(lupa.__file__).resolve().parent
    if not destination.is_relative_to(Path(sys.prefix).resolve()):
        parser.error('Lupa must be installed inside the active virtual environment')
    for module in ('Cython', 'setuptools'):
        if importlib.util.find_spec(module) is None:
            parser.error(f'Install {module} in this virtual environment first')
    with tempfile.TemporaryDirectory(prefix='civcraft-lupa-build-') as temporary:
        with tarfile.open(args.lupa_archive) as archive:
            archive.extractall(temporary, filter='data')
        build = Path(temporary) / 'lupa-2.8'
        setup = build / 'setup.py'
        text = setup.read_text()
        needle = 'configs = get_lua_build_from_arguments()\n'
        assert text.count(needle) == 1, 'Unexpected Lupa setup layout'
        # The upstream custom-library path defaults to module name "lua".
        # Give it an explicit name so existing reference extensions stay intact.
        setup.write_text(text.replace(needle, needle + 'for config in configs:\n    config["libversion"] = "luajit21"\n'))
        subprocess.run([sys.executable, 'setup.py', 'build_ext', '--inplace', '--with-cython',
                        '--lua-lib', str(library), '--lua-includes', str(source / 'src')],
                       cwd=build, check=True)
        extensions = list((build / 'lupa').glob('luajit21*.so')) + list((build / 'lupa').glob('luajit21*.pyd'))
        if len(extensions) != 1:
            raise RuntimeError(f'Expected one extension, found {extensions}')
        target = destination / extensions[0].name
        shutil.copy2(extensions[0], target)
        print(json.dumps({'extension': str(target), 'extensionSha256': hashlib.sha256(target.read_bytes()).hexdigest(),
                          'lupaArchiveSha256': LUPA_SHA256,
                          'luaJitLibrarySha256': hashlib.sha256(library.read_bytes()).hexdigest()}))


if __name__ == '__main__':
    main()
