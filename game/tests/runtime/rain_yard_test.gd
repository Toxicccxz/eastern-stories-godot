extends RefCounted

## 师娘彩蛋 A (计划 build/plans/师娘彩蛋_计划.md, owner 2026-11-27; DECISIONS「师娘彩蛋 A」): the yard
## north of the 黄土小径 — its gate shut to one not grown or not of 封山, opened by a knock to one
## who is; 沈疏雨 (the other of 柳淳风's 风雨双侠) and 何守拙 (who guards and does not strike); the
## line 镇外的小院: meet her, ask of the 雨, spar 何守拙 (won or lost), keep her asking of the 竹书 from
## 柳淳风 (师娘彩蛋 B), and the night at her desk — 留下: 「夜雨」 and an old silver hairpin; 告辞: 「听雨」
## the next morning and her slips. The same move either way; 柳淳风's one flat line after.
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
const TAUGHT_NIGHT: String = "学了夜雨"
const PROMISED: String = "答应了沈疏雨"
const DESK: StringName = &"snow.rain_house.desk"
const HAIRPIN: StringName = &"native:snow/silver_hairpin"
const SLIPS: StringName = &"native:snow/rain_slips"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var session: WorldSessionController = await _session(tree)
	await _test_line(tree, session)
	session.free()
	await tree.process_frame
	session = await _session(tree)
	await _test_stay(tree, session)
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
	_check(shen.talk().inquiry_rules("雨").size() == 6 and shen.talk().listed_for("雨", {}), "her 「雨」: six answers, listed to whoever came in")
	_check(not shen.talk().listed_for("竹书", {}) and shen.talk().listed_for("竹书", {"沈疏雨问起竹书": 1}) and shen.talk().confirm_applies("竹书", {"沈疏雨问起竹书": 1}) and not shen.talk().confirm_applies("竹书", {"沈疏雨问起竹书": 1, PROMISED: 1}), "「竹书」: listed once she asked, the promise asked first, once")
	_check(shen.talk().ask_confirm("竹书").contains("不告诉柳淳风"), "the confirm says what is kept from whom")
	_check(he != null and he.hooks().spar_over_mark == SPARRED and not he.dealings().is_fight_deferred(), "何守拙 can be sparred, and a spar a blow ended leaves its mark")
	_check(he.skill_map().get(&"parry", &"") == &"fonxansword" and not he.skill_map().has(&"sword"), "he parries with 封山剑法 and strikes with the plain sword")
	# Where they stand.
	for spawn_id: StringName in [&"native.rain_yard.shen_shuyu", &"native.rain_yard.he_shouzhuo"]:
		var spawn: NpcSpawnDefinition = catalog.spawn(spawn_id)
		_check(spawn != null and spawn.zone_id == &"snow.rain_yard" and spawn.map_id == &"snow.rain_compound", "%s in the yard" % spawn_id)
	# The line.
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	_check(quest != null and quest.line == StoryQuestDefinition.LINE_REGION and quest.steps.size() == 5, "镇外的小院: a 地区 line of five steps")
	var ids: Array = quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids == [&"meet", &"ask", &"spar", &"secret", &"night"], "meet, ask, spar, secret, night: %s" % [ids])
	_check(quest.step(&"night").is_branch() and quest.step(&"night").options.size() == 2, "the night is a choice of two")
	# 「听雨」 and 「夜雨」 are hers to give: one move, two names, one mark each.
	var sword: SkillDefinition = catalog.skill(&"fonxansword")
	_check(sword.perform_when.get(&"rainpress").key == TAUGHT and sword.perform_when.get(&"nightrain").key == TAUGHT_NIGHT, "each name asks its own mark")
	_check(not sword.perform_numbers.has(&"nightrain") and catalog.pacing().beat_rules().cost_of_action(&"perform/nightrain") == catalog.pacing().beat_rules().cost_of_action(&"perform/rainpress"), "「夜雨」 reads 「听雨」's numbers and costs the same")
	_check(SpecialFunctions.perform(&"nightrain").hint(catalog) == SpecialFunctions.perform(&"rainpress").hint(catalog), "and its button says the same")
	# The desk: done, or the night, or wait for it, else nothing.
	var desk: RoomActDefinition = catalog.service(DESK).act
	_check(desk.acts.size() == 6 and desk.acts[3].phase == ([&"night", &"midnight"] as Array[StringName]) and not desk.acts[4].ask.is_empty(), "the desk: three afterwards, the night, waiting for it, nothing")
	# Their master's one line: to his own (封山), and through 李火狮 to the 北宗.
	_check(_says(catalog.npc(&"common.npc.swordsman.master"), "最近总往镇外跑") and _says(catalog.npc(&"snow.npc.fist_trainer"), "最近总往镇外跑"), "「最近总往镇外跑」: 柳淳风 to his own, 李火狮 to the 北宗")
	# 师娘彩蛋 C: the town knows she lives out there (to anyone: no more than that); 何守拙 on 「雨」,
	# one line for each name, on his list only for one taught it.
	var town: FamilyDefinition.Hearsay = _hearsay(catalog, &"snow.npc.waiter", "风雨双侠")
	_check(town != null and town.asker_marks.is_empty() and town.say.contains("师娘") and town.say.contains("黄土小径") and not town.say.contains("沈疏雨"), "店小二 on 「风雨双侠」: a 师娘 out past the 黄土小径, to anyone, unnamed")
	var guard_talk: NpcTalk = catalog.npc(HE).talk()
	_check(not guard_talk.listed_for("雨", {}) and guard_talk.listed_for("雨", {TAUGHT: 1}) and guard_talk.listed_for("雨", {TAUGHT_NIGHT: 1}), "何守拙's 「雨」: listed only to one taught it, by either name")
	var ending: EpilogueDefinition = catalog.epilogue(&"ending")
	_check(_told(ending, ["告辞了"]).contains("不再一步一停") and not _told(ending, ["告辞了"]).contains("倒扣着"), "the ending, 告辞: her sword no longer waits")
	_check(_told(ending, ["留下了"]).contains("倒扣着") and not _told(ending, ["留下了"]).contains("一步一停"), "the ending, 留下: the cups turned down, the lamp late")
	_check(not _told(ending, []).contains("镇外"), "the ending says nothing of her to one who never went")


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
	# Not taught yet: the 雨 asks of the 竹书 now.
	_check(not catalog.skill(&"fonxansword").performs(&"rainpress", state), "after the spar 「听雨」 is not theirs yet")
	_check(_said(_ask(yard, shen, "雨"), "你读过吗") and state.marks.has("沈疏雨问起竹书") and yard.ask_topics_selected().has("竹书"), "「雨」 after the spar: she asks of the 竹书")
	_check(_said(_ask(yard, shen, "竹书"), "你别同他说") and state.marks.get(PROMISED, 0) == 1, "「竹书」: the promise kept from 柳淳风")
	_check(_said(_ask(yard, shen, "雨"), "天黑以后"), "「雨」 now: after dark, in the house")
	session.record_journal()
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"night", "next: the night")
	# The desk by day: wait for the dark (asked first), then she comes in and asks.
	var house: WorldMapController = await _at_desk(tree, session)
	var desk: ActService = house.service(DESK) as ActService
	_set_phase(session, &"morning") # TEST-ONLY: day
	desk.interact()
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("等到天黑"), "by day: wait for the dark? (asked first)")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_close_box(ui)
	await _settle(tree)
	_check(session.day_clock().phase().phase_id == &"night", "the clock went on to the night (%s)" % session.day_clock().phase().phase_id)
	_check(ui.is_asking() and _index(ui, "留下") >= 0 and _index(ui, "告辞") >= 0, "she asks: stay, or come back in the morning")
	ui.confirm_prompt.choice_buttons[_index(ui, "告辞")].pressed.emit()
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("「听雨」"), "告辞 asked first, naming the move it teaches")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_close_box(ui)
	await _settle(tree)
	_check(state.marks.get(TAUGHT, 0) == 1 and state.marks.get("告辞了", 0) == 1 and not state.marks.has(TAUGHT_NIGHT) and not state.marks.has("留下了"), "告辞: 「听雨」, and nothing of the night")
	_check(_carries(session, SLIPS) and not _carries(session, HAIRPIN), "her slips, not the hairpin")
	_check(session.day_clock().phase().phase_id == &"morning", "taught in the morning (%s)" % session.day_clock().phase().phase_id)
	var shen_after: NpcRuntimeState = _first(session, &"snow.rain_yard", SHEN)
	_check(session.player_runtime().world_location().zone_id == &"snow.rain_yard" and shen_after != null, "taught in the yard, as the lines say: both of them out there")
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(not state.marks.has("小院又来过") and not _said(_recent(ui, 12), "剑练得怎么样"), "no 'next visit' greeting the morning she taught")
	_check(catalog.skill(&"fonxansword").performs(&"rainpress", state) and not catalog.skill(&"fonxansword").performs(&"nightrain", state), "「听雨」 is theirs, 「夜雨」 is not")
	session.record_journal()
	_check(state.quests.has("%s/night/leave" % QUEST) and state.quests.has("%s#done" % QUEST), "the line is done, the 告辞 way")
	yard = MapPlaces.enter(session, &"snow.rain_yard", &"snow.rain_yard.gate_arrival")
	await _settle(tree)
	_close_box(ui)
	_check(_said(_ask(yard, _first(session, &"snow.rain_yard", SHEN), "竹简"), "头一回"), "「竹简」: the first time it was written")
	_check(_said(_ask(yard, _first(session, &"snow.rain_yard", HE), "雨"), "看着你学的"), "何守拙 on 「雨」, 告辞: he watched it taught")
	var told: String = _arts_entry(state, catalog)
	_check(told.contains("何守拙说过：「听雨」是她的剑") and not told.contains("「夜雨」"), "the 见识录's 封山剑法: what 何守拙 said of 「听雨」 (%s)" % told)
	# 柳淳风, back at the 武馆: his one flat line, once.
	var hall: WorldMapController = MapPlaces.enter(session, &"snow.schoolhall", &"snow.schoolhall.master.1")
	await _settle(tree)
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(state.marks.get("柳淳风说过镇外", 0) == 1 and _said(_recent(ui, 12), "最近总往镇外跑"), "柳淳风: 「最近总往镇外跑」")


