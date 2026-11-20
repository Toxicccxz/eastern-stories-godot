extends SceneTree

## Dev only, opt-in (never an autoload; tests/ is not in a release): the game started as usual,
## its main menu driven to a New Game, and that New Game set up at the start of a chapter of the
## main story (ChapterStart) — then the normal game, in the development save slot:
## <godot> --path game --script res://tests/dev/chapter_start/run_chapter_start.gd -- <chapter> [words]
## <chapter>: prologue, 1 … 10, finale, after (终章之后). Words: fist (柳家拳 bare-handed; default 封山剑法 with a
## sword), chase (第三章 by the chase; default the rescue), sneak (第六章 潜入; default 借兵), ronin (第七章 站浪人;
## default 大秦人), pulled (第八章 the sword drawn), side=expose|deal|uncle (第九章), who=self|uncle|xiao (第十章: who
## drew 旋芒), line=<line> [stage=<stage>] (a faction line at a step: ChapterStart.LINES), explore (the exploring
## player's exp), male. A state no player reaches (旋芒 in the 皇叔's hands when he never came to court, drawn yourself
## under six bells, a faction step before its chapter) is refused with the reason. The same as the F6 scene res://tests/dev/chapter_start.tscn.

const Runner := preload("res://tests/dev/chapter_start/chapter_start_runner.gd")


func _initialize() -> void:
	var spec: ChapterStart.Spec = Runner.parse(OS.get_cmdline_user_args())
	if spec == null:
		printerr("refused: " + Runner.why_not(OS.get_cmdline_user_args()))
		printerr("usage: --script res://tests/dev/chapter_start/run_chapter_start.gd -- <prologue|1..10|finale|after> [fist] [chase] [sneak] [ronin] [pulled] [side=expose|deal|uncle] [who=self|uncle|xiao] [line=<line> stage=<stage>] [explore] [male]")
		quit(2)
		return
	var runner: Node = Runner.new()
	runner.name = "_dev_chapter_start"
	runner.spec = spec
	root.add_child(runner)
	change_scene_to_file.call_deferred(ProjectSettings.get_setting("application/run/main_scene"))
