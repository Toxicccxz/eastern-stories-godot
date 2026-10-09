#!/usr/bin/env python3
"""Canonical local/CI verification entrypoint for Phase 10A."""

from __future__ import annotations

import argparse
import os
import re
import shutil
import signal
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field
from pathlib import Path
from typing import BinaryIO


REPOSITORY = Path(__file__).resolve().parents[2]
BUILD_SCRIPT_DIR = REPOSITORY / "tools/build"
sys.path.insert(0, str(BUILD_SCRIPT_DIR))

from build import BuildError, _godot_environment, resolve_godot, validate_godot_version  # noqa: E402
from prepare_release_project import prepare_release_project, validate_release_project  # noqa: E402


# A step that outlives its budget has hung (e.g. a GDScript error that stops a SceneTree
# script before it can quit); fail it instead of waiting forever. CI's job limit (45 min)
# bounds the whole run. Gameplay suites run one Godot process each, so their budget is per
# suite; the slowest takes a few minutes.
TOOLING_TIMEOUT_SECONDS = 10 * 60
IMPORT_TIMEOUT_SECONDS = 10 * 60
SUITE_TIMEOUT_SECONDS = 10 * 60
SCRIPT_ERROR_MARKER = "SCRIPT ERROR"
SUITE_RUNNER = "res://tests/run_suite.gd"
SLOW_SUITE_PREFIXES = ("res://tests/runtime/", "res://tests/application/")
# The slowest suites on CI (PR #91, 4 at a time), slowest first: each starts at once, so
# none of them runs alone at the end. versioned_source_save_test alone took 9.6 min of
# the 29.5 when it started 20 min in.
SLOWEST_SUITES = (
    "res://tests/runtime/versioned_source_save_test.gd",
    "res://tests/runtime/world_soak_test.gd",
    "res://tests/application/mobile_lifecycle_test.gd",
    "res://tests/application/application_shell_test.gd",
    "res://tests/runtime/snow_finance_test.gd",
    "res://tests/runtime/player_recovery_cadence_test.gd",
    "res://tests/runtime/snow_water_test.gd",
    "res://tests/application/public_source_new_game_test.gd",
)
SUITE_SUMMARY = re.compile(r"^(PASS|FAIL): (\d+) suite\(s\), (\d+) assertions, (\d+) failure\(s\)$")


