extends RefCounted

## 终章 B 湖底 (owner's plan build/plans/终章_计划.md, 2026-11-08「按推荐的做」; DECISIONS「终章 B」), from 第十章's
## ledger with the night of A done (下了决战, the dive: 终章下了湖底) — TEST-ONLY marks; a character grown to
## 15 万 exp fights each fight out on 自动, empty-handed (how hard it is for the main story's own, sword in
## hand and every beat ordered: boss_strength_finale_test / boss_strength_demon_test):
## - The data: main.finale's eight steps, 侮天鬼's four forms (stronger without the robe, stronger grown),
##   the keepers' 穿灵, 璃虹's feather, the services of the 封坛.
## - 灭 (seal kept, 旋芒 in hand, 安妮儿 with the robe, every 帮手, 能灭它): the 冰龙厅 — 商玦's two lines,
##   the dragons on his four, 冯策 beside; 商玦 down; the pool asked first; the 封坛 with 安妮儿; 穿灵 drawn
##   now (asked first), the robe's form; down; 钉下去 asked first — 旋芒, the robe, the nail, 璃虹 out of the
##   ice: 侮天鬼灭了; up at dawn to the lakeside, home next.
## - 再封 (the sword drawn in 第八章, 冰龙 beaten, 瑷伦 called, 萧辟尘 with 旋芒, 南危水): his four come at
##   the player; the grown form with the robe (瑷伦's); 钉下去 says only a seal; 瑷伦 on 留下, 穿灵 given her:
##   瑷伦留在了冰里, the seal option, 再封了侮天鬼; her figure in the ice once one comes again.
## - 你自己: on a ledger with nobody to stay, 璃虹 on 留下 says 或者是你, and 我留下 is the player's.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Grown := preload("res://tests/support/grown_character.gd")
const GROWN_EXP: int = 150000
const SWORD: StringName = &"native:village/soul_impaler"
const XUANMANG: StringName = &"native:lancheng/xuanmang"
const FEATHER: StringName = &"native:village/lihong_feather"
const HALL: StringName = &"village.lakebottom2"
const ALTAR: StringName = &"village.seal_altar"
const TABLE: Array[String] = ["霍铮回了寨", "关北的骑兵欠你一阵", "大秦人留下了", "冰龙倒了", "冯策随你下湖", "宝衣给了安妮儿", "替南危水保密", "卫沧澜出了尚书府", "瑷伦守到决战", "带走了宝衣"]
const NIGHT: Array[String] = ["点过将", "下了决战", "终章下了湖底"]

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
	var quest: StoryQuestDefinition = catalog.story_quest(&"main.finale")
	_check(quest.steps.map(func(step: StoryQuestDefinition.Step) -> StringName: return step.step_id) == [&"lake", &"gather", &"shore", &"hall", &"depths", &"demon", &"end", &"home"], "main.finale: eight steps")
	var end: StoryQuestDefinition.Step = quest.step(&"end")
	_check(end.options.size() == 6 and end.option(&"slay") != null and end.option(&"seal_self") != null and end.options.slice(1).all(func(option: StoryQuestDefinition.Option) -> bool: return option.reward.marks == ["再封了侮天鬼"]), "灭, or five ways to seal it again (each marks 再封了侮天鬼)")
	var forms: Array = [&"native.npc.wutian_gui", &"native.npc.wutian_gui_blazing", &"native.npc.wutian_gui_grown", &"native.npc.wutian_gui_grown_blazing"]
	# DECISIONS「主线必打的仗」second round: the four forms fight alike (both builds near the band's
	# ends leave no room for a spread); which one comes is still the robe's and the pull's. The fights
	# themselves are boss_strength_demon_test's.
	var kee: Array = forms.map(func(id: StringName) -> int: return catalog.npc(id).resource_overrides().vitality().maximum())
	_check(kee.all(func(value: int) -> bool: return value == kee[0] and value > 0), "侮天鬼: the four forms alike in kee %s" % [kee])
	_check(forms.all(func(id: StringName) -> bool: return catalog.npc(id).talk().inquiry_topics().is_empty()), "妖魔不解释: no topics")
	var sword: ItemContentDefinition = catalog.item(SWORD)
	_check(sword.give_to.has(&"native.npc.elon_altar") and sword.give_to.has(&"native.npc.lihong"), "穿灵 can be given to a keeper")
	for id: StringName in [&"village.seal_altar.face", &"village.seal_altar.nail"]:
		_check(catalog.service(id) != null, "%s" % id)


