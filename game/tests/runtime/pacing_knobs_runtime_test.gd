extends RefCounted

## The pacing knobs reach the running game (common/pacing.json: ×3 exp, ×3 recovery;
## the ×1.5 task time is cloud_quest_test's): the player's heal_up tick and the
## player's side of a blow carry them, NPCs keep ES2's pace. tests/core/
## pacing_knobs_test.gd covers the rules; suites pinning ES2's own numbers run with
## Es2Pacing.

const RecoveryTest := preload("res://tests/runtime/player_recovery_cadence_test.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")

var assertions: int = 0
var failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	await _player_heals_three_times_as_much(tree)
	await _player_side_of_a_blow_carries_the_gain(tree)
	return {"assertions": assertions, "failures": failures}


## damage.c heal_up(): con 30 / 3 = 10 gin and sen a tick in ES2, 30 with the knob.
func _player_heals_three_times_as_much(tree: SceneTree) -> void:
	var session: WorldSessionController = RecoveryTest.create_session(tree, RecoveryTest.RandomSequence.new())
	await tree.process_frame
	var state: CharacterState = session.player_runtime().state
	check(GameContent.catalog().pacing().player_recovery_gain == 3, "pacing.json: player_recovery_gain 3")
	for i: int in 2:
		check(Work.work(session).succeeded(), "打工 (30 gin and 30 sen)")
	var food: int = state.recovery.food
	check(state.essence.current == 40 and session.advance_player_recovery(12.0).opportunities == 1, "one heal_up tick after six pulses")
	check(state.essence.current == 70 and state.spirit.current == 70, "40 -> 70: con/3 x 3 (ES2: 50); got %d/%d" % [state.essence.current, state.spirit.current])
	check(state.recovery.food == food - 1, "food: one a tick, as ES2")
	session.free()
	await tree.process_frame


func _player_side_of_a_blow_carries_the_gain(tree: SceneTree) -> void:
	var session: WorldSessionController = RecoveryTest.create_session(tree, RecoveryTest.RandomSequence.new())
	await tree.process_frame
	session.handoff_to(&"snow.outdoor", &"snow.square", &"snow.square", &"snow.square.inn_entry")
	for frame: int in 4:
		await tree.process_frame
	var map: WorldMapController = session.active_map() as WorldMapController
	var player_gain: int = 0
	var npc_gains: Array[int] = []
	for binding: CombatSliceCharacterBinding in map.combat_lifecycle.build_participants():
		var facts: CombatProgressionFacts = CombatSliceProjectionBuilder.build_progression_facts(binding)
		if binding.is_user:
			player_gain = facts.experience_gain
		elif not npc_gains.has(facts.experience_gain):
			npc_gains.append(facts.experience_gain)
	check(player_gain == 3, "the player's side gets pacing.json's player_exp_gain 3: %d" % player_gain)
	check(npc_gains == [1], "every NPC's side keeps ES2's 1: %s" % [npc_gains])
	session.free()
	await tree.process_frame


func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append("pacing knobs: " + label)
