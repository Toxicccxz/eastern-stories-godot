extends RefCounted

## The card after a 切磋 (SparSummaryPanel, CombatSparSummary; owner 2026-11-22): the summary
## reads the outcome from who landed the blow and the gains from the player's state before and
## after; a real spar in the 武馆 leaves one, the card shows it once the fight's screen is gone,
## holds world time while up and goes with B / Esc or 继续.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const TRAINEE: StringName = &"snow.school2.trainee.1.character"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_build()
	await _test_real_spar(tree)
	return {"assertions": _count, "failures": _failures}


func _test_build() -> void:
	var state := CharacterState.new()
	state.skills.set_raw_level(&"unarmed", 10)
	state.skills.set_raw_level(&"parry", 5)
	state.skills.set_raw_level(&"dodge", 3)
	state.progression.combat_experience = 100
	state.progression.potential = 40
	var before: Dictionary = CombatSparSummary.snapshot(state)
	state.skills.set_raw_level(&"unarmed", 11)
	state.skills.set_learned_progress(&"parry", 7)
	state.progression.combat_experience = 112
	state.progression.potential = 43
	var opponents: Array[StringName] = [&"npc.a"]
	var won := CombatSparSummary.build(&"e1", &"me", &"me", opponents, 4, before, state)
	_check(won.outcome == CombatSparSummary.Outcome.WON and won.rounds == 4 and won.opponent_ids == opponents, "the player landed it: won")
	_check(won.combat_experience_gained == 12 and won.potential_gained == 3, "exp and potential gained: %d %d" % [won.combat_experience_gained, won.potential_gained])
	_check(won.skills.size() == 2 and won.skills[0].skill_id == &"unarmed" and won.skills[0].levelled() and won.skills[0].level_before == 10 and won.skills[0].level_after == 11, "a level first: %s" % [won.skills.map(func(gain: CombatSparSummary.SkillGain) -> String: return String(gain.skill_id))])
	_check(won.skills[1].skill_id == &"parry" and not won.skills[1].levelled(), "then progress alone")
	_check(CombatSparSummary.build(&"e1", &"me", &"npc.a", opponents, 4, before, state).outcome == CombatSparSummary.Outcome.LOST, "the other landed it: lost")
	_check(CombatSparSummary.build(&"e1", &"me", &"", opponents, 4, before, state).outcome == CombatSparSummary.Outcome.EVEN, "nobody landed it: even")
	var nothing := CombatSparSummary.build(&"e2", &"me", &"me", opponents, 1, CombatSparSummary.snapshot(state), state)
	_check(not nothing.gained_anything() and SparSummaryPanel.gain_lines(nothing) == ["这一场没有长进。"], "nothing gained says so")
	var lines: Array[String] = SparSummaryPanel.gain_lines(won)
	_check(lines.size() == 4 and lines[0] == "实战经验 +12" and lines[1] == "潜能 +3" and lines[2].ends_with("10 → 11 级") and lines[3].ends_with("有所长进"), "the card's gain lines: %s" % [lines])
	_check(SparSummaryPanel.title_text(CombatSparSummary.Outcome.WON) == "切磋 · 胜" and SparSummaryPanel.title_text(CombatSparSummary.Outcome.LOST) == "切磋 · 负", "titles")


func _test_real_spar(tree: SceneTree) -> void:
	SparSummaryPanel.shown_in_play = true
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	_check(session.handoff_to(&"snow.outdoor", &"snow.square", &"snow.square", &"snow.square.inn_entry").succeeded(), "fixture walks out to the square")
	for frame: int in range(5):
		await tree.process_frame
	var map: WorldMapController = MapPlaces.enter(session, &"snow.school2", &"snow.school2.trainee.6")
	_check(map != null, "the player stands in the 武馆 court")
	await tree.physics_frame
	await tree.physics_frame
	map.select_npc(TRAINEE)
	map.spar_selected()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	_check(coordinator.has_active_encounter(), "the trainee accepts the spar")
	var ui: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 300:
		ui.refresh_projection()
		coordinator.advance_scheduler(1.0)
		rounds += 1
	var receipt: CombatEncounterCompletionResult = coordinator.last_completion()
	_check(not coordinator.has_active_encounter() and receipt.terminal_result.kind == CombatEncounterResultKind.Value.SPAR_CONCLUDED, "the spar ends")
	var summary: CombatSparSummary = coordinator.spar_summary(receipt.encounter_id)
	_check(summary != null and summary.opponent_ids.has(TRAINEE) and summary.rounds > 0 and summary.outcome != CombatSparSummary.Outcome.EVEN, "a summary of it: %s" % ("none" if summary == null else "%d rounds, outcome %d" % [summary.rounds, summary.outcome]))
	_check(summary != null and summary.gained_anything(), "a spar teaches something")
	var panel: SparSummaryPanel = session.shared_ui().spar_summary
	session.set_process(true)
	ui.refresh_projection()
	for frame: int in range(240):
		await tree.process_frame
		if panel.shown():
			break
	_check(panel.shown() and panel.summary() == summary, "the card comes up once the fight's screen is gone")
	_check(panel.title.text.begins_with("切磋 · ") and panel.opponent_line.text.contains("共 ") and panel.gains.get_child_count() > 0, "it says the outcome, the opponent and the gains: %s / %s" % [panel.title.text, panel.opponent_line.text])
	_check(session.world_time_held(), "world time stands still under it")
	await tree.process_frame
	_check(tree.root.gui_get_focus_owner() == panel.continue_button, "继续 has the focus")
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await tree.process_frame
	await tree.process_frame
	_check(not panel.shown() and not session.world_time_held(), "B / Esc closes it and the world goes on")
	SparSummaryPanel.shown_in_play = false
	session.free()
	await tree.process_frame


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