func _test_slay(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	_ledger(session, "self", "expose", false, ["霍铮回了寨", "关北的骑兵欠你一阵", "大秦人留下了", "冯策随你下湖", "宝衣给了安妮儿", "替南危水保密", "能灭它"])
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.finale")
	_check(StoryQuestLog.current_step(state, quest).step_id == &"hall", "after the dive: the 冰龙厅 next")
	var hall: WorldMapController = MapPlaces.enter(session, HALL, &"village.lakebottom2.pool_return") # TEST-ONLY
	await _settle(tree)
	await _until_fight(tree, session, hall)
	_check(_said(ui.log_lines(), "五千年的头") and _said(ui.log_lines(), "白鳞冰龙") and _said(ui.log_lines(), "还债"), "商玦's two lines; the dragons fall on his four")
	_check(_first(session, HALL, &"native.npc.niling_taoist_lake") == null and _first(session, HALL, &"native.npc.feng_ce_lakebottom") != null, "no 道士 left standing; 冯策 beside")
	await _fight_out(tree, session, hall)
	session.record_journal()
	_check(state.marks.get("商玦倒了", 0) == 1 and StoryQuestLog.current_step(state, quest).step_id == &"depths", "商玦 down: down the pool next")
	var altar: WorldMapController = await _dive(tree, session, hall)
	_check(altar != null and _first(session, ALTAR, &"native.npc.annie_altar") != null and _first(session, ALTAR, &"native.npc.elon_altar") == null, "the 封坛: 安妮儿 with the robe")
	await _act(tree, altar, &"village.seal_altar.face")
	_check(_said(_recent(ui), "钉还钉着"), "迎上去 on the kept ledger: the nail first")
	await _act(tree, altar, &"village.seal_altar.pull")
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("当场成形"), "穿灵 drawn now: asked first")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(session.player_held_item_ids().has(SWORD) and state.marks.get("侮天鬼成形", 0) == 1 and _said(_recent(ui), "宝衣的下摆一展"), "the sword in hand; it takes shape, the robe holds its flame")
	_check(_first(session, ALTAR, &"native.npc.wutian_gui") != null and _first(session, ALTAR, &"native.npc.wutian_gui_blazing") == null, "the form the robe faces")
	await _until_fight(tree, session, altar)
	await _fight_out(tree, session, altar)
	session.record_journal()
	_check(state.marks.get("侮天鬼倒了", 0) == 1 and StoryQuestLog.current_step(state, quest).step_id == &"end", "侮天鬼 down: the last stroke next")
	await _act(tree, altar, &"village.seal_altar.nail")
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("灭了它") and ui.confirm_prompt.message.text.contains("就烧成灰了") and ui.confirm_prompt.message.text.contains("留下"), "钉下去 asked first, both sides' cost said (主线修补 A)")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	session.record_journal()
	var said: Array[String] = _recent(ui, 20)
	_check(_said(said, "你拔出旋芒") and _said(said, "宝衣的下摆一展") and _said(said, "头裂开了") and _said(said, "璃虹从冰里走出来"), "旋芒, the robe, the nail; 璃虹 out of the ice (%s)" % [said])
	_check(state.marks.get("侮天鬼灭了", 0) == 1 and StoryQuestLog.took(state, quest, &"slay") and DeedLog.done(state, "在玉螺湖底灭了侮天鬼"), "侮天鬼灭了: the option and the deed")
	_check(_said(said, "化成了灰") and state.marks.get("宝衣烧了", 0) == 1, "the robe burns with the last flame: 宝衣烧了 (主线修补 A)")
	await _act(tree, altar, &"village.seal_altar.pool")
	await _settle(tree)
	session.record_journal()
	_check(session.active_map().map_id() == &"village.main" and session.day_phase_id() == &"dawn" and state.marks.get("终章上了岸", 0) == 1 and StoryQuestLog.current_step(state, quest).step_id == &"home", "up at dawn to the lakeside; home next")


