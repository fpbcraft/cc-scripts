"""Unit tests for native process timeout reporting and cleanup."""
import subprocess
import tempfile
import unittest
from pathlib import Path

from civcraft_native_process import NativeProcessTimeout, run_native_process


class FakeProcess:
	def __init__(self, events, timeout=False, return_code=0, interrupt_wait=False):
		self.events = events
		self.pid = 43210
		self.returncode = None
		self.timeout = timeout
		self.exit_code = return_code
		self.interrupt_wait = interrupt_wait

	def wait(self, timeout=None):
		self.events.append(("wait", timeout))
		if timeout is not None and self.interrupt_wait:
			self.interrupt_wait = False
			raise KeyboardInterrupt
		if timeout is not None and self.timeout:
			raise subprocess.TimeoutExpired(["fake-native"], timeout)
		if self.returncode is None:
			self.returncode = -9 if self.timeout else self.exit_code
		return self.returncode

	def poll(self):
		self.events.append(("poll", self.pid))
		return self.returncode

	def kill(self):
		self.events.append(("kill", self.pid))
		self.returncode = -9


class NativeProcessTests(unittest.TestCase):
	def test_success_records_exit_without_sampling(self):
		with tempfile.TemporaryDirectory() as directory:
			profile = Path(directory)
			events = []
			process = FakeProcess(events)
			result = run_native_process(
				["fake-native"],
				profile,
				subprocess.DEVNULL,
				popen_factory=lambda *args, **kwargs: process,
				sampler=lambda *_: self.fail("success must not sample"),
			)
			self.assertFalse(result["timedOut"])
			self.assertEqual(result["returnCode"], 0)
			self.assertEqual(result["pid"], 43210)
			self.assertEqual(result["profile"], str(profile))

	def test_nonzero_exit_code_is_preserved(self):
		with tempfile.TemporaryDirectory() as directory:
			process = FakeProcess([], return_code=7)
			result = run_native_process(
				["fake-native"],
				Path(directory),
				subprocess.DEVNULL,
				popen_factory=lambda *args, **kwargs: process,
				sampler=lambda *_: self.fail("nonzero exit must not sample"),
			)
			self.assertFalse(result["timedOut"])
			self.assertEqual(result["returnCode"], 7)

	def test_timeout_samples_before_kill_and_reaps_after_sampler_failure(self):
		with tempfile.TemporaryDirectory() as directory:
			profile = Path(directory)
			events = []
			process = FakeProcess(events, timeout=True)

			def failed_sample(pid, sample_profile):
				events.append(("sample", pid, sample_profile))
				raise OSError("sample unavailable")

			with self.assertRaises(NativeProcessTimeout) as raised:
				run_native_process(
					["fake-native"],
					profile,
					subprocess.DEVNULL,
					popen_factory=lambda *args, **kwargs: process,
					sampler=failed_sample,
				)
			sample_index = next(i for i, event in enumerate(events) if event[0] == "sample")
			kill_index = next(i for i, event in enumerate(events) if event[0] == "kill")
			self.assertLess(sample_index, kill_index)
			self.assertEqual(events[-1], ("wait", None))
			self.assertEqual(process.returncode, -9)
			self.assertTrue(raised.exception.report["timedOut"])
			self.assertEqual(raised.exception.report["returnCode"], -9)
			self.assertEqual(raised.exception.report["signal"], "SIGKILL")
			self.assertIn("sample unavailable", raised.exception.report["sample"]["error"])

	def test_wait_interrupt_kills_and_reaps_owned_child_then_propagates(self):
		with tempfile.TemporaryDirectory() as directory:
			events = []
			process = FakeProcess(events, interrupt_wait=True)
			with self.assertRaises(KeyboardInterrupt):
				run_native_process(
					["fake-native"],
					Path(directory),
					subprocess.DEVNULL,
					popen_factory=lambda *args, **kwargs: process,
					sampler=lambda *_: self.fail("interrupted wait must not sample"),
				)
			self.assertIn(("kill", 43210), events)
			self.assertEqual(events[-1], ("wait", None))
			self.assertEqual(process.returncode, -9)

	def test_sampler_interrupt_kills_and_reaps_owned_child_then_propagates(self):
		with tempfile.TemporaryDirectory() as directory:
			events = []
			process = FakeProcess(events, timeout=True)

			def interrupted_sample(pid, _profile):
				events.append(("sample", pid))
				raise KeyboardInterrupt

			with self.assertRaises(KeyboardInterrupt):
				run_native_process(
					["fake-native"],
					Path(directory),
					subprocess.DEVNULL,
					popen_factory=lambda *args, **kwargs: process,
					sampler=interrupted_sample,
				)
			self.assertEqual(events[1], ("sample", 43210))
			self.assertIn(("kill", 43210), events)
			self.assertEqual(events[-1], ("wait", None))
			self.assertEqual(process.returncode, -9)


if __name__ == "__main__":
	unittest.main()
