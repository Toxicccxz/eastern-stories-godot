extends SceneTree

## Opt-in development run for playtesting what needs a seasoned character (the 迷阵 and
## 绝尘子 want 100000 combat_exp, 绝尘子 spi 24 too) without fighting for days: the game
## starts as usual, and each journey begun or continued gets combat_exp raised once to the
## given value (default 100000) and spi to the given one (default 24) when they are lower.
## The log says so. A save made afterwards keeps the values. Never an autoload; tests/ is
## not in a release:
## <godot> --path game --script res://tests/runtime/run_with_experience.gd [-- <combat_exp> [<spi>]]

const DEFAULT_COMBAT_EXP: int = 100000
const DEFAULT_SPI: int = 24


class Booster extends Node:
	var combat_exp: int = DEFAULT_COMBAT_EXP
	var spi: int = DEFAULT_SPI
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
		var state: CharacterState = session.player_runtime().state
		var raised: bool = false
		if state.progression.combat_experience < combat_exp:
			state.progression.combat_experience = combat_exp
			raised = true
		if state.attributes.spirituality < spi:
			state.attributes.spirituality = spi
			raised = true
		if raised:
			session.shared_ui().append_log_lines(["（开发脚本）实战经验设为 %d，灵性 %d。" % [state.progression.combat_experience, state.attributes.spirituality]])


func _initialize() -> void:
	var booster := Booster.new()
	booster.name = "_dev_experience"
	booster.process_mode = Node.PROCESS_MODE_ALWAYS
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		booster.combat_exp = int(args[0])
	if args.size() > 1 and args[1].is_valid_int():
		booster.spi = int(args[1])
	root.add_child(booster)
	change_scene_to_file.call_deferred(ProjectSettings.get_setting("application/run/main_scene"))
