extends SceneTree

## Opt-in report of the A2 pacing simulation (ExpPacingSim), for tuning
## common/progression.json and pacing.json's progression knobs. Never an autoload;
## tests/ is not in a release:
## <godot> --headless --path game --script res://tests/sim/run_exp_pacing_sim.gd -- [seeds] [classic]
## `classic`: the progression knobs at ES2's (no 历练 rewards, no catch-up, cap 100, 打坐 ×1).
## Prints the route's timeline per seed, then 打坐 to max_force 50 (con 30 and 20).


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seeds: int = int(args[0]) if not args.is_empty() and args[0].is_valid_int() else 1
	var previous: PacingDefinition = GameContent.catalog().pacing()
	if args.has("classic"):
		GameContent.catalog().set_pacing(previous.copy().with_progression(false, 0, false, 1))
	var route: Array = ExpPacingSim.load_route("res://tests/fixtures/exp_pacing_route.json")["route"]
	var times: Array[float] = []
	for seed: int in seeds:
		var sim := ExpPacingSim.new(self)
		await sim.start(seed)
		await sim.run(route)
		print("=== route, seed %d ===\n%s" % [seed, sim.report()])
		times.append(sim.reached.get(1001, -1.0))
		await sim.finish()
	print("exp 1001 per seed (min): ", times.map(func(t: float) -> String: return "never" if t < 0 else "%.1f" % (t / 60.0)))
	for con: int in [30, 20]:
		var sim := ExpPacingSim.new(self)
		await sim.start(0)
		ExpPacingSim.prepare_exercise(sim.state(), con)
		var took: float = sim.exercise_to(50, 6.0 * 3600.0)
		print("打坐 to max_force 50 at con %d: %.1f min (max_force %d)" % [con, took / 60.0, sim.state().recovery.inner_force.maximum])
		await sim.finish()
	GameContent.catalog().set_pacing(previous)
	quit()
