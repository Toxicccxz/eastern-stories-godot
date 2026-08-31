#!/usr/bin/env python3
"""Create and validate the single sanitized Godot release project."""

from __future__ import annotations

import argparse
import hashlib
import shutil
import sys
from pathlib import Path


EXPECTED_MAIN_SCENE = "res://scenes/runtime/oldpine_game_runtime_host.tscn"
REQUIRED_PATHS = (
    "project.godot",
    "export_presets.cfg",
    "core",
    "data",
    "runtime",
    "scenes",
    "scenes/runtime/oldpine_game_runtime_host.tscn",
    "scenes/world/oldpine/oldpine_world_session.tscn",
)
FORBIDDEN_PATHS = (
    "addons/godot_ai",
    "tests",
    "godot-ai-LICENSE.txt",
    "scenes/mcp_test.tscn",
)
FORBIDDEN_TEXT = (
    "_mcp_game_helper",
    "addons/godot_ai",
    "--remote-debug",
    "127.0.0.1:6107",
    "res://tests/",
)
TEXT_SUFFIXES = {
    ".cfg",
    ".gd",
    ".godot",
    ".json",
    ".md",
    ".shader",
    ".svg",
    ".tres",
    ".tscn",
    ".txt",
}


class ReleaseProjectError(RuntimeError):
    """Raised when release preparation cannot prove its safety contract."""


def _normalized(path: Path) -> Path:
    return path.expanduser().resolve()


def _is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def source_tree_digest(source: Path) -> str:
    """Hash source content, ignoring only Godot's generated import cache."""
    source = _normalized(source)
    digest = hashlib.sha256()
    for path in sorted(source.rglob("*"), key=lambda item: item.as_posix()):
        relative = path.relative_to(source)
        if relative.parts and relative.parts[0] == ".godot":
            continue
        if path.is_dir():
            continue
        digest.update(relative.as_posix().encode("utf-8"))
        digest.update(b"\0")
        with path.open("rb") as handle:
            while chunk := handle.read(1024 * 1024):
                digest.update(chunk)
        digest.update(b"\0")
    return digest.hexdigest()


def _copy_ignore(directory: str, names: list[str]) -> set[str]:
    directory_path = Path(directory)
    ignored: set[str] = set()
    if directory_path.name == "game":
        ignored.update(name for name in names if name in {".godot", "tests", "godot-ai-LICENSE.txt"})
    if directory_path.name == "addons" and "godot_ai" in names:
        ignored.add("godot_ai")
    ignored.update(name for name in names if name == "__pycache__" or name.endswith(".log"))
    return ignored


def _section_blocks(text: str) -> list[tuple[str | None, list[str]]]:
    blocks: list[tuple[str | None, list[str]]] = []
    section: str | None = None
    lines: list[str] = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            blocks.append((section, lines))
            section = stripped[1:-1]
            lines = []
        else:
            lines.append(line)
    blocks.append((section, lines))
    return blocks


def sanitize_project_config(text: str) -> str:
    """Remove development-only Godot AI and local debugger activation."""
    output: list[str] = []
    for section, lines in _section_blocks(text):
        if section is None:
            output.extend(lines)
            continue

        kept = list(lines)
        if section == "autoload":
            kept = [
                line
                for line in kept
                if "_mcp_game_helper" not in line
                and "addons/godot_ai" not in line
                and "_phase10b4_qa_bridge" not in line
                and "res://tests/" not in line
            ]
        elif section == "editor_plugins":
            kept = [line for line in kept if "addons/godot_ai" not in line]
        elif section == "editor":
            kept = [
                line
                for line in kept
                if "--remote-debug" not in line and "127.0.0.1:6107" not in line
            ]

        if any(line.strip() and not line.lstrip().startswith(";") for line in kept):
            while output and output[-1] == "":
                output.pop()
            output.extend(("", f"[{section}]", ""))
            output.extend(kept)

    return "\n".join(output).strip() + "\n"


def _project_setting(text: str, section_name: str, key: str) -> str | None:
    current: str | None = None
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
            continue
        if current != section_name or not line.startswith(f"{key}="):
            continue
        value = line.split("=", 1)[1].strip()
        if len(value) >= 2 and value[0] == value[-1] == '"':
            return value[1:-1]
        return value
    return None


def validate_release_project(project: Path) -> list[str]:
    project = _normalized(project)
    errors: list[str] = []
    for relative in REQUIRED_PATHS:
        if not (project / relative).exists():
            errors.append(f"required release path is missing: {relative}")
    for relative in FORBIDDEN_PATHS:
        if (project / relative).exists():
            errors.append(f"development-only path remains: {relative}")

    project_file = project / "project.godot"
    if project_file.is_file():
        project_text = project_file.read_text(encoding="utf-8")
        main_scene = _project_setting(project_text, "application", "run/main_scene")
        if main_scene != EXPECTED_MAIN_SCENE:
            errors.append(
                "canonical main scene changed: "
                f"expected {EXPECTED_MAIN_SCENE!r}, found {main_scene!r}"
            )

    for path in sorted(project.rglob("*"), key=lambda item: item.as_posix()):
        if not path.is_file() or path.suffix.lower() not in TEXT_SUFFIXES:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        normalized_text = text.replace("\\", "/")
        for token in FORBIDDEN_TEXT:
            if token in normalized_text:
                errors.append(
                    f"forbidden release reference {token!r} in {path.relative_to(project).as_posix()}"
                )
    return errors


def prepare_release_project(source: Path, output: Path) -> Path:
    source = _normalized(source)
    output = _normalized(output)
    if not source.is_dir():
        raise ReleaseProjectError(f"source Godot project does not exist: {source}")
    if not (source / "project.godot").is_file():
        raise ReleaseProjectError(f"source has no project.godot: {source}")
    if source == output or _is_relative_to(output, source):
        raise ReleaseProjectError("release output must be outside the source Godot project")

    before = source_tree_digest(source)
    if output.exists():
        shutil.rmtree(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, output, ignore=_copy_ignore)

    for relative in (".godot", *FORBIDDEN_PATHS):
        path = output / relative
        if path.is_dir():
            shutil.rmtree(path)
        elif path.exists():
            path.unlink()

    project_file = output / "project.godot"
    project_file.write_text(
        sanitize_project_config(project_file.read_text(encoding="utf-8")),
        encoding="utf-8",
        newline="\n",
    )
    addons = output / "addons"
    if addons.is_dir() and not any(addons.iterdir()):
        addons.rmdir()

    errors = validate_release_project(output)
    after = source_tree_digest(source)
    if before != after:
        errors.append("source Godot project changed while preparing the release copy")
    if errors:
        raise ReleaseProjectError("\n".join(errors))
    return output


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path("game"))
    parser.add_argument("--output", type=Path, default=Path("build/release-project"))
    parser.add_argument("--validate-only", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        if args.validate_only:
            errors = validate_release_project(args.output)
            if errors:
                raise ReleaseProjectError("\n".join(errors))
            print(f"Sanitized release project PASS: {args.output.resolve()}")
        else:
            result = prepare_release_project(args.source, args.output)
            print(f"Sanitized release project prepared: {result}")
        return 0
    except (OSError, ReleaseProjectError) as error:
        print(f"Release project preparation failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