## The 留下 way, from the promise on (TEST-ONLY: the earlier marks given by hand): the night at once,
## 「夜雨」 at dawn and the hairpin; she greets one who came back, and 何守拙 looks up.
func _test_stay(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var catalog: ContentCatalog = GameContent.catalog()
	StoryFixtures.fonxan_gated(session)
	state.progression.combat_experience = 12000 # TEST-ONLY
	for mark: String in [OPEN, MET, SENT, SPARRED, "沈疏雨问起竹书", PROMISED]:
		state.marks[mark] = 1 # TEST-ONLY
	var house: WorldMapController = await _at_desk(tree, session)
	var desk: ActService = house.service(DESK) as ActService
	_set_phase(session, &"night") # TEST-ONLY: already dark
	desk.interact()
	await _settle(tree)
	_close_box(ui)
	await _settle(tree)
	_check(ui.is_asking() and _index(ui, "留下") >= 0, "after dark: no waiting, she asks at once")
	ui.confirm_prompt.choice_buttons[_index(ui, "留下")].pressed.emit()
	await _settle(tree)
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("「夜雨」") and ui.confirm_prompt.message.text.contains("柳淳风不会知道"), "留下 asked first: the move's name, and who will not know")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_close_box(ui)
	await _settle(tree)
	_check(state.marks.get(TAUGHT_NIGHT, 0) == 1 and state.marks.get("留下了", 0) == 1 and not state.marks.has(TAUGHT), "留下: 「夜雨」, not 「听雨」")
	_check(_carries(session, HAIRPIN) and not _carries(session, SLIPS), "the hairpin, not the slips")
	_check(session.day_clock().phase().phase_id == &"dawn", "taught at dawn (%s)" % session.day_clock().phase().phase_id)
	_check(catalog.skill(&"fonxansword").performs(&"nightrain", state) and not catalog.skill(&"fonxansword").performs(&"rainpress", state), "「夜雨」 is theirs, 「听雨」 is not")
	session.record_journal()
	_check(state.quests.has("%s/night/stay" % QUEST) and state.quests.has("%s#done" % QUEST), "the line is done, the 留下 way")
	_check(_line_with(desk_lines(catalog), "倒扣着"), "the desk afterwards: the cups turned down")
	# Out of the house into the yard, the same dawn: no greeting yet.
	house.place_player(&"snow.rain_yard", MapPlaces.zone_spot(house, &"snow.rain_yard"))
	await _settle(tree)
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(not state.marks.has("小院又来过") and not _said(_recent(ui, 12), "你来了"), "stepping out of the house after the night: no 'next visit' greeting")
	# Back in the yard another day, by the gate: her greeting, and 何守拙's look.
	MapPlaces.enter(session, &"snow.eroad2", &"snow.eroad2.yard_return")
	await _settle(tree)
	var yard: WorldMapController = MapPlaces.enter(session, &"snow.rain_yard", &"snow.rain_yard.gate_arrival")
	await _settle(tree)
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(state.marks.get("小院又来过", 0) == 1 and _said(_recent(ui, 12), "你来了") and _said(_recent(ui, 12), "劈他的柴"), "she greets one who came back; 何守拙 looks up")
	var shen: NpcRuntimeState = _first(session, &"snow.rain_yard", SHEN)
	_check(yard.select_npc(shen.character_id) and yard.ask_topics_selected().has("簪子") and not yard.ask_topics_selected().has("竹简"), "「簪子」 to ask of, not 「竹简」")
	_check(_said(_ask(yard, _first(session, &"snow.rain_yard", HE), "雨"), "什么也没听见"), "何守拙 on 「雨」, 留下: he heard nothing that night")
	_check(_arts_entry(state, catalog).contains("何守拙说过：「夜雨」就是她那一剑"), "the 见识录 keeps it")


