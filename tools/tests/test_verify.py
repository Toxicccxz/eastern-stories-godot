#!/usr/bin/env python3
"""Tests for the verification entrypoint's step runner."""

from __future__ import annotations

import importlib.util
import os
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[2]
MODULE_PATH = REPOSITORY / "tools/ci/verify.py"
SPEC = importlib.util.spec_from_file_location("verify", MODULE_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load {MODULE_PATH}")
verify = importlib.util.module_from_spec(SPEC)
# dataclasses look their module up in sys.modules while the module executes.
sys.modules[SPEC.name] = verify
SPEC.loader.exec_module(verify)


class StepRunnerTests(unittest.TestCase):
    def test_successful_step_returns(self) -> None:
        verify._run([sys.executable, "-c", "pass"], timeout=30)

    def test_failing_step_raises(self) -> None:
        with self.assertRaisesRegex(RuntimeError, "exit code 3"):
            verify._run([sys.executable, "-c", "raise SystemExit(3)"], timeout=30)

    def test_hung_step_is_stopped_and_fails(self) -> None:
        with self.assertRaisesRegex(RuntimeError, "timed out"):
            verify._run([sys.executable, "-c", "import time; time.sleep(30)"], timeout=0.5)

    def test_script_error_fails_a_godot_step(self) -> None:
        script = "print('SCRIPT ERROR: Invalid call.'); print('   at: helper (res://tests/x.gd:7)'); print('PASS')"
        with self.assertRaisesRegex(RuntimeError, r"1 SCRIPT ERROR line\(s\)[\s\S]*res://tests/x.gd:7"):
            verify._run([sys.executable, "-c", script], timeout=30, fail_on_script_errors=True)

    def test_script_error_on_the_last_line_fails(self) -> None:
        with self.assertRaisesRegex(RuntimeError, "1 SCRIPT ERROR line"):
            verify._run([sys.executable, "-c", "print('PASS'); print('SCRIPT ERROR: at the end')"], timeout=30, fail_on_script_errors=True)

    def test_exit_code_is_reported_before_script_errors(self) -> None:
        with self.assertRaisesRegex(RuntimeError, "exit code 4"):
            verify._run([sys.executable, "-c", "print('SCRIPT ERROR: x'); raise SystemExit(4)"], timeout=30, fail_on_script_errors=True)

    def test_relayed_bytes_that_are_not_utf8_do_not_break_the_step(self) -> None:
        script = "import sys; sys.stdout.buffer.write(bytes([0xff, 0xfe, 10])); print('PASS')"
        verify._run([sys.executable, "-c", script], timeout=30, fail_on_script_errors=True)

    def test_hung_godot_step_is_stopped_and_fails(self) -> None:
        with self.assertRaisesRegex(RuntimeError, "timed out"):
            verify._run([sys.executable, "-c", "import time; time.sleep(30)"], timeout=0.5, fail_on_script_errors=True)

    def test_script_error_is_only_checked_in_godot_steps(self) -> None:
        verify._run([sys.executable, "-c", "print('SCRIPT ERROR: quoted by a tooling test')"], timeout=30)


class GameplaySuiteTests(unittest.TestCase):
    """Step 4 runs each *_test.gd in its own process and judges it by its run_suite.gd log."""

    SUITE = "res://tests/runtime/lake_test.gd"

    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def _judge(self, log: str, returncode: int | None = 0):
        path = self.root / "suite.log"
        path.write_bytes(log.encode("utf-8"))
        run = verify.SuiteRun(self.SUITE, path)
        verify._check_suite_log(run, returncode)
        return run

    def test_every_test_file_is_discovered_without_registration(self) -> None:
        game = self.root / "game"
        for relative in ["tests/core/b_test.gd", "tests/runtime/a_test.gd", "tests/support/helper.gd", "tests/run_suite.gd"]:
            (game / relative).parent.mkdir(parents=True, exist_ok=True)
            (game / relative).write_text("extends RefCounted\n", encoding="utf-8")
        self.assertEqual(
            ["res://tests/core/b_test.gd", "res://tests/runtime/a_test.gd"], verify.discover_suites(game)
        )

    def test_passing_suite_counts_its_assertions(self) -> None:
        run = self._judge(f"{self.SUITE}  92 assertions, 0 failures, 4116 ms\nPASS: 1 suite(s), 92 assertions, 0 failure(s)\n")
        self.assertTrue(run.passed)
        self.assertEqual(92, run.assertions)

    def test_failed_assertions_are_named(self) -> None:
        run = self._judge(
            "lake_test.gd: existing Fill UI path at Lake\nlake_test.gd: Waterfall Fill regression\n"
            "FAIL: 1 suite(s), 92 assertions, 2 failure(s)\n",
            1,
        )
        self.assertFalse(run.passed)
        self.assertEqual(
            ["lake_test.gd: existing Fill UI path at Lake", "lake_test.gd: Waterfall Fill regression"], run.failures
        )

    def test_script_error_fails_a_suite_that_reports_pass(self) -> None:
        run = self._judge(
            "SCRIPT ERROR: Invalid call.\n   at: helper (res://tests/x.gd:7)\n"
            "PASS: 1 suite(s), 10 assertions, 0 failure(s)\n"
        )
        self.assertFalse(run.passed)
        self.assertEqual(["SCRIPT ERROR: Invalid call. at: helper (res://tests/x.gd:7)"], run.script_errors)

    def test_suite_without_a_summary_returned_no_result(self) -> None:
        run = self._judge("Godot Engine v4.7.2\n", 1)
        self.assertFalse(run.passed)
        self.assertIn("returned no result", run.problems[0])

    def test_suite_that_ran_no_assertions_fails(self) -> None:
        run = self._judge("PASS: 1 suite(s), 0 assertions, 0 failure(s)\n")
        self.assertEqual(["no assertions ran"], run.problems)

    def test_nonzero_exit_fails_a_suite_that_reports_pass(self) -> None:
        run = self._judge("PASS: 1 suite(s), 5 assertions, 0 failure(s)\n", 3)
        self.assertEqual(["exit code 3"], run.problems)

    def test_unloadable_suite_fails(self) -> None:
        run = self._judge(f"{self.SUITE}: cannot load or instantiate\nFAIL: 1 suite(s), 0 assertions, 1 failure(s)\n", 1)
        self.assertEqual([f"{self.SUITE}: cannot load or instantiate"], run.failures)
        self.assertFalse(run.passed)

    def test_stopped_process_is_gone(self) -> None:
        processes = verify._SuiteProcesses()
        with (self.root / "sleep.log").open("wb") as log:
            process = processes.start([sys.executable, "-c", "import time; time.sleep(60)"], dict(os.environ), log)
            self.assertIsNotNone(process)
            verify._kill_tree(process)
        self.assertIsNotNone(process.poll())
        processes.finish(process)
        processes.stop_all()
        with (self.root / "late.log").open("wb") as log:
            self.assertIsNone(processes.start([sys.executable, "-c", "pass"], dict(os.environ), log))


if __name__ == "__main__":
    unittest.main()
