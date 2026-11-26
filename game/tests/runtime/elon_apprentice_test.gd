extends RefCounted

## 成长曲线 A (owner 2026-11-19, Q10; DECISIONS「成长曲线 A」): 瑷伦 takes a student from 30000 exp
## (pacing exp_gates `elon`; elon.c's 100000 kept in the data), and her accept test's lashes carry
## 35% of her inner force and spare the student, as her story lashes do (DECISIONS「考验三招」): a
## woman of 30000 exp who sat about half her 打坐 cap stands them six or seven times in ten; one
## who does not faints, never dies, keeps no wound. The confirm says so.

const Grown := preload("res://tests/support/grown_character.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const SAMPLES: int = 200
const PASS_LOW: float = 0.55
const PASS_HIGH: float = 0.80

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("祖师", CharacterState.GENDER_FEMALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	var manor: WorldMapController = MapPlaces.enter(session, &"latemoon.latemoon1", &"latemoon.latemoon1.dance_arrival")
	await _settle(tree)
	var elon: NpcRuntimeState = MapPlaces.npc_at(session, &"latemoon.room.eastroom.elon.1")
	var body: Node2D = null if elon == null else manor.runtime_body_for_character(elon.character_id)
	_check(elon != null and body != null and manor.place_player(elon.world_location().zone_id, body.global_position + Vector2(0, 56)), "TEST-ONLY: beside 瑷伦")
	await _settle(tree)
	if elon != null:
		_test_gate(manor, elon, session.player_runtime().state)
		_test_lashes(manor, elon, session.player_runtime().state)
	session.free()
	return {"assertions": _count, "failures": _failures.duplicate()}


## Below 30000 she sends the student to 芷萍; from 30000 she asks for the test.
func _test_gate(manor: WorldMapController, elon: NpcRuntimeState, state: CharacterState) -> void:
	var teacher: TeacherService = null
	for node: Node in manor.service_nodes:
		if node is TeacherService and (node as TeacherService).npc == elon:
			teacher = node
	_check(teacher != null, "瑷伦 takes students")
	if teacher == null:
		return
	Grown.grow(state, 29999, 50)
	var refused: NpcApprenticeship.Outcome = teacher.request_apprentice()
	_check(not teacher.offers_trial() and teacher.last_lines.any(func(line: String) -> bool: return line.contains("芷萍")), "29999 exp: 「去找芷萍」 (%s, %s)" % [NpcApprenticeship.Outcome.find_key(refused), teacher.last_lines])
	Grown.grow(state, 30000, 50)
	_check(teacher.offers_trial(), "30000 exp: she offers the test")
	var question: Array[String] = teacher.ui.trial_question()
	_check(question[0].contains("不伤性命") and not question[0].contains("伤得太重会死"), "the confirm: no wound, no death (%s)" % question[0])


## Her three lashes, struck SAMPLES times at a 30000-exp woman who sat half her cap, as take_trial()
## strikes them: how often all three are stood, and that nobody dies of them or keeps a wound.
func _test_lashes(manor: WorldMapController, elon: NpcRuntimeState, state: CharacterState) -> void:
	var rule: NpcTeaching.ApprenticeRule = elon.definition().teaching().apprentice
	var elon_force: int = elon.character_state.recovery.inner_force.current
	var passed: int = 0
	var dead: int = 0
	var wounded: int = 0
	for sample: int in SAMPLES:
		Grown.grow(state, 30000)
		elon.character_state.recovery.inner_force.current = elon_force
		var stood: bool = true
		for blow: int in rule.blows.size():
			if manor.attack_player_outside_fight(elon, rule.blow_modifiers()) == null or state.vitality.current < 0:
				stood = false
				dead += 1 if state.is_death_threshold_reached() else 0
				break
		wounded += 1 if state.vitality.effective < state.vitality.maximum or state.conditions.size() > 0 else 0
		passed += 1 if stood else 0
	var rate: float = float(passed) / SAMPLES
	_check(rate >= PASS_LOW and rate <= PASS_HIGH, "30000 exp, half the 打坐 cap (kee %d): stood %d of %d (%.0f%%), within %.0f–%.0f%%" % [state.vitality.maximum, passed, SAMPLES, rate * 100.0, PASS_LOW * 100.0, PASS_HIGH * 100.0])
	_check(dead == 0, "a lash not stood never kills (%d)" % dead)
	_check(wounded == 0, "nor leaves a wound or a condition (%d)" % wounded)
	Grown.grow(state, 30000, 100)
	var stood_all: bool = true
	for blow: int in rule.blows.size():
		if manor.attack_player_outside_fight(elon, rule.blow_modifiers()) == null or state.vitality.current < 0:
			stood_all = false
	_check(stood_all, "one who sat to the cap stands them")
	elon.character_state.recovery.inner_force.current = elon_force


func _settle(tree: SceneTree) -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
