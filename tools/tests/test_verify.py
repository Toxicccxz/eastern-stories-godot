#!/usr/bin/env python3
"""Tests for the verification entrypoint's step runner."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import os
import random
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

    def test_suites_run_headless_at_a_fixed_frame_rate(self) -> None:
        command = verify.suite_command(Path("godot"), self.SUITE)
        self.assertEqual("godot", command[0])
        self.assertIn("--headless", command)
        # Frames follow one another at once instead of waiting for the wall clock.
        self.assertEqual("60", command[command.index("--fixed-fps") + 1])
        self.assertEqual(["--script", "res://tests/run_suite.gd", "--", self.SUITE], command[-4:])

    def test_slowest_suites_start_first(self) -> None:
        times = verify.SuiteTimes({"slow": 300.0, "mid": 90.0, "tied_b": 5.0, "tied_a": 5.0}, 60.0)
        self.assertEqual(
            ["slow", "mid", "new", "tied_a", "tied_b"],
            verify.suite_order(["tied_b", "new", "tied_a", "mid", "slow"], times),
        )

    def test_long_suites_have_their_own_limit(self) -> None:
        self.assertEqual(verify.suite_timeout("res://tests/core/anything_test.gd"), verify.SUITE_TIMEOUT_SECONDS)
        soak = "res://tests/runtime/world_soak_test.gd"
        self.assertGreater(verify.suite_timeout(soak), verify.SUITE_TIMEOUT_SECONDS)
        # Each override names a suite that exists and leaves room over its recorded time.
        times = verify.load_suite_times()
        for suite, limit in verify.SUITE_TIMEOUT_OVERRIDES.items():
            self.assertTrue((REPOSITORY / "game" / suite.removeprefix("res://")).is_file(), suite)
            self.assertGreaterEqual(limit, 2 * times.of(suite), suite)

    def test_recorded_suite_times_are_usable(self) -> None:
        times = verify.load_suite_times()
        self.assertGreater(times.default_seconds, 0)
        self.assertEqual([], [suite for suite, seconds in times.recorded.items() if seconds <= 0])
        # A new suite may be missing, but a run of the shards rests on most of them being known.
        suites = verify.discover_suites(verify.REPOSITORY / "game")
        self.assertGreater(sum(suite in times.recorded for suite in suites), len(suites) * 0.9)

    def test_each_suite_goes_to_the_lightest_shard(self) -> None:
        times = verify.SuiteTimes({"a": 9.0, "b": 8.0, "c": 7.0, "d": 3.0, "e": 2.0, "f": 1.0}, 60.0)
        ordered = verify.suite_order(list("abcdef"), times)
        self.assertEqual(
            [["a", "f"], ["b", "e"], ["c", "d"]],
            [verify.shard_suites(ordered, times, (index, 3)) for index in (1, 2, 3)],
        )

    def test_shards_run_every_suite_once(self) -> None:
        discovered = verify.discover_suites(verify.REPOSITORY / "game")
        times = verify.load_suite_times()
        # The new suite has no record: it is still assigned, as default_seconds.
        suites = discovered + ["res://tests/runtime/not_measured_yet_test.gd"]
        ordered = verify.suite_order(suites, times)
        for count in (1, 3, 6, 7):
            with self.subTest(count):
                shards = [verify.shard_suites(ordered, times, (index, count)) for index in range(1, count + 1)]
                self.assertEqual(sorted(suites), sorted(suite for shard in shards for suite in shard))
        self.assertEqual(ordered, verify.shard_suites(ordered, times, None))

    def test_shards_do_not_depend_on_the_discovery_order(self) -> None:
        suites = verify.discover_suites(verify.REPOSITORY / "game")
        times = verify.load_suite_times()
        ordered = verify.suite_order(suites, times)
        shuffled = list(suites)
        random.Random(7).shuffle(shuffled)
        reordered = verify.suite_order(shuffled, times)
        for index in range(1, 7):
            self.assertEqual(
                verify.shard_suites(ordered, times, (index, 6)), verify.shard_suites(reordered, times, (index, 6))
            )

    def test_shards_take_about_as_long(self) -> None:
        times = verify.load_suite_times()
        ordered = verify.suite_order(list(times.recorded), times)
        loads = [sum(times.of(suite) for suite in verify.shard_suites(ordered, times, (index, 6))) for index in range(1, 7)]
        self.assertLess(max(loads), sum(loads) / 6 * 1.05)

    def test_a_shard_runs_its_suites_slowest_first(self) -> None:
        times = verify.load_suite_times()
        ordered = verify.suite_order(list(times.recorded), times)
        for index in range(1, 7):
            shard = verify.shard_suites(ordered, times, (index, 6))
            self.assertEqual(verify.suite_order(shard, times), shard)

    def test_suite_shard_option_takes_k_of_n(self) -> None:
        self.assertEqual((2, 3), verify._arguments(["--suite-shard", "2/3"]).suite_shard)
        self.assertIsNone(verify._arguments([]).suite_shard)
        for arguments in (["--suite-shard", "0/3"], ["--suite-shard", "4/3"], ["--suite-shard", "3"],
                          ["--suite-shard", "1/3", "--skip-gameplay-tests"]):
            with self.subTest(arguments), self.assertRaises(SystemExit), contextlib.redirect_stderr(io.StringIO()):
                verify._arguments(arguments)

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

    def test_fail_summary_without_failure_lines_still_fails(self) -> None:
        run = self._judge("FAIL: 1 suite(s), 7 assertions, 2 failure(s)\n", 1)
        self.assertEqual(["suite reported 2 failure(s)"], run.problems)

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
