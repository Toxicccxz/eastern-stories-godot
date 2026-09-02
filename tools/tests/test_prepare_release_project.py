from __future__ import annotations

import hashlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY / "tools/build"))

from prepare_release_project import (  # noqa: E402
    EXPECTED_MAIN_SCENE,
    REQUIRED_PATHS,
    ReleaseProjectError,
    prepare_release_project,
    sanitize_project_config,
    source_tree_digest,
    validate_release_project,
)


PROJECT_TEXT = f'''config_version=5

[application]

config/name="Test"
run/main_scene="{EXPECTED_MAIN_SCENE}"

[autoload]

_mcp_game_helper="*res://addons/godot_ai/runtime/game_helper.gd"
_phase10b4_qa_bridge="*res://tests/runtime/phase10b4_qa_bridge.gd"

[editor]

run/main_run_args="--remote-debug tcp://127.0.0.1:6107"

[editor_plugins]

enabled=PackedStringArray("res://addons/godot_ai/plugin.cfg")

[rendering]

renderer/rendering_method="mobile"
'''


class PrepareReleaseProjectTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.source = self.root / "source"
        self.output = self.root / "output"
        for relative in (
            "core",
            "data",
            "runtime",
            "application/settings",
            "runtime/application",
            "scenes/application",
            "scenes/world/oldpine",
            "scenes/runtime",
            "tests",
            "addons/godot_ai/runtime",
            ".godot",
        ):
            (self.source / relative).mkdir(parents=True, exist_ok=True)
        (self.source / "project.godot").write_text(PROJECT_TEXT, encoding="utf-8")
        (self.source / "export_presets.cfg").write_text("[preset.0]\nname=\"Windows Desktop\"\n", encoding="utf-8")
        (self.source / "core/domain.gd").write_text("class_name Domain\n", encoding="utf-8")
        (self.source / "data/content.gd").write_text("class_name Content\n", encoding="utf-8")
        (self.source / "runtime/runtime.gd").write_text("class_name Runtime\n", encoding="utf-8")
        (self.source / "application/settings/application_settings_snapshot.gd").write_text(
            "class_name ApplicationSettingsSnapshot\n", encoding="utf-8"
        )
        (self.source / "application/settings/application_settings_repository.gd").write_text(
            "class_name ApplicationSettingsRepository\n", encoding="utf-8"
        )
        (self.source / "application/settings/application_settings_service.gd").write_text(
            "class_name ApplicationSettingsService\n", encoding="utf-8"
        )
        (self.source / "runtime/application/godot_window_mode_capability.gd").write_text(
            "class_name GodotWindowModeCapability\n", encoding="utf-8"
        )
        (self.source / "scenes/application/application_shell.tscn").write_text("[gd_scene]\n", encoding="utf-8")
        (self.source / "scenes/world/oldpine/oldpine_world_session.tscn").write_text("[gd_scene]\n", encoding="utf-8")
        (self.source / "scenes/runtime/oldpine_game_runtime_host.tscn").write_text("[gd_scene]\n", encoding="utf-8")
        (self.source / "scenes/mcp_test.tscn").write_text("[gd_scene]\n", encoding="utf-8")
        (self.source / "tests/run_tests.gd").write_text("extends SceneTree\n", encoding="utf-8")
        (self.source / "addons/godot_ai/runtime/game_helper.gd").write_text("extends Node\n", encoding="utf-8")
        (self.source / "godot-ai-LICENSE.txt").write_text("development license\n", encoding="utf-8")
        (self.source / ".godot/generated.txt").write_text("generated\n", encoding="utf-8")
        for relative in REQUIRED_PATHS:
            if relative.endswith(".gd") and not (self.source / relative).exists():
                path = self.source / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("extends RefCounted\n", encoding="utf-8")

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_sanitize_config_removes_only_development_activation(self) -> None:
        sanitized = sanitize_project_config(PROJECT_TEXT)
        self.assertNotIn("_mcp_game_helper", sanitized)
        self.assertNotIn("addons/godot_ai", sanitized)
        self.assertNotIn("_phase10b4_qa_bridge", sanitized)
        self.assertNotIn("--remote-debug", sanitized)
        self.assertNotIn("6107", sanitized)
        self.assertIn('[rendering]', sanitized)
        self.assertIn('renderer/rendering_method="mobile"', sanitized)
        self.assertIn(EXPECTED_MAIN_SCENE, sanitized)

    def test_prepare_preserves_production_and_main_scene(self) -> None:
        prepare_release_project(self.source, self.output)
        self.assertTrue((self.output / "core/domain.gd").is_file())
        self.assertTrue((self.output / "data/content.gd").is_file())
        self.assertTrue((self.output / "runtime/runtime.gd").is_file())
        self.assertTrue(
            (self.output / "application/settings/application_settings_repository.gd").is_file()
        )
        self.assertTrue(
            (self.output / "runtime/application/godot_window_mode_capability.gd").is_file()
        )
        self.assertTrue((self.output / "scenes/application/application_shell.tscn").is_file())
        self.assertTrue((self.output / "scenes/world/oldpine/oldpine_world_session.tscn").is_file())
        self.assertTrue((self.output / "scenes/runtime/oldpine_game_runtime_host.tscn").is_file())
        self.assertEqual([], validate_release_project(self.output))

    def test_mobile_presentation_survives_sanitizing_without_fakes(self) -> None:
        source_config = (REPOSITORY / "game/project.godot").read_text(encoding="utf-8")
        sanitized = sanitize_project_config(source_config)
        for entry in (
            "window/size/viewport_width=1152",
            "window/size/viewport_height=648",
            "window/size/viewport_width.mobile=960",
            "window/size/viewport_height.mobile=540",
            'window/stretch/mode="canvas_items"',
            'window/stretch/aspect="expand"',
            "window/handheld/orientation=4",
            "config/quit_on_go_back=false",
        ):
            self.assertIn(entry, sanitized)
        fake = self.source / "tests/presentation/fake_safe_area_capability.gd"
        fake.parent.mkdir(parents=True)
        fake.write_text("extends RefCounted\n", encoding="utf-8")
        prepare_release_project(self.source, self.output)
        for relative in REQUIRED_PATHS:
            self.assertTrue((self.output / relative).exists(), relative)
        self.assertFalse((self.output / "tests/presentation").exists())
        (self.output / "presentation/layout/safe_area_metrics.gd").unlink()
        self.assertTrue(any("safe_area_metrics.gd" in error for error in validate_release_project(self.output)))

    def test_touch_back_required_paths_are_production_only(self) -> None:
        prepare_release_project(self.source, self.output)
        for name in ("mobile_touch_adapter", "android_back_adapter", "application_exit_capability"):
            path = self.output / f"runtime/application/{name}.gd"
            self.assertTrue(path.is_file())
        (self.output / "runtime/application/mobile_touch_adapter.gd").unlink()
        self.assertTrue(any("mobile_touch_adapter.gd" in error for error in validate_release_project(self.output)))

    def test_prepare_removes_godot_ai_helper_plugin_and_addon(self) -> None:
        prepare_release_project(self.source, self.output)
        self.assertFalse((self.output / "addons/godot_ai").exists())
        self.assertFalse((self.output / "scenes/mcp_test.tscn").exists())
        project_text = (self.output / "project.godot").read_text(encoding="utf-8")
        self.assertNotIn("_mcp_game_helper", project_text)
        self.assertNotIn("editor_plugins", project_text)

    def test_prepare_removes_remote_debug_and_tests(self) -> None:
        prepare_release_project(self.source, self.output)
        self.assertFalse((self.output / "tests").exists())
        project_text = (self.output / "project.godot").read_text(encoding="utf-8")
        self.assertNotIn("--remote-debug", project_text)
        self.assertNotIn("6107", project_text)

    def test_source_directory_is_unchanged(self) -> None:
        before = source_tree_digest(self.source)
        prepare_release_project(self.source, self.output)
        self.assertEqual(before, source_tree_digest(self.source))
        self.assertTrue((self.source / "addons/godot_ai/runtime/game_helper.gd").is_file())
        self.assertTrue((self.source / "tests/run_tests.gd").is_file())

    def test_removes_qa_startup_and_rejects_local_paths(self) -> None:
        config = self.source / "project.godot"
        config.write_text(
            config.read_text(encoding="utf-8") + "\n[phase10b4]\nqa_startup_load=true\n",
            encoding="utf-8",
        )
        prepare_release_project(self.source, self.output)
        self.assertNotIn("qa_startup_load", (self.output / "project.godot").read_text(encoding="utf-8"))
        cache = self.output / ".godot/editor"
        cache.mkdir(parents=True)
        (cache / "project_metadata.cfg").write_text(
            '[editor_metadata]\nexecutable_path="Z:/tools/godot.exe"\n', encoding="utf-8"
        )
        self.assertEqual([], validate_release_project(self.output))
        (self.output / "runtime/bad.gd").write_text('const PATH = "Z:/machine/only"\n', encoding="utf-8")
        self.assertTrue(any("local absolute path" in error for error in validate_release_project(self.output)))

    def test_second_run_discards_stale_output(self) -> None:
        prepare_release_project(self.source, self.output)
        stale = self.output / "stale.txt"
        stale.write_text("must disappear", encoding="utf-8")
        prepare_release_project(self.source, self.output)
        self.assertFalse(stale.exists())

    def test_invalid_source_raises_without_output(self) -> None:
        missing = self.root / "missing"
        with self.assertRaises(ReleaseProjectError):
            prepare_release_project(missing, self.output)
        self.assertFalse(self.output.exists())

    def test_dangling_forbidden_reference_fails_closed(self) -> None:
        (self.source / "runtime/bad.gd").write_text(
            'const Helper = preload("res://addons/godot_ai/runtime/game_helper.gd")\n',
            encoding="utf-8",
        )
        with self.assertRaises(ReleaseProjectError) as context:
            prepare_release_project(self.source, self.output)
        self.assertIn("forbidden release reference", str(context.exception))

    def test_cli_invalid_source_returns_nonzero(self) -> None:
        script = REPOSITORY / "tools/build/prepare_release_project.py"
        result = subprocess.run(
            [sys.executable, str(script), "--source", str(self.root / "missing"), "--output", str(self.output)],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.assertNotEqual(0, result.returncode)


if __name__ == "__main__":
    unittest.main()