func _test_seal(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	_ledger(session, "xiao", "deal", true, ["冰龙倒了", "瑷伦守到决战", "叫来了瑷伦", "替南危水保密"])
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.finale")
	var hall: WorldMapController = MapPlaces.enter(session, HALL, &"village.lakebottom2.pool_return") # TEST-ONLY
	await _settle(tree)
	await _until_fight(tree, session, hall)
	_check(_said(ui.log_lines(), "四个黑冠道士") and _first(session, HALL, &"native.npc.feng_ce_lakebottom") == null, "the dragons beaten: his four come; no 冯策 on this ledger")
	await _fight_out(tree, session, hall)
	session.record_journal()
	_check(state.marks.get("商玦倒了", 0) == 1, "商玦 and his four down")
	var altar: WorldMapController = await _dive(tree, session, hall)
	for npc_id: StringName in [&"native.npc.elon_altar", &"native.npc.xiao_pichen_altar", &"native.npc.nan_weishui_altar", &"native.npc.lihong_finale"]:
		_check(_first(session, ALTAR, npc_id) != null, "%s at the 封坛" % npc_id)
	await _act(tree, altar, &"village.seal_altar.face")
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("三百年"), "迎上去 asked first")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	_check(_first(session, ALTAR, &"native.npc.wutian_gui_grown") != null and _said(_recent(ui), "宝衣的下摆一展"), "grown, the robe 瑷伦's")
	await _until_fight(tree, session, altar)
	await _fight_out(tree, session, altar)
	session.record_journal()
	await _act(tree, altar, &"village.seal_altar.nail")
	_check(not ui.is_asking() and _said(_recent(ui), "只能再封") and _said(_recent(ui), "问他们「留下」"), "钉下去: only a seal; ask them")
	var elon: NpcRuntimeState = _first(session, ALTAR, &"native.npc.elon_altar")
	_check(elon != null and altar.select_npc(elon.character_id) and _said(altar.ask_selected("留下"), "把穿灵给我"), "瑷伦 on 留下")
	var rule: NpcObjectRule = elon.definition().dealings().object_rules[2]
	_check(rule.item == SWORD and rule.ask.contains("再封") and rule.mark_giver == "瑷伦留在了冰里", "giving her 穿灵 is asked first")
	var given: ItemHandlingResult = altar.give_to_selected(_carried(altar, SWORD))
	await _settle(tree)
	if ui.is_asking():
		ui.confirm_prompt.confirm_button.pressed.emit()
		await _settle(tree)
	session.record_journal()
	_check(given.done() and state.marks.get("瑷伦留在了冰里", 0) == 1 and not session.player_held_item_ids().has(SWORD), "穿灵 hers: 瑷伦留在了冰里")
	_check(StoryQuestLog.took(state, quest, &"seal_elon") and state.marks.get("再封了侮天鬼", 0) == 1 and DeedLog.done(state, "在玉螺湖底再封了侮天鬼，瑷伦留在了冰里"), "the seal option, its mark and deed")
	await _act(tree, altar, &"village.seal_altar.pool")
	await _settle(tree)
	_check(session.active_map().map_id() == &"village.main", "up to the lakeside")
	# Nobody kept the shore on this ledger: the 鬼卒 waiting there come at the player as they surface.
	var shore: WorldMapController = session.active_map() as WorldMapController
	await _until_fight(tree, session, shore)
	_check(_first(session, &"village.lakeside", &"native.npc.hell_runner_finale") != null, "the 鬼卒 nobody kept wait on the shore")
	await _fight_out(tree, session, shore)
	MapPlaces.enter(session, ALTAR, &"village.seal_altar.pool_arrival") # TEST-ONLY: down again
	await _settle(tree)
	_check(_first(session, ALTAR, &"native.npc.elon_ice") != null and _first(session, ALTAR, &"native.npc.elon_altar") == null, "瑷伦 in the ice now")
	_check(_first(session, ALTAR, &"native.npc.nan_weishui_altar") == null and _first(session, ALTAR, &"native.npc.xiao_pichen_altar") == null and _first(session, ALTAR, &"native.npc.nan_weishui_ice") == null, "the others gone home; only who stayed is in the ice")


