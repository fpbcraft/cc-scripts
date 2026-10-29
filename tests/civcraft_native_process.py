"""Run a native process with persisted exit and timeout diagnostics."""
from __future__ import annotations

import json
import signal
import subprocess
import time
from pathlib import Path
from typing import Any, Callable


class NativeProcessTimeout(Exception):
	"""Raised after a native child reaches its fixed deadline and is reaped."""

	def __init__(self, report: dict[str, Any]):
		self.report = report
		super().__init__(f"Native process timed out after {report['elapsedSeconds']:.3f}s")


def _signal_name(return_code: int | None) -> str | None:
	if return_code is None or return_code >= 0:
		return None
	try:
		return signal.Signals(-return_code).name
	except ValueError:
		return f"SIG{-return_code}"


def _save_report(profile: Path, report: dict[str, Any]) -> None:
	(profile / "native-process.json").write_text(json.dumps(report, indent=2) + "\n")


def capture_process_sample(pid: int, profile: Path, timeout: float = 4.0) -> dict[str, Any]:
	"""Capture a bounded sample of the still-running native process."""
	path = profile / "native-process.sample.txt"
	try:
		completed = subprocess.run(
			["/usr/bin/sample", str(pid), "2", "-file", str(path)],
			capture_output=True,
			text=True,
			timeout=timeout,
			check=False,
		)
		return {
			"path": str(path),
			"exitCode": completed.returncode,
			"error": completed.stderr.strip() or None,
			"fileExists": path.exists(),
		}
	except Exception as error:
		return {"path": str(path), "error": f"{type(error).__name__}: {error}"}


def run_native_process(
	command: list[str],
	profile: Path,
	stdout: Any,
	timeout: float = 120,
	*,
	popen_factory: Callable[..., Any] = subprocess.Popen,
	sampler: Callable[[int, Path], dict[str, Any]] = capture_process_sample,
	clock: Callable[[], float] = time.monotonic,
) -> dict[str, Any]:
	"""Wait for a native process, sampling it before killing on deadline."""
	profile = Path(profile)
	process = popen_factory(command, stdout=stdout, stderr=subprocess.STDOUT)
	started = clock()
	try:
		process.wait(timeout=timeout)
	except subprocess.TimeoutExpired:
		elapsed = clock() - started
		try:
			sample = sampler(process.pid, profile)
		except Exception as error:
			sample = {"error": f"{type(error).__name__}: {error}"}
		process.kill()
		process.wait()
		report = {
			"timedOut": True,
			"pid": process.pid,
			"elapsedSeconds": elapsed,
			"profile": str(profile),
			"returnCode": process.returncode,
			"signal": _signal_name(process.returncode),
			"sample": sample,
		}
		_save_report(profile, report)
		raise NativeProcessTimeout(report)

	report = {
		"timedOut": False,
		"pid": process.pid,
		"elapsedSeconds": clock() - started,
		"profile": str(profile),
		"returnCode": process.returncode,
		"signal": _signal_name(process.returncode),
	}
	_save_report(profile, report)
	return report
