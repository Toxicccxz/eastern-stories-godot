#!/usr/bin/env python3
"""Start the game for real and fail on any error line it logs.

Three uses, one rule (an ERROR, SHADER ERROR or SCRIPT ERROR line fails the run):

  start  the shell on a project (verify.py step 5 runs it on the cleaned release copy):
         main menu, 新的旅程, a few hundred frames, one save through 系统 (start_smoke.gd).
  walk   the windowed walkthrough agents do for every package: the same start on the
         development project, then two or three maps, a screenshot of each under build/.
  exe    the exported executable, headless, for a few hundred frames (CI's Windows job).

Each run gets its own user data folder under build/, so no developer save is read or written.

  py -3 tools/ci/start_smoke.py start --godot <godot> [--project build/verify-release-project]
  py -3 tools/ci/start_smoke.py walk --godot <godot> [--maps snow.outdoor,snow.inn_upstairs,cloud.outdoor]
  py -3 tools/ci/start_smoke.py exe --exe dist/windows/Eastern-Stories-Godot.exe
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY / "tools/build"))

from build import BuildError, _godot_environment, resolve_godot  # noqa: E402


SMOKE_SCRIPT = REPOSITORY / "tools/ci/start_smoke.gd"
# Godot's error lines: an engine error or push_error() (ERROR), a shader that failed to
# compile (SHADER ERROR), a GDScript runtime error (SCRIPT ERROR). Warnings do not count.
ERROR_LINE = re.compile(r"^\s*(?:USER )?(?:SCRIPT |SHADER )?ERROR:")
PASS_LINE = "START SMOKE PASS"
SMOKE_TIMEOUT_SECONDS = 10 * 60
# The exported game, headless: this many frames of the main menu, then it quits by itself.
EXE_FRAMES = 300
EXE_TIMEOUT_SECONDS = 5 * 60
DEFAULT_MAPS = "snow.outdoor,snow.inn_upstairs,cloud.outdoor"


def error_lines(output: str) -> list[str]:
    """Every error line of a Godot log, with the `at:` line Godot prints after it."""
    lines = output.splitlines()
    found: list[str] = []
    for index, line in enumerate(lines):
        if ERROR_LINE.match(line):
            following = lines[index + 1].strip() if index + 1 < len(lines) else ""
            found.append(f"{line.strip()} {following}" if following.startswith("at:") else line.strip())
    return found


def judge(output: str, returncode: int | None, *, needs_pass_line: bool) -> list[str]:
    """What is wrong with a run: its error lines, a nonzero exit, no PASS line."""
    problems = [f"error line: {line}" for line in error_lines(output)]
    if returncode is None:
        problems.append("timed out and was stopped")
    elif returncode != 0:
        problems.append(f"exit code {returncode}")
    if needs_pass_line and PASS_LINE not in output.splitlines():
        failure = next((line for line in output.splitlines() if line.startswith("START SMOKE FAIL")), None)
        problems.append(failure or f"no {PASS_LINE!r} line")
    return problems


def _run(command: list[str], env: dict[str, str], timeout: float, log: Path) -> tuple[str, int | None]:
    print(f"+ {' '.join(command)}", flush=True)
    log.parent.mkdir(parents=True, exist_ok=True)
    try:
        result = subprocess.run(
            command, cwd=REPOSITORY, env=env, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, timeout=timeout, check=False,
        )
        output, returncode = result.stdout.decode("utf-8", "replace"), result.returncode
    except subprocess.TimeoutExpired as expired:
        output = (expired.stdout or b"").decode("utf-8", "replace")
        returncode = None
    log.write_text(output, encoding="utf-8")
    return output, returncode


def _report(name: str, log: Path, problems: list[str]) -> int:
    shown = log.relative_to(REPOSITORY).as_posix() if log.is_relative_to(REPOSITORY) else str(log)
    if not problems:
        print(f"{name} PASS (log: {shown})", flush=True)
        return 0
    print(f"{name} FAIL (log: {shown})", flush=True)
    for problem in problems[:30]:
        print(f"  {problem}", flush=True)
    return 1


def smoke_command(godot: Path, project: Path, mode: str, *extra: str, headless: bool = True) -> list[str]:
    command = [str(godot)]
    if headless:
        command.append("--headless")
    return [*command, "--path", str(project), "--script", SMOKE_SCRIPT.as_posix(), "--", mode, *extra]


def run_start(godot: Path, project: Path, work: Path, timeout: float = SMOKE_TIMEOUT_SECONDS) -> list[str]:
    """The start-up smoke on `project` (already imported). Its problems; empty when it passed."""
    output, returncode = _run(smoke_command(godot, project, "start"), _godot_environment(work / "user"), timeout, work / "start.log")
    return judge(output, returncode, needs_pass_line=True)


def run_walk(godot: Path, maps: str, shots: Path, screen: int | None, work: Path) -> list[str]:
    command = smoke_command(godot, REPOSITORY / "game", "walk", shots.resolve().as_posix(), maps, headless=False)
    if screen is not None:
        command[1:1] = ["--screen", str(screen)]
    output, returncode = _run(command, _godot_environment(work / "user"), SMOKE_TIMEOUT_SECONDS, work / "walk.log")
    return judge(output, returncode, needs_pass_line=True)


def run_exe(executable: Path, work: Path, frames: int = EXE_FRAMES) -> list[str]:
    """The exported game, headless, quitting by itself after `frames` frames. The log goes to
    a file too (a GUI-subsystem exe may print nowhere)."""
    if not executable.is_file():
        return [f"no executable at {executable}"]
    log_file = work / "exe-godot.log"
    if log_file.exists():
        log_file.unlink()
    command = [str(executable), "--headless", "--quit-after", str(frames), "--log-file", str(log_file)]
    output, returncode = _run(command, _godot_environment(work / "user"), EXE_TIMEOUT_SECONDS, work / "exe.log")
    if log_file.is_file():
        output += "\n" + log_file.read_text(encoding="utf-8", errors="replace")
    problems = judge(output, returncode, needs_pass_line=False)
    if "Eastern Stories " not in output:
        problems.append("the start-up line (Eastern Stories <version> · Godot …) is not in the log")
    return problems


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("mode", choices=("start", "walk", "exe"))
    parser.add_argument("--godot", help="the Godot editor binary (start, walk)")
    parser.add_argument("--project", type=Path, default=REPOSITORY / "game", help="start: the project to start")
    parser.add_argument("--maps", default=DEFAULT_MAPS, help="walk: the maps to visit, comma-separated")
    parser.add_argument("--out", type=Path, default=REPOSITORY / "build/walkthrough", help="walk: where the screenshots go")
    parser.add_argument("--screen", type=int, help="walk: the screen the window opens on")
    parser.add_argument("--exe", type=Path, default=REPOSITORY / "dist/windows/Eastern-Stories-Godot.exe", help="exe: the exported game")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    work = REPOSITORY / "build/start-smoke" / args.mode
    try:
        if args.mode == "exe":
            return _report("Exported game start", work / "exe.log", run_exe(args.exe.resolve(), work))
        godot = resolve_godot(args.godot)
        if args.mode == "start":
            return _report("Start-up smoke", work / "start.log", run_start(godot, args.project.resolve(), work))
        shots = args.out / "shots"
        problems = run_walk(godot, args.maps, shots, args.screen, work)
        print(f"Screenshots: {shots}", flush=True)
        return _report("Walkthrough", work / "walk.log", problems)
    except (BuildError, OSError) as error:
        print(f"Start smoke failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
