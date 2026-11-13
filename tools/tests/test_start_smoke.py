from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


REPOSITORY = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY / "tools/ci"))

import start_smoke  # noqa: E402


PASSING = "Godot Engine v4.7.2\nSTART SMOKE start: Eastern Stories dev\nSTART SMOKE: saved\nSTART SMOKE PASS\n"


class ErrorLineTests(unittest.TestCase):
    def test_a_clean_run_passes(self) -> None:
        self.assertEqual([], start_smoke.judge(PASSING, 0, needs_pass_line=True))

    def test_every_kind_of_error_line_fails(self) -> None:
        for line in ("ERROR: Cannot open file", "SHADER ERROR: Unknown identifier", "SCRIPT ERROR: Invalid call", "USER ERROR: old style"):
            with self.subTest(line=line):
                problems = start_smoke.judge(PASSING + line + "\n", 0, needs_pass_line=True)
                self.assertEqual([f"error line: {line}"], problems)

    def test_the_at_line_is_kept_with_its_error(self) -> None:
        output = PASSING + "ERROR: Shader compile failed.\n   at: _compile (servers/rendering/x.cpp:12)\n"
        self.assertEqual(
            ["ERROR: Shader compile failed. at: _compile (servers/rendering/x.cpp:12)"],
            start_smoke.error_lines(output),
        )

    def test_warnings_do_not_count(self) -> None:
        self.assertEqual([], start_smoke.error_lines("WARNING: ObjectDB instances leaked at exit\n"))

    def test_a_word_inside_a_line_is_no_error_line(self) -> None:
        self.assertEqual([], start_smoke.error_lines("START SMOKE: the ERROR: word in a message\n"))

    def test_a_nonzero_exit_fails(self) -> None:
        self.assertEqual(["exit code 1"], start_smoke.judge(PASSING, 1, needs_pass_line=True))

    def test_a_timeout_fails(self) -> None:
        self.assertIn("timed out and was stopped", start_smoke.judge(PASSING, None, needs_pass_line=True))

    def test_a_run_without_its_pass_line_names_the_failure(self) -> None:
        output = "START SMOKE FAIL: the save failed: no result\n"
        self.assertEqual(["START SMOKE FAIL: the save failed: no result"], start_smoke.judge(output, 0, needs_pass_line=True))

    def test_the_exe_needs_no_pass_line(self) -> None:
        self.assertEqual([], start_smoke.judge("Eastern Stories 1a2b3c4d\n", 0, needs_pass_line=False))


class CommandTests(unittest.TestCase):
    def test_the_start_smoke_runs_headless_on_the_given_project(self) -> None:
        command = start_smoke.smoke_command(Path("godot"), Path("build/verify-release-project"), "start")
        self.assertEqual(["godot", "--headless", "--path"], command[:3])
        self.assertEqual(["--script", start_smoke.SMOKE_SCRIPT.as_posix(), "--", "start"], command[-4:])

    def test_the_walk_is_windowed(self) -> None:
        command = start_smoke.smoke_command(Path("godot"), Path("game"), "walk", "shots", "snow.outdoor", headless=False)
        self.assertNotIn("--headless", command)
        self.assertEqual(["walk", "shots", "snow.outdoor"], command[-3:])

    def test_the_smoke_script_lives_outside_the_project(self) -> None:
        # The release copy has no tests/: the script is passed by its absolute path.
        self.assertTrue(start_smoke.SMOKE_SCRIPT.is_file())
        self.assertFalse(start_smoke.SMOKE_SCRIPT.is_relative_to(REPOSITORY / "game"))

    def test_the_exe_quits_by_itself_and_logs_to_a_file(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            work = Path(temporary)
            executable = work / "game.exe"
            executable.write_bytes(b"x")
            seen: list[list[str]] = []

            def fake_run(command: list[str], env: dict[str, str], timeout: float, log: Path) -> tuple[str, int]:
                seen.append(command)
                Path(command[command.index("--log-file") + 1]).write_text("Eastern Stories 1a2b3c4d · Godot 4.7.2\n", encoding="utf-8")
                return "", 0

            with mock.patch.object(start_smoke, "_run", side_effect=fake_run):
                self.assertEqual([], start_smoke.run_exe(executable, work))
            self.assertEqual([str(executable), "--headless", "--quit-after", str(start_smoke.EXE_FRAMES)], seen[0][:4])

    def test_an_exe_without_the_start_line_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            work = Path(temporary)
            executable = work / "game.exe"
            executable.write_bytes(b"x")
            with mock.patch.object(start_smoke, "_run", return_value=("", 0)):
                problems = start_smoke.run_exe(executable, work)
            self.assertEqual(1, len(problems))
            self.assertIn("start-up line", problems[0])

    def test_a_missing_exe_fails(self) -> None:
        self.assertEqual(["no executable at nowhere.exe"], start_smoke.run_exe(Path("nowhere.exe"), Path(".")))


if __name__ == "__main__":
    unittest.main()
