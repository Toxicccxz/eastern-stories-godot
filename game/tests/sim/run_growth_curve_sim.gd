extends SceneTree

## Opt-in report of the growth curve (GrowthCurveSim), for the plan that sets 历练, rest and the
## regions' recommended_exp. Never an autoload; tests/ is not in a release:
## <godot> --headless --fixed-fps 60 --path game --script res://tests/sim/run_growth_curve_sim.gd -- [start=main|exploring|<exp>] [seed=<n>] [force=<percent of the bottleneck>] [self] [quest=<percent>|<chapter>:<percent>[,...]] [extra=<chapter>:<percent>[,...]] [recommended=<region>:<exp>[,...]] [rest=<scale>] [path]
## `start`: where the first two hours leave the player (StoryArrival's MAIN_START 1000 or
## EXPLORING_START 2500, or a number).
## `force`: 打坐 after each chapter to this percent of exercise.c's bottleneck (default 100;
## grown_character.gd, the must-win fights' character, uses 50).
## `self`: 基本内功 past 柳淳风's level by 自学.
## `quest`: every main-story quest (StoryArrival's ROUTE) at this percent of the stage unit
## (progression.json quest_percent; today 100), or chapter by chapter (main.chapter2:330,...).
## `extra`: shares of the stage unit paid after a chapter's own rewards (main.chapter6:600 is a
## faction line finished in chapter 6 worth 600%).
## `recommended`: regions' recommended_exp for this run (lancheng:40000).
## `rest`: pacing rest_world_scale for this run (the report's real time with the rest).
## `path`: the exp path only, no training (fast).
## Prints one row per chapter on arriving there: exp, potential, the seven skills' raw levels,
## max_force and its bottleneck, 气 / 精 / 神, the steps and stops of training so far, the world
## minutes waited and the real minutes with 歇到回满 and standing it out.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	TestFeel.turn_off()
	TestAway.turn_off()
	TestAlert.turn_off()
	TestDay.turn_off()
	TestDeath.turn_off()
	var start: int = GrowthCurveSim.Arrival.MAIN_START
	var seed: int = 1
	var sim := GrowthCurveSim.new(self)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("start="):
			var value: String = arg.substr(6)
			start = GrowthCurveSim.Arrival.MAIN_START if value == "main" else GrowthCurveSim.Arrival.EXPLORING_START if value == "exploring" else int(value)
		elif arg.begins_with("seed="):
			seed = int(arg.substr(5))
		elif arg.begins_with("force="):
			sim.force_percent = int(arg.substr(6))
		elif arg == "self":
			sim.self_learn = true
		elif arg == "path":
			sim.train_between = false
		elif arg.begins_with("quest="):
			for pair: String in arg.substr(6).split(","):
				if pair.contains(":"):
					sim.quest_percents[StringName(pair.get_slice(":", 0))] = int(pair.get_slice(":", 1))
				else:
					for chapter: Array in GrowthCurveSim.Arrival.ROUTE:
						sim.quest_percents[StringName(chapter[0])] = int(pair)
		elif arg.begins_with("extra="):
			for pair: String in arg.substr(6).split(","):
				var chapter_id := StringName(pair.get_slice(":", 0))
				if not sim.extra.has(chapter_id):
					sim.extra[chapter_id] = []
				sim.extra[chapter_id].append(int(pair.get_slice(":", 1)))
		elif arg.begins_with("recommended="):
			for pair: String in arg.substr(12).split(","):
				sim.recommended[StringName(pair.get_slice(":", 0))] = int(pair.get_slice(":", 1))
		elif arg.begins_with("rest="):
			sim.rest_scale_override = float(arg.substr(5))
	if not await sim.start(seed):
		print("growth sim: the session did not start")
		quit(1)
		return
	if sim.train_between:
		await sim.join(GrowthCurveSim.MASTER)
		print("拜师: %s" % sim.joined)
	await sim.journey(start)
	print(sim.table())
	await sim.finish()
	print("GROWTH SIM DONE")
	quit()

