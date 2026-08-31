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

    def test_feature_branch_push_cannot_be_added_to_main_post_merge_gate(self) -> None:
        altered = self.workflow.replace(
            "      - main\n  workflow_dispatch:",
            "      - main\n      - feature/**\n  workflow_dispatch:",
        )
        errors = repository_checks.ci_trigger_policy_errors(altered)
        self.assertIn("CI push trigger must target only main for post-merge validation", errors)

    def test_draft_skip_guard_is_required(self) -> None:
        altered = self.workflow.replace("github.event.pull_request.draft == false", "true")
        errors = repository_checks.ci_trigger_policy_errors(altered)
        self.assertIn("CI must skip expensive jobs while a pull request remains draft", errors)


if __name__ == "__main__":
    unittest.main()
