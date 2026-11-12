extends RefCounted

## 第九章 E 后果 (owner's plan, 2026-11-06「按你的推荐来」; DECISIONS「第九章 E」), from C's end
## (StoryFixtures.chapter9_compared) or D's (chapter9_done: story_chapter9d_test checks D's play leaves it;
## E adds nothing to the ledger, so the hand-over to 第十章 is that check):
## - 冯策 in his duty room: 刀谱 hands over the 《禁中刀谱》 once the 殿试 is passed (冯策给了刀谱), asked
##   again only 给过你了; 研读 reads 禁中刀 to 40, past it 太浅了; 湖底 refused until he goes down with you.
## - expose (庾子建下狱): the chapter done and the tenth's 旋芒 opened (its 风 step next); 庾子建 gone from his
##   客厅, 庾清尘 from the 内宅 and in the 相国府's yard; the 花匠 says so; 卫沧澜 gone from the 客房 and at the
##   水烟阁 (水烟阁: 老松岭); 葛升 on 庾尚书: 下了狱.
## - deal (私了了庾子建): 庾子建 still in his 客厅, 宋朴 at the 午门, nobody in the 相国府's yard.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const MANUAL: StringName = &"native:imperial/palace_blade_manual"
const FENG: StringName = &"native.npc.feng_ce"
const YU: StringName = &"city.npc.shangshu.shangshu"
const QING: StringName = &"city.npc.shangshu.qing_chen"
const GARDENER: StringName = &"city.npc.shangshu.gardener"
const WEI: StringName = &"native.npc.wei_canglan"
const GE: StringName = &"native.npc.ge_sheng"
const SONG: StringName = &"native.npc.song_pu_messenger"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	for kind: String in ["feng", "expose", "deal"]:
		var session: WorldSessionController = await _session(tree)
		match kind:
			"feng": await _test_feng(tree, session)
			"expose": await _test_expose(tree, session)
			"deal": await _test_deal(tree, session)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var art: SkillDefinition = catalog.skill(&"palace-blade")
	_check(art != null and art.display_name == "禁中刀" and art.action_set() != null and art.action_set().size() == 7 and art.valid_enabled_uses().has(&"blade"), "禁中刀: seven strokes, a blade art")
	var manual: ItemContentDefinition = catalog.item(MANUAL)
	_check(manual != null and manual.no_drop and manual.study != null and manual.study.skill_id == &"palace-blade" and manual.study.max_skill == 40, "《禁中刀谱》 reads 禁中刀 to 40")
	var next: StoryQuestDefinition = catalog.story_quest(&"main.chapter10")
	_check(next != null and next.title == "旋芒" and next.requires.has(&"main.chapter9") and next.steps[0].step_id == &"wind", "第十章 旋芒: after the ninth, the 风 first")


func _ready_for_choice(session: WorldSessionController) -> void:
	StoryFixtures.chapter9_compared(session, false, false, true, false)
	session.record_journal()


