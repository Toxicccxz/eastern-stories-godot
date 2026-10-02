extends SceneTree

## Opt-in QA run of the game with the Phase 10B4 bridge (F6 saves, F7 corrupts the
## development save, PHASE10B4_QA evidence lines). Never an autoload:
## <godot> --path game --script res://tests/runtime/run_with_qa_bridge.gd [-- --phase10b4-startup-load]


func _initialize() -> void:
	var bridge: Node = (load("res://tests/runtime/phase10b4_qa_bridge.gd") as GDScript).new()
	bridge.name = "_phase10b4_qa_bridge"
	root.add_child(bridge)
	change_scene_to_file.call_deferred(ProjectSettings.get_setting("application/run/main_scene"))
