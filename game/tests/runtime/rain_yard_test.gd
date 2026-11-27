extends RefCounted

## 师娘彩蛋 A (计划 build/plans/师娘彩蛋_计划.md, owner 2026-11-27; DECISIONS「师娘彩蛋 A」): the yard
## north of the 黄土小径 — its gate shut to one not grown or not of 封山, opened by a knock to one
## who is; 沈疏雨 (the other of 柳淳风's 风雨双侠) and 何守拙 (who guards and does not strike); the
## line 镇外的小院: meet her, ask of the 雨, spar 何守拙 (won or lost), learn 「听雨」.
## TEST-ONLY fixtures, each marked where used: the player's family, skills and experience,
## the ambience source, the spar ended by hand.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const SHEN: StringName = &"native.npc.shen_shuyu"
const HE: StringName = &"native.npc.he_shouzhuo"
const GATE: StringName = &"snow.eroad2.rain_gate"
const QUEST: StringName = &"region.rain_yard"
const OPEN: String = "小院开了门"
const MET: String = "见过沈疏雨"
const SENT: String = "沈疏雨叫你试老何"
const SPARRED: String = "和何守拙过了招"
const TAUGHT: String = "学了听雨"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var session: WorldSessionController = await _session(tree)
	await _test_line(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	# Whom the gate opens to: grown, of 封山 or its 北宗, with the sword at 40.
	var welcome: JournalEntryDefinition = catalog.conditions().get("rain.welcome")
	_check(welcome != null and welcome.when == JournalEntryDefinition.When.ALL and welcome.parts.size() == 3, "rain.welcome: three things asked")
	# pacing.json itself: the suites' own pacing leaves the ages out.
	var grown: int = -1
	var pacing: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/common/pacing.json"))
	for row: Dictionary in pacing["pacing"]["player_age_by_exp"]:
		if int(row["age"]) == 18:
			grown = int(row["exp"])
	_check(welcome != null and welcome.parts[0].when == JournalEntryDefinition.When.EXP_AT_LEAST and welcome.parts[0].amount == grown and grown > 0, "grown: the experience pacing.json makes eighteen at (%d)" % grown)
	_check(welcome != null and welcome.parts[2].when == JournalEntryDefinition.When.SKILL_AT_LEAST and welcome.parts[2].key == "fonxansword" and welcome.parts[2].amount == 40, "封山剑法 40: all 柳绘心 can give")
	var hers: Array = catalog.npc(&"snow.npc.girl").skill_levels().filter(func(level: NpcSkillLevelDefinition) -> bool: return level.skill_id == &"fonxansword")
	_check(hers.size() == 1 and (hers[0] as NpcSkillLevelDefinition).raw_level == 40, "(柳绘心's own 封山剑法 is 40)")
	# The gate: shut by an exit rule until the knock opened it.
	var rules: Array[ZoneExitRuleDefinition] = catalog.exit_rules_between(&"snow.eroad2", &"snow.rain_yard")
	_check(rules.size() == 1 and rules[0].mark == OPEN, "the yard's gate is shut until 「%s」" % OPEN)
	var knock: RoomActDefinition = catalog.service(GATE).act
	_check(knock.acts.size() == 3 and knock.acts[0].mark == OPEN and knock.acts[1].when != null and knock.acts[2].when == null and knock.acts[2].mark.is_empty(), "the knock: open already, opened to one welcome, else nobody answers")
	# The two people.
	var shen: NpcDefinition = catalog.npc(SHEN)
	var he: NpcDefinition = catalog.npc(HE)
	_check(shen != null and shen.dealings().is_fight_deferred() and shen.nickname == catalog.npc(&"common.npc.swordsman.master").nickname and shen.nickname == "风雨双侠", "沈疏雨 wears 柳淳风's own nickname, and is not to be fought")
	_check(shen.talk().inquiry_rules("雨").size() == 4 and shen.talk().listed_for("雨", {}), "her 「雨」: four answers, listed to whoever came in")
	_check(he != null and he.hooks().spar_over_mark == SPARRED and not he.dealings().is_fight_deferred(), "何守拙 can be sparred, and a spar a blow ended leaves its mark")
	_check(he.skill_map().get(&"parry", &"") == &"fonxansword" and not he.skill_map().has(&"sword"), "he parries with 封山剑法 and strikes with the plain sword")
	# Where they stand.
	for spawn_id: StringName in [&"native.rain_yard.shen_shuyu", &"native.rain_yard.he_shouzhuo"]:
		var spawn: NpcSpawnDefinition = catalog.spawn(spawn_id)
		_check(spawn != null and spawn.zone_id == &"snow.rain_yard" and spawn.map_id == &"snow.rain_compound", "%s in the yard" % spawn_id)
	# The line.
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	_check(quest != null and quest.line == StoryQuestDefinition.LINE_REGION and quest.steps.size() == 4, "镇外的小院: a 地区 line of four steps")
	var ids: Array = quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids == [&"meet", &"ask", &"spar", &"learn"], "meet, ask, spar, learn: %s" % [ids])
	# 「听雨」 is hers to give: the mark the perform asks is the one her answer leaves.
	_check(catalog.skill(&"fonxansword").perform_when.get(&"rainpress").key == TAUGHT, "「听雨」 asks the mark her teaching leaves")