func _test_feng(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	_ready_for_choice(session)
	var room: WorldMapController = MapPlaces.enter(session, &"imperial.duty_room", &"imperial.duty_room.feng_ce.1") # TEST-ONLY
	await _settle(tree)
	var feng: NpcRuntimeState = _first(session, &"imperial.duty_room", FENG)
	_check(feng != null and room.select_npc(feng.character_id), "冯策 in his duty room")
	if feng == null:
		return
	_check(_said(room.ask_selected("湖底"), "守的是宫门"), "湖底: not before he goes down with you")
	_check(_said(room.ask_selected("刀谱"), "禁中刀") and state.marks.get("冯策给了刀谱", 0) == 1 and session.player_held_item_ids().get(MANUAL, false), "刀谱: the 《禁中刀谱》 handed over")
	_check(_said(room.ask_selected("刀谱"), "给过你了"), "刀谱 again: 给过你了")
	state.marks["冯策随你下湖"] = 1 # TEST-ONLY: as the expose writes it
	_check(_said(room.ask_selected("湖底"), "算老夫一个"), "湖底: 算老夫一个")
	var manual_id: StringName = _carried(room, MANUAL)
	state.skills.set_raw_level(SkillIds.LITERATE, 10) # TEST-ONLY
	state.progression.combat_experience = 30000 # TEST-ONLY: 研读 wants it
	state.spirit = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY: the 神 it costs
	var first: StudyResult = session.martial_arts().study(manual_id)
	_check(first.outcome == StudyResult.Outcome.STUDIED and ui.log_lines()[-1].contains("禁中刀"), "研读: 禁中刀 begun: %s" % ui.log_lines()[-1])
	state.skills.set_raw_level(&"palace-blade", 40) # TEST-ONLY
	_check(session.martial_arts().study(manual_id).outcome == StudyResult.Outcome.STUDIED, "at 40 the book still has something to say")
	state.skills.set_raw_level(&"palace-blade", 41) # TEST-ONLY
	_check(session.martial_arts().study(manual_id).outcome == StudyResult.Outcome.TOO_SHALLOW, "past 40: 太浅了")


func _test_expose(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.chapter9_done(session, "expose", false, true, false)
	session.record_journal()
	var catalog: ContentCatalog = GameContent.catalog()
	var next: StoryQuestDefinition = catalog.story_quest(&"main.chapter10")
	_check(StoryQuestLog.is_done(state, catalog.story_quest(&"main.chapter9")) and StoryQuestLog.current_step(state, next) != null and StoryQuestLog.current_step(state, next).step_id == &"wind", "expose: the ninth done, the tenth's 风 next")
	MapPlaces.enter(session, &"city.shangshu.keting", &"city.shangshu.keting.shangshu.1") # TEST-ONLY
	await _settle(tree)
	_check(_first(session, &"city.shangshu.keting", YU) == null, "expose: 庾子建 gone from his 客厅")
	_check(_first(session, &"city.shangshu.neizhai", QING) == null, "expose: 庾清尘 gone from the 内宅")
	_check(_first(session, &"city.shangshu.kefang", WEI) == null, "expose: 卫沧澜 gone from the 客房")
	var garden: WorldMapController = MapPlaces.enter(session, &"city.shangshu.huayuan", &"city.shangshu.huayuan.gardener.1") # TEST-ONLY
	await _settle(tree)
	var gardener: NpcRuntimeState = _first(session, &"city.shangshu.huayuan", GARDENER)
	_check(gardener != null and garden.select_npc(gardener.character_id) and _said(garden.ask_selected("庾清尘"), "相国府"), "expose: the 花匠: 小姐去了相国府")
	MapPlaces.enter(session, &"city.xiangguo_yard", &"city.xiangguo_yard.qing_chen.1") # TEST-ONLY
	await _settle(tree)
	_check(_first(session, &"city.xiangguo_yard", QING) != null, "expose: 庾清尘 in the 相国府's yard")
	var hall: WorldMapController = MapPlaces.enter(session, &"waterfog.guildhall", &"waterfog.guildhall.wei_canglan.1") # TEST-ONLY
	await _settle(tree)
	var wei: NpcRuntimeState = _first(session, &"waterfog.guildhall", WEI)
	_check(wei != null and hall.select_npc(wei.character_id) and _said(hall.ask_selected("水烟阁"), "老松岭"), "expose: 卫沧澜 at the 水烟阁 (老松岭)")
	var school: WorldMapController = MapPlaces.enter(session, &"city.jiaowu", &"city.jiaowu.ge_sheng.1") # TEST-ONLY
	await _settle(tree)
	var ge: NpcRuntimeState = _first(session, &"city.jiaowu", GE)
	_check(ge != null and school.select_npc(ge.character_id) and _said(school.ask_selected("庾尚书"), "下了狱"), "expose: 葛升: 尚书下了狱")
	_check(_first(session, &"city.wumen", SONG) == null, "expose: no 宋朴 at the 午门")
	# Save and Continue with the ninth chapter done, exact.
	var walker: RefCounted = Work.new()
	await walker.round_trip(tree, session, Work.capture(session), "第九章 E (expose)")
	_check(walker._failures.is_empty(), "expose: the save reads back exactly: %s" % [walker._failures])


func _test_deal(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	StoryFixtures.chapter9_done(session, "deal", false, true, false)
	session.record_journal()
	_check(StoryQuestLog.is_done(state, GameContent.catalog().story_quest(&"main.chapter9")), "deal: the ninth done")
	MapPlaces.enter(session, &"city.shangshu.keting", &"city.shangshu.keting.shangshu.1") # TEST-ONLY
	await _settle(tree)
	_check(_first(session, &"city.shangshu.keting", YU) != null and _first(session, &"city.shangshu.neizhai", QING) != null, "deal: 庾子建 and his daughter stay")
	MapPlaces.enter(session, &"city.wumen", &"city.wumen.song_pu.1") # TEST-ONLY
	await _settle(tree)
	_check(_first(session, &"city.wumen", SONG) != null, "deal: 宋朴 at the 午门")
	MapPlaces.enter(session, &"city.xiangguo_yard", &"city.xiangguo_yard.qing_chen.1") # TEST-ONLY
	await _settle(tree)
	_check(_first(session, &"city.xiangguo_yard", QING) == null, "deal: nobody new in the 相国府's yard")


func _said(lines: Array, part: String) -> bool:
	return lines.any(func(line: String) -> bool: return line.contains(part))


func _carried(map: WorldMapController, definition_id: StringName) -> StringName:
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, map.session.player_runtime().character_id)
	for item_id: StringName in map.inventory_state().direct_children(holder):
		var item: ItemInstance = map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			return item_id
	return &""


func _first(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> NpcRuntimeState:
	for npc: NpcRuntimeState in session.world_map_of(MapPlaces.map_of(zone_id)).resident_npcs():
		if npc.exists_in_map and npc.world_location().zone_id == zone_id and NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
			return npc
	return null


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("番坊", CharacterState.GENDER_MALE)
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
