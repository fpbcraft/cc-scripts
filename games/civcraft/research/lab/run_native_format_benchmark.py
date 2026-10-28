#!/usr/bin/env python3
"""Run each generated format in a fresh CraftOS process."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
CRAFTOS = Path("/Applications/CraftOS-PC.app/Contents/MacOS/craftos")


def run_format(name: str) -> dict:
    profile = Path(tempfile.mkdtemp(prefix="civcraft-native-format-"))
    expression = ("fs.makeDir('/research/lab'); fs.makeDir('/research/lab/formats'); "
                 f"fs.copy('/repo/games/civcraft/research/lab/formats/actual_{name}.lua', '/research/lab/formats/actual_{name}.lua'); "
                 "fs.copy('/repo/games/civcraft/research/lab/datasets/actual_holdout_vectors.lua', '/research/lab/actual_holdout_vectors.lua'); "
                 f"_G.POLICY_NAME='{name}'; _G.POLICY_PATH='/research/lab/formats/actual_{name}.lua'; "
                 "dofile('/repo/games/civcraft/research/lab/native_inference_benchmark.lua'); os.shutdown()")
    command = [str(CRAFTOS), "--headless", "--directory", str(profile),
               "--mount-ro", f"/repo={ROOT}", "--exec", expression]
    try:
        completed = subprocess.run(command, text=True, capture_output=True, timeout=180)
        (profile / "stdout.log").write_text(completed.stdout, encoding="utf-8", errors="replace")
        (profile / "stderr.log").write_text(completed.stderr, encoding="utf-8", errors="replace")
        raw_stdout = re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", completed.stdout)
        raw_stdout = "".join(ch for ch in raw_stdout if ch == "\n" or ch == "\r" or ord(ch) >= 32)
        raw_stdout = raw_stdout.replace("\r", "").replace("\n", "")
        start = raw_stdout.find('{"status":"native_benchmark"')
        if start >= 0:
            raw_stdout = raw_stdout[start:]
        lines = [line.strip() for line in completed.stdout.splitlines() if line.strip()]
        parsed = None
        result_files = list(profile.rglob("native_benchmark_result.json"))
        if result_files:
            try:
                parsed = json.loads(result_files[0].read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                parsed = None
        candidates = [re.sub(r"\s+", "", raw_stdout)] + list(reversed(lines))
        for line in candidates if parsed is None else []:
            try:
                item, _ = json.JSONDecoder().raw_decode(line)
                if isinstance(item, dict) and (item.get("status") == "native_benchmark" or item.get("status") == "error"):
                    parsed = item
                    break
            except json.JSONDecodeError:
                continue
        return {"format": name, "processReturnCode": completed.returncode,
                "stdoutTail": lines[-3:], "stderrTail": completed.stderr.splitlines()[-3:],
                "result": parsed, "profile": str(profile)}
    except subprocess.TimeoutExpired as exc:
        return {"format": name, "status": "timeout", "error": str(exc), "profile": str(profile)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=HERE / "results/native_actual_format_benchmark.json")
    args = parser.parse_args()
    results = [run_format(name) for name in ("weights", "rule_tree", "tiny_quantized_mlp")]
    output = {"status": "native_actual_format_benchmark", "fresh_process_per_format": True,
              "formats": results,
              "source_hashes": {str(p.relative_to(HERE)): hashlib.sha256(p.read_bytes()).hexdigest()
                                for p in [HERE / "native_inference_benchmark.lua",
                                          HERE / "datasets/actual_holdout_vectors.lua"] +
                                list((HERE / "formats").glob("actual_*.lua"))}}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(output, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
