from __future__ import annotations

import os
import io
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr
from pathlib import Path
from unittest import mock


REPOSITORY = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY / "tools/build"))

import build  # noqa: E402


class BuildToolTest(unittest.TestCase):
    def test_technical_android_abi_changes_only_disposable_preset(self) -> None:
        source = REPOSITORY / "game/export_presets.cfg"
        original = source.read_bytes()
        stage = self.root / "stage"
        stage.mkdir()
        preset = stage / "export_presets.cfg"
        preset.write_bytes(original)
        build.configure_technical_android_abi(stage, None)
        self.assertEqual(preset.read_bytes(), original)
        build.configure_technical_android_abi(stage, "x86_64")
        text = preset.read_text(encoding="utf-8")
        self.assertIn("architectures/x86_64=true", text)
        for abi in ("armeabi-v7a", "arm64-v8a", "x86"):
            self.assertIn(f"architectures/{abi}=false", text)
        self.assertNotIn('architectures/x86_64="true"', text)
        self.assertEqual(source.read_bytes(), original)

    def test_technical_abi_rejects_other_values_or_targets(self) -> None:
        with self.assertRaises(build.BuildError):
            build.configure_technical_android_abi(self.root, "arm64-v8a")
        with redirect_stderr(io.StringIO()):
            self.assertEqual(build.main(["--target", "windows", "--android-technical-abi", "x86_64"]), 1)

    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def _file(self, name: str) -> Path:
        path = self.root / name
        path.write_text("tool", encoding="utf-8")
        return path

    def _android_package(self, sdk: Path, relative: str, properties: str) -> None:
        directory = sdk / relative
        directory.mkdir(parents=True)
        (directory / "source.properties").write_text(properties, encoding="utf-8")

    def test_explicit_godot_wins_over_environment(self) -> None:
        explicit = self._file("explicit-godot")
        environment = self._file("environment-godot")
        found = build.resolve_godot(str(explicit), {"GODOT_BIN": str(environment)})
        self.assertEqual(explicit.resolve(), found)

    def test_environment_godot_is_second_priority(self) -> None:
        environment = self._file("environment-godot")
        found = build.resolve_godot(None, {"GODOT_BIN": str(environment)})
        self.assertEqual(environment.resolve(), found)

    def test_missing_godot_has_actionable_failure(self) -> None:
        with mock.patch.object(build.shutil, "which", return_value=None):
            with self.assertRaises(build.BuildError) as context:
                build.resolve_godot(None, {})
        self.assertIn("--godot", str(context.exception))
        self.assertIn("GODOT_BIN", str(context.exception))

    def test_version_accepts_official_and_steam_suffixes(self) -> None:
        executable = self._file("godot")
        for value in ("4.7.2.stable.official.abc", "4.7.2.stable.steam.ed1daf0bf"):
            completed = subprocess.CompletedProcess([str(executable)], 0, stdout=value + "\n")
            with mock.patch.object(build, "_run", return_value=completed):
                self.assertEqual(value, build.validate_godot_version(executable))

    def test_version_rejects_another_patch(self) -> None:
        executable = self._file("godot")
        completed = subprocess.CompletedProcess([str(executable)], 0, stdout="4.7.1.stable.official\n")
        with mock.patch.object(build, "_run", return_value=completed):
            with self.assertRaises(build.BuildError):
                build.validate_godot_version(executable)

    def test_java_version_requires_exact_pinned_temurin_build(self) -> None:
        java_sdk = self.root / "jdk"
        executable = java_sdk / "bin" / ("java.exe" if build.platform.system() == "Windows" else "java")
        executable.parent.mkdir(parents=True)
        executable.write_text("tool", encoding="utf-8")
        output = (
            'openjdk version "17.0.18" 2026-01-20\n'
            'OpenJDK Runtime Environment Temurin-17.0.18+8 (build 17.0.18+8)\n'
        )
        completed = subprocess.CompletedProcess([str(executable)], 0, stdout=output)
        with mock.patch.object(build, "_run", return_value=completed):
            self.assertEqual('openjdk version "17.0.18" 2026-01-20', build._java_version(java_sdk))

    def test_java_version_rejects_unpinned_jdk_17(self) -> None:
        java_sdk = self.root / "jdk"
        executable = java_sdk / "bin" / ("java.exe" if build.platform.system() == "Windows" else "java")
        executable.parent.mkdir(parents=True)
        executable.write_text("tool", encoding="utf-8")
        completed = subprocess.CompletedProcess(
            [str(executable)],
            0,
            stdout='openjdk version "17.0.17"\nOpenJDK Runtime Environment Temurin-17.0.17+10\n',
        )
        with mock.patch.object(build, "_run", return_value=completed):
            with self.assertRaises(build.BuildError):
                build._java_version(java_sdk)

    def test_missing_template_reports_filename(self) -> None:
        executable = self._file("godot")
        templates = self.root / "templates"
        templates.mkdir()
        (templates / "version.txt").write_text("4.7.2.stable\n", encoding="utf-8")
        with self.assertRaises(build.BuildError) as context:
            build.resolve_template("windows", executable, templates)
        self.assertIn("windows_release_x86_64.exe", str(context.exception))

    def test_template_resolution_uses_explicit_directory(self) -> None:
        executable = self._file("godot")
        templates = self.root / "templates"
        templates.mkdir()
        (templates / "version.txt").write_text("4.7.2.stable\n", encoding="utf-8")
        template = templates / "android_release.apk"
        template.write_bytes(b"apk")
        self.assertEqual(template.resolve(), build.resolve_template("android", executable, templates))

    def test_template_resolution_rejects_missing_version_metadata(self) -> None:
        executable = self._file("godot")
        templates = self.root / "templates"
        templates.mkdir()
        (templates / "android_release.apk").write_bytes(b"apk")
        with self.assertRaises(build.BuildError) as context:
            build.resolve_template("android", executable, templates)
        self.assertIn("missing version.txt", str(context.exception))

    def test_template_resolution_rejects_mismatched_version(self) -> None:
        executable = self._file("godot")
        templates = self.root / "templates"
        templates.mkdir()
        (templates / "version.txt").write_text("4.7.1.stable\n", encoding="utf-8")
        (templates / "android_release.apk").write_bytes(b"apk")
        with self.assertRaises(build.BuildError) as context:
            build.resolve_template("android", executable, templates)
        self.assertIn("4.7.1.stable", str(context.exception))

    def test_ios_cli_fails_clearly_before_tool_resolution_on_non_macos(self) -> None:
        errors = io.StringIO()
        with mock.patch.object(build.platform, "system", return_value="Windows"):
            with redirect_stderr(errors):
                result = build.main(["--target", "ios"])
        self.assertEqual(1, result)
        self.assertIn("macOS with Xcode", errors.getvalue())

    def test_xcode_selector_rejects_multiple_workspaces(self) -> None:
        export = self.root / "ios"
        (export / "one.xcworkspace").mkdir(parents=True)
        (export / "two.xcworkspace").mkdir()
        with self.assertRaises(build.BuildError):
            build._xcode_selector(export)

    def test_xcode_scheme_requires_unambiguous_metadata(self) -> None:
        self.assertEqual(
            "GeneratedGame",
            build._xcode_scheme({"project": {"schemes": ["GeneratedGame"]}}),
        )
        with self.assertRaises(build.BuildError):
            build._xcode_scheme({"project": {"schemes": ["One", "Two"]}})

    def test_ios_sdl_compat_shim_is_compiled_for_device_arm64(self) -> None:
        export = self.root / "ios"
        seen_commands: list[list[str]] = []

        def fake_run(command: list[str], **_kwargs: object) -> subprocess.CompletedProcess[str]:
            seen_commands.append(command)
            Path(command[-1]).write_bytes(b"object")
            return subprocess.CompletedProcess(command, 0, stdout="")

        with mock.patch.object(build, "_run", side_effect=fake_run):
            output = build._compile_ios_sdl_compat_shim("xcrun", export, {})

        self.assertTrue(output.is_file())
        self.assertEqual("xcrun", seen_commands[0][0])
        self.assertIn("iphoneos", seen_commands[0])
        self.assertIn("arm64", seen_commands[0])
        self.assertIn("-mios-version-min=16.0", seen_commands[0])
        self.assertEqual(str(output), seen_commands[0][-1])

    def test_android_signing_secret_is_not_logged_and_generated_keys_are_removed(self) -> None:
        godot = self._file("godot")
        stage = self.root / "stage"
        stage.mkdir()
        dist = self.root / "dist"
        work_root = self.root / "work"
        environment = build._godot_environment(work_root)
        generated_debug_key = work_root / "godot-editor-data/keystores/debug.keystore"
        generated_debug_key.parent.mkdir(parents=True)
        generated_debug_key.write_bytes(b"generated")
        java_sdk = self.root / "jdk"
        keytool = java_sdk / "bin" / ("keytool.exe" if build.platform.system() == "Windows" else "keytool")
        keytool.parent.mkdir(parents=True)
        keytool.write_text("tool", encoding="utf-8")
        android_sdk = self.root / "android-sdk"
        seen_commands: list[list[str]] = []

        def fake_run(command: list[str], **_kwargs: object) -> subprocess.CompletedProcess[str]:
            seen_commands.append(command)
            if "--export-release" in command:
                apk = dist / "android" / f"{build.PROJECT_NAME}-android-arm64.apk"
                apk.write_bytes(b"apk")
            return subprocess.CompletedProcess(command, 0, stdout="")

        manifest: dict[str, object] = {"toolchain": {}}
        with mock.patch.object(build.secrets, "token_hex", return_value="supersecret"):
            with mock.patch.object(build, "_run", side_effect=fake_run):
                with mock.patch.object(build, "_validate_apk", return_value="validated"):
                    build._build_android(
                        godot,
                        stage,
                        dist,
                        work_root,
                        environment,
                        manifest,
                        java_sdk,
                        android_sdk,
                    )

        flattened = [value for command in seen_commands for value in command]
        self.assertNotIn("supersecret", flattened)
        self.assertIn("PHASE10A_KEYSTORE_PASSWORD", flattened)
        self.assertFalse((work_root / "ephemeral-signing").exists())
        self.assertFalse((work_root / "godot-editor-data").exists())

    def test_set_preset_option_updates_only_selected_preset(self) -> None:
        config = self.root / "export_presets.cfg"
        config.write_text(
            '[preset.0]\nname="Windows Desktop"\n\n[preset.0.options]\ncustom_template/release=""\n'
            '\n[preset.1]\nname="Android"\n\n[preset.1.options]\ncustom_template/release=""\n',
            encoding="utf-8",
        )
        build.set_preset_option(config, "Android", "custom_template/release", "/tmp/android_release.apk")
        text = config.read_text(encoding="utf-8")
        self.assertIn('custom_template/release="/tmp/android_release.apk"', text)
        self.assertEqual(1, text.count('custom_template/release=""'))

    def test_apk_validation_uses_aapt2_package_name(self) -> None:
        apk = self._file("game.apk")
        sdk = self.root / "sdk"
        aapt2 = sdk / "build-tools" / "35.0.1" / "aapt2.exe"
        aapt2.parent.mkdir(parents=True)
        aapt2.write_text("tool", encoding="utf-8")
        completed = subprocess.CompletedProcess(
            [str(aapt2)],
            0,
            stdout=build.PACKAGE_ID + "\n",
        )
        with mock.patch.object(build.platform, "system", return_value="Windows"):
            with mock.patch.object(build, "_run", return_value=completed):
                self.assertEqual(
                    f"aapt2 package={build.PACKAGE_ID}",
                    build._validate_apk(apk, sdk),
                )

    def test_android_sdk_validation_records_exact_pins(self) -> None:
        sdk = self.root / "sdk"
        self._android_package(sdk, "platform-tools", "Pkg.Revision=37.0.1\n")
        self._android_package(sdk, "build-tools/35.0.1", "Pkg.Revision=35.0.1\n")
        self._android_package(sdk, "platforms/android-35", "AndroidVersion.ApiLevel=35\n")
        self._android_package(sdk, "cmdline-tools/20.0", "Pkg.Revision=20.0\n")
        self._android_package(sdk, "cmake/3.10.2.4988404", "Pkg.Revision=3.10.2\n")
        self._android_package(sdk, "ndk/28.1.13356709", "Pkg.Revision=28.1.13356709\n")
        result = build._validate_android_sdk(sdk)
        self.assertEqual("37.0.1", result["platform_tools"])
        self.assertEqual("20.0", result["command_line_tools"])

    def test_android_sdk_validation_rejects_drifting_command_line_tools(self) -> None:
        sdk = self.root / "sdk"
        self._android_package(sdk, "platform-tools", "Pkg.Revision=37.0.1\n")
        self._android_package(sdk, "build-tools/35.0.1", "Pkg.Revision=35.0.1\n")
        self._android_package(sdk, "platforms/android-35", "AndroidVersion.ApiLevel=35\n")
        self._android_package(sdk, "cmdline-tools/20.0", "Pkg.Revision=19.0\n")
        self._android_package(sdk, "cmake/3.10.2.4988404", "Pkg.Revision=3.10.2\n")
        self._android_package(sdk, "ndk/28.1.13356709", "Pkg.Revision=28.1.13356709\n")
        with self.assertRaises(build.BuildError):
            build._validate_android_sdk(sdk)

    def test_isolated_godot_environment_discards_stale_settings(self) -> None:
        work_root = self.root / "work"
        stale = work_root / "godot-editor-data" / "stale.txt"
        stale.parent.mkdir(parents=True)
        stale.write_text("old build state", encoding="utf-8")
        with mock.patch.object(build.platform, "system", return_value="Windows"):
            environment = build._godot_environment(work_root)
        self.assertFalse(stale.exists())
        self.assertEqual(
            work_root / "godot-editor-data" / "AppData" / "Roaming",
            Path(environment["APPDATA"]),
        )


if __name__ == "__main__":
    unittest.main()
