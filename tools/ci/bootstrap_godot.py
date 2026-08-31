#!/usr/bin/env python3
"""Download the official pinned Godot editor and export templates for CI."""

from __future__ import annotations

import argparse
import hashlib
import os
import platform
import shutil
import stat
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path


VERSION = "4.7.2"
STATUS = "stable"
TAG = f"{VERSION}-{STATUS}"
RELEASE_BASE = f"https://github.com/godotengine/godot-builds/releases/download/{TAG}"
CHECKSUM_FILE = "SHA512-SUMS.txt"
TEMPLATE_ARCHIVE = f"Godot_v{TAG}_export_templates.tpz"
EDITOR_ARCHIVES = {
    "windows": f"Godot_v{TAG}_win64.exe.zip",
    "linux": f"Godot_v{TAG}_linux.x86_64.zip",
    "macos": f"Godot_v{TAG}_macos.universal.zip",
}


class BootstrapError(RuntimeError):
    """Raised when the pinned toolchain cannot be prepared safely."""


def _download(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".part")
    if temporary.exists():
        temporary.unlink()
    print(f"Downloading {url}")
    with urllib.request.urlopen(url) as response, temporary.open("wb") as output:
        shutil.copyfileobj(response, output)
    temporary.replace(destination)


def _parse_sha512_sums(text: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in text.splitlines():
        parts = line.strip().split(maxsplit=1)
        if len(parts) != 2:
            continue
        digest, name = parts
        values[name.lstrip("*")] = digest.lower()
    return values


def _sha512(path: Path) -> str:
    digest = hashlib.sha512()
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def _verified_download(filename: str, downloads: Path, checksums: dict[str, str]) -> Path:
    expected = checksums.get(filename)
    if expected is None:
        raise BootstrapError(f"official checksum list has no entry for {filename}")
    destination = downloads / filename
    if not destination.is_file() or _sha512(destination) != expected:
        if destination.exists():
            destination.unlink()
        _download(f"{RELEASE_BASE}/{filename}", destination)
    actual = _sha512(destination)
    if actual != expected:
        raise BootstrapError(f"SHA-512 mismatch for {filename}")
    print(f"SHA-512 PASS: {filename}")
    return destination


def _detect_platform() -> str:
    value = platform.system()
    return {"Windows": "windows", "Linux": "linux", "Darwin": "macos"}.get(value, value.lower())


def _extract_editor(archive: Path, destination: Path, target: str) -> Path:
    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True)
    if target == "macos":
        result = subprocess.run(
            ["ditto", "-x", "-k", str(archive), str(destination)],
            check=False,
        )
        if result.returncode != 0:
            raise BootstrapError(f"ditto could not extract the macOS editor archive: {archive}")
    else:
        with zipfile.ZipFile(archive) as package:
            package.extractall(destination)
    if target == "windows":
        console = sorted(destination.rglob("*_console.exe"))
        regular = sorted(destination.rglob("*.exe"))
        candidates = console or regular
    elif target == "linux":
        candidates = [
            path
            for path in sorted(destination.rglob("Godot*"))
            if path.is_file() and ".zip" not in path.name
        ]
    else:
        candidates = sorted(destination.rglob("Godot.app/Contents/MacOS/Godot"))
    if not candidates:
        raise BootstrapError(f"could not find the Godot editor in {archive}")
    executable = candidates[0]
    if target != "windows":
        executable.chmod(executable.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    return executable


def _extract_templates(archive: Path, destination: Path) -> Path:
    version_dir = destination / "4.7.2.stable"
    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True)
    with zipfile.ZipFile(archive) as package:
        package.extractall(destination)
    nested = destination / "templates"
    if nested.is_dir():
        if version_dir.exists():
            shutil.rmtree(version_dir)
        nested.rename(version_dir)
    if not version_dir.is_dir():
        version_files = list(destination.rglob("version.txt"))
        if len(version_files) != 1:
            raise BootstrapError("export template archive has an unexpected layout")
        source_dir = version_files[0].parent
        if source_dir != version_dir:
            source_dir.rename(version_dir)
    version_text = (version_dir / "version.txt").read_text(encoding="utf-8").strip()
    if version_text != "4.7.2.stable":
        raise BootstrapError(f"unexpected template version: {version_text!r}")
    return version_dir


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=tuple(EDITOR_ARCHIVES), default=_detect_platform())
    parser.add_argument("--output", type=Path, default=Path("build/toolchain"))
    parser.add_argument("--skip-editor", action="store_true")
    parser.add_argument("--skip-templates", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    output = args.output.resolve()
    downloads = output / "downloads"
    try:
        checksums_path = downloads / CHECKSUM_FILE
        _download(f"{RELEASE_BASE}/{CHECKSUM_FILE}", checksums_path)
        checksums = _parse_sha512_sums(checksums_path.read_text(encoding="utf-8"))
        result: dict[str, str] = {}
        if not args.skip_editor:
            archive = _verified_download(EDITOR_ARCHIVES[args.platform], downloads, checksums)
            result["godot"] = str(_extract_editor(archive, output / "editor", args.platform))
        if not args.skip_templates:
            archive = _verified_download(TEMPLATE_ARCHIVE, downloads, checksums)
            result["templates"] = str(_extract_templates(archive, output / "templates"))
        env_file = os.environ.get("GITHUB_OUTPUT")
        if env_file:
            with Path(env_file).open("a", encoding="utf-8") as handle:
                for key, value in result.items():
                    handle.write(f"{key}={value}\n")
        for key, value in result.items():
            print(f"{key}={value}")
        return 0
    except (BootstrapError, OSError, zipfile.BadZipFile) as error:
        print(f"Godot bootstrap failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
