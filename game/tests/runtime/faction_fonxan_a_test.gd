extends RefCounted

## 势力线第一批 封山 A (计划 build/plans/势力线第一批_计划.md §3; DECISIONS「封山 A」): the line begins with
## 拜师; 守馆 — 柳淳风's word, 罗七 and his two on the 青石官道 (there only for that step, friendly
## until called out, then all three at once), the 腰牌, 逄义 at 绮云镇's 赌场, the 腰牌 given back and
## the rank 大弟子; then the 门房: 说破 (刘安禄 leaves the gate for the 山坳) or 替他瞒 (he stays), each
## with its deed; the 势力 column and the 声望 page; one who is no disciple sees none of it.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MASTER: StringName = &"common.npc.swordsman.master"
const TRAINER: StringName = &"snow.npc.fist_trainer"
const GUARD: StringName = &"snow.npc.guard"
const HEAD: StringName = &"native.npc.fake_disciple_head"
const LACKEY: StringName = &"native.npc.fake_disciple"
const PANG: StringName = &"snow.npc.mercenary"
const TALLY: StringName = &"native:snow/fonxan_tally"
const QUEST: StringName = &"faction.fonxan"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var session: WorldSessionController = await _session(tree)
	await _test_stranger(tree, session)
	session.free()
	await tree.process_frame
	session = await _session(tree)
	await _test_guarding(tree, session)
	session.free()
	await tree.process_frame
	session = await _session(tree)
	await _test_reveal(tree, session)
	session.free()
	await tree.process_frame
	session = await _session(tree)
	await _test_cover(tree, session)
	session.free()
	await tree.process_frame
	session = await _session(tree)
	await _test_gone_home(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var quest: StoryQuestDefinition = catalog.story_quest(QUEST)
	_check(quest != null and quest.line == StoryQuestDefinition.LINE_FACTION and quest.starts.when == JournalEntryDefinition.When.FAMILY and quest.starts.key == "family.fonxan", "faction.fonxan: a 势力 quest that begins with 拜师")
	var ids: Array = [] if quest == null else quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id)
	_check(ids == [&"hear", &"fakes", &"pang", &"report", &"gate", &"book"], "its steps: %s" % [ids])
	var gate: StoryQuestDefinition.Step = quest.step(&"gate")
	_check(gate.is_branch() and gate.weight == StoryQuestDefinition.WEIGHT_SMALL and gate.options.size() == 2 and not gate.options[0].reward.deed.is_empty() and not gate.options[1].reward.deed.is_empty(), "the 门房 is a small choice of two, each a deed")
	_check(gate.objective.contains("离开武馆") and gate.objective.contains("算在你头上"), "the cost of either way is said before the choice (owner: 选前说代价)")
	_check(quest.step(&"report").reward.rank_title == "大弟子" and quest.step(&"report").reward.rank_family == &"family.fonxan", "守馆 done: 大弟子")
	# 逄义: ES2's own, placed at last.
	var pang: NpcDefinition = catalog.npc(PANG)
	_check(pang != null and pang.description.contains("生性好赌") and pang.description.contains("和柳淳风同辈的弟子"), "逄义 is mercenary.c's, word for word")
	var place: NpcSpawnDefinition = catalog.spawn(&"native.duchang.pang_yi")
	_check(place != null and place.zone_id == &"cloud.duchang" and place.npc_definition_id == PANG, "he is at 绮云镇's 赌场")
	var head: NpcSpawnDefinition = catalog.spawn(&"native.sroad3.fake_head")
	var lackeys: NpcSpawnDefinition = catalog.spawn(&"native.sroad3.fake_disciples")
	_check(head != null and head.zone_id == &"snow.sroad3" and head.cleared_mark == "冒牌头目倒了" and lackeys != null and lackeys.spawn_point_ids().size() == 2 and lackeys.cleared_mark == "冒牌帮闲倒了", "罗七 and two hangers-on on the 青石官道")
	_check(catalog.item(TALLY) != null and catalog.item(TALLY).description.contains("逄") and catalog.item(TALLY).description.contains("绮云"), "the 腰牌 says whose it is and where it came from")
	_check(FileAccess.get_file_as_string("res://data/niling/npcs.json").contains("老二就是老刘") and not FileAccess.get_file_as_string("res://data/niling/npcs.json").contains("老二在丹房"), "霍铮's 老二 is 刘安禄 (guard.c: 野羊山寨二寨主)")


