extends SceneTree

## Opt-in development run for playtesting what needs max_force 50 (封山剑法,
## 倒乱七星步法) without exercising for hours: the game starts as usual, and each
## journey begun or continued gets max_force raised once to the given value (default
## 49) when it is lower, with force at twice that, so the next 打坐 passes the
## threshold (if 基本内功 allows: max_force stops at (基本内功 + 有效内功 / 5) * 10).
## The log says so. A save made afterwards keeps the values. Never an autoload;
## tests/ is not in a release:
## <godot> --path game --script res://tests/runtime/run_with_max_force.gd [-- <max_force>]

const DEFAULT_MAX_FORCE: int = 49


class Booster extends Node:
	var target: int = DEFAULT_MAX_FORCE
	var _done: Array[int] = []

	func _process(_delta: float) -> void:
		var shell := get_tree().current_scene as ApplicationShellController
		if shell == null or shell.runtime_host() == null:
			return
		var session: OldPineWorldSessionController = shell.runtime_host().current_session()
		if session == null or not session.is_initialized() or session.player_runtime() == null:
			return
		if _done.has(session.get_instance_id()):
			return
		_done.append(session.get_instance_id())
		var force: CharacterInternalResourceState = session.player_runtime().state.recovery.inner_force
		if force.maximum >= target:
			return
		force.maximum = target
		force.current = maxi(force.current, target * 2)
		session.shared_ui().append_log_lines(["（开发脚本）最大内力设为 %d，内力 %d。" % [force.maximum, force.current]])


func _initialize() -> void:
	var booster := Booster.new()
	booster.name = "_dev_max_force"
	booster.process_mode = Node.PROCESS_MODE_ALWAYS
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty() and args[0].is_valid_int():
		booster.target = int(args[0])
	root.add_child(booster)
	change_scene_to_file.call_deferred(ProjectSettings.get_setting("application/run/main_scene"))
