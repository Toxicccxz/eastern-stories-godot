extends RefCounted

## The player's 天邪神功 (水烟阁 C): daemon/class/fighter/celestial/powerup.c,
## powerfade.c (its faint in a fight) and roar.c through exert.c (ExertService), the
## practice exert.c gives in weak mode, and the bellicosity that boils over
## (feature/attack.c init(), cmds/std/look.c, combatd.c start_berserk(): Berserk) with
## its one-time warning. Every draw is scripted.

var _assertions: int = 0
var _failures: Array[String] = []
var _bounds: Array[int] = []


func run_all() -> Dictionary:
	_test_offered()
	_test_powerup()
	_test_powerfade()
	_test_powerfade_faint()
	_test_roar()
	_test_roar_refusals()
	_test_weak_practice()
	_test_berserk_rolls()
	_test_berserk_threshold()
	return {"assertions": _assertions, "failures": _failures}


func _check(ok: bool, label: String) -> void:
	_assertions += 1
	if not ok:
		_failures.append("celestial exert: " + label)


func _catalog() -> ContentCatalog:
	return GameContent.catalog()


## A 天邪派 student: force 40 and celestial 40 enabled (query_skill("force") 60),
## force 500, cps 10, bellicosity 300, gin/kee/sen 200.
func _fighter() -> CharacterState:
	var character := CharacterState.new()
	for resource: CharacterResourceState in [character.essence, character.vitality, character.spirit]:
		resource.maximum = 200
		resource.effective = 200
		resource.current = 200
	character.attributes.spirituality = 20
	character.attributes.composure = 10
	character.attributes.bellicosity = 300
	character.skills.set_raw_level(&"force", 40)
	character.skills.set_raw_level(&"celestial", 40)
	character.skills.map_skill(&"force", &"celestial")
	character.recovery.inner_force.maximum = 500
	character.recovery.inner_force.current = 500
	return character


func _level(character: CharacterState) -> int:
	return character.skills.effective_level(&"force", 0)


## MudOS random(n) answering `values` in turn (n - 1 once they run out); every
## bound drawn is recorded.
func _random(values: Array[int]) -> Callable:
	_bounds.clear()
	return func(n: int) -> int:
		if n <= 0:
			return 0
		_bounds.append(n)
		return values.pop_front() if not values.is_empty() else n - 1


func _exert(
	character: CharacterState, function_id: StringName, fighting: bool = false, busy: ActionBusyState = null,
	values: Array[int] = [], room: Array[SpecialSide] = [],
) -> ExertResult:
	var effects := SkillImprovementEffectRegistry.new()
	effects.register_legacy_defaults()
	return ExertService.exert(
		character, function_id, _catalog(), _level(character), fighting,
		busy if busy != null else ActionBusyState.new(), _random(values), effects, &"player", room,
	)


## Someone in the room: cps, max_force and force as roar.c reads them.
func _other(id: StringName, composure: int, max_force: int, force: int, living: bool = true) -> SpecialSide:
	var state := CharacterState.new()
	for resource: CharacterResourceState in [state.essence, state.vitality, state.spirit]:
		resource.maximum = 300
		resource.effective = 300
		resource.current = 300
	state.attributes.composure = composure
	state.recovery.inner_force.maximum = max_force
	state.recovery.inner_force.current = force
	var side := SpecialSide.new(id, state, ActionBusyState.new(), CombatRelationshipState.new(id))
	side.living = living
	return side


func _texts(result: ExertResult) -> Array[String]:
	return ColoredLine.texts(result.lines)


func _test_offered() -> void:
	var character := _fighter()
	_check(_level(character) == 60, "query_skill(force) = 40 / 2 + 40")
	_check(ExertService.offered(character, _catalog()) == [&"recover", &"refresh", &"regenerate", &"powerup", &"powerfade"], "outside a fight no 天邪虎啸 (roar.c refuses there)")
	_check(ExertService.offered(character, _catalog(), true).has(&"roar"), "in a fight 天邪虎啸")
	_check(ExertFunctions.LABELS[&"roar"] == "天邪虎啸", "doc/skill/celestial: 天邪虎啸")