func _test_self(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	_ledger(session, "self", "deal", true, ["冰龙倒了", "带走了宝衣", "瑷伦守到决战", "叫来了瑷伦", "商玦倒了", "回到了湖底", "侮天鬼成形", "侮天鬼倒了"])
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.finale")
	var altar: WorldMapController = MapPlaces.enter(session, ALTAR, &"village.seal_altar.pool_arrival") # TEST-ONLY
	await _settle(tree)
	var lihong: NpcRuntimeState = _first(session, ALTAR, &"native.npc.lihong_finale")
	_check(lihong != null and altar.select_npc(lihong.character_id), "璃虹 come down")
	if lihong == null:
		return
	_check(_said(altar.ask_selected("我留下"), "你在说什么"), "我留下 before she says it: nothing")
	_check(_said(altar.ask_selected("留下"), "或者是你") and state.marks.get("璃虹说了或者是你", 0) == 1, "璃虹 on 留下: 或者是你")
	_check(_said(altar.ask_selected("我留下"), "好") and state.marks.get("你留在了冰里", 0) == 1, "我留下: the player stays")
	session.record_journal()
	_check(StoryQuestLog.took(state, quest, &"seal_self") and state.marks.get("再封了侮天鬼", 0) == 1, "the seal option of one's own")
	var elon: NpcRuntimeState = _first(session, ALTAR, &"native.npc.elon_altar")
	_check(elon != null and altar.select_npc(elon.character_id), "瑷伦 still there")
	if elon != null:
		altar.give_to_selected(_carried(altar, SWORD))
		await _settle(tree)
		_check(state.marks.get("瑷伦留在了冰里", 0) == 0 and session.player_held_item_ids().has(SWORD), "once the player stayed, no one else stays: 穿灵 refused")


## 第十章's ledger, the choices' marks, A's night done; the swords and the feather in hand as the ledger has them.
func _ledger(session: WorldSessionController, who: String, side: String, pulled: bool, marks: Array) -> void:
	StoryFixtures.chapter10_done(session, who, side, pulled)
	var state: CharacterState = session.player_runtime().state
	for mark: String in TABLE:
		state.marks.erase(mark) # TEST-ONLY
	for mark: String in marks + NIGHT:
		state.marks[mark] = 1 # TEST-ONLY
	for key: String in ["main.finale#started", "main.finale/lake", "main.finale/gather", "main.finale/shore"]:
		state.quests[key] = state.quests.size() + 1 # TEST-ONLY: as A writes them
	var map: WorldMapController = session.active_map() as WorldMapController
	if who == "self":
		map.give_new_item_to_player(XUANMANG) # TEST-ONLY
	if pulled:
		map.give_new_item_to_player(SWORD) # TEST-ONLY
	else:
		map.give_new_item_to_player(FEATHER) # TEST-ONLY
	session.day_clock().set_day_seconds(80000) # TEST-ONLY: the night of the battle (A's 等到天黑)
	# TEST-ONLY: a character grown well past the finale's arrival (DECISIONS「主线必打的仗」: 37275 on the main
	# story alone, 52294 exploring on the way), 柳家拳 empty-handed on 自动 (ES2's courage gate): at 8 万 it
	# lost to 商玦 and his four; the fights are fought out as they come.
	Grown.grow(state, GROWN_EXP)
	session.record_journal()


func _until_fight(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	for second: int in 30:
		if coordinator.has_active_encounter():
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
		map.hostilities.process_pending_aggression()
	_check(coordinator.has_active_encounter(), "a fight opens on %s" % map.map_id())


func _fight_out(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	coordinator.set_manual_turns(false) # TEST-ONLY
	BattlePace.after_knockout = BattlePace.AfterKnockout.FINISH
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 3000:
		coordinator.advance_scheduler(1.0)
		rounds += 1

	BattlePace.after_knockout = BattlePace.AfterKnockout.ASK
	session.shared_ui().dismiss_current_panel()
	await _settle(tree)
	_check(not coordinator.has_active_encounter(), "the fight on %s over in %d rounds" % [map.map_id(), rounds])


func _dive(tree: SceneTree, session: WorldSessionController, hall: WorldMapController) -> WorldMapController:
	var ui: SharedGameplayUI = session.shared_ui()
	await _act(tree, hall, &"village.lakebottom2.pool")
	_check(ui.is_asking() and ui.confirm_prompt.message.text.contains("去见它"), "the pool asked first")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	session.record_journal()
	_check(session.active_map().map_id() == &"village.seal_chamber" and session.player_runtime().state.marks.get("回到了湖底", 0) == 1, "down to the 封坛")
	return session.active_map() as WorldMapController


func _act(tree: SceneTree, map: WorldMapController, service_id: StringName) -> void:
	var service: ActService = map.service(service_id) as ActService
	var reached: bool = service != null and await MapPlaces.drive(tree, map, MapPlaces.service_spot(map, service_id)) and service.in_reach()
	_check(reached, "within reach of %s" % service_id)
	if reached:
		service.interact()
	await _settle(tree)


func _carried(map: WorldMapController, definition_id: StringName) -> StringName:
	var holder := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, map.session.player_runtime().character_id)
	for item_id: StringName in map.inventory_state().direct_children(holder):
		var item: ItemInstance = map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			return item_id
	return &""


func _recent(ui: SharedGameplayUI, count: int = 12) -> Array[String]:
	var lines: Array[String] = ui.log_lines()
	return lines.slice(maxi(0, lines.size() - count))


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
