extends RefCounted

## A2 经验节奏's regression check (ExpPacingSim, one seed): with the game's knobs the route
## reaches 朱鸿雪's 1001 combat_exp within the agreed one to two hours (some slack for the
## route's guesses) and 打坐 to 50 at con 30 takes 20-25 minutes or so; with the classic
## knobs (Es2Pacing) the route gives no 历练 at all and 打坐 is ES2's slow one.

const ROUTE: String = "res://tests/fixtures/exp_pacing_route.json"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var route: Array = ExpPacingSim.load_route(ROUTE)["route"]
	var sim := ExpPacingSim.new(tree)
	_check(await sim.start(0), "a New Game")
	await sim.run(route)
	var report: String = sim.report()
	var minutes: float = sim.reached.get(1001, -60.0) / 60.0
	_check(minutes >= 60.0 and minutes <= 130.0, "exp 1001 at %.1f min (60-130):\n%s" % [minutes, report])
	# The route's late bounties may beat its player, who learns less than a real one: no
	# death before 1001.
	_check(sim.death_times.all(func(t: float) -> bool: return sim.reached.has(1001) and t > sim.reached[1001]), "no death before 1001: %s" % [sim.death_notes])
	# An outlaw that kills the player ends the route's bounties: the fights are not seeded.
	_check(sim.bounties_done >= 2 or sim.deaths > 0, "bounties paid on the route: %d
%s" % [sim.bounties_done, report])
	_check(sim.rewards.size() >= 8, "the route's 历练: %d" % sim.rewards.size())
	_check(sim.first_special.has(&"liuh-ken") and sim.first_special[&"liuh-ken"] < 10.0 * 60.0, "柳家拳 within ten minutes of New Game")
	await sim.finish()
	var exercise := ExpPacingSim.new(tree)
	await exercise.start(0)
	ExpPacingSim.prepare_exercise(exercise.state(), 30)
	var took: float = exercise.exercise_to(50, 3.0 * 3600.0) / 60.0
	_check(took >= 18.0 and took <= 28.0, "打坐 to 50 at con 30: %.1f min (18-28)" % took)
	await exercise.finish()

	var previous: PacingDefinition = Es2Pacing.use()
	var classic := ExpPacingSim.new(tree)
	await classic.start(0)
	await classic.run(route.slice(0, 12))
	_check(classic.rewards.is_empty() and classic.state().milestones.is_empty(), "classic: no 历练: %s" % [classic.rewards])
	await classic.finish()
	var slow := ExpPacingSim.new(tree)
	await slow.start(0)
	ExpPacingSim.prepare_exercise(slow.state(), 30)
	var es2_took: float = slow.exercise_to(50, 4.0 * 3600.0) / 60.0
	_check(es2_took > 90.0, "classic 打坐 to 50 at con 30: %.1f min (ES2's pace, over 90)" % es2_took)
	await slow.finish()
	Es2Pacing.restore(previous)
	return {"assertions": _count, "failures": _failures.duplicate()}


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