## powerup.c: 100 force, bellicosity + 100 + skill / 2, attack/dodge + skill / 3 for
## skill seconds; busy 3 in a fight.
func _test_powerup() -> void:
	var character := _fighter()
	var busy := ActionBusyState.new()
	var result: ExertResult = _exert(character, &"powerup", true, busy, [119])
	_check(result.succeeded() and _texts(result)[0] == "你微一凝神，运起天邪神功，全身骨节发出一阵爆豆般的声响！", "powerup's line, as 你: " + str(_texts(result)))
	_check(character.recovery.inner_force.current == 400 and character.attributes.bellicosity == 300 + 100 + 30, "100 force; bellicosity + 100 + 60 / 2")
	_check(character.timed_applies.has(&"powerup") and busy.is_busy(), "the applies run; busy in a fight")
	result = _exert(character, &"powerup", false, null, [119])
	_check(not result.succeeded() and _texts(result) == ["你已经在运功中了。"], "not twice")


## powerfade.c outside a fight: 100 force and 100 sen, bellicosity - 100 - skill / 3,
## never a faint draw.
func _test_powerfade() -> void:
	var character := _fighter()
	var result: ExertResult = _exert(character, &"powerfade", false, null, [119])
	_check(result.succeeded() and not result.fainted and character.attributes.bellicosity == 300 - 100 - 20, "bellicosity - 100 - 60 / 3")
	_check(character.recovery.inner_force.current == 400 and character.spirit.current == 100, "100 force and 100 sen")
	_check(_bounds == [120], "outside a fight only exert.c's practice draw: " + str(_bounds))
	character.attributes.bellicosity = 0
	result = _exert(character, &"powerfade")
	_check(_texts(result) == ["你现在毫无杀气。"], "no bellicosity: refused")
	character.attributes.bellicosity = 300
	character.timed_applies.start(&"powerup", {&"attack": 1}, 1000)
	result = _exert(character, &"powerfade")
	_check(_texts(result) == ["你已经在运功中了。"], "not while powerup runs")


## powerfade.c in a fight: random(skill) < cps * 3 knocks the user out.
func _test_powerfade_faint() -> void:
	var character := _fighter()
	var result: ExertResult = _exert(character, &"powerfade", true, null, [29, 119])
	_check(result.succeeded() and result.fainted and character.is_unconscious_threshold_reached(), "random(60) = 29 < cps 10 * 3: out cold")
	_check(_bounds == [60, 120], "the faint draws random(skill) before exert.c's practice: " + str(_bounds))
	character = _fighter()
	result = _exert(character, &"powerfade", true, null, [30, 119])
	_check(result.succeeded() and not result.fainted and not character.is_unconscious_threshold_reached(), "random(60) = 30 is not below 30: stays up")
	_check(PowerfadeExertFunction.faint_chance(60, 10) == 0.5 and PowerfadeExertFunction.faint_chance(20, 10) == 1.0, "the chance: cps * 3 / skill, at most 1")
	_check(PowerfadeExertFunction.faint_chance(0, 10) == 1.0 and PowerfadeExertFunction.faint_chance(60, 0) == 0.0, "random(0) is 0: always below cps * 3 > 0; cps 0 never")
	_check(PowerfadeExertFunction.would_run(_fighter()) and not PowerfadeExertFunction.would_run(CharacterState.new()), "would_run(): its refusals")


## roar.c: 150 force, 10 kee, busy 5; each living other withstands it when
## skill / 2 + random(skill / 2) < cps * 2, else loses skill - max_force / 10 sen,
## a wound of half when its force < skill * 2, and kill_ob()s the user unless it
## already kills them.
func _test_roar() -> void:
	var character := _fighter()
	var busy := ActionBusyState.new()
	var weak := _other(&"weak", 5, 100, 10)
	var strong := _other(&"strong", 40, 100, 1000)
	var asleep := _other(&"asleep", 0, 0, 0, false)
	var killer := _other(&"killer", 0, 900, 1000)
	killer.relationship.mark_lethal_target(&"player")
	var room: Array[SpecialSide] = [weak, asleep, strong, killer]
	var result: ExertResult = _exert(character, &"roar", true, busy, [0, 29, 0, 119], room)
	_check(result.succeeded() and _texts(result)[0] == "你深深地吸一口气，开始发出有如猛虎般的啸声！", "roar's line: " + str(_texts(result)))
	_check(character.recovery.inner_force.current == 350 and character.vitality.current == 190 and busy.is_busy(), "150 force, 10 kee, busy")
	_check(_bounds == [30, 30, 30, 120], "one random(skill / 2) for each living other, then exert.c's practice: " + str(_bounds))
	_check(weak.state.spirit.current == 300 - 50 and weak.state.spirit.effective == 300 - 25, "30 + 0 not below 10: 60 - 100 / 10 = 50 sen, force 10 < 120: wound 25")
	_check(strong.state.spirit.current == 300, "30 + 29 < cps 40 * 2: withstood, untouched")
	_check(asleep.state.spirit.current == 300, "one not living() is passed over")
	_check(killer.state.spirit.current == 300, "60 - 900 / 10 = -30: no damage")
	_check(result.killers == [&"weak"], "kill_ob(): the weak one; not who withstood, nor one already killing: " + str(result.killers))


