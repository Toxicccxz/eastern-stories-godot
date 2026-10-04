extends RefCounted

## Internal power in Core: cmds/std/enforce.c and exert.c with the exert function
## files (d/force/recover.c, refresh.c, regenerate.c, daemon/class/swordsman/
## fonxanforce/heal.c), their checks, effects, lines, busy and the practice exert.c
## draws for; race/human.c's max_force/4 when a player logs in again.

var _assertions: int = 0
var _failures: Array[String] = []
var _bounds: Array[int] = []


func run_all() -> Dictionary:
	_test_data()
	_test_enforce()
	_test_exert_gates()
	_test_restore()
	_test_heal()
	_test_practice()
	_test_login_maxima()
	return {"assertions": _assertions, "failures": _failures}


func _check(ok: bool, label: String) -> void:
	_assertions += 1
	if not ok:
		_failures.append("internal power: " + label)


func _catalog() -> ContentCatalog:
	return GameContent.catalog()


## A 封山 student with force 10 / fonxanforce 10 enabled (query_skill("force") 15),
## max_force 50 and force 100, everything at 100.
func _student() -> CharacterState:
	var character := CharacterState.new()
	for resource: CharacterResourceState in [character.essence, character.vitality, character.spirit]:
		resource.maximum = 100
		resource.effective = 100
		resource.current = 100
	character.attributes.spirituality = 20
	character.attributes.constitution = 20
	character.skills.set_raw_level(&"force", 10)
	character.skills.set_raw_level(&"fonxanforce", 10)
	character.skills.map_skill(&"force", &"fonxanforce")
	character.recovery.inner_force.maximum = 50
	character.recovery.inner_force.current = 100
	return character


func _level(character: CharacterState) -> int:
	return character.skills.effective_level(&"force", 0)


## MudOS random(n) answering `values` in turn; every bound drawn is recorded.
func _random(values: Array[int]) -> Callable:
	_bounds.clear()
	return func(n: int) -> int:
		if n <= 0:
			return 0
		_bounds.append(n)
		return values.pop_front() if not values.is_empty() else n - 1


func _exert(character: CharacterState, function_id: StringName, fighting: bool = false, busy: ActionBusyState = null, values: Array[int] = []) -> ExertResult:
	var effects := SkillImprovementEffectRegistry.new()
	effects.register_legacy_defaults()
	return ExertService.exert(
		character, function_id, _catalog(), _level(character), fighting,
		busy if busy != null else ActionBusyState.new(), _random(values), effects,
	)


func _texts(result: ExertResult) -> Array[String]:
	return ColoredLine.texts(result.lines)


func _test_data() -> void:
	_check(_catalog().skill(&"fonxanforce").exert_functions == [&"heal"], "fonxanforce.c's exert_function_file() has heal.c")
	_check(_catalog().skill(&"force").exert_functions == [&"recover", &"refresh", &"regenerate"], "force.c's /d/force has recover, refresh and regenerate")
	var character := _student()
	_check(ExertService.offered(character, _catalog()) == [&"heal", &"recover", &"refresh", &"regenerate"], "with fonxanforce enabled: its heal and /d/force's three")
	character.skills.set_raw_level(&"celestial", 1)
	character.skills.map_skill(&"force", &"celestial")
	_check(ExertService.offered(character, _catalog()) == [&"recover", &"refresh", &"regenerate", &"powerup", &"powerfade"], "天邪神功: /d/force's three, then its powerup and powerfade: " + str(ExertService.offered(character, _catalog())))
	_check(ExertService.offered(CharacterState.new(), _catalog()).is_empty(), "nothing without an enabled force")
	var errors: Array[String] = []
	SkillDefinition.from_record(ContentRecordReader.new({
		"id": "x", "name": "X", "kind": "specialized", "type": "martial", "enable": ["force"], "legacy_source": "x.c",
		"exert": ["roar"],
	}, "s", errors))
	_check(errors.size() == 1 and errors[0].contains("roar"), "skills.json lists only exert functions the game has (celestial's roar.c is not one): " + str(errors))


