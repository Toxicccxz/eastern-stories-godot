#!/usr/bin/env python3
"""Canonical local/CI verification entrypoint for Phase 10A."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[2]
BUILD_SCRIPT_DIR = REPOSITORY / "tools/build"
sys.path.insert(0, str(BUILD_SCRIPT_DIR))

from build import BuildError, _godot_environment, resolve_godot, validate_godot_version  # noqa: E402
from prepare_release_project import prepare_release_project, validate_release_project  # noqa: E402


def _run(
    command: list[str],
    cwd: Path = REPOSITORY,
    env: dict[str, str] | None = None,
) -> None:
    print(f"+ {' '.join(command)}", flush=True)
    result = subprocess.run(command, cwd=cwd, env=env, check=False)
    if result.returncode != 0:
        raise RuntimeError(f"verification command failed with exit code {result.returncode}")


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
        _run([str(godot), "--headless", "--path", "game", "--editor", "--quit"], env=godot_env)

        print("[4/5] Canonical complete gameplay test suite", flush=True)
        if args.skip_gameplay_tests:
            print("SKIPPED by explicit clean-checkout smoke option", flush=True)
        else:
            _run(
                [str(godot), "--headless", "--path", "game", "--script", "res://tests/run_tests.gd"],
                env=godot_env,
            )

        print("[5/5] Actual release sanitizer and sanitized-project validation", flush=True)
        prepare_release_project(REPOSITORY / "game", release_project)
        errors = validate_release_project(release_project)
        if errors:
            raise RuntimeError("\n".join(errors))
        _run(
            [str(godot), "--headless", "--path", str(release_project), "--editor", "--quit"],
            env=godot_env,
        )
        print("Phase 10A verification PASS", flush=True)
        return 0
    except (BuildError, OSError, RuntimeError) as error:
        print(f"Phase 10A verification failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