func _test_line(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var catalog: ContentCatalog = GameContent.catalog()
	var road: WorldMapController = MapPlaces.enter(session, &"snow.eroad2", &"snow.eroad2.yard_return")
	await _settle(tree)
	var gate: ActService = road.service(GATE) as ActService
	_check(gate != null and road.place_player(&"snow.eroad2", MapPlaces.service_spot(road, GATE)), "TEST-ONLY: at the gate")
	await _settle(tree)
	# A new character: nobody answers, the gate stays shut.
	gate.interact()
	await _settle(tree)
	_check(not state.marks.has(OPEN) and _said(_recent(ui), "没有人应"), "a new character knocks: nobody answers")
	# Of 封山, the sword at 40, but not grown: still nobody.
	StoryFixtures.fonxan_gated(session)
	for skill: String in ["sword", "fonxansword", "parry", "dodge"]:
		state.skills.set_raw_level(StringName(skill), 40) # TEST-ONLY
	state.skills.map_skill(&"sword", &"fonxansword")
	state.skills.map_skill(&"parry", &"fonxansword")
	state.progression.combat_experience = 11999 # TEST-ONLY
	gate.interact()
	await _settle(tree)
	_check(not state.marks.has(OPEN), "of 封山 with the sword at 40, a point short of eighteen: nobody answers")
	state.progression.combat_experience = 12000 # TEST-ONLY
	gate.interact()
	await _settle(tree)
	_check(state.marks.get(OPEN, 0) == 1 and _said(_recent(ui), "封山的人"), "grown: 何守拙 opens the gate")
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"meet", "the line begins: go in")
	# In: she speaks first.
	var yard: WorldMapController = MapPlaces.enter(session, &"snow.rain_yard", &"snow.rain_yard.gate_arrival")
	await _settle(tree)
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(state.marks.get(MET, 0) == 1, "沈疏雨 looks up from her sword and speaks")
	if ui.dialogue_box.is_open():
		ui.dialogue_box.close()
	var shen: NpcRuntimeState = _first(session, &"snow.rain_yard", SHEN)
	var he: NpcRuntimeState = _first(session, &"snow.rain_yard", HE)
	_check(shen != null and he != null, "both stand in the yard")
	_check(_said(_ask(yard, shen, "风雨双侠"), "风是他，雨是我"), "「风雨双侠」: the wind is he, the rain is she")
	# Before she sends them, 何守拙 spars with nobody.
	_check(yard.select_npc(he.character_id) and yard.spar_selected().outcome != CombatSliceInitiationResult.Outcome.COMPLETED and _said(_recent(ui), "师娘没发话") and not session.combat_encounter_coordinator().has_active_encounter(), "何守拙 before her word: no spar")
	_check(_said(_ask(yard, shen, "雨"), "老何") and state.marks.get(SENT, 0) == 1 and not state.marks.has(TAUGHT), "「雨」: first go and spar 何守拙")
	_check(_said(_ask(yard, shen, "雨"), "回来再说") and not state.marks.has(TAUGHT), "asked again before the spar: not yet")
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"spar", "next: the spar")
	# The spar, ended by a blow of his (TEST-ONLY: his blow written in by hand): the mark all the same.
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player_id: StringName = session.player_runtime().character_id
	# A spar broken off with no blow landed (TEST-ONLY: the two parted by hand) leaves no mark.
	_check(yard.select_npc(he.character_id) and yard.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "何守拙 takes the spar once she sent them")
	session.player_runtime().relationship.remove_opponent(he.character_id) # TEST-ONLY
	he.relationship.remove_opponent(player_id) # TEST-ONLY
	for step: int in 20:
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
		await _settle(tree)
	_check(not coordinator.has_active_encounter() and not state.marks.has(SPARRED), "a spar no blow ended: no mark")
	ui.dismiss_current_panel()
	await _settle(tree)
	_check(yard.select_npc(he.character_id) and yard.spar_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "何守拙 takes the spar again")
	coordinator.resolution()._spar_winner = he.character_id # TEST-ONLY
	coordinator.resolution()._spar_loser = player_id # TEST-ONLY
	session.player_runtime().relationship.remove_opponent(he.character_id) # TEST-ONLY
	he.relationship.remove_opponent(player_id) # TEST-ONLY
	for step: int in 20:
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
		await _settle(tree)
	_check(not coordinator.has_active_encounter() and state.marks.get(SPARRED, 0) == 1, "a spar his blow ended: 「%s」 all the same" % SPARRED)
	ui.dismiss_current_panel()
	await _settle(tree)
	# Taught.
	_check(not catalog.skill(&"fonxansword").performs(&"rainpress", state), "before her teaching 「听雨」 is not theirs")
	_check(_said(_ask(yard, shen, "雨"), "听雨") and state.marks.get(TAUGHT, 0) == 1, "「雨」 after the spar: she teaches 「听雨」")
	_check(catalog.skill(&"fonxansword").performs(&"rainpress", state), "and 封山剑法 gives it to them from then on")
	_check(_said(_ask(yard, shen, "雨"), "是逼，不是抢"), "asked again: a word on how it is used")
	_check(_said(_ask(yard, he, "过招"), "怎么敲门"), "何守拙 asks for another spar")
	session.record_journal()
	_check(state.quests.has("%s#done" % QUEST), "the line is done")


func _ask(map: WorldMapController, npc: NpcRuntimeState, topic: String) -> Array[String]:
	if map == null or npc == null or not map.select_npc(npc.character_id):
		return []
	var lines: Array[String] = map.ask_selected(topic)
	var ui: SharedGameplayUI = map.hud()
	if ui != null and ui.dialogue_box.is_open():
		ui.dialogue_box.close()
	return lines


func _recent(ui: SharedGameplayUI, count: int = 8) -> Array[String]:
	var lines: Array[String] = ui.log_lines()
	return lines.slice(maxi(0, lines.size() - count))


func _said(lines: Array, part: String) -> bool:
	return lines.any(func(line: String) -> bool: return line.contains(part))


func _first(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	var map: WorldMapController = session.world_map_of(MapPlaces.map_of(zone_id))
	if map == null:
		return null
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.exists_in_map and npc.world_location().zone_id == zone_id and NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
			return npc
	return null


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("听雨", CharacterState.GENDER_MALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	return session


func _settle(tree: SceneTree) -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append("rain yard: " + message)