func _test_enforce() -> void:
	var character := _student()
	_check(EnforceService.limit(_level(character)) == 7, "query_skill(force) 15 / 2")
	_check(ColoredLine.texts(EnforceService.enforce(CharacterState.new(), 1, 0)) == ["你必须先 enable 一种内功。"], "enforce.c needs an enabled force")
	_check(ColoredLine.texts(EnforceService.enforce(character, 8, _level(character))) == ["你只能用 none 表示不运内力，或数字表示每一击用几点内力。"] and character.attributes.force_factor == 0, "above the limit: refused, unchanged")
	_check(ColoredLine.texts(EnforceService.enforce(character, -1, _level(character))).size() == 1 and character.attributes.force_factor == 0, "a negative factor is refused")
	_check(ColoredLine.texts(EnforceService.enforce(character, 7, _level(character))) == ["Ok."] and character.attributes.force_factor == 7, "enforce 7: Ok.")
	_check(character.attributes.effective_strength() == character.attributes.strength + 7, "query_str() adds force_factor")
	_check(ColoredLine.texts(EnforceService.enforce(character, 0, _level(character))) == ["Ok."] and character.attributes.force_factor == 0, "enforce none")


func _test_exert_gates() -> void:
	var character := _student()
	var busy := ActionBusyState.new()
	busy.start_busy(1)
	var result: ExertResult = _exert(character, &"recover", false, busy)
	_check(result.failure == ExertResult.Failure.BUSY and _texts(result) == ["( 你上一个动作还没有完成，不能施用内功。)"], "exert.c: busy first")
	result = _exert(CharacterState.new(), &"recover")
	_check(result.failure == ExertResult.Failure.FORCE_NOT_ENABLED and _texts(result) == ["你请先用 enable 指令选择你要使用的内功。"], "exert.c without an enabled force")
	result = _exert(character, &"powerup")
	_check(result.failure == ExertResult.Failure.REFUSED and _texts(result) == ["你所学的内功中没有这种功能。"] and _bounds.is_empty(), "a function neither force has")


func _test_restore() -> void:
	var character := _student()
	var result: ExertResult = _exert(character, &"recover")
	_check(_texts(result) == ["你的气已经恢复到上限了。"] and character.recovery.inner_force.current == 100, "recover.c with kee full")
	character.vitality.current = 50
	character.recovery.inner_force.current = 19
	result = _exert(character, &"recover")
	_check(_texts(result) == ["你的内力不够。"], "recover.c under 20 force")
	character.recovery.inner_force.current = 30
	result = _exert(character, &"recover", false, null, [39])
	_check(result.succeeded() and _texts(result) == ["你深深吸了几口气，脸色看起来好多了。"], "recover.c's line, as 你: " + str(_texts(result)))
	_check(character.vitality.current == 65 and character.recovery.inner_force.current == 10, "20 force, kee + query_skill(force)/3 + 10 = 15")
	_check(_bounds == [40] and result.skill_improvement == null, "exert.c: random(force * 4) < force, not here")
	var busy := ActionBusyState.new()
	character.recovery.inner_force.current = 100
	character.vitality.current = 95
	result = _exert(character, &"recover", true, busy)
	_check(character.vitality.current == 100 and busy.busy_value == 1, "in a fight: kee up to its effective value, then busy 1")
	character.spirit.current = 90
	result = _exert(character, &"refresh")
	_check(_texts(result) == ["你微一凝神，缓缓地吸了口气，看起来有精神多了。"] and character.spirit.current == 100 and character.recovery.inner_force.current == 60, "refresh.c: sen")
	_check(_texts(_exert(character, &"refresh")) == ["你的神已经恢复到上限了。"], "refresh.c with sen full")
	character.essence.effective = 80
	character.essence.current = 10
	result = _exert(character, &"regenerate")
	_check(_texts(result) == ["你深深地吸了口气，手脚活动了几下，看起来有活力多了。"] and character.essence.current == 25, "regenerate.c: gin by 15")
	character.essence.current = 80
	_check(_texts(_exert(character, &"regenerate")) == ["你的精力已经恢复到上限了。"], "regenerate.c up to the effective value")


