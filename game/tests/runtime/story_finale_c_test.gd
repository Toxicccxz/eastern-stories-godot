extends RefCounted

## 终章 C 归乡 (owner's plan build/plans/终章_计划.md, 2026-11-08「按推荐的做」; DECISIONS「终章 C」「结局讲述」),
## from 第十章's ledger with the battle done (TEST-ONLY marks):
## - The data: the ending's fourteen cards, `final` the player in the ice, the three heralds by side.
## - 灭, the expose ledger: up on the lakeside the 雪亭 square has 冯策 with the edict: the 宣诏 read (妖氛已靖,
##   庾子建 问罪), 宣过诏, the ending told over the 沙盘 once the box is read — the cards that hold for this
##   ledger, in order, 店小二 on the clear lake, 那少年，便是你 — the world held while it is told and let go
##   after; the finale done, 终章, the milestone; the world goes on.
## - 再封 by 瑷伦, the uncle's ledger: 於兰天武 reads; the 封坛 card has 瑷伦 in the ice, 店小二 the man in the ice;
##   晚月庄's 瑷伦 gone from her room, 萧辟尘 still at the 水烟阁.
## - 你自己: 璃虹's 我留下 tells the ending at once, final (那少年，留在了冰里).

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const TABLE: Array[String] = ["霍铮回了寨", "关北的骑兵欠你一阵", "大秦人留下了", "冰龙倒了", "冯策随你下湖", "宝衣给了安妮儿", "替南危水保密", "卫沧澜出了尚书府", "瑷伦守到决战", "带走了宝衣"]
const DONE: Array[String] = ["点过将", "下了决战", "终章下了湖底", "商玦倒了", "回到了湖底", "侮天鬼成形", "侮天鬼倒了"]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	for kind: String in ["slay", "seal", "self"]:
		var session: WorldSessionController = await _session(tree)
		match kind:
			"slay": await _test_slay(tree, session)
			"seal": await _test_seal(tree, session)
			"self": await _test_self(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var ending: EpilogueDefinition = catalog.epilogue(&"ending")
	_check(ending != null and ending.cards.size() == 14 and ending.final != null and ending.final.key == "你留在了冰里", "the ending: fourteen cards, final for the player in the ice")
	_check(ending.cards.slice(0, 10).all(func(card: EpilogueDefinition.Card) -> bool: return catalog.map(card.place) != null), "ten places, each a map of the world")
	for herald: StringName in [&"native.square.herald_feng_ce", &"native.square.herald_uncle", &"native.square.herald_ministry"]:
		var spawn: NpcSpawnDefinition = catalog.spawn(herald)
		_check(spawn != null and spawn.zone_id == &"snow.square" and spawn.until != null and spawn.until.key == "宣过诏", "%s on the square until the edict is read" % herald)
	var quest: StoryQuestDefinition = catalog.story_quest(&"main.finale")
	_check(quest.reward.milestone and quest.reward.marks == ["终章"] and quest.step(&"home").condition.key == "宣过诏", "the finale ends with the edict: 终章 and the milestone")


func _test_slay(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	_ledger(session, "self", "expose", false, ["霍铮回了寨", "关北的骑兵欠你一阵", "大秦人留下了", "冯策随你下湖", "宝衣给了安妮儿", "替南危水保密", "能灭它", "侮天鬼灭了", "终章上了岸"], ["main.finale/end/slay"])
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.finale")
	_check(StoryQuestLog.current_step(state, quest).step_id == &"home", "up on the lakeside: home next")
	var square: WorldMapController = MapPlaces.enter(session, &"snow.square", &"snow.square.inn_entry") # TEST-ONLY
	await _settle(tree)
	_check(_first(session, &"snow.square", &"native.npc.herald_feng_ce") != null and _first(session, &"snow.square", &"native.npc.herald_uncle") == null, "冯策 with the edict (the expose ledger)")
	await _beats(tree, session, 4)
	_check(_said(ui.log_lines(), "妖氛已靖") and _said(ui.log_lines(), "即日问罪") and state.marks.get("宣过诏", 0) == 1, "the 宣诏: 妖氛已靖, 庾子建 问罪")
	ui.dialogue_box.close()
	await _settle(tree)
	var overlay: EpilogueOverlay = ui.epilogue
	_check(overlay.active() and session.presentation_held(WorldSessionController.EPILOGUE_HOLD), "the ending told, the world held")
	var titles: Array[String] = await _read_all(tree, overlay)
	_check(titles.size() >= 12 and titles[0].contains("雪亭镇") and titles[-1].contains("东方故事"), "the cards that say something, 雪亭镇 first, the credits last (a card with nothing for the ledger is passed over: %s)" % [titles])
	var all_lines: String = "\n".join(titles)
	_check(all_lines.contains("湖水清得能看见底") and all_lines.contains("那少年，便是你") and all_lines.contains("天牢里过了冬") and not all_lines.contains("留在了冰里"), "店小二 on the clear lake; 那少年，便是你; 庾子建 in the 天牢")
	await _until_finished(tree, overlay)
	session.record_journal()
	_check(not overlay.active() and not session.presentation_held(WorldSessionController.EPILOGUE_HOLD), "told: the world let go")
	_check(StoryQuestLog.is_done(state, quest) and state.marks.get("终章", 0) == 1 and DeedLog.done(state, "从玉螺湖底回到了雪亭镇，听了宣诏"), "the finale done: 终章 and its deed")
	_check(square != null and session.active_map() == square, "the world goes on where it was")


func _test_seal(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	_ledger(session, "uncle", "uncle", false, ["瑷伦守到决战", "叫来了瑷伦", "瑷伦留在了冰里", "再封了侮天鬼", "终章上了岸"], ["main.finale/end/seal_elon"])
	var test: Callable = session.quest_condition_test()
	var shown: Array[Array] = GameContent.catalog().epilogue(&"ending").shown(test)
	var text: String = "\n".join(shown.map(func(entry: Array) -> String: return "\n".join(entry[1])))
	_check(text.contains("瑷伦披着宝衣站着") and text.contains("湖底冰里站着一个人") and text.contains("守衣人去守另一件东西了") and not text.contains("湖水清得"), "the seal card: 瑷伦 in the ice; 店小二 on the man in the ice")
	_check(not GameContent.catalog().epilogue(&"ending").ends_journey(test), "the world goes on after it")
	MapPlaces.enter(session, &"snow.square", &"snow.square.inn_entry") # TEST-ONLY
	await _settle(tree)
	_check(_first(session, &"snow.square", &"native.npc.herald_uncle") != null, "於兰天武 reads it on the uncle's ledger")
	MapPlaces.enter(session, &"latemoon.room.eastroom", &"latemoon.room.eastroom.elon.1") # TEST-ONLY
	await _settle(tree)
	_check(_first(session, &"latemoon.room.eastroom", &"latemoon.npc.room.elon") == null, "瑷伦 gone from her room: she is in the ice")
	MapPlaces.enter(session, &"waterfog.guildhall", &"waterfog.guildhall.master.1") # TEST-ONLY
	await _settle(tree)
	_check(_first(session, &"waterfog.guildhall", &"common.npc.fighter.master") != null, "萧辟尘 still at the 水烟阁 (he did not stay)")


func _test_self(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	_ledger(session, "self", "deal", true, ["冰龙倒了", "带走了宝衣", "璃虹说了或者是你"], [])
	var ended: Array[bool] = []
	session.epilogue_ended.connect(func(final: bool) -> void: ended.append(final))
	var altar: WorldMapController = MapPlaces.enter(session, &"village.seal_altar", &"village.seal_altar.pool_arrival") # TEST-ONLY
	await _settle(tree)
	var lihong: NpcRuntimeState = _first(session, &"village.seal_altar", &"native.npc.lihong_finale")
	_check(lihong != null and altar.select_npc(lihong.character_id) and _said(altar.ask_selected("我留下"), "好"), "我留下")
	ui.dialogue_box.close()
	await _settle(tree)
	_check(state.marks.get("你留在了冰里", 0) == 1 and ui.epilogue.active(), "the ending told at once")
	var titles: Array[String] = await _read_all(tree, ui.epilogue)
	var all_lines: String = "\n".join(titles)
	_check(all_lines.contains("站着一个年轻人") and all_lines.contains("那少年，留在了冰里") and all_lines.contains("楼上那间房"), "the player in the ice: 那少年，留在了冰里")
	await _until_finished(tree, ui.epilogue)
	_check(ended == [true], "the journey ends with it (%s)" % [ended])


## Every card's title and lines as shown, going on through them.
func _read_all(tree: SceneTree, overlay: EpilogueOverlay) -> Array[String]:
	var seen: Array[String] = []
	for frame: int in 30:
		if overlay.card_index() >= 0:
			break
		await tree.process_frame
	while overlay.active() and overlay.card_index() >= 0:
		seen.append(overlay.shown_title() + "\n" + overlay.shown_lines())
		var at: int = overlay.card_index()
		overlay.advance()
		if overlay.card_index() == at:
			break
	return seen


func _until_finished(tree: SceneTree, overlay: EpilogueOverlay) -> void:
	for frame: int in 240:
		if not overlay.active() and not overlay.visible:
			break
		await tree.process_frame


func _ledger(session: WorldSessionController, who: String, side: String, pulled: bool, marks: Array, keys: Array) -> void:
	StoryFixtures.chapter10_done(session, who, side, pulled)
	var state: CharacterState = session.player_runtime().state
	for mark: String in TABLE:
		state.marks.erase(mark) # TEST-ONLY
	for mark: String in marks + DONE:
		state.marks[mark] = 1 # TEST-ONLY
	for key: String in ["main.finale#started", "main.finale/lake", "main.finale/gather", "main.finale/shore", "main.finale/hall", "main.finale/depths", "main.finale/demon"] + keys:
		state.quests[key] = state.quests.size() + 1 # TEST-ONLY: as A and B write them
	session.record_journal()


func _beats(tree: SceneTree, session: WorldSessionController, seconds: int) -> void:
	for second: int in seconds:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)


func _said(lines: Array, part: String) -> bool:
	return lines.any(func(line: String) -> bool: return line.contains(part))


func _first(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	var map: WorldMapController = session.world_map_of(MapPlaces.map_of(zone_id))
	if map == null:
		return null
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.exists_in_map and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD and npc.world_location().zone_id == zone_id and NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
			return npc
	return null


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("终章", CharacterState.GENDER_MALE)
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
