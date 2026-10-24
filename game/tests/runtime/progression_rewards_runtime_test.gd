extends RefCounted

## A2 经验节奏 in the world (DECISIONS「经验节奏」): where the one-time 历练 rewards are
## earned (a spar won, someone of note beaten, a region or place first come to, a book
## read through), that each comes once, the birthplace gives none, the classic knobs give
## none, and the 角色 page's lines for the potential cap and 落后补偿.

const TRAINEES: StringName = &"snow.school_compound.school2.trainees"
const OLD_BOOK: StringName = &"es2:obj/old_book"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: WorldSessionController = await _session(tree)
	await _test_birthplace(session)
	await _test_spar_won(tree, session)
	await _test_region_once(tree, session)
	_test_notable(session)
	_test_book(session)
	_test_sheet(session)
	session.free()
	await tree.process_frame
	var previous: PacingDefinition = Es2Pacing.use()
	var classic: WorldSessionController = await _session(tree)
	await _test_classic(tree, classic)
	classic.free()
	Es2Pacing.restore(previous)
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_birthplace(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	_check(state.milestones.has("region/snow"), "New Game: 雪亭镇 is written down as the birthplace")
	session.record_journal()
	_check(not _rewards(session).any(func(line: String) -> bool: return line.contains("雪亭镇")), "and gives no reward: %s" % [_rewards(session)])


## A real spar the player's blow ends (combatd.c's winner): the line comes after the fight
## once; the next win against another trainee (the same definition) gives nothing.
func _test_spar_won(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	state.progression.combat_experience = 150 # TEST-ONLY: stage 150, unit 40
	state.skills.set_raw_level(&"unarmed", 30) # TEST-ONLY: the player lands the first blow
	await _stand_at(tree, session, TRAINEES)
	var won: int = 0
	for attempt: int in 12:
		var before: int = _rewards(session).size()
		_spar(session, TRAINEES, attempt)
		_rest(session)
		var lines: Array[String] = _rewards(session).slice(before)
		won += lines.filter(func(line: String) -> bool: return line.begins_with("【历练】你第一次在切磋中胜过了武馆弟子")).size()
	_check(won == 1, "won spars against the trainees: one reward in all, %d" % won)
	_check(state.milestones.has("spar/snow.npc.trainee"), "written down by the NPC's definition")
	var line: String = _rewards(session).filter(func(l: String) -> bool: return l.contains("武馆弟子")).front() if won > 0 else ""
	# 40 at stage 150; 落后补偿 in 雪亭镇 (300) at about 150: +50%, less as the spars added exp.
	_check(line.contains("实战经验 +") and line.contains("落后补偿 +"), "with its catch-up: " + line)


func _test_region_once(tree: SceneTree, session: WorldSessionController) -> void:
	var before: int = _rewards(session).size()
	_check(session.handoff_to(&"cloud.outdoor", &"cloud.dragonhill.nroad", &"cloud.dragonhill.nroad", &"cloud.dragonhill.nroad.snow_entry").succeeded(), "to 卧龙岗")
	await _settle(tree)
	session.record_journal()
	var lines: Array[String] = _rewards(session).slice(before)
	_check(lines.size() == 1 and lines[0].begins_with("【历练】你第一次来到绮云镇："), "first time in 绮云镇: %s" % [lines])
	_check(session.handoff_to(&"snow.outdoor", &"snow.square", &"snow.square", &"snow.square.inn_entry").succeeded(), "back to the square")
	await _settle(tree)
	session.record_journal()
	_check(session.handoff_to(&"cloud.outdoor", &"cloud.dragonhill.nroad", &"cloud.dragonhill.nroad", &"cloud.dragonhill.nroad.snow_entry").succeeded(), "and to 卧龙岗 again")
	await _settle(tree)
	session.record_journal()
	_check(_rewards(session).size() == before + 1, "coming back gives nothing more")


func _test_notable(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var rewards: WorldProgressionRewards = session.progression_rewards()
	var trainer := _npc_of(session, &"snow.npc.fist_trainer")
	var farmer := _npc_of(session, &"snow.npc.farmer")
	_check(trainer != null and farmer != null, "李火狮 and a farmer stand in Snow")
	if trainer == null or farmer == null:
		return
	var before: int = _rewards(session).size()
	state.progression.combat_experience = 100000 # TEST-ONLY: far stronger than 李火狮 (3000)
	rewards.defeated(trainer)
	_check(_rewards(session).size() == before and not state.milestones.has("defeat/snow.npc.fist_trainer"), "beating 李火狮 far weaker: nothing, not written down")
	state.progression.combat_experience = 1000
	rewards.defeated(farmer)
	_check(_rewards(session).size() == before, "a farmer is nobody of note: a fall gives nothing")
	rewards.defeated(trainer)
	var lines: Array[String] = _rewards(session).slice(before)
	# 300% of 150, and 绮云镇's catch-up (1500) at 1000: +33%: 598 or 599 with the carry.
	_check(lines.size() == 1 and lines[0].begins_with("【历练】你第一次击败了李火狮：实战经验 +59") and lines[0].ends_with("（落后补偿 +33%）"), "李火狮 at 1000: %s" % [lines])
	rewards.spar_won(trainer)
	_check(_rewards(session).size() == before + 1, "winning a spar against him later: nothing more (the same key)")


func _test_book(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var map: WorldMapController = session.active_map() as WorldMapController
	var book: StringName = map.give_new_item_to_player(OLD_BOOK)
	_check(not book.is_empty(), "TEST-ONLY: an old book in hand")
	state.skills.set_raw_level(&"literate", 1)
	state.skills.set_raw_level(&"force", 10)
	state.skills.set_learned_progress(&"force", 121) # one point short of level 11 (more than 11 * 11)
	state.spirit = CharacterResourceState.new(500, 500, 500)
	var before: int = _rewards(session).size()
	var result: StudyResult = session.martial_arts().study(book)
	_check(result != null and result.outcome == StudyResult.Outcome.STUDIED and state.skills.raw_level(&"force") == 11, "研读 takes 基本内功 past the book's 10: %s, %d" % ["null" if result == null else StudyResult.Outcome.find_key(result.outcome), state.skills.raw_level(&"force")])
	var lines: Array[String] = _rewards(session).slice(before)
	_check(lines.size() == 1 and lines[0].begins_with("【历练】你读通了"), "read through: %s" % [lines])
	session.martial_arts().study(book)
	_check(_rewards(session).size() == before + 1, "too shallow from now on: nothing more")


func _test_sheet(session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var sheet := CharacterSheet.new()
	state.progression.combat_experience = 100
	state.progression.potential = 100
	state.progression.potential_spent = 30
	_check(session.handoff_to(&"snow.outdoor", &"snow.square", &"snow.square", &"snow.square.inn_entry").succeeded(), "on the square")
	sheet.refresh(session.player_runtime(), session)
	_check(sheet.potential_cap.text == "可用潜能 70 / 100", "the cap at stage 0: " + sheet.potential_cap.text)
	_check(sheet.catch_up.visible and sheet.catch_up.text == "落后补偿：雪亭镇推荐实战经验 300，你在这里所得的经验和潜能 +66%，赶上后恢复。", "落后补偿 below 300: " + sheet.catch_up.text)
	state.progression.combat_experience = 1500
	state.progression.potential = 480
	sheet.refresh(session.player_runtime(), session)
	_check(not sheet.catch_up.visible, "caught up: no line")
	_check(sheet.potential_cap.text == "可用潜能 450 / 450（已满，先去请教或研读）", "full at stage 1000: " + sheet.potential_cap.text)
	sheet.free()


## Es2Pacing (the classic knobs): no birthplace written, no reward, ES2's cap.
func _test_classic(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	_check(state.milestones.is_empty(), "classic: nothing written at New Game")
	state.progression.combat_experience = 150
	state.skills.set_raw_level(&"unarmed", 30)
	await _stand_at(tree, session, TRAINEES)
	for attempt: int in 6:
		_spar(session, TRAINEES, attempt)
		_rest(session)
	_check(session.handoff_to(&"cloud.outdoor", &"cloud.dragonhill.nroad", &"cloud.dragonhill.nroad", &"cloud.dragonhill.nroad.snow_entry").succeeded(), "classic: to 卧龙岗")
	await _settle(tree)
	session.record_journal()
	_check(_rewards(session).is_empty() and state.milestones.is_empty(), "classic: no 历练 at all: %s" % [_rewards(session)])
	_check(WorldProgressionRewards.potential_cap(state) == 100 and WorldProgressionRewards.catch_up_percent(state, &"cloud.dragonhill.nroad") == 0, "classic: cap 100, no catch-up")


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("历练", CharacterState.GENDER_MALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	return session


func _stand_at(tree: SceneTree, session: WorldSessionController, spawn_id: StringName) -> void:
	var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(spawn_id)
	session.handoff_to(spawn.map_id, spawn.zone_id, spawn.zone_id, spawn.spawn_point_ids()[1])
	await _settle(tree)


func _spar(session: WorldSessionController, spawn_id: StringName, turn: int) -> void:
	var map: WorldMapController = session.active_map() as WorldMapController
	var members: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.spawn_id == spawn_id and npc.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE:
			members.append(npc)
	if members.is_empty():
		return
	var npc: NpcRuntimeState = members[turn % members.size()]
	map.select_npc(npc.character_id)
	if map.spar_selected().outcome != CombatSliceInitiationResult.Outcome.COMPLETED:
		return
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 200:
		coordinator.advance_scheduler(1.0)
		rounds += 1
	CombatEncounterCoordinator.take_aborted_total()
	# The fight's result is shown; the lines that wait for it follow.
	(session.get_node("BattlePresentationLayer/BattleSurface") as BattlePresentationController).refresh_projection()


func _rest(session: WorldSessionController) -> void:
	for pulse: int in 60:
		session.advance_player_recovery(2.0)
		session.advance_npc_heartbeat(2.0)


func _settle(tree: SceneTree) -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _npc_of(session: WorldSessionController, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in session.world_npcs():
		if npc.definition().definition_id == definition_id:
			return npc
	return null


func _rewards(session: WorldSessionController) -> Array[String]:
	var lines: Array[String] = []
	for line: String in session.shared_ui().log_lines():
		if line.begins_with("【历练】"):
			lines.append(line)
	return lines


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
