from __future__ import annotations

import datetime
import io
import sys
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock


REPOSITORY = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY / "tools/build"))

import playtest_round  # noqa: E402


class PlaytestRoundTest(unittest.TestCase):
    def test_reads_the_world_revision_of_the_checkout(self) -> None:
        text = (REPOSITORY / playtest_round.REVISION_FILE).read_text(encoding="utf-8")
        revision = playtest_round.parse_revision(text)
        self.assertRegex(revision, r"^[A-Z0-9_]+$")
        self.assertIn(revision, text.split("enum Value {", 1)[1].split("}", 1)[0])

    def test_a_file_without_the_revision_is_refused(self) -> None:
        with self.assertRaises(ValueError):
            playtest_round.parse_revision("const OTHER = 1")

    def test_the_default_tag_names_the_day(self) -> None:
        self.assertEqual(playtest_round.default_name(datetime.date(2026, 11, 13)), "playtest-2026-11-13")

    def test_a_tag_not_named_playtest_is_refused(self) -> None:
        with mock.patch.object(playtest_round, "run") as run, redirect_stderr(io.StringIO()):
            self.assertEqual(playtest_round.cut("v1.0", dry_run=True), 2)
        run.assert_not_called()

    def test_cut_tags_origin_main_pushes_the_tag_and_dispatches_ci(self) -> None:
        calls: list[tuple[list[str], bool]] = []

        def fake(command: list[str], dry_run: bool = False, capture: bool = True) -> str:
            calls.append((command, dry_run))
            if command[:2] == ["git", "tag"] and "--list" in command:
                return ""
            if command[:2] == ["git", "rev-parse"]:
                return "0123456789abcdef\n"
            if command[:2] == ["git", "show"]:
                return "const CURRENT_PUBLIC: Value = Value.SOURCE_ENTRY_TEST_V1\n"
            return ""

        with mock.patch.object(playtest_round, "run", side_effect=fake), redirect_stdout(io.StringIO()):
            self.assertEqual(playtest_round.cut("playtest-2026-11-13", dry_run=True), 0)
        commands = [" ".join(command) for command, _dry in calls]
        self.assertIn("git rev-parse origin/main", commands)
        tag = next(command for command, _dry in calls if command[:3] == ["git", "tag", "-a"])
        self.assertEqual(tag[3:5], ["playtest-2026-11-13", "0123456789abcdef"])
        self.assertIn("SOURCE_ENTRY_TEST_V1", tag[-1])
        pushed = [dry for command, dry in calls if command[:2] in (["git", "push"], ["gh", "workflow"])]
        self.assertEqual(pushed, [True, True], "the push and the dispatch are what a dry run leaves out")
        self.assertIn("gh workflow run ci.yml --ref playtest-2026-11-13", commands)

    def test_cut_refuses_a_tag_already_on_origin(self) -> None:
        def fake(command: list[str], dry_run: bool = False, capture: bool = True) -> str:
            return "abc refs/tags/playtest-2026-11-13\n" if "ls-remote" in command else ""

        with mock.patch.object(playtest_round, "run", side_effect=fake) as run, redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            self.assertEqual(playtest_round.cut("playtest-2026-11-13", dry_run=False), 2)
        self.assertFalse(any(call.args[0][:2] in (["git", "push"], ["git", "tag"]) for call in run.call_args_list))

    def test_cut_pushes_a_local_tag_a_failed_cut_left(self) -> None:
        calls: list[list[str]] = []

        def fake(command: list[str], dry_run: bool = False, capture: bool = True) -> str:
            calls.append(command)
            if "--list" in command:
                return "playtest-2026-11-13\n"
            if command[:2] == ["git", "rev-parse"]:
                return "0123456789abcdef\n"
            if command[:2] == ["git", "show"]:
                return "const CURRENT_PUBLIC: Value = Value.SOURCE_ENTRY_TEST_V1\n"
            return ""

        with mock.patch.object(playtest_round, "run", side_effect=fake), redirect_stdout(io.StringIO()):
            self.assertEqual(playtest_round.cut("playtest-2026-11-13", dry_run=True), 0)
        self.assertFalse(any(command[:3] == ["git", "tag", "-a"] for command in calls), "the tag is not made again")
        self.assertIn(["git", "push", "origin", "refs/tags/playtest-2026-11-13"], calls)

    def test_cut_refuses_a_local_tag_on_another_commit(self) -> None:
        def fake(command: list[str], dry_run: bool = False, capture: bool = True) -> str:
            if "--list" in command:
                return "playtest-2026-11-13\n"
            if command[:2] == ["git", "rev-parse"]:
                return "fedcba9876543210\n" if command[2].endswith("^{commit}") else "0123456789abcdef\n"
            if command[:2] == ["git", "show"]:
                return "const CURRENT_PUBLIC: Value = Value.SOURCE_ENTRY_TEST_V1\n"
            return ""

        with mock.patch.object(playtest_round, "run", side_effect=fake), redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            self.assertEqual(playtest_round.cut("playtest-2026-11-13", dry_run=False), 2)


if __name__ == "__main__":
    unittest.main()
