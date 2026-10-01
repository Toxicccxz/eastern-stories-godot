#!/usr/bin/env python3
"""Tests for the verification entrypoint's step runner."""

from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[2]
MODULE_PATH = REPOSITORY / "tools/ci/verify.py"
SPEC = importlib.util.spec_from_file_location("verify", MODULE_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load {MODULE_PATH}")
verify = importlib.util.module_from_spec(SPEC)
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


if __name__ == "__main__":
    unittest.main()
