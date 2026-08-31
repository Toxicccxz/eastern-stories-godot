#!/usr/bin/env python3
"""Build one Phase 10A target from the sanitized Godot project."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import platform
import re
import secrets
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

from prepare_release_project import (
    ReleaseProjectError,
    prepare_release_project,
    validate_release_project,
)


SUPPORTED_GODOT_VERSION = "4.7.2"
PROJECT_NAME = "Eastern-Stories-Godot"
PACKAGE_ID = "com.example.easternstoriesgodot"
JDK_VERSION = "17.0.18+8"
PRESET_NAMES = {
    "windows": "Windows Desktop",
    "android": "Android",
    "ios": "iOS",
}
TEMPLATE_NAMES = {
    "windows": "windows_release_x86_64.exe",
    "android": "android_release.apk",
    "ios": "ios.zip",
}


class BuildError(RuntimeError):
    """Raised for an actionable build failure."""


def _run(
    command: list[str],
    *,
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
    capture: bool = False,
) -> subprocess.CompletedProcess[str]:
    shown = " ".join(command)
    print(f"+ {shown}")
    result = subprocess.run(
        command,
        cwd=cwd,
        env=env,
        check=False,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.STDOUT if capture else None,
    )
    if capture and result.stdout:
        print(result.stdout, end="" if result.stdout.endswith("\n") else "\n")
    if result.returncode != 0:
        raise BuildError(f"command failed with exit code {result.returncode}: {shown}")
    return result


def resolve_godot(explicit: str | None, environment: dict[str, str] | None = None) -> Path:
    environment = environment or os.environ
    candidates: list[str] = []
    if explicit:
        candidates.append(explicit)
    elif environment.get("GODOT_BIN"):
        candidates.append(environment["GODOT_BIN"])
    else:
        candidates.extend(("godot", "godot4"))

    for candidate in candidates:
        path = Path(candidate).expanduser()
        if path.is_file():
            return path.resolve()
        discovered = shutil.which(candidate)
        if discovered:
            return Path(discovered).resolve()
    priority = "--godot, then GODOT_BIN, then godot/godot4 on PATH"
    raise BuildError(f"Godot editor not found ({priority})")


def validate_godot_version(godot: Path) -> str:
    result = _run([str(godot), "--version"], capture=True)
    version_line = (result.stdout or "").strip().splitlines()[0]
    if not re.match(r"^4\.7\.2(?:\.|$)", version_line):
        raise BuildError(
            f"unsupported Godot version {version_line!r}; Phase 10A requires {SUPPORTED_GODOT_VERSION}"
        )
    return version_line


def _standard_template_roots(godot: Path) -> list[Path]:
    roots: list[Path] = []
    roots.append(godot.parent / "editor_data" / "export_templates" / "4.7.2.stable")
    system = platform.system()
    if system == "Windows" and os.environ.get("APPDATA"):
        roots.append(Path(os.environ["APPDATA"]) / "Godot" / "export_templates" / "4.7.2.stable")
    elif system == "Darwin":
        roots.append(Path.home() / "Library/Application Support/Godot/export_templates/4.7.2.stable")
    else:
        data_home = os.environ.get("XDG_DATA_HOME")
        root = Path(data_home) if data_home else Path.home() / ".local/share"
        roots.append(root / "godot/export_templates/4.7.2.stable")
    return roots


def resolve_template(
    target: str,
    godot: Path,
    explicit_directory: Path | None,
    environment: dict[str, str] | None = None,
) -> Path:
    environment = environment or os.environ
    roots: list[Path] = []
    if explicit_directory is not None:
        roots.append(explicit_directory.expanduser())
    elif environment.get("GODOT_EXPORT_TEMPLATES_DIR"):
        roots.append(Path(environment["GODOT_EXPORT_TEMPLATES_DIR"]).expanduser())
    else:
        roots.extend(_standard_template_roots(godot))

    filename = TEMPLATE_NAMES[target]
    invalid_roots: list[str] = []
    for root in roots:
        resolved_root = root.resolve()
        candidate = resolved_root / filename
        if candidate.is_file() and candidate.stat().st_size > 0:
            version_file = resolved_root / "version.txt"
            if not version_file.is_file():
                invalid_roots.append(f"{resolved_root} (missing version.txt)")
                continue
            version = version_file.read_text(encoding="utf-8").strip()
            if version != "4.7.2.stable":
                invalid_roots.append(
                    f"{resolved_root} (version.txt is {version!r}, expected '4.7.2.stable')"
                )
                continue
            return candidate
    if invalid_roots:
        raise BuildError(
            f"mismatched Godot {SUPPORTED_GODOT_VERSION} export template directory: "
            + "; ".join(invalid_roots)
        )
    checked = ", ".join(str(root.resolve()) for root in roots) or "no template directories"
    raise BuildError(
        f"missing Godot {SUPPORTED_GODOT_VERSION} export template {filename}; checked: {checked}. "
        "Install the official matching templates or pass --templates."
    )


def _gd_string(value: str) -> str:
    return '"' + value.replace("\\", "/").replace('"', '\\"') + '"'


def set_preset_option(config_path: Path, preset_name: str, key: str, value: str) -> None:
    lines = config_path.read_text(encoding="utf-8").splitlines()
    preset_number: str | None = None
    section: str | None = None
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            section = stripped[1:-1]
        elif section and section.startswith("preset.") and ".options" not in section:
            if stripped == f'name="{preset_name}"':
                preset_number = section.split(".")[1]
                break
    if preset_number is None:
        raise BuildError(f"export preset not found: {preset_name}")

    option_section = f"preset.{preset_number}.options"
    start: int | None = None
    end = len(lines)
    for index, line in enumerate(lines):
        stripped = line.strip()
        if stripped == f"[{option_section}]":
            start = index
            continue
        if start is not None and index > start and stripped.startswith("[") and stripped.endswith("]"):
            end = index
            break
    if start is None:
        lines.extend(("", f"[{option_section}]", f"{key}={_gd_string(value)}"))
    else:
        replacement = f"{key}={_gd_string(value)}"
        for index in range(start + 1, end):
            if lines[index].strip().startswith(f"{key}="):
                lines[index] = replacement
                break
        else:
            lines.insert(end, replacement)
    config_path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8", newline="\n")


def _git_metadata(repository: Path) -> tuple[str, bool]:
    try:
        commit = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=repository,
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        ).stdout.strip()
        dirty = bool(
            subprocess.run(
                ["git", "status", "--porcelain"],
                cwd=repository,
                check=True,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
            ).stdout.strip()
        )
        return commit, dirty
    except (OSError, subprocess.CalledProcessError):
        return os.environ.get("GITHUB_SHA", "unknown"), False


def _manifest(
    target: str,
    godot_version: str,
    repository: Path,
    signing_mode: str,
    toolchain: dict[str, str],
) -> dict[str, object]:
    commit, dirty = _git_metadata(repository)
    return {
        "project": PROJECT_NAME,
        "target": target,
        "godot_version": godot_version,
        "git_commit": commit,
        "dirty": dirty,
        "build_type": "release",
        "timestamp_utc": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
        "package_id": PACKAGE_ID if target in {"android", "ios"} else None,
        "signing_mode": signing_mode,
        "toolchain": toolchain,
    }


def _write_manifest(path: Path, manifest: dict[str, object]) -> None:
    path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _godot_environment(work_root: Path) -> dict[str, str]:
    env = os.environ.copy()
    settings_root = work_root / "godot-editor-data"
    if settings_root.exists():
        shutil.rmtree(settings_root)
    settings_root.mkdir(parents=True)
    if platform.system() == "Windows":
        env["APPDATA"] = str(settings_root / "AppData/Roaming")
        env["LOCALAPPDATA"] = str(settings_root / "AppData/Local")
    else:
        env["XDG_DATA_HOME"] = str(settings_root / "share")
        env["XDG_CONFIG_HOME"] = str(settings_root / "config")
        env["XDG_CACHE_HOME"] = str(settings_root / "cache")
    return env


def _editor_settings_path(env: dict[str, str]) -> Path:
    if platform.system() == "Windows":
        return Path(env["APPDATA"]) / "Godot/editor_settings-4.7.tres"
    return Path(env["XDG_CONFIG_HOME"]) / "godot/editor_settings-4.7.tres"


def _write_android_editor_settings(env: dict[str, str], java_sdk: Path, android_sdk: Path) -> None:
    path = _editor_settings_path(env)
    path.parent.mkdir(parents=True, exist_ok=True)
    content = (
        '[gd_resource type="EditorSettings" format=3]\n\n'
        "[resource]\n"
        f"export/android/java_sdk_path = {_gd_string(java_sdk.as_posix())}\n"
        f"export/android/android_sdk_path = {_gd_string(android_sdk.as_posix())}\n"
    )
    path.write_text(content, encoding="utf-8", newline="\n")


def _java_version(java_sdk: Path) -> str:
    executable = java_sdk / "bin" / ("java.exe" if platform.system() == "Windows" else "java")
    if not executable.is_file():
        raise BuildError(f"Java executable not found under --java-sdk: {executable}")
    result = _run([str(executable), "-version"], capture=True)
    text = result.stdout or ""
    if f'version "{JDK_VERSION.split("+")[0]}"' not in text or f"Temurin-{JDK_VERSION}" not in text:
        raise BuildError(f"Android builds require pinned Temurin JDK {JDK_VERSION}; found: {text.strip()}")
    return text.splitlines()[0].strip()


def _source_property(directory: Path, key: str) -> str:
    path = directory / "source.properties"
    if not path.is_file():
        raise BuildError(f"Android SDK package metadata is missing: {path}")
    for line in path.read_text(encoding="utf-8").splitlines():
        name, separator, value = line.partition("=")
        if separator and name.strip() == key:
            return value.strip()
    raise BuildError(f"Android SDK package metadata has no {key}: {path}")


def _validate_android_sdk(android_sdk: Path) -> dict[str, str]:
    command_line_tools = android_sdk / "cmdline-tools/20.0"
    if not command_line_tools.exists():
        command_line_tools = android_sdk / "cmdline-tools/latest"
    required = {
        "platform_tools": android_sdk / "platform-tools",
        "build_tools": android_sdk / "build-tools/35.0.1",
        "platform": android_sdk / "platforms/android-35",
        "command_line_tools": command_line_tools,
        "cmake": android_sdk / "cmake/3.10.2.4988404",
        "ndk": android_sdk / "ndk/28.1.13356709",
    }
    missing = [name for name, path in required.items() if not path.exists()]
    if missing:
        details = ", ".join(f"{name}={required[name]}" for name in missing)
        raise BuildError(f"Android SDK is missing pinned Phase 10A packages: {details}")
    versions = {
        "platform_tools": _source_property(required["platform_tools"], "Pkg.Revision"),
        "build_tools": _source_property(required["build_tools"], "Pkg.Revision"),
        "platform": _source_property(required["platform"], "AndroidVersion.ApiLevel"),
        "command_line_tools": _source_property(required["command_line_tools"], "Pkg.Revision"),
        "cmake": _source_property(required["cmake"], "Pkg.Revision"),
        "ndk": _source_property(required["ndk"], "Pkg.Revision"),
    }
    if tuple(int(part) for part in versions["platform_tools"].split(".")) < (35, 0, 0):
        raise BuildError(f"Android Platform-Tools 35.0.0+ is required; found {versions['platform_tools']}")
    expected = {
        "build_tools": "35.0.1",
        "platform": "35",
        "command_line_tools": "20.0",
        "cmake": "3.10.2",
        "ndk": "28.1.13356709",
    }
    mismatched = [name for name, value in expected.items() if versions[name] != value]
    if mismatched:
        details = ", ".join(f"{name}={versions[name]} (expected {expected[name]})" for name in mismatched)
        raise BuildError(f"Android SDK package versions do not match Phase 10A pins: {details}")
    return {
        "platform_sdk_available": "android-35",
        "build_tools_available": "35.0.1",
        "command_line_tools": "20.0",
        "platform_tools": versions["platform_tools"],
        "cmake": "3.10.2.4988404",
        "ndk": "28.1.13356709",
    }


def _validate_apk(apk: Path, android_sdk: Path) -> str:
    if not apk.is_file() or apk.stat().st_size <= 0:
        raise BuildError(f"Android export did not create a non-empty APK: {apk}")
    executable = "aapt2.exe" if platform.system() == "Windows" else "aapt2"
    aapt2 = android_sdk / "build-tools/35.0.1" / executable
    if not aapt2.is_file():
        return "aapt2 unavailable; file and exporter status validated"
    output = _run([str(aapt2), "dump", "packagename", str(apk)], capture=True).stdout or ""
    found = output.strip().splitlines()[-1] if output.strip() else ""
    if found != PACKAGE_ID:
        raise BuildError(f"unexpected APK package identifier: {found!r}")
    return f"aapt2 package={found}"


def _headless_validate(godot: Path, project: Path, env: dict[str, str]) -> None:
    _run([str(godot), "--headless", "--path", str(project), "--editor", "--quit"], env=env)


def _clean_directory(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def _build_windows(
    godot: Path,
    stage: Path,
    dist: Path,
    env: dict[str, str],
    manifest: dict[str, object],
) -> None:
    target_dir = dist / "windows"
    _clean_directory(target_dir)
    executable = target_dir / f"{PROJECT_NAME}.exe"
    _run(
        [str(godot), "--headless", "--path", str(stage), "--export-release", PRESET_NAMES["windows"], str(executable)],
        env=env,
    )
    if not executable.is_file() or executable.stat().st_size <= 0:
        raise BuildError(f"Windows export did not create a non-empty executable: {executable}")
    manifest_path = target_dir / "build-manifest.json"
    _write_manifest(manifest_path, manifest)
    archive = dist / f"{PROJECT_NAME}-windows-x86_64.zip"
    if archive.exists():
        archive.unlink()
    runtime_files = sorted(path for path in target_dir.iterdir() if path.is_file())
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as package:
        for path in runtime_files:
            package.write(path, path.name)
    if archive.stat().st_size <= 0:
        raise BuildError("Windows ZIP is empty")
    print(f"Windows Release artifact: {archive} ({archive.stat().st_size} bytes)")


def _build_android(
    godot: Path,
    stage: Path,
    dist: Path,
    work_root: Path,
    env: dict[str, str],
    manifest: dict[str, object],
    java_sdk: Path,
    android_sdk: Path,
) -> None:
    target_dir = dist / "android"
    _clean_directory(target_dir)
    _write_android_editor_settings(env, java_sdk, android_sdk)
    keytool = java_sdk / "bin" / ("keytool.exe" if platform.system() == "Windows" else "keytool")
    if not keytool.is_file():
        raise BuildError(f"keytool not found: {keytool}")
    keystore_dir = work_root / "ephemeral-signing"
    _clean_directory(keystore_dir)
    keystore = keystore_dir / "phase10a-qa.keystore"
    password = secrets.token_hex(16)
    alias = "phase10aqa"
    apk = target_dir / f"{PROJECT_NAME}-android-arm64.apk"
    try:
        _run(
            [
                str(keytool),
                "-genkeypair",
                "-keystore",
                str(keystore),
                "-storepass:env",
                "PHASE10A_KEYSTORE_PASSWORD",
                "-keypass:env",
                "PHASE10A_KEYSTORE_PASSWORD",
                "-alias",
                alias,
                "-keyalg",
                "RSA",
                "-keysize",
                "2048",
                "-validity",
                "2",
                "-dname",
                "CN=Phase10A QA, OU=Ephemeral CI, O=Technical Build, C=XX",
            ],
            env={**env, "PHASE10A_KEYSTORE_PASSWORD": password},
        )
        export_env = env.copy()
        export_env.update(
            {
                "GODOT_ANDROID_KEYSTORE_RELEASE_PATH": str(keystore),
                "GODOT_ANDROID_KEYSTORE_RELEASE_USER": alias,
                "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD": password,
            }
        )
        _run(
            [str(godot), "--headless", "--path", str(stage), "--export-release", PRESET_NAMES["android"], str(apk)],
            env=export_env,
        )
        manifest["toolchain"]["apk_validation"] = _validate_apk(apk, android_sdk)  # type: ignore[index]
        _write_manifest(target_dir / "build-manifest.json", manifest)
    finally:
        if keystore_dir.exists():
            shutil.rmtree(keystore_dir)
        shutil.rmtree(work_root / "godot-editor-data", ignore_errors=True)
    print(f"Android technical Release APK: {apk} ({apk.stat().st_size} bytes)")


def _json_from_output(text: str) -> dict[str, object]:
    start = text.find("{")
    end = text.rfind("}")
    if start < 0 or end < start:
        raise BuildError("xcodebuild did not return JSON project metadata")
    try:
        value = json.loads(text[start : end + 1])
    except json.JSONDecodeError as error:
        raise BuildError(f"invalid xcodebuild JSON metadata: {error}") from error
    if not isinstance(value, dict):
        raise BuildError("xcodebuild project metadata is not an object")
    return value


def _xcode_selector(export_dir: Path) -> list[str]:
    workspaces = sorted(export_dir.rglob("*.xcworkspace"))
    projects = sorted(export_dir.rglob("*.xcodeproj"))
    if workspaces:
        if len(workspaces) != 1:
            names = ", ".join(path.relative_to(export_dir).as_posix() for path in workspaces)
            raise BuildError(f"Godot iOS export produced multiple Xcode workspaces: {names}")
        return ["-workspace", str(workspaces[0])]
    if projects:
        if len(projects) != 1:
            names = ", ".join(path.relative_to(export_dir).as_posix() for path in projects)
            raise BuildError(f"Godot iOS export produced multiple Xcode projects: {names}")
        return ["-project", str(projects[0])]
    raise BuildError("Godot iOS export produced no Xcode project or workspace")


def _xcode_scheme(metadata: dict[str, object]) -> str:
    container = metadata.get("workspace") or metadata.get("project")
    if not isinstance(container, dict):
        raise BuildError("xcodebuild metadata has no project/workspace section")
    schemes = container.get("schemes")
    if not isinstance(schemes, list) or not schemes:
        raise BuildError("generated Xcode project exposes no scheme")
    if "EasternStoriesGodot" in schemes:
        return "EasternStoriesGodot"
    if len(schemes) == 1 and isinstance(schemes[0], str) and schemes[0]:
        return schemes[0]
    raise BuildError(f"generated Xcode project has ambiguous schemes: {schemes!r}")


def _compile_ios_sdl_compat_shim(xcrun: str, export_dir: Path, env: dict[str, str]) -> Path:
    source = Path(__file__).with_name("ios_sdl_compat_shim.m")
    if not source.is_file():
        raise BuildError(f"Godot 4.7 iOS SDL compatibility shim is missing: {source}")
    shim_dir = export_dir / "Phase10ACompat"
    shim_dir.mkdir(parents=True, exist_ok=True)
    output = shim_dir / "ios_sdl_compat_shim.o"
    _run(
        [
            xcrun,
            "--sdk",
            "iphoneos",
            "clang",
            "-arch",
            "arm64",
            "-mios-version-min=16.0",
            "-fobjc-arc",
            "-c",
            str(source),
            "-o",
            str(output),
        ],
        env=env,
    )
    if not output.is_file():
        raise BuildError("iOS SDL compatibility shim compiler produced no object file")
    return output


def _build_ios(
    godot: Path,
    stage: Path,
    dist: Path,
    env: dict[str, str],
    manifest: dict[str, object],
) -> None:
    if platform.system() != "Darwin":
        raise BuildError("iOS build validation requires macOS and Xcode")
    xcodebuild = shutil.which("xcodebuild")
    if not xcodebuild:
        raise BuildError("xcodebuild is unavailable; install/select Xcode before iOS validation")
    xcrun = shutil.which("xcrun")
    if not xcrun:
        raise BuildError("xcrun is unavailable; install/select Xcode before iOS validation")
    target_dir = dist / "ios"
    _clean_directory(target_dir)
    export_dir = target_dir / "xcode"
    export_dir.mkdir(parents=True)
    export_name = export_dir / "EasternStoriesGodot"
    _run(
        [str(godot), "--headless", "--path", str(stage), "--export-release", PRESET_NAMES["ios"], str(export_name)],
        env=env,
    )
    selector = _xcode_selector(export_dir)

    metadata_result = _run([xcodebuild, *selector, "-list", "-json"], capture=True)
    metadata = _json_from_output(metadata_result.stdout or "")
    scheme = _xcode_scheme(metadata)
    xcode_version = _run([xcodebuild, "-version"], capture=True).stdout or ""
    sdl_compat_shim = _compile_ios_sdl_compat_shim(xcrun, export_dir, env)
    log_path = target_dir / "xcodebuild.log"
    command = [
        xcodebuild,
        *selector,
        "-scheme",
        scheme,
        "-configuration",
        "Release",
        "-sdk",
        "iphoneos",
        "-destination",
        "generic/platform=iOS",
        "-derivedDataPath",
        str(target_dir / "DerivedData"),
        "CODE_SIGNING_ALLOWED=NO",
        "CODE_SIGNING_REQUIRED=NO",
        "CODE_SIGN_IDENTITY=",
        f"OTHER_LDFLAGS=$(inherited) {sdl_compat_shim}",
        "build",
    ]
    print(f"+ {' '.join(command)}")
    result = subprocess.run(command, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log_path.write_text(result.stdout or "", encoding="utf-8")
    print(result.stdout or "", end="")
    if result.returncode != 0:
        raise BuildError(f"xcodebuild unsigned Release compile failed with exit code {result.returncode}")
    manifest["toolchain"]["xcode"] = xcode_version.strip().replace("\n", "; ")  # type: ignore[index]
    manifest["toolchain"]["scheme"] = scheme  # type: ignore[index]
    _write_manifest(target_dir / "build-manifest.json", manifest)
    archive = target_dir / f"{PROJECT_NAME}-ios-xcode.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as package:
        for path in sorted(export_dir.rglob("*")):
            if path.is_file():
                package.write(path, path.relative_to(export_dir).as_posix())
        package.write(target_dir / "build-manifest.json", "build-manifest.json")
        package.write(log_path, "xcodebuild.log")
    shutil.rmtree(target_dir / "DerivedData", ignore_errors=True)
    print(f"iOS unsigned build-validation artifact: {archive} ({archive.stat().st_size} bytes)")


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", choices=tuple(PRESET_NAMES), required=True)
    parser.add_argument("--godot")
    parser.add_argument("--templates", type=Path)
    parser.add_argument("--source-project", type=Path, default=Path("game"))
    parser.add_argument("--staging", type=Path, default=Path("build/release-project"))
    parser.add_argument("--dist", type=Path, default=Path("dist"))
    parser.add_argument("--android-sdk", type=Path)
    parser.add_argument("--java-sdk", type=Path)
    parser.add_argument("--require-clean", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    repository = Path(__file__).resolve().parents[2]
    source = args.source_project.resolve()
    staging = args.staging.resolve()
    dist = args.dist.resolve()
    work_root = staging.parent
    try:
        if args.target == "ios" and platform.system() != "Darwin":
            raise BuildError("iOS validation requires macOS with Xcode; run the iOS Build Validation CI job")
        if args.require_clean:
            _, dirty = _git_metadata(repository)
            if dirty:
                raise BuildError("--require-clean was requested, but the Git worktree is dirty")
        godot = resolve_godot(args.godot)
        godot_version = validate_godot_version(godot)
        template = resolve_template(args.target, godot, args.templates)
        prepare_release_project(source, staging)
        errors = validate_release_project(staging)
        if errors:
            raise BuildError("\n".join(errors))
        set_preset_option(
            staging / "export_presets.cfg",
            PRESET_NAMES[args.target],
            "custom_template/release",
            str(template),
        )
        env = _godot_environment(work_root)
        toolchain: dict[str, str] = {"export_template": TEMPLATE_NAMES[args.target]}
        signing_mode = {"windows": "none", "android": "ephemeral_qa", "ios": "unsigned_validation"}[args.target]
        android_sdk: Path | None = None
        java_sdk: Path | None = None
        if args.target == "android":
            android_sdk_value = args.android_sdk or (Path(os.environ["ANDROID_SDK_ROOT"]) if os.environ.get("ANDROID_SDK_ROOT") else None) or (Path(os.environ["ANDROID_HOME"]) if os.environ.get("ANDROID_HOME") else None)
            java_sdk_value = args.java_sdk or (Path(os.environ["JAVA_HOME"]) if os.environ.get("JAVA_HOME") else None)
            if android_sdk_value is None or java_sdk_value is None:
                raise BuildError("Android build requires --android-sdk/ANDROID_SDK_ROOT and --java-sdk/JAVA_HOME")
            android_sdk = android_sdk_value.expanduser().resolve()
            java_sdk = java_sdk_value.expanduser().resolve()
            toolchain.update(_validate_android_sdk(android_sdk))
            toolchain["java"] = _java_version(java_sdk)
            _write_android_editor_settings(env, java_sdk, android_sdk)

        _headless_validate(godot, staging, env)

        if args.target == "windows":
            manifest = _manifest(args.target, godot_version, repository, signing_mode, toolchain)
            _build_windows(godot, staging, dist, env, manifest)
        elif args.target == "android":
            if android_sdk is None or java_sdk is None:
                raise BuildError("internal Android toolchain validation error")
            manifest = _manifest(args.target, godot_version, repository, signing_mode, toolchain)
            _build_android(godot, staging, dist, work_root, env, manifest, java_sdk, android_sdk)
        else:
            toolchain["host"] = platform.platform()
            manifest = _manifest(args.target, godot_version, repository, signing_mode, toolchain)
            _build_ios(godot, staging, dist, env, manifest)
        return 0
    except (BuildError, OSError, ReleaseProjectError) as error:
        print(f"Build failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
