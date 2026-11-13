from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


REPOSITORY = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY / "tools/build"))

import build  # noqa: E402


class BuildToolTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def _file(self, name: str) -> Path:
        path = self.root / name
        path.write_text("tool", encoding="utf-8")
        return path

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
        template = templates / "windows_release_x86_64.exe"
        template.write_bytes(b"exe")
        self.assertEqual(template.resolve(), build.resolve_template("windows", executable, templates))

    def test_template_resolution_rejects_missing_version_metadata(self) -> None:
        executable = self._file("godot")
        templates = self.root / "templates"
        templates.mkdir()
        (templates / "windows_release_x86_64.exe").write_bytes(b"exe")
        with self.assertRaises(build.BuildError) as context:
            build.resolve_template("windows", executable, templates)
        self.assertIn("missing version.txt", str(context.exception))

    def test_template_resolution_rejects_mismatched_version(self) -> None:
        executable = self._file("godot")
        templates = self.root / "templates"
        templates.mkdir()
        (templates / "version.txt").write_text("4.7.1.stable\n", encoding="utf-8")
        (templates / "windows_release_x86_64.exe").write_bytes(b"exe")
        with self.assertRaises(build.BuildError) as context:
            build.resolve_template("windows", executable, templates)
        self.assertIn("4.7.1.stable", str(context.exception))

    def test_set_preset_option_updates_only_selected_preset(self) -> None:
        config = self.root / "export_presets.cfg"
        config.write_text(
            '[preset.0]\nname="Windows Desktop"\n\n[preset.0.options]\ncustom_template/release=""\n'
            '\n[preset.1]\nname="Linux"\n\n[preset.1.options]\ncustom_template/release=""\n',
            encoding="utf-8",
        )
        build.set_preset_option(config, "Windows Desktop", "custom_template/release", "/tmp/windows_release_x86_64.exe")
        text = config.read_text(encoding="utf-8")
        self.assertIn('custom_template/release="/tmp/windows_release_x86_64.exe"', text)
        self.assertEqual(1, text.count('custom_template/release=""'))

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

    def test_staged_project_gets_its_version(self) -> None:
        project = self.root / "project.godot"
        project.write_text('config_version=5\n\n[application]\n\nconfig/name="Eastern-Stories-Godot"\n\n[display]\n', encoding="utf-8")
        build.set_project_version(project, "v0.3 (1a2b3c4d)")
        build.set_project_version(project, "1a2b3c4d")
        lines = project.read_text(encoding="utf-8").splitlines()
        self.assertEqual(['config/version="1a2b3c4d"'], [line for line in lines if line.startswith("config/version=")])
        self.assertEqual(lines.index("[application]") + 2, lines.index('config/version="1a2b3c4d"'))
        self.assertIn('config/name="Eastern-Stories-Godot"', lines)

    def test_a_project_without_application_section_is_refused(self) -> None:
        project = self.root / "project.godot"
        project.write_text("config_version=5\n", encoding="utf-8")
        with self.assertRaises(build.BuildError):
            build.set_project_version(project, "1a2b3c4d")

    def test_version_label_is_the_short_commit_with_the_tag_when_there_is_one(self) -> None:
        answers = {("rev-parse", "--short=8", "HEAD"): "1a2b3c4d", ("describe", "--tags", "--exact-match", "HEAD"): None}
        with mock.patch.object(build, "_git_output", side_effect=lambda _repository, *arguments: answers[arguments]), \
                mock.patch.object(build, "_git_metadata", return_value=("1a2b3c4d" * 5, False)):
            self.assertEqual("1a2b3c4d", build.version_label(self.root))
            answers[("describe", "--tags", "--exact-match", "HEAD")] = "v0.3"
            self.assertEqual("v0.3 (1a2b3c4d)", build.version_label(self.root))
        with mock.patch.object(build, "_git_output", side_effect=lambda _repository, *arguments: answers[arguments]), \
                mock.patch.object(build, "_git_metadata", return_value=("1a2b3c4d" * 5, True)):
            self.assertEqual("v0.3 (1a2b3c4d-dirty)", build.version_label(self.root))

    def test_a_pull_requests_build_names_the_branch_head(self) -> None:
        # CI checks out the PR's merge commit; the workflow names the branch's head instead.
        answers = {("rev-parse", "--short=8", "HEAD"): "merge000", ("describe", "--tags", "--exact-match", "HEAD"): None}
        with mock.patch.dict(os.environ, {"ES_BUILD_COMMIT": "9246edb9c0ffee"}), \
                mock.patch.object(build, "_git_output", side_effect=lambda _repository, *arguments: answers[arguments]), \
                mock.patch.object(build, "_git_metadata", return_value=("merge000" * 5, False)):
            self.assertEqual("9246edb9", build.version_label(self.root))


if __name__ == "__main__":
    unittest.main()
