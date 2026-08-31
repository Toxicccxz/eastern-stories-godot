#!/usr/bin/env python3
"""Run narrow repository/static checks for the Phase 10A contract."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path


REQUIRED_FILES = (
    "README.md",
    "THIRD_PARTY_NOTICES.md",
    "docs/production/STATUS.md",
    "docs/production/ROADMAP.md",
    "docs/production/BUILD.md",
    "docs/production/GODOT_AI_DEVELOPMENT.md",
    "docs/production/LICENSE_PROVENANCE.md",
    "docs/production/REPOSITORY_POLICY.md",
    "tools/build/prepare_release_project.py",
    "tools/build/build.py",
    "tools/build/ios_sdl_compat_shim.m",
    "tools/ci/bootstrap_godot.py",
    "tools/ci/verify.py",
    "game/export_presets.cfg",
    ".github/workflows/ci.yml",
)
GENERATED_PATTERNS = (
    re.compile(r"^(build|dist)/"),
    re.compile(r"\.(apk|exe|ipa|keystore|pck|tpz|zip)$", re.IGNORECASE),
    re.compile(r"(^|/)__pycache__/"),
    re.compile(r"\.pyc$"),
    re.compile(r"\.xcodeproj/"),
    re.compile(r"\.xcworkspace/"),
)
ABSOLUTE_PATH_PATTERNS = (
    re.compile(r"[A-Za-z]:[\\/](?:Projects|Users)[\\/]"),
    re.compile(r"/Users/[^/<\s]+/"),
    re.compile(r"/home/[^/<\s]+/"),
)
PHASE10_TEXT_ROOTS = (
    "README.md",
    "THIRD_PARTY_NOTICES.md",
    "docs/production",
    "tools",
    ".github",
    "game/export_presets.cfg",
)
STABLE_CI_JOB_NAMES = (
    "Godot Verify",
    "Windows Release Build",
    "Android Release Build",
    "iOS Build Validation",
)
PR_INTEGRATION_EVENTS = (
    "opened",
    "reopened",
    "synchronize",
    "ready_for_review",
)


def _git_lines(repository: Path, *arguments: str) -> list[str]:
    result = subprocess.run(
        ["git", *arguments],
        cwd=repository,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"git {' '.join(arguments)} failed")
    return [line for line in result.stdout.splitlines() if line]


def _candidate_text_files(repository: Path) -> list[Path]:
    files: list[Path] = []
    for relative in PHASE10_TEXT_ROOTS:
        path = repository / relative
        if path.is_file():
            files.append(path)
        elif path.is_dir():
            files.extend(item for item in path.rglob("*") if item.is_file())
    return sorted(set(files), key=lambda item: item.as_posix())


def _workflow_trigger_block(workflow_text: str, event: str) -> list[str]:
    lines = workflow_text.replace("\r\n", "\n").splitlines()
    marker = f"  {event}:"
    try:
        start = lines.index(marker)
    except ValueError:
        return []
    block = [marker]
    for line in lines[start + 1 :]:
        indentation = len(line) - len(line.lstrip(" "))
        if line and indentation <= 2:
            break
        block.append(line)
    while block and not block[-1]:
        block.pop()
    return block


def ci_trigger_policy_errors(workflow_text: str) -> list[str]:
    """Validate the narrow major-phase integration event contract without a YAML dependency."""
    errors: list[str] = []
    normalized = workflow_text.replace("\r\n", "\n")

    expected_pull_request = [
        "  pull_request:",
        "    branches:",
        "      - main",
        "    types:",
        *(f"      - {event}" for event in PR_INTEGRATION_EVENTS),
    ]
    pull_request_block = _workflow_trigger_block(normalized, "pull_request")
    if pull_request_block != expected_pull_request:
        errors.append(
            "CI pull_request trigger must target only main and use opened, reopened, "
            "synchronize, and ready_for_review"
        )

    expected_push = ["  push:", "    branches:", "      - main"]
    if _workflow_trigger_block(normalized, "push") != expected_push:
        errors.append("CI push trigger must target only main for post-merge validation")
    if "  workflow_dispatch:\n" not in normalized:
        errors.append("CI must retain manual workflow_dispatch")
    if "github.event.pull_request.draft == false" not in normalized:
        errors.append("CI must skip expensive jobs while a pull request remains draft")

    for job_name in STABLE_CI_JOB_NAMES:
        if f"    name: {job_name}\n" not in normalized:
            errors.append(f"CI stable job name is missing: {job_name}")
    return errors


def check_repository(repository: Path, *, require_git: bool = True) -> list[str]:
    repository = repository.resolve()
    errors: list[str] = []
    for relative in REQUIRED_FILES:
        if not (repository / relative).exists():
            errors.append(f"required Phase 10A file is missing: {relative}")

    presets = repository / "game/export_presets.cfg"
    if presets.is_file():
        text = presets.read_text(encoding="utf-8")
        for name in ("Windows Desktop", "Android", "iOS"):
            if f'name="{name}"' not in text:
                errors.append(f"export preset is missing: {name}")
        if "com.example.easternstoriesgodot" not in text:
            errors.append("provisional mobile package identifier is missing")
        if "application/export_project_only=true" not in text:
            errors.append("iOS preset must export the Xcode project without invoking a signed archive")

    workflow = repository / ".github/workflows/ci.yml"
    if workflow.is_file():
        workflow_text = workflow.read_text(encoding="utf-8")
        if "/Applications/Xcode_26.3.app" not in workflow_text:
            errors.append("iOS CI must select the Godot 4.7.2-compatible pinned Xcode 26.3 toolchain")
        errors.extend(ci_trigger_policy_errors(workflow_text))

    for path in _candidate_text_files(repository):
        if path == repository / "tools/ci/repository_checks.py":
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        relative = path.relative_to(repository).as_posix()
        for pattern in ABSOLUTE_PATH_PATTERNS:
            if pattern.search(text):
                errors.append(f"absolute developer path leaked into {relative}")

    production_roots = (repository / "game/core", repository / "game/data", repository / "game/runtime", repository / "game/scenes", repository / "game/ui")
    for root in production_roots:
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if not path.is_file() or path.suffix.lower() not in {".gd", ".tscn", ".tres", ".godot"}:
                continue
            text = path.read_text(encoding="utf-8")
            if "res://tests/" in text:
                errors.append(f"production resource depends on tests: {path.relative_to(repository).as_posix()}")

    if require_git:
        try:
            tracked = _git_lines(repository, "ls-files")
            for relative in tracked:
                normalized = relative.replace("\\", "/")
                if any(pattern.search(normalized) for pattern in GENERATED_PATTERNS):
                    errors.append(f"generated artifact is tracked: {normalized}")
            reference_changes = _git_lines(repository, "diff", "--name-only", "--", "reference/es2")
            if reference_changes:
                errors.append(f"reference/es2 has modifications: {len(reference_changes)}")
        except RuntimeError as error:
            errors.append(str(error))
    return errors


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", type=Path, default=Path.cwd())
    parser.add_argument("--no-git", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    errors = check_repository(args.repository, require_git=not args.no_git)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("Repository/static checks PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
