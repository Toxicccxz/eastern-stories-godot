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
        (self.source / "scenes/world/oldpine/oldpine_world_session.tscn").write_text("[gd_scene]\n", encoding="utf-8")
        (self.source / "scenes/runtime/oldpine_game_runtime_host.tscn").write_text("[gd_scene]\n", encoding="utf-8")
        (self.source / "scenes/mcp_test.tscn").write_text("[gd_scene]\n", encoding="utf-8")
        (self.source / "tests/run_tests.gd").write_text("extends SceneTree\n", encoding="utf-8")
        (self.source / "addons/godot_ai/runtime/game_helper.gd").write_text("extends Node\n", encoding="utf-8")
        (self.source / "godot-ai-LICENSE.txt").write_text("development license\n", encoding="utf-8")
        (self.source / ".godot/generated.txt").write_text("generated\n", encoding="utf-8")

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
        self.assertTrue((self.output / "scenes/world/oldpine/oldpine_world_session.tscn").is_file())
        self.assertTrue((self.output / "scenes/runtime/oldpine_game_runtime_host.tscn").is_file())
        self.assertEqual([], validate_release_project(self.output))

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