## No disciple: no line, nobody on the road, 柳淳风 keeps the house's business to the house.
func _test_stranger(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	session.record_journal()
	_check(not state.quests.has("faction.fonxan#started"), "no family: the line has not begun")
	var hall: WorldMapController = MapPlaces.enter(session, &"snow.schoolhall", &"snow.schoolhall.master.1")
	await _settle(tree)
	var master: NpcRuntimeState = _first(session, &"snow.schoolhall", MASTER)
	_check(master != null and _said(_ask(hall, master, "武馆的事"), "不劳外人费心") and not state.marks.has("柳淳风说了冒牌"), "柳淳风 to a stranger: 武馆自家的事")
	MapPlaces.enter(session, &"snow.sroad2", &"snow.sroad2.academy_return")
	await _settle(tree)
	_check(_count_in(session, &"snow.sroad3", HEAD) == 0 and _count_in(session, &"snow.sroad3", LACKEY) == 0, "nobody collecting a 拜师钱 on the road")
	ui.quest_page.fill(state, "小兄弟", "", session.quest_condition_test())
	_check(not ui.quest_page.shown_text().contains("势力"), "the 势力 column is not shown")
	ui.standing_page.fill(session.quest_condition_test())
	_check(ui.standing_page.shown_text() == StandingPage.NOTHING_YET, "the 声望 page: nobody remembers you yet (%s)" % ui.standing_page.shown_text())


func _test_guarding(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var ui: SharedGameplayUI = session.shared_ui()
	StoryFixtures.fonxan_joined(session)
	session.record_journal()
	_check(state.quests.has("faction.fonxan#started") and StoryQuestLog.current_step(state, GameContent.catalog().story_quest(QUEST)).objective.contains("武馆的事"), "拜师: the line begins, the first thing is to ask 柳淳风")
	ui.quest_page.fill(state, "小兄弟", "", session.quest_condition_test())
	_check(ui.quest_page.shown_text().contains("势力") and ui.quest_page.shown_text().contains("封山剑派 · 雪亭镇"), "the 势力 column has the line")
	# Before he speaks of them, nobody is on the road.
	MapPlaces.enter(session, &"snow.sroad2", &"snow.sroad2.academy_return")
	await _settle(tree)
	_check(_count_in(session, &"snow.sroad3", HEAD) == 0, "before 柳淳风's word: nobody on the road")
	var hall: WorldMapController = MapPlaces.enter(session, &"snow.schoolhall", &"snow.schoolhall.master.1")
	await _settle(tree)
	var master: NpcRuntimeState = _first(session, &"snow.schoolhall", MASTER)
	_check(_said(_ask(hall, master, "武馆的事"), "拜师钱") and state.marks.get("柳淳风说了冒牌", 0) == 1, "柳淳风 to his own: the 拜师钱 on the 青石官道")
	session.record_journal()
	_check(state.quests.has("faction.fonxan/hear"), "step hear done")
	# The three on the road: friendly until called out.
	var road: WorldMapController = MapPlaces.enter(session, &"snow.sroad2", &"snow.sroad2.academy_return")
	await _settle(tree)
	_check(_count_in(session, &"snow.sroad3", HEAD) == 1 and _count_in(session, &"snow.sroad3", LACKEY) == 2, "罗七 and his two under the banner")
	var boss: NpcRuntimeState = MapPlaces.npc_at(session, &"snow.sroad3.fake_head.1")
	var body: Node2D = null if boss == null else road.runtime_body_for_character(boss.character_id)
	_check(body != null and road.place_player(&"snow.sroad3", MapPlaces.spot(road, &"snow.sroad3", body.global_position, 96.0)), "TEST-ONLY: beside 罗七")
	await _settle(tree)
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "they leave a passer-by alone (ignores_when)")
	_check(_said(_ask(road, boss, "腰牌"), "假不了") and _said(_ask(road, boss, "封山剑法"), "快字"), "罗七 shows a real 腰牌 and gets the sword wrong")
	_check(_said(_ask(road, boss, "冒牌"), "砸咱们的饭碗") and state.marks.get("说破了冒牌弟子", 0) == 1, "called out: 说破了冒牌弟子")
	for second: int in 4:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
		if session.combat_encounter_coordinator().has_active_encounter():
			break
	_check(session.combat_encounter_coordinator().has_active_encounter(), "called out, they fall on the player")
	var against: int = 0
	if session.combat_encounter_coordinator().has_active_encounter():
		for participant: CombatParticipant in session.combat_encounter_coordinator().active_encounter().participants():
			var npc: NpcRuntimeState = road.npcs.find_resident_npc(participant.participant_id)
			if npc != null and npc.definition().definition_id in [HEAD, LACKEY]:
				against += 1
	_check(against == 3, "all three at once (进门一起上): %d" % against)
	await _flee(tree, session)
	# TEST-ONLY: the three leave as if beaten (the clearing counts them gone); the 腰牌 as if picked up.
	_clear(road, HEAD)
	_clear(road, LACKEY)
	session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	session.record_journal()
	_check(state.marks.get("冒牌头目倒了", 0) == 1 and state.marks.get("冒牌帮闲倒了", 0) == 1 and state.quests.has("faction.fonxan/fakes"), "beaten: both marks, step fakes done")
	road.give_new_item_to_player(TALLY)
	var catalog: ContentCatalog = GameContent.catalog()
	_check(catalog.npc(HEAD).hooks().spared_drop == TALLY and catalog.npc(HEAD).hooks().spared_leave and catalog.npc(HEAD).hooks().die_item_id == TALLY, "罗七 spared drops the 腰牌; killed, his corpse holds it")
	# 柳淳风 knows the 牌 but wants 逄义 asked first.
	hall = MapPlaces.enter(session, &"snow.schoolhall", &"snow.schoolhall.master.1")
	await _settle(tree)
	master = _first(session, &"snow.schoolhall", MASTER)
	_check(_said(_ask(hall, master, "腰牌"), "逄义师弟的牌") and _said(_ask(hall, master, "腰牌"), "绮云镇的赌场"), "柳淳风 knows whose it is and where he is")
	_check(hall.select_npc(master.character_id), "柳淳风 selected")
	var early: ItemHandlingResult = hall.give_to_selected(_carried(session, TALLY))
	_check(not _carried(session, TALLY).is_empty() and not state.marks.has("守馆办完了"), "given before 逄义 was asked: handed back (%s)" % [early.lines if early != null else []])
	# 逄义 at the 赌场.
	var den: WorldMapController = MapPlaces.enter(session, &"cloud.duchang", &"cloud.duchang.eroad1_entry")
	await _settle(tree)
	var pang: NpcRuntimeState = MapPlaces.npc_at(session, &"cloud.duchang.pang_yi.1")
	_check(pang != null and pang.definition().definition_id == PANG, "逄义 at a table in the 赌场")
	_check(_said(_ask(den, pang, "柳淳风"), "同门师兄"), "his ES2 word of 柳淳风")
	_check(_said(_ask(den, pang, "腰牌"), "是我的牌") and state.marks.get("逄义认了腰牌", 0) == 1, "逄义 owns to the 牌")
	session.record_journal()
	_check(state.quests.has("faction.fonxan/pang"), "step pang done")
	# Back: the 牌 given, 大弟子.
	hall = MapPlaces.enter(session, &"snow.schoolhall", &"snow.schoolhall.master.1")
	await _settle(tree)
	master = _first(session, &"snow.schoolhall", MASTER)
	_check(hall.select_npc(master.character_id), "柳淳风 selected again")
	hall.give_to_selected(_carried(session, TALLY))
	_check(_carried(session, TALLY).is_empty() and state.marks.get("守馆办完了", 0) == 1, "the 腰牌 given back: 守馆办完了")
	session.record_journal()
	_check(state.quests.has("faction.fonxan/report") and state.affiliation.family_title == "大弟子", "step report done: 大弟子 (%s)" % state.affiliation.family_title)
	_check(player.shown_title().contains("大弟子") and player.facts.title.contains("大弟子"), "the title shown and kept: %s / %s" % [player.shown_title(), player.facts.title])
	_check(DeedLog.done(state, "清了打着淳风武馆旗号收拜师钱的人"), "the deed is written")
	_check(_recent(ui, 12).any(func(line: String) -> bool: return line.contains("【晋阶】")), "the rise is told: %s" % [_recent(ui, 6)])
	_check(StoryQuestLog.current_step(state, catalog.story_quest(QUEST)).step_id == &"gate", "next: the 门房")
	# The road is clear for good.
	MapPlaces.enter(session, &"snow.sroad2", &"snow.sroad2.academy_return")
	await _settle(tree)
	_check(_count_in(session, &"snow.sroad3", HEAD) == 0 and _count_in(session, &"snow.sroad3", LACKEY) == 0, "nobody on the road any more")
	ui.standing_page.fill(session.quest_condition_test())
	var standing: String = ui.standing_page.shown_text()
	_check(standing.contains("封山剑派 · 门派 · 雪亭镇") and standing.contains("你是封山剑派的弟子") and standing.contains("是你清的") and standing.contains("逄义认了那块腰牌"), "the 声望 page: 封山's card, in sentences: %s" % standing)
	_check(not standing.contains("天邪派") and not standing.contains("逆灵宫"), "houses with nothing to say are left out")


## 说破: he leaves the gate, and stands at the 山坳; 柳淳风 and he each say it once.
func _test_reveal(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.fonxan_guarded(session)
	session.record_journal()
	var yard: WorldMapController = MapPlaces.enter(session, &"snow.school2", &"snow.school2.gate_entry")
	await _settle(tree)
	var trainer: NpcRuntimeState = MapPlaces.npc_at(session, &"snow.school2.fist_trainer.1")
	_check(_said(_ask(yard, trainer, "说破门房的来历"), "说破什么") and not state.marks.has("说破了刘安禄"), "before 李火狮 has put the question, the word is not taken")
	_check(_said(_ask(yard, trainer, "门房"), "武馆不留匪") and state.marks.get("李火狮说了门房", 0) == 1, "李火狮 puts the question")
	var talk: NpcTalk = GameContent.catalog().npc(TRAINER).talk()
	_check(talk.ask_confirm("说破门房的来历").contains("离开武馆") and talk.ask_confirm("替门房瞒下来").contains("算在你头上") and talk.confirm_applies("说破门房的来历", state.marks), "the confirms say what each way costs, and ask now")
	_check(_said(_ask(yard, trainer, "说破门房的来历"), "血手刘三") and state.marks.get("说破了刘安禄", 0) == 1, "说破")
	_check(_said(_ask(yard, trainer, "替门房瞒下来"), "瞒不回去") and not state.marks.has("替刘安禄瞒了"), "the other way is closed")
	session.record_journal()
	_check(state.quests.has("faction.fonxan/gate/reveal") and DeedLog.done(state, "说破了淳风武馆门房的来历"), "the choice and its deed are recorded")
	# Out of the compound: the gate is empty, he stands at the 山坳.
	MapPlaces.enter(session, &"snow.school1", &"snow.school1.gate_return")
	await _settle(tree)
	_check(_count_in(session, &"snow.school1", GUARD) == 0 and _count_in(session, &"snow.crossroad", GUARD) == 1, "刘安禄 has left the gate and stands at the 山坳 (%d, %d)" % [_count_in(session, &"snow.school1", GUARD), _count_in(session, &"snow.crossroad", GUARD)])
	var road: NpcRuntimeState = MapPlaces.npc_at(session, &"snow.crossroad.liu_anlu.1")
	_check(road != null and GameContent.catalog().npc(GUARD).talk().inquiry_topics().has("刘老三"), "he is the same man there: guard.c's 刘老三 can still be asked")
	var standing: SharedGameplayUI = session.shared_ui()
	standing.standing_page.fill(session.quest_condition_test())
	_check(standing.standing_page.shown_text().contains("是你说破了门房的来历"), "the 声望 page says so")
	_check(_ending_lines(session, &"snow").any(func(line: String) -> bool: return line.contains("门房空了一冬")), "the ending's 雪亭 card: the gate stood empty")


## 替他瞒: he stays at the gate.
func _test_cover(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.fonxan_guarded(session)
	session.record_journal()
	var yard: WorldMapController = MapPlaces.enter(session, &"snow.school2", &"snow.school2.gate_entry")
	await _settle(tree)
	var trainer: NpcRuntimeState = MapPlaces.npc_at(session, &"snow.school2.fist_trainer.1")
	_check(_said(_ask(yard, trainer, "门房"), "二寨主"), "李火狮 puts the question")
	_check(_said(_ask(yard, trainer, "替门房瞒下来"), "认错了人") and state.marks.get("替刘安禄瞒了", 0) == 1, "替他瞒")
	_check(_said(_ask(yard, trainer, "说破门房的来历"), "别改了") and not state.marks.has("说破了刘安禄"), "the other way is closed")
	session.record_journal()
	_check(state.quests.has("faction.fonxan/gate/cover") and DeedLog.done(state, "替淳风武馆的门房瞒下了来历"), "the choice and its deed are recorded")
	_check(StoryQuestLog.is_active(state, GameContent.catalog().story_quest(QUEST)), "the line goes on (封山 B)")
	MapPlaces.enter(session, &"snow.school1", &"snow.school1.gate_return")
	await _settle(tree)
	_check(_count_in(session, &"snow.school1", GUARD) == 1 and _count_in(session, &"snow.crossroad", GUARD) == 0, "刘安禄 is still the 门房")
	_check(_ending_lines(session, &"snow").any(func(line: String) -> bool: return line.contains("只有三个人知道")), "the ending's 雪亭 card: three know")


## Spared and home already (第三章's rescue): the gate was empty before the question; 李火狮 asks where he went.
func _test_gone_home(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.fonxan_guarded(session)
	state.marks["放过了刘安禄"] = 1 # TEST-ONLY: 第三章, the rescue
	state.marks["霍铮回了寨"] = 1 # TEST-ONLY
	session.record_journal()
	var yard: WorldMapController = MapPlaces.enter(session, &"snow.school2", &"snow.school2.gate_entry")
	await _settle(tree)
	var trainer: NpcRuntimeState = MapPlaces.npc_at(session, &"snow.school2.fist_trainer.1")
	_check(_said(_ask(yard, trainer, "门房"), "不辞而别") and state.marks.get("李火狮说了门房", 0) == 1, "李火狮: he left without a word")
	_check(_said(_ask(yard, trainer, "说破门房的来历"), "血手刘三") and state.marks.get("说破了刘安禄", 0) == 1, "说破 all the same")
	MapPlaces.enter(session, &"snow.school1", &"snow.school1.gate_return")
	await _settle(tree)
	_check(_count_in(session, &"snow.school1", GUARD) == 0 and _count_in(session, &"snow.crossroad", GUARD) == 0, "he is at the stockade, not at the 山坳")
	_check(_ending_lines(session, &"snow").any(func(line: String) -> bool: return line.contains("二寨主")) and not _ending_lines(session, &"snow").any(func(line: String) -> bool: return line.contains("门房空了一冬")), "the ending keeps the line of the one who went home")


## The lines the ending's card `card_id` would show now.
func _ending_lines(session: WorldSessionController, card_id: StringName) -> Array[String]:
	var ending: EpilogueDefinition = GameContent.catalog().epilogue(&"ending")
	for card: EpilogueDefinition.Card in ending.cards:
		if card.card_id == card_id:
			return card.shown(session.quest_condition_test())
	return []


func _ask(map: WorldMapController, npc: NpcRuntimeState, topic: String) -> Array[String]:
	if map == null or npc == null or not map.select_npc(npc.character_id):
		return []
	return map.ask_selected(topic)


func _recent(ui: SharedGameplayUI, count: int = 12) -> Array[String]:
	var lines: Array[String] = ui.log_lines()
	return lines.slice(maxi(0, lines.size() - count))


func _flee(tree: SceneTree, session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 600:
		for info: CombatTacticalActionInfo in coordinator.action_infos():
			if info.action_id == CombatFleeTacticalPolicy.ACTION_ID:
				coordinator.submit_player_action(CombatTacticalRequest.new(StringName("flee:%d" % rounds), coordinator.active_encounter().encounter_id, player.character_id, info.action_id, info.category))
		coordinator.advance_scheduler(1.0)
		rounds += 1
	session.shared_ui().dismiss_current_panel()
	for _frame: int in range(3):
		await tree.physics_frame


## TEST-ONLY: every standing NPC of `definition_id` on the map leaves for good (as if beaten).
func _clear(map: WorldMapController, definition_id: StringName) -> void:
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.definition().definition_id == definition_id and npc.exists_in_map:
			map.npcs.leave_for_good(npc)


## The instance id of the first of `definition_id` the player carries ("" when none).
func _carried(session: WorldSessionController, definition_id: StringName) -> StringName:
	var map: WorldMapController = session.active_map() as WorldMapController
	if map == null:
		return &""
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)
	for item_id: StringName in map.inventory_state().direct_children(holder):
		var item: ItemInstance = map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			return item_id
	return &""


func _count_in(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> int:
	var found: int = 0
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if npc.definition().definition_id == definition_id and npc.world_location().zone_id == zone_id and npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE):
				found += 1
	return found


func _first(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	var map: WorldMapController = session.world_map_of(MapPlaces.map_of(zone_id))
	if map == null:
		return null
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.exists_in_map and npc.world_location().zone_id == zone_id and NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
			return npc
	return null


func _said(lines: Array, part: String) -> bool:
	return lines.any(func(line: String) -> bool: return line.contains(part))


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("封山", CharacterState.GENDER_MALE)
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
		_failures.append(message)