## TEST-ONLY: the clock put a minute into `phase_id`.
func _set_phase(session: WorldSessionController, phase_id: StringName) -> void:
	var clock: DayClock = session.day_clock()
	var phases: Array[StringName] = [phase_id]
	clock.set_day_seconds(clock.day_seconds() + clock.seconds_until_phase(phases) + 60)


## The house, at its desk (TEST-ONLY: placed there).
func _at_desk(tree: SceneTree, session: WorldSessionController) -> WorldMapController:
	var house: WorldMapController = MapPlaces.enter(session, &"snow.rain_yard", &"snow.rain_yard.gate_arrival")
	await _settle(tree)
	house.place_player(&"snow.rain_house", MapPlaces.service_spot(house, DESK))
	await _settle(tree)
	# The NPCs see the player come into the house (on their heartbeat, as in play).
	session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	return house


func desk_lines(catalog: ContentCatalog) -> Array:
	var lines: Array = []
	for step: ScriptedAct.Step in catalog.service(DESK).act.acts[0].steps:
		if step.line != null:
			lines.append(step.line.text)
	return lines


func _line_with(lines: Array, part: String) -> bool:
	return lines.any(func(line: String) -> bool: return line.contains(part))


## Whether one of the NPC's calls says `part`.
## The town's line of hearsay `npc` hangs on `topic`, or null.
func _hearsay(catalog: ContentCatalog, npc_id: StringName, topic: String) -> FamilyDefinition.Hearsay:
	for line: FamilyDefinition.Hearsay in catalog.hearsay_for(&"fonxansword"):
		if line.npc_id == npc_id and line.topic == topic:
			return line
	return null


