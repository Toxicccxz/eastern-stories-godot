#!/usr/bin/env python3
"""Canonical local/CI verification entrypoint for Phase 10A."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import threading
from pathlib import Path
from typing import BinaryIO


REPOSITORY = Path(__file__).resolve().parents[2]
BUILD_SCRIPT_DIR = REPOSITORY / "tools/build"
sys.path.insert(0, str(BUILD_SCRIPT_DIR))

from build import BuildError, _godot_environment, resolve_godot, validate_godot_version  # noqa: E402
from prepare_release_project import prepare_release_project, validate_release_project  # noqa: E402


# A step that outlives its budget has hung (e.g. a GDScript error that stops a SceneTree
# script before it can quit); fail it instead of waiting forever. CI's job limit is 30 min.
TOOLING_TIMEOUT_SECONDS = 10 * 60
IMPORT_TIMEOUT_SECONDS = 10 * 60
GAMEPLAY_TESTS_TIMEOUT_SECONDS = 20 * 60
SCRIPT_ERROR_MARKER = "SCRIPT ERROR"


def _run(
    command: list[str],
    cwd: Path = REPOSITORY,
    env: dict[str, str] | None = None,
    timeout: float = TOOLING_TIMEOUT_SECONDS,
    fail_on_script_errors: bool = False,
) -> None:
    """Runs one step, relaying its output. A Godot step also fails when its output has a
    SCRIPT ERROR line: a runtime error inside a suite's helper aborts only that helper, so
    the suite can still report PASS (and a crashed import still exits 0)."""
    print(f"+ {' '.join(command)}", flush=True)
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
    relay.join()
    if returncode != 0:
        raise RuntimeError(f"verification command failed with exit code {returncode}")
    if fail_on_script_errors and script_errors:
        shown = "\n".join(script_errors[:20])
        raise RuntimeError(f"{len(script_errors)} {SCRIPT_ERROR_MARKER} line(s) in the output:\n{shown}")


def _relay_output(stream: BinaryIO, script_errors: list[str]) -> None:
    """Copies the child's output bytes unchanged and remembers each SCRIPT ERROR line
    with the `at:` line Godot prints after it."""
    pending: str | None = None
    for raw in iter(stream.readline, b""):
        sys.stdout.buffer.write(raw)
        sys.stdout.buffer.flush()
        line = raw.decode("utf-8", "replace").rstrip()
        if pending is not None:
            script_errors.append(f"{pending} {line.strip()}" if line.strip().startswith("at:") else pending)
            pending = None
        if SCRIPT_ERROR_MARKER in line:
            pending = line.encode("ascii", "backslashreplace").decode("ascii")
    if pending is not None:
        script_errors.append(pending)
    stream.close()


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot")
    parser.add_argument("--no-git", action="store_true")
    parser.add_argument("--skip-gameplay-tests", action="store_true")
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

        print("[4/5] Canonical complete gameplay test suite", flush=True)
        if args.skip_gameplay_tests:
            print("SKIPPED by explicit clean-checkout smoke option", flush=True)
        else:
            _run(
                [str(godot), "--headless", "--path", "game", "--script", "res://tests/run_tests.gd"],
                env=godot_env,
                timeout=GAMEPLAY_TESTS_TIMEOUT_SECONDS,
                fail_on_script_errors=True,
            )

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