func _test_roar_refusals() -> void:
	var character := _fighter()
	var result: ExertResult = _exert(character, &"roar", false)
	_check(_texts(result) == ["天邪虎啸只能在战斗中使用。"], "only in a fight")
	character.recovery.inner_force.current = 149
	result = _exert(character, &"roar", true)
	_check(_texts(result) == ["你的内力不够。"] and character.vitality.current == 200, "149 force: refused, nothing spent")
	_check(not RoarExertFunction.would_run(character, true) and not RoarExertFunction.would_run(_fighter(), false) and RoarExertFunction.would_run(_fighter(), true), "would_run()")


## exert.c: random(120) < query_skill("force") improves the enabled force in weak mode:
## a player gains progress, never a level (天邪神功只能用学的).
func _test_weak_practice() -> void:
	var character := _fighter()
	character.skills.set_learned_progress(&"celestial", 2000)
	var result: ExertResult = _exert(character, &"powerup", false, null, [59])
	_check(result.skill_improvement != null and character.skills.learned_progress(&"celestial") == 2001, "random(120) = 59 < 60: one point of progress")
	_check(character.skills.raw_level(&"celestial") == 40, "no level for a player in weak mode, however far over (41 * 41)")
	character = _fighter()
	result = _exert(character, &"powerup", false, null, [60])
	_check(result.skill_improvement == null and character.skills.learned_progress(&"celestial") == 0, "random(120) = 60: no practice")


## attack.c init(): random(bellicosity / 40) > cps; look.c: random(bellicosity / 10) >
## per; start_berserk(): force > (random(b) + b) / 2 calms, b > score kills, else fights.
func _test_berserk_rolls() -> void:
	var state := _fighter()
	state.attributes.bellicosity = 1000
	state.recovery.inner_force.current = 100
	var source := ScriptedWorldInteractionRandomSource.new([11])
	_check(Berserk.init_roll(state, source) and source.requested_bounds() == [25], "random(1000 / 40) = 11 > cps 10")
	source = ScriptedWorldInteractionRandomSource.new([10])
	_check(not Berserk.init_roll(state, source), "10 is not above cps 10")
	source = ScriptedWorldInteractionRandomSource.new([31])
	_check(Berserk.look_roll(state, 30, source) and source.requested_bounds() == [100], "look.c: random(1000 / 10) = 31 > per 30")
	source = ScriptedWorldInteractionRandomSource.new([0])
	_check(Berserk.start(state, 999, source) == Berserk.Outcome.KILL and source.requested_bounds() == [1000], "force 100 not above (0 + 1000) / 2; 1000 over score 999: kill")
	source = ScriptedWorldInteractionRandomSource.new([0])
	_check(Berserk.start(state, 1000, source) == Berserk.Outcome.FIGHT, "not above score 1000: only a fight")
	state.recovery.inner_force.current = 501
	source = ScriptedWorldInteractionRandomSource.new([0])
	_check(Berserk.start(state, 0, source) == Berserk.Outcome.STARE, "force 501 above 500: he only stares")
	var calm := CharacterState.new()
	source = ScriptedWorldInteractionRandomSource.new()
	_check(not Berserk.init_roll(calm, source) and source.call_count() == 0, "no bellicosity: random(0) draws nothing")


## The one-time warning: from 40 * (cps + 2) on, random(b / 40) can exceed cps.
func _test_berserk_threshold() -> void:
	_check(Berserk.threshold(10) == 480, "cps 10: 40 * 12")
	var state := _fighter()
	state.attributes.bellicosity = 479
	_check(not Berserk.can_lose_control(state) and not Berserk.take_warning(state), "479: random(11) is at most 10, never above cps 10")
	state.attributes.bellicosity = 480
	var source := ScriptedWorldInteractionRandomSource.new([11])
	_check(Berserk.can_lose_control(state) and Berserk.init_roll(state, source), "480: random(12) can be 11")
	_check(Berserk.take_warning(state) and state.progression.berserk_warned, "told once")
	_check(not Berserk.take_warning(state), "not twice")
	state.attributes.bellicosity = 0
	state.attributes.bellicosity = 900
	_check(not Berserk.take_warning(state), "nor after it fell and rose again")