## What the ending tells one who holds `marks`.
func _told(epilogue: EpilogueDefinition, marks: Array) -> String:
	var state := CharacterState.new()
	for mark: String in marks:
		state.marks[mark] = 1 # TEST-ONLY
	var temps: Dictionary[String, int] = {}
	var held: Dictionary[StringName, bool] = {}
	var test: Callable = func(condition: JournalEntryDefinition) -> bool: return JournalLog.holds(condition, state, temps, held)
	var lines: Array[String] = []
	for shown: Array in epilogue.shown(test):
		lines.append_array(shown[1])
	return "\n".join(lines)


## The 见识录's 封山剑法 entry as text ("" without one).
func _arts_entry(state: CharacterState, catalog: ContentCatalog) -> String:
	for entry: CodexContent.Entry in CodexContent.entries(CodexContent.Section.ARTS, state, catalog):
		if entry.key == "moves/fonxansword":
			return entry.text()
	return ""


func _says(npc: NpcDefinition, part: String) -> bool:
	for call: NpcHooks.Call in npc.hooks().calls:
		for step: ScriptedAct.Step in call.act.steps:
			if step.line != null and step.line.text.contains(part):
				return true
	return false


func _carries(session: WorldSessionController, item_id: StringName) -> bool:
	var inventory: InventoryState = session.inventory_state()
	var carried := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)
	for instance_id: StringName in inventory.direct_children(carried):
		var item: ItemInstance = session.item_instance_index().resolve(instance_id)
		if item != null and item.item_definition_id == item_id:
			return true
	return false


func _index(ui: SharedGameplayUI, prefix: String) -> int:
	if not ui.is_asking():
		return -1
	for index: int in ui.confirm_prompt.choice_buttons.size():
		var button: Button = ui.confirm_prompt.choice_buttons[index]
		if button.visible and button.text.begins_with(prefix):
			return index
	return -1


## The dialogue box read to its end and shut (the scene's lines).
func _close_box(ui: SharedGameplayUI) -> void:
	for page: int in 40:
		if not ui.dialogue_box.is_open():
			return
		ui.dialogue_box.finish_typing()
		if not ui.dialogue_box.advance():
			ui.dialogue_box.close()

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