func _test_heal() -> void:
	var character := _student()
	character.attributes.force_factor = 5
	character.vitality.effective = 60
	character.vitality.current = 60
	var result: ExertResult = _exert(character, &"heal", true)
	_check(_texts(result) == ["战斗中运功疗伤？找死吗？"] and _bounds.is_empty(), "heal.c in a fight (no /d/force heal to fall back on)")
	character.recovery.inner_force.current = 99
	_check(_texts(_exert(character, &"heal")) == ["你的真气不够。"], "heal.c: force must top max_force by 50")
	character.recovery.inner_force.current = 100
	character.vitality.effective = 49
	_check(_texts(_exert(character, &"heal")) == ["你已经受伤过重，只怕一运真气便有生命危险！"], "heal.c: eff_kee under half")
	character.vitality.effective = 60
	character.vitality.current = 60
	result = _exert(character, &"heal", false, null, [119])
	_check(result.succeeded() and result.lines.size() == 1 and result.lines[0].text == "你全身放松，坐下来开始运功疗伤。" and result.lines[0].color == ColoredLine.HIW, "heal.c writes in HIW")
	_check(character.vitality.effective == 73 and character.vitality.current == 60, "receive_curing(kee, 10 + 15 / 5): eff_kee only")
	_check(character.recovery.inner_force.current == 50 and character.attributes.force_factor == 0, "50 force, force_factor 0")
	_check(_bounds == [120] and result.skill_improvement == null, "exert.c: random(120) < query_skill(force), not here")


func _test_practice() -> void:
	var character := _student()
	character.vitality.current = 50
	var result: ExertResult = _exert(character, &"recover", false, null, [9])
	_check(result.skill_improvement != null and result.skill_improvement.skill_id == &"force" and character.skills.learned_progress(&"force") == 1, "/d/force's function practises basic force")
	character.skills.set_learned_progress(&"force", 121)
	character.vitality.current = 50
	result = _exert(character, &"recover", false, null, [0])
	_check(character.skills.raw_level(&"force") == 11 and _texts(result) == ["你深深吸了几口气，脸色看起来好多了。", "你的「基本内功」进步了！"] and result.lines[1].color == ColoredLine.HIC, "a level from exert, improve_skill()'s HIC line: " + str(_texts(result)))
	character.recovery.inner_force.current = 100
	character.vitality.effective = 60
	result = _exert(character, &"heal", false, null, [0])
	_check(result.skill_improvement != null and result.skill_improvement.skill_id == &"fonxanforce" and character.skills.learned_progress(&"fonxanforce") == 1, "heal.c practises fonxanforce")
	character.skills.set_learned_progress(&"fonxanforce", 200)
	character.recovery.inner_force.current = 100
	result = _exert(character, &"heal", false, null, [0])
	_check(character.skills.raw_level(&"fonxanforce") == 10 and character.skills.learned_progress(&"fonxanforce") == 201 and result.lines.size() == 1, "weak mode: a player gains progress, never a level")
	character.skills.set_raw_level(&"force", 0)
	character.vitality.current = 50
	result = _exert(character, &"recover")
	_check(result.succeeded() and _bounds.is_empty() and result.skill_improvement == null, "random(0) draws nothing (MudOS)")


func _test_login_maxima() -> void:
	var character := _student()
	character.recovery.atman.maximum = 40
	character.recovery.mana.maximum = 80
	CharacterDerivedValues.refresh_human_player_maxima(character, 14)
	_check(character.vitality.maximum == 112 and character.essence.maximum == 110 and character.spirit.maximum == 120, "race/human.c: 100 + max_force 50, max_atman 40 and max_mana 80 / 4")
	_check(character.vitality.effective == 100 and character.vitality.current == 100, "eff_kee and kee stay")
	CharacterDerivedValues.refresh_human_player_maxima(character, 25)
	_check(character.vitality.maximum == 232 and character.essence.maximum == 230 and character.spirit.maximum == 120, "by age: kee 220, gin 220 at 25")
	character.recovery.inner_force.maximum = 0
	character.vitality.effective = 232
	character.vitality.current = 232
	CharacterDerivedValues.refresh_human_player_maxima(character, 14)
	_check(character.vitality.maximum == 100 and character.vitality.effective == 100 and character.vitality.current == 100, "a lower maximum clamps eff and current (DECISIONS)")
