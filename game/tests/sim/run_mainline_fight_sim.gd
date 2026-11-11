extends SceneTree

## Opt-in report of the must-win fights (MainlineFightSim), for tuning their foes. Never an autoload;
## tests/ is not in a release:
## <godot> --headless --fixed-fps 60 --path game --script res://tests/sim/run_mainline_fight_sim.gd -- [only=<label part>] [n=<duels>] [exp=<a,b>] [tune=<json file>] [stance=attack|guard|evade] [low]
## `low`: each fight's first exp only (the main story alone).
## `tune`: MainlineFightSim.tune for this run (a path from the project's parent folder, e.g. build/x.json).
## Prints a table: the lineup, each exp's win rate and median rounds of the won duels, and the
## game's 战前预判 before the fight.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	TestFeel.turn_off()
	TestAway.turn_off()
	TestAlert.turn_off()
	TestDay.turn_off()
	TestDeath.turn_off()
	WorldSessionController.keep_map_scenes = true
	var only: String = ""
	var duels: int = 20
	var experiences: Array = []
	var tune: Dictionary = {}
	var stance: int = CombatStance.Value.ATTACK
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.substr(5)
		elif arg.begins_with("n="):
			duels = int(arg.substr(2))
		elif arg.begins_with("exp="):
			experiences = Array(arg.substr(4).split(",")).map(func(text: String) -> int: return int(text))
		elif arg.begins_with("stance="):
			stance = CombatStance.STORAGE.find_key(arg.substr(7))
		elif arg.begins_with("tune="):
			tune = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../" + arg.substr(5))))
	print("| 战斗 | 阵容（敌 / 帮手） | 经验 | 胜率 | 胜场回合中位 | 预判 | 预判比 | 备注 |")
	print("|---|---|---|---|---|---|---|---|")
	for entry: Dictionary in MainlineFightSim.FIGHTS:
		if not only.is_empty() and not String(entry["label"]).contains(only):
			continue
		var sim := MainlineFightSim.new(self)
		sim.tune = tune
		sim.stance = stance
		sim.verbose = OS.get_cmdline_user_args().has("verbose")
		var exps: Array = [entry["exps"][0]] if OS.get_cmdline_user_args().has("low") and experiences.is_empty() else experiences
		for result: MainlineFightSim.Result in await sim.run(entry, duels, 7, exps):
			var lineup: String = "%d/%d · %d/%d" % [result.enemies_in, result.expected_enemies, result.allies_in, result.expected_allies]
			print("| %s | %s | %d | %d%% | %s | %s | %.2f | %s |" % [result.label, lineup, result.experience, roundi(result.rate() * 100.0), "—" if result.median_rounds() < 0 else str(result.median_rounds()), MainlineFightSim.verdict_word(result.forecast), result.forecast_ratio, ("卡住 %d " % result.stuck if result.stuck > 0 else "") + ("不算 %d " % result.short_lineup if result.short_lineup > 0 else "") + "；".join(result.notes)])
	print("SIM DONE")
	quit()
