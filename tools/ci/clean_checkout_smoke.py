#!/usr/bin/env python3
"""Simulate a clean checkout using only repository-visible files."""

from __future__ import annotations

import argparse
import io
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path


class CleanCheckoutError(RuntimeError):
    """Raised when the clean candidate cannot be created or verified."""


def _extract_committed_head(repository: Path, output: Path) -> None:
    result = subprocess.run(
        ["git", "archive", "--format=tar", "HEAD"],
        cwd=repository,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        raise CleanCheckoutError(result.stderr.decode("utf-8", errors="replace").strip())
    with tarfile.open(fileobj=io.BytesIO(result.stdout), mode="r:") as archive:
        archive.extractall(output, filter="data")


def _validate_output(repository: Path, output: Path) -> None:
    controlled_root = (repository / "build").resolve()
    if output == controlled_root:
        raise CleanCheckoutError("refusing to replace the complete controlled build directory")
    try:
        output.relative_to(controlled_root)
    except ValueError as error:
        raise CleanCheckoutError(
            f"clean-checkout output must be a child of the controlled directory: {controlled_root}"
        ) from error


def _run(command: list[str], cwd: Path) -> None:
    print(f"+ {' '.join(command)}", flush=True)
    result = subprocess.run(command, cwd=cwd, check=False)
    if result.returncode != 0:
        raise CleanCheckoutError(f"command failed with exit code {result.returncode}")


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--templates", type=Path)
    parser.add_argument("--output", type=Path, default=Path("build/clean-checkout"))
    parser.add_argument("--skip-gameplay-tests", action="store_true")
    parser.add_argument("--skip-windows-build", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    repository = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    try:
        _validate_output(repository, output)
        if output.exists():
            shutil.rmtree(output)
        output.mkdir(parents=True)
        _extract_committed_head(repository, output)

        verify = [sys.executable, "tools/ci/verify.py", "--godot", str(Path(args.godot).resolve()), "--no-git"]
        if args.skip_gameplay_tests:
            verify.append("--skip-gameplay-tests")
        _run(verify, output)

        if not args.skip_windows_build:
            if args.templates is None:
                raise CleanCheckoutError("Windows clean-checkout build requires --templates")
            _run(
                [
                    sys.executable,
                    "tools/build/build.py",
                    "--target",
                    "windows",
                    "--godot",
                    str(Path(args.godot).resolve()),
                    "--templates",
                    str(args.templates.resolve()),
                ],
                output,
            )
        print(f"Clean-checkout simulation PASS: {output}")
        return 0
    except (CleanCheckoutError, OSError) as error:
        print(f"Clean-checkout simulation failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
