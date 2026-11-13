#!/usr/bin/env python3
"""Tests for repository policy checks that do not require external packages."""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[2]
MODULE_PATH = REPOSITORY / "tools/ci/repository_checks.py"
SPEC = importlib.util.spec_from_file_location("repository_checks", MODULE_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load {MODULE_PATH}")
repository_checks = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(repository_checks)


class CiTriggerPolicyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.workflow = (REPOSITORY / ".github/workflows/ci.yml").read_text(encoding="utf-8")

    def test_current_workflow_matches_policy(self) -> None:
        self.assertEqual([], repository_checks.ci_trigger_policy_errors(self.workflow))

    def test_missing_pr_synchronize_event_is_rejected(self) -> None:
        altered = self.workflow.replace("      - synchronize\n", "")
        errors = repository_checks.ci_trigger_policy_errors(altered)
        self.assertTrue(any("pull_request trigger" in error for error in errors))

    def test_push_trigger_is_rejected(self) -> None:
        altered = self.workflow.replace(
            "  workflow_dispatch:",
            "  push:\n    branches:\n      - main\n  workflow_dispatch:",
        )
        errors = repository_checks.ci_trigger_policy_errors(altered)
        self.assertIn("CI must not run on push: a change is verified once, on its pull request", errors)

    def test_draft_skip_guard_is_required(self) -> None:
        altered = self.workflow.replace("github.event.pull_request.draft == false", "true")
        errors = repository_checks.ci_trigger_policy_errors(altered)
        self.assertIn("CI must skip expensive jobs while a pull request remains draft", errors)

    def test_mobile_build_jobs_are_rejected(self) -> None:
        # build.py takes `--target X`, `--target=X` and a quoted value; a YAML `>-` block may break
        # the line between the flag and its value.
        spellings = ("--target {}", "--target={}", '--target "{}"', "--target='{}'", "--target\n          {}")
        for target in ("android", "ios"):
            for spelling in spellings:
                with self.subTest(target=target, spelling=spelling):
                    altered = self.workflow + (
                        f"\n  {target}-build:\n    name: {target} build\n    runs-on: ubuntu-24.04\n"
                        f"    steps:\n      - run: >-\n          python tools/build/build.py\n"
                        f"          {spelling.format(target)}\n"
                    )
                    errors = repository_checks.ci_trigger_policy_errors(altered)
                    self.assertIn(f"CI must not build {target}: the mobile port is paused", errors)

    def test_windows_target_is_not_mistaken_for_a_mobile_one(self) -> None:
        self.assertIn("--target windows", self.workflow)
        errors = repository_checks.ci_trigger_policy_errors(self.workflow)
        self.assertFalse(any("mobile port is paused" in error for error in errors))

    def test_windows_build_job_is_required(self) -> None:
        altered = self.workflow.replace("    name: Windows Release Build\n", "    name: Windows\n")
        errors = repository_checks.ci_trigger_policy_errors(altered)
        self.assertIn("CI stable job name is missing: Windows Release Build", errors)


NL = chr(10)


class ExportPresetTests(unittest.TestCase):
    def test_current_presets_exclude_tests_and_addons(self) -> None:
        text = (REPOSITORY / "game/export_presets.cfg").read_text(encoding="utf-8")
        self.assertEqual([], repository_checks.export_preset_errors(text))

    def test_a_preset_that_ships_the_suites_is_rejected(self) -> None:
        text = '[preset.0]' + NL + 'name="Windows Desktop"' + NL + 'exclude_filter="addons/*"' + NL + 'export_path="../build/x.exe"' + NL
        self.assertEqual(
            ["export preset Windows Desktop does not exclude tests/*"],
            repository_checks.export_preset_errors(text),
        )

    def test_a_preset_that_exports_into_dist_is_rejected(self) -> None:
        text = '[preset.0]' + NL + 'name="Windows Desktop"' + NL + 'exclude_filter="tests/*, addons/*"' + NL + 'export_path="../dist/windows/a.exe"' + NL
        self.assertEqual(
            ["export preset Windows Desktop exports into dist/, where build.py writes its build"],
            repository_checks.export_preset_errors(text),
        )


if __name__ == "__main__":
    unittest.main()