def _run(
    command: list[str],
    cwd: Path = REPOSITORY,
    env: dict[str, str] | None = None,
    timeout: float = TOOLING_TIMEOUT_SECONDS,
    fail_on_script_errors: bool = False,
) -> None:
    """Runs one step. A Godot step (fail_on_script_errors) has its output relayed and fails
    on a SCRIPT ERROR line: a crashed import still exits 0. Other steps write straight to
    the console as before."""
    print(f"+ {' '.join(command)}", flush=True)
    if not fail_on_script_errors:
        try:
            result = subprocess.run(command, cwd=cwd, env=env, check=False, timeout=timeout)
        except subprocess.TimeoutExpired:
            raise RuntimeError(f"verification command timed out after {timeout:g} s and was stopped") from None
        if result.returncode != 0:
            raise RuntimeError(f"verification command failed with exit code {result.returncode}")
        return
    process = subprocess.Popen(command, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    script_errors: list[str] = []
    relay = threading.Thread(target=_relay_output, args=(process.stdout, script_errors), daemon=True)
    relay.start()
    try:
        returncode = process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
        relay.join(timeout=5)
        raise RuntimeError(f"verification command timed out after {timeout:g} s and was stopped") from None
    # A grandchild still holding the pipe must not hang the step.
    relay.join(timeout=30)
    if returncode != 0:
        raise RuntimeError(f"verification command failed with exit code {returncode}")
    if script_errors:
        shown = "\n".join(script_errors[:20])
        raise RuntimeError(f"{len(script_errors)} {SCRIPT_ERROR_MARKER} line(s) in the output:\n{shown}")


class _ScriptErrorCollector:
    """Remembers each SCRIPT ERROR line with the `at:` line Godot prints after it."""

    def __init__(self, script_errors: list[str]) -> None:
        self.script_errors = script_errors
        self._pending: str | None = None

    def feed(self, line: str) -> None:
        if self._pending is not None:
            at = line.strip()
            self.script_errors.append(f"{self._pending} {at}" if at.startswith("at:") else self._pending)
            self._pending = None
        if SCRIPT_ERROR_MARKER in line:
            self._pending = line

    def finish(self) -> None:
        if self._pending is not None:
            self.script_errors.append(self._pending)
            self._pending = None


def _console_line(raw: bytes) -> str:
    return raw.decode("utf-8", "replace").rstrip().encode("ascii", "backslashreplace").decode("ascii")


def _relay_output(stream: BinaryIO, script_errors: list[str]) -> None:
    """Copies the child's output bytes unchanged and collects its SCRIPT ERROR lines.
    Keeps draining if the console fails."""
    collector = _ScriptErrorCollector(script_errors)
    for raw in iter(stream.readline, b""):
        try:
            sys.stdout.buffer.write(raw)
            sys.stdout.buffer.flush()
        except (AttributeError, OSError, ValueError):
            pass
        collector.feed(_console_line(raw))
    collector.finish()
    stream.close()


@dataclass
class SuiteRun:
    """One suite, run in its own Godot process through run_suite.gd."""

    path: str
    log: Path
    seconds: float = 0.0
    assertions: int = 0
    problems: list[str] = field(default_factory=list)
    failures: list[str] = field(default_factory=list)
    script_errors: list[str] = field(default_factory=list)

    @property
    def passed(self) -> bool:
        return not (self.problems or self.failures or self.script_errors)


def discover_suites(game: Path) -> list[str]:
    """Every *_test.gd under game/tests as a res:// path: a new suite needs no registration."""
    return sorted("res://" + path.relative_to(game).as_posix() for path in (game / "tests").rglob("*_test.gd"))


def suite_order(suites: list[str]) -> list[str]:
    """The order suites start in: the known slowest first (SLOWEST_SUITES), then the other
    world suites (a minute or more each), then the core suites (seconds)."""
    def key(suite: str) -> tuple[int, int, str]:
        if suite in SLOWEST_SUITES:
            return (0, SLOWEST_SUITES.index(suite), suite)
        return (1 if suite.startswith(SLOW_SUITE_PREFIXES) else 2, 0, suite)
    return sorted(suites, key=key)


def default_jobs() -> int:
    return os.cpu_count() or 1


class _SuiteProcesses:
    """The suite processes still running, so an interrupt can stop them together with the
    child Godot processes some suites start (cold-process saves)."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._running: set[subprocess.Popen[bytes]] = set()
        self._stopping = False

    def start(self, command: list[str], env: dict[str, str], log: BinaryIO) -> subprocess.Popen[bytes] | None:
        with self._lock:
            if self._stopping:
                return None
            process = subprocess.Popen(
                command,
                cwd=REPOSITORY,
                env=env,
                stdin=subprocess.DEVNULL,
                stdout=log,
                stderr=subprocess.STDOUT,
                start_new_session=os.name != "nt",
            )
            self._running.add(process)
            return process

    def finish(self, process: subprocess.Popen[bytes]) -> None:
        with self._lock:
            self._running.discard(process)

    def stop_all(self) -> None:
        with self._lock:
            self._stopping = True
            running = list(self._running)
        for process in running:
            _kill_tree(process)


def _kill_tree(process: subprocess.Popen[bytes]) -> None:
    """Stops a suite process and every process it started."""
    if process.poll() is not None:
        return
    if os.name == "nt":
        subprocess.run(["taskkill", "/F", "/T", "/PID", str(process.pid)], capture_output=True, check=False)
    else:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    try:
        process.wait(timeout=30)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()


def _run_suite(
    godot: Path, suite: str, env: dict[str, str], log_path: Path, timeout: float, processes: _SuiteProcesses
) -> SuiteRun:
    run = SuiteRun(suite, log_path)
    command = [str(godot), "--headless", "--path", "game", "--script", SUITE_RUNNER, "--", suite]
    started = time.monotonic()
    returncode: int | None = None
    with log_path.open("wb") as log:
        process = processes.start(command, env, log)
        if process is None:
            run.problems.append("not run (verification stopped)")
            return run
        try:
            returncode = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            _kill_tree(process)
            run.problems.append(f"timed out after {timeout:g} s and was stopped")
        finally:
            processes.finish(process)
    run.seconds = time.monotonic() - started
    _check_suite_log(run, returncode)
    return run


def _check_suite_log(run: SuiteRun, returncode: int | None) -> None:
    """A suite fails on a FAIL summary, on any SCRIPT ERROR line (a runtime error inside a
    helper ends only that helper, so the suite can still report PASS), on a nonzero exit,
    and when it printed no summary or no assertions (it stopped before reporting)."""
    suite_file = run.path.rsplit("/", 1)[-1]
    collector = _ScriptErrorCollector(run.script_errors)
    summary: re.Match[str] | None = None
    for raw in run.log.read_bytes().splitlines():
        line = _console_line(raw)
        # run_suite.gd prints each failed assertion as "<suite file>: <description>".
        if line.startswith((f"{suite_file}: ", f"{run.path}: ")):
            run.failures.append(line)
        else:
            collector.feed(line)
        match = SUITE_SUMMARY.match(line)
        if match:
            summary = match
    collector.finish()
    if summary is not None:
        run.assertions = int(summary.group(3))
    if returncode is None:
        return
    if summary is None:
        run.problems.append(f"returned no result (exit code {returncode}, no summary line)")
        return
    if summary.group(1) != "PASS" and not run.failures:
        run.problems.append(f"suite reported {summary.group(4)} failure(s)")
    elif summary.group(1) == "PASS" and returncode != 0:
        run.problems.append(f"exit code {returncode}")
    if run.assertions == 0:
        run.problems.append("no assertions ran")


def run_gameplay_suites(godot: Path, jobs: int, timeout: float = SUITE_TIMEOUT_SECONDS) -> None:
    """Runs every suite in its own Godot process, `jobs` at a time. Each process gets its
    own user data directory, so no two suites share save files."""
    suites = discover_suites(REPOSITORY / "game")
    if not suites:
        raise RuntimeError("no *_test.gd suites found under game/tests")
    work_root = REPOSITORY / "build/verify-suites"
    if work_root.exists():
        shutil.rmtree(work_root)
    (work_root / "logs").mkdir(parents=True)
    jobs = max(1, min(jobs, len(suites)))
    print(f"{len(suites)} suites, {jobs} at a time; logs in build/verify-suites/logs", flush=True)
    processes = _SuiteProcesses()
    runs: list[SuiteRun] = []
    started = time.monotonic()
    pool = ThreadPoolExecutor(max_workers=jobs)
    try:
        futures = []
        # The slowest first, then world suites (a minute or more each), then core suites
        # (seconds): no slow suite runs alone at the end.
        for suite in suite_order(suites):
            name = suite.removeprefix("res://tests/").removesuffix(".gd").replace("/", "__")
            env = _godot_environment(work_root / "env" / name)
            log = work_root / "logs" / f"{name}.log"
            futures.append(pool.submit(_run_suite, godot, suite, env, log, timeout, processes))
        for future in as_completed(futures):
            run = future.result()
            runs.append(run)
            print(
                f"[{len(runs)}/{len(suites)}] {'PASS' if run.passed else 'FAIL'} {run.path}  "
                f"{run.assertions} assertions, {run.seconds:.1f} s",
                flush=True,
            )
    except BaseException:
        processes.stop_all()
        pool.shutdown(wait=True, cancel_futures=True)
        raise
    pool.shutdown(wait=True)
    elapsed = time.monotonic() - started

    slowest = sorted(runs, key=lambda run: run.seconds, reverse=True)[:5]
    print("Slowest: " + ", ".join(f"{run.path.rsplit('/', 1)[-1]} {run.seconds:.0f} s" for run in slowest), flush=True)
    failed = sorted((run for run in runs if not run.passed), key=lambda run: run.path)
    for run in failed:
        print(f"\nFAIL {run.path} (log: {run.log.relative_to(REPOSITORY).as_posix()})", flush=True)
        for line in run.problems + run.failures[:20] + run.script_errors[:20]:
            print(f"  {line}", flush=True)
        print("  --- last lines of the log ---", flush=True)
        for raw in run.log.read_bytes().splitlines()[-40:]:
            print(f"  | {_console_line(raw)}", flush=True)
    assertions = sum(run.assertions for run in runs)
    print(
        f"{'PASS' if not failed else 'FAIL'}: {len(runs)} suites, {assertions} assertions, "
        f"{len(failed)} failed, {elapsed / 60:.1f} min with {jobs} at a time",
        flush=True,
    )
    if failed:
        raise RuntimeError(f"{len(failed)} gameplay suite(s) failed: " + ", ".join(run.path for run in failed))


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot")
    parser.add_argument("--no-git", action="store_true")
    parser.add_argument("--skip-gameplay-tests", action="store_true")
    parser.add_argument(
        "--jobs",
        type=int,
        default=default_jobs(),
        help="gameplay suites run at the same time (default: the CPU count)",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    python = sys.executable
    release_project = REPOSITORY / "build/verify-release-project"
    try:
        print("[1/5] Python tooling unit tests", flush=True)
        _run([python, "-m", "unittest", "discover", "-s", "tools/tests", "-p", "test_*.py", "-v"])

        print("[2/5] Repository/static checks", flush=True)
        command = [python, "tools/ci/repository_checks.py"]
        if args.no_git:
            command.append("--no-git")
        _run(command)

        godot = resolve_godot(args.godot)
        validate_godot_version(godot)
        godot_env = _godot_environment(REPOSITORY / "build/verify-godot-environment")
        print("[3/5] Development Godot headless editor validation", flush=True)
        _run(
            [str(godot), "--headless", "--path", "game", "--editor", "--quit"],
            env=godot_env,
            timeout=IMPORT_TIMEOUT_SECONDS,
            fail_on_script_errors=True,
        )

        print("[4/5] Complete gameplay test suites, one process each", flush=True)
        if args.skip_gameplay_tests:
            print("SKIPPED by explicit clean-checkout smoke option", flush=True)
        else:
            run_gameplay_suites(godot, args.jobs)

        print("[5/5] Actual release sanitizer and sanitized-project validation", flush=True)
        prepare_release_project(REPOSITORY / "game", release_project)
        errors = validate_release_project(release_project)
        if errors:
            raise RuntimeError("\n".join(errors))
        _run(
            [str(godot), "--headless", "--path", str(release_project), "--editor", "--quit"],
            env=godot_env,
            timeout=IMPORT_TIMEOUT_SECONDS,
            fail_on_script_errors=True,
        )
        print("Phase 10A verification PASS", flush=True)
        return 0
    except (BuildError, OSError, RuntimeError) as error:
        print(f"Phase 10A verification failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
