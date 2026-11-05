extends RefCounted

## 番坊 A and B (DECISIONS「番坊 A」「番坊 B」): the region's seven maps — the 海崖道 from the south end
## of the path outside 忘情谷 (fanfang.cliff_road), the port (fanfang.dock), the bazaar's street with
## 铁盾会's gate and the lane south (fanfang.bazaar), the 市舶司 (fanfang.customs), 铁盾会's yard and
## the 会首's hut (fanfang.hall), the 拜火祠 (fanfang.fire_temple) and 日陀罗寺 (fanfang.lama_temple)
## — their seventeen native rooms, the ways between them and back up to 玉螺湖村, the people at their
## posts, the vendors and their goods, the landmarks' texts, the 兵部文书 (its second sentence for one
## who learned the 印色), the 火前问话's branches, 卢卡 at the gate only after 关北, 龙若法王's 剃度
## (master.c's words), and a Save/Continue round trip from the office. Walks use the move actions
## (MapPlaces). The chapter's steps are story_chapter7_test.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const MapPlaces := preload("res://tests/support/map_places.gd")
const MAPS: Dictionary = {&"fanfang.cliff_road": 3, &"fanfang.port": 2, &"fanfang.bazaar": 4, &"fanfang.customs": 2, &"fanfang.shield_hall": 2, &"fanfang.fire_temple": 2, &"fanfang.lama_temple": 2}
## Where each kind stands (卢卡 is counted on the walk: he comes after 关北).
const PEOPLE: Dictionary = {
	&"fanfang.cliff_path": {&"native.npc.salt_porter": 2},
	&"fanfang.dock": {&"native.npc.boatman": 2, &"native.npc.cargo_merchant": 2, &"native.npc.tax_clerk": 1},
	&"fanfang.shed": {&"native.npc.boatman": 1},
	&"fanfang.bazaar_west": {&"native.npc.glass_merchant": 1, &"native.npc.carpet_merchant": 1, &"native.npc.storyteller": 1},
	&"fanfang.bazaar_east": {&"native.npc.spice_merchant": 1, &"native.npc.stall_child": 1, &"native.npc.copper_merchant": 1},
	&"fanfang.office": {&"native.npc.feng_lu": 1, &"native.npc.customs_clerk": 1},
	&"fanfang.yard": {&"native.npc.customs_runner": 2},
	&"fanfang.shield_yard": {&"native.npc.shield_swordsman": 6},
	&"fanfang.hall": {&"native.npc.andun": 1},
	&"fanfang.fire_hall": {&"native.npc.fire_priest": 1, &"native.npc.fire_worshipper": 2},
	&"fanfang.temple_yard": {&"fanfang.npc.lama_master": 1, &"native.npc.indian_monk": 1},
	&"fanfang.shrine": {&"native.npc.indian_monk": 1},
}

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	await _test_walk(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var maps: Dictionary = {}
	for zone: ZoneDefinition in catalog.zones():
		if String(zone.zone_id).begins_with("fanfang."):
			maps[zone.map_id] = maps.get(zone.map_id, 0) + 1
			_check(zone.room_ids().size() == 1 and catalog.room(zone.room_ids()[0]) != null and String(zone.room_ids()[0]).begins_with("native:fanfang/"), "%s: one native room" % zone.zone_id)
	_check(maps == MAPS, "seventeen native rooms on seven maps: %s" % maps)
	_check(catalog.region(&"fanfang").display_name == "番坊", "the region is 番坊")
	_check(catalog.map(&"fanfang.customs").interior and not catalog.map(&"fanfang.cliff_road").interior and not catalog.map(&"fanfang.port").interior and not catalog.map(&"fanfang.bazaar").interior, "the 市舶司 is indoors, the road, the dock and the bazaar outdoors")
	_check(catalog.map(&"fanfang.shield_hall").interior and catalog.map(&"fanfang.fire_temple").interior and catalog.map(&"fanfang.lama_temple").interior, "铁盾会, the 拜火祠 and 日陀罗寺 are buildings of their own (番坊 B)")
	_check(catalog.portal(&"fanfang.bazaar_north.north").destination_zone_id == &"fanfang.shield_yard" and catalog.portal(&"fanfang.shield_yard.south").destination_zone_id == &"fanfang.bazaar_north", "铁盾会's gate opens onto its yard, and back to the lane")
	_check(catalog.portal(&"fanfang.bazaar_east.east").destination_zone_id == &"fanfang.fire_hall" and catalog.portal(&"fanfang.fire_hall.west").destination_zone_id == &"fanfang.bazaar_east", "the 拜火祠's door off the street's east end, and out")
	_check(catalog.portal(&"fanfang.bazaar_slope.south").destination_zone_id == &"fanfang.temple_yard" and catalog.portal(&"fanfang.temple_yard.north").destination_zone_id == &"fanfang.bazaar_slope", "the lane slopes south to 日陀罗寺's yard, and back")
	for id: StringName in [&"fanfang.fire_hall.landmark.fire", &"fanfang.hall.landmark.tablet", &"fanfang.temple_yard.landmark.banyan", &"fanfang.shrine.landmark.buddha"]:
		_check(catalog.landmark(id) != null, "landmark %s" % id)
	var questions: ServiceDefinition = catalog.service(&"fanfang.fire_hall.questions")
	_check(questions != null and questions.act != null and questions.act.verb == "问话" and questions.act.acts.size() == 6, "the 火前问话: six branches (the day the fire refused — at dawn, and after; the tablet in hand; the 大秦人's side; the 浪人's; the undecided)")
	if questions != null and questions.act != null and questions.act.acts.size() == 6:
		var asked: ScriptedAct = questions.act.acts[3]
		var last: ScriptedAct.Step = asked.steps[-1]
		_check(asked.mark == "站了大秦人" and last.kind == ScriptedAct.Kind.QUESTIONS and last.questions.size() == 3 and last.questions[0].answers.size() == 2 and last.questions[2].answers.size() == 3 and last.questions[0].answers[0].mark == "替南危水保密" and last.questions[2].answers[2].mark == "宝衣给了安妮儿", "three questions on the player's own deeds (owner Q2), their answers true by the saved marks")
		_check(last.when_true.any(func(step: ScriptedAct.Step) -> bool: return step.kind == ScriptedAct.Kind.GIVE and step.item_id == &"native:fanfang/bronze_tablet") and last.when_true.any(func(step: ScriptedAct.Step) -> bool: return step.kind == ScriptedAct.Kind.MARK and step.flag == "铜牒到手") and last.when_false.any(func(step: ScriptedAct.Step) -> bool: return step.kind == ScriptedAct.Kind.SET_TEMP and step.flag == "火不肯"), "all true: the tablet and 铜牒到手; a lie: 火不肯 for the day")
		_check(questions.act.acts[1].temp == "火不肯" and not questions.act.acts[1].ask.is_empty() and questions.act.acts[1].steps.any(func(step: ScriptedAct.Step) -> bool: return step.kind == ScriptedAct.Kind.UNTIL_PHASE and step.phases == [&"dawn"]), "the day the fire refused: 等到明天 asks first and puts the clock to dawn")
		_check(questions.act.acts[0].temp == "火不肯" and questions.act.acts[0].phase == [&"dawn"] and questions.act.acts[0].ask.is_empty() and not questions.act.acts[0].steps.any(func(step: ScriptedAct.Step) -> bool: return step.kind == ScriptedAct.Kind.CLEAR_TEMP), "a lie told at dawn: no wait to offer (the clock would not move), the refusal kept until dawn has passed")
	var tablet: ItemContentDefinition = catalog.item(&"native:fanfang/bronze_tablet")
	_check(tablet != null and tablet.quest_item and tablet.no_drop, "the 铜牒 is a quest item nobody drops")
	var andun: NpcDefinition = catalog.npc(&"native.npc.andun")
	_check(andun != null and andun.age == 61 and andun.hooks() != null and andun.hooks().calls.size() == 1 and andun.hooks().calls[0].act.npc_in == &"fanfang.hall" and andun.talk().inquiry_topics().has("铜牒") and andun.talk().inquiry_topics().has("站大秦人"), "安敦: 61, meets the player in his hut, tells of the 铜牒 and takes a side")
	var lama: NpcDefinition = catalog.npc(&"fanfang.npc.lama_master")
	_check(lama != null and lama.age == 71 and lama.class_id == &"lama" and lama.internal_power(&"max_force") == 1500 and lama.internal_power(&"force_factor") == 5 and lama.skill_map().get(&"force") == &"lotusforce" and lama.ordination() != null and lama.teaching() == null, "龙若法王 as master.c makes him: 71, force 1500 / 5, 莲花内功, 剃度 by kneeling (his 日陀罗寺 family and teaching are 番坊 D's)")
	var south: PortalDefinition = catalog.portal(&"village.valley1.south")
	_check(south != null and south.destination_zone_id == &"fanfang.cliff_top" and south.set_mark == "到了番坊" and catalog.portal(&"fanfang.cliff_top.north").destination_zone_id == &"village.valley1", "the path outside 忘情谷 runs on south to the 海崖口 (marking 到了番坊), and back")
	_check(catalog.portal(&"fanfang.cliff_foot.south").destination_zone_id == &"fanfang.dock" and catalog.portal(&"fanfang.dock.north").destination_zone_id == &"fanfang.cliff_foot", "the steps down to the dock, and back up")
	_check(catalog.portal(&"fanfang.dock.east").destination_zone_id == &"fanfang.bazaar_west" and catalog.portal(&"fanfang.bazaar_west.west").destination_zone_id == &"fanfang.dock", "the road from the dock into the bazaar, and back")
	_check(catalog.portal(&"fanfang.bazaar_west.south").destination_zone_id == &"fanfang.office" and catalog.portal(&"fanfang.office.north").destination_zone_id == &"fanfang.bazaar_west", "the 市舶司's door off the street, and out")
	for id: StringName in [&"fanfang.cliff_top.landmark.shrine", &"fanfang.cliff_path.landmark.sea", &"fanfang.dock.landmark.boats", &"fanfang.bazaar_north.landmark.shields"]:
		_check(catalog.landmark(id) != null, "landmark %s" % id)
	var notice: WorldLandmarkDefinition = catalog.landmark(&"fanfang.office.landmark.notice")
	_check(notice != null and notice.description.contains("辑拿要犯----於兰天武"), "the wanted notice copied word for word from eastdoor2.c")
	var papers: ServiceDefinition = catalog.service(&"fanfang.office.papers")
	_check(papers != null and papers.act != null and papers.act.verb == "看" and papers.act.acts.size() == 2 and papers.act.acts[0].mark == "学过印色", "the 兵部文书: 看, its second sentence for one who learned the 印色")
	_check(catalog.vendor(&"fanfang.vendor.glass").goods_keys().size() == 1 and catalog.vendor(&"fanfang.vendor.carpet").goods_keys().size() == 1 and catalog.vendor(&"fanfang.vendor.spice").goods_keys().size() == 2 and catalog.vendor(&"fanfang.vendor.copper").goods_keys().size() == 1, "the four merchants' goods")
	var bread: ItemContentDefinition = catalog.item(&"native:fanfang/hu_bread")
	var kettle: ItemContentDefinition = catalog.item(&"native:fanfang/copper_kettle")
	_check(bread != null and bread.category == ItemContentDefinition.CATEGORY_FOOD and kettle != null and kettle.liquid_initial_name == "清水", "the 胡饼 is food, the 铜壶 holds water")
	var luca_market: NpcSpawnDefinition = catalog.spawn(&"guanbei.market.luca")
	var luca_port: NpcSpawnDefinition = catalog.spawn(&"fanfang.bazaar_north.luca")
	_check(luca_market != null and luca_market.until != null and luca_market.until.key == "关北一章" and luca_port != null and luca_port.present != null and luca_port.present.key == "关北一章", "卢卡 leaves the 马市 for 铁盾会's gate once 关北 is done")
	var luca: NpcDefinition = catalog.npc(&"native.npc.luca")
	_check(luca != null and luca.hooks() != null and luca.hooks().calls.size() == 1 and luca.hooks().calls[0].reaction and luca.hooks().calls[0].act.mark == "关北一章" and luca.hooks().calls[0].act.npc_in == &"fanfang.bazaar_north", "卢卡 greets the player at the gate, and only there")
	_check(luca.dealings().object_rules.size() == 5 and luca.dealings().object_rules[1].giver_mark == "卢卡在番坊见到你" and luca.dealings().object_rules[1].gives == &"native:guanbei/gladius", "in 番坊 his sword sells without the 马市's word on the fare")
	var quest: StoryQuestDefinition = catalog.story_quest(&"main.chapter7")
	_check(quest != null and quest.steps.size() == 7 and quest.steps[0].condition.key == "到了番坊" and quest.steps[1].condition.key == "见了安敦" and quest.steps[2].condition.topic == "铜牒" and quest.steps[3].options.size() == 2 and quest.steps[3].options[0].condition.key == "站了大秦人" and quest.steps[4].only_after == &"rome" and quest.steps[4].condition.key == "铜牒到手" and quest.steps[5].only_after == &"ronin" and quest.steps[6].condition.key == "读过铜牒", "the chapter so far: the way down, 安敦, the tablet's tale, the side, the fire or the blade, then the reading (番坊 C)")
	_check(WorldContentRevision.CURRENT_PUBLIC == WorldContentRevision.Value.SOURCE_ENTRY_FANFANG_B_V1, "番坊 B's world revision is current")


## From the path outside 忘情谷: south down the 海崖道 to the dock and the shed, into the bazaar
## and the 市舶司 and back; the people at their posts; then (TEST-ONLY: 关北 done) 卢卡 at the gate.
func _test_walk(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var valley: WorldMapController = MapPlaces.enter(session, &"village.valley1", &"village.valley1.cave_return")
	_check(valley != null and valley.map_id() == &"village.main", "on the path outside 忘情谷")
	await _settle(tree)
	var road: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.cliff_top")
	_check(road != null and road.map_id() == &"fanfang.cliff_road" and state.marks.get("到了番坊", 0) == 1, "south out of the woods onto the 海崖口; 到了番坊 marked by the way")
	_check(road.select_landmark(&"fanfang.cliff_top.landmark.shrine") and road.inspect_selected() and ui.inspection_text.text.contains("平安"), "the sea god's niche: 平安")
	ui.dismiss_current_panel()
	await _settle(tree)
	_check(await MapPlaces.drive_through(tree, road, [&"fanfang.cliff_path"]), "down onto the cliff road")
	_check(road.select_landmark(&"fanfang.cliff_path.landmark.sea") and road.inspect_selected() and ui.inspection_text.text.contains("看不见对岸"), "the sea looked at")
	ui.dismiss_current_panel()
	await _settle(tree)
	var porter: NpcRuntimeState = MapPlaces.npc_at(session, &"fanfang.cliff_path.porter.1")
	_check(porter != null and await MapPlaces.drive(tree, road, MapPlaces.spot(road, &"fanfang.cliff_path", road.runtime_body_for_character(porter.character_id).global_position + Vector2(0, 60), 64.0)) and road.select_npc(porter.character_id), "beside a salt porter")
	_check(road.ask_selected("盐").any(func(line: String) -> bool: return line.contains("玉螺湖村")), "the salt goes up to 玉螺湖村")
	_check(await MapPlaces.drive_through(tree, road, [&"fanfang.cliff_foot"]), "down to the cliff's foot")
	var dock: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.dock")
	_check(dock != null and dock.map_id() == &"fanfang.port", "down the steps onto the quay")
	_check(dock.select_landmark(&"fanfang.dock.landmark.boats") and dock.inspect_selected() and ui.inspection_text.text.contains("南边来的商人"), "the boats are others'")
	ui.dismiss_current_panel()
	await _settle(tree)
	var clerk: NpcRuntimeState = MapPlaces.npc_at(session, &"fanfang.dock.tax_clerk.1")
	_check(clerk != null and await MapPlaces.drive(tree, dock, MapPlaces.spot(dock, &"fanfang.dock", dock.runtime_body_for_character(clerk.character_id).global_position + Vector2(0, 60), 64.0)) and dock.select_npc(clerk.character_id), "beside the tax clerk")
	_check(dock.ask_selected("大秦人").any(func(line: String) -> bool: return line.contains("两面大盾")), "he points the way to 铁盾会")
	_check(await MapPlaces.drive_through(tree, dock, [&"fanfang.shed", &"fanfang.dock"]), "west into the shed and back")
	var bazaar: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.bazaar_west")
	_check(bazaar != null and bazaar.map_id() == &"fanfang.bazaar", "east into the bazaar")
	for zone: StringName in PEOPLE:
		for kind: StringName in PEOPLE[zone]:
			_check(_count_in(session, zone, kind) == PEOPLE[zone][kind], "%d %s in %s" % [PEOPLE[zone][kind], kind, zone])
	_check(_count_in(session, &"fanfang.bazaar_north", &"native.npc.luca") == 0, "卢卡 is not here before 关北")
	var teller: NpcRuntimeState = MapPlaces.npc_at(session, &"fanfang.bazaar_west.storyteller.1")
	_check(teller != null and await MapPlaces.drive(tree, bazaar, MapPlaces.spot(bazaar, &"fanfang.bazaar_west", bazaar.runtime_body_for_character(teller.character_id).global_position + Vector2(0, -60), 64.0)) and bazaar.select_npc(teller.character_id), "beside the old storyteller")
	_check(bazaar.ask_selected("大秦").any(func(line: String) -> bool: return line.contains("已经没有了")), "the empire is gone")
	_check(await MapPlaces.drive_through(tree, bazaar, [&"fanfang.bazaar_east", &"fanfang.bazaar_north"]), "east along the street and up the lane to 铁盾会's gate")
	_check(bazaar.select_landmark(&"fanfang.bazaar_north.landmark.shields") and bazaar.inspect_selected() and ui.inspection_text.text.contains("鹰"), "the two great shields")
	ui.dismiss_current_panel()
	await _settle(tree)
	# 番坊 B: through the gate into 铁盾会's yard and the 会首's hut, and back.
	var hall: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.shield_yard")
	_check(hall != null and hall.map_id() == &"fanfang.shield_hall", "through the gate into 铁盾会's yard")
	_check(await MapPlaces.drive_through(tree, hall, [&"fanfang.hall"]), "and into the 会首's hut")
	_check(hall.select_landmark(&"fanfang.hall.landmark.tablet") and hall.inspect_selected() and ui.inspection_text.text.contains("盾不倒"), "the tablet: 盾在前，剑在后")
	ui.dismiss_current_panel()
	await _settle(tree)
	var swordsman: NpcRuntimeState = MapPlaces.npc_at(session, &"fanfang.shield_yard.swordsman.1")
	_check(await MapPlaces.drive_through(tree, hall, [&"fanfang.shield_yard"]) and swordsman != null and await MapPlaces.drive(tree, hall, MapPlaces.spot(hall, &"fanfang.shield_yard", hall.runtime_body_for_character(swordsman.character_id).global_position + Vector2(-60, 0), 48.0)) and hall.select_npc(swordsman.character_id), "beside a swordsman in the yard")
	_check(hall.ask_selected("盾").any(func(line: String) -> bool: return line.contains("盾不倒")), "盾在前，剑在后")
	bazaar = await MapPlaces.go_to(tree, session, &"fanfang.bazaar_north")
	_check(bazaar != null and bazaar.map_id() == &"fanfang.bazaar", "out of the gate")
	# The 拜火祠 at the street's east end: the fire, the priest's one rule.
	_check(await MapPlaces.drive_through(tree, bazaar, [&"fanfang.bazaar_east"]), "down the lane")
	var temple: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.fire_hall")
	_check(temple != null and temple.map_id() == &"fanfang.fire_temple", "into the 拜火祠")
	for second: int in 2:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(state.marks.get("穆护见过你", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("火前，不说谎")), "穆护: 进来可以。火前，不说谎")
	_check(temple.select_landmark(&"fanfang.fire_hall.landmark.fire") and temple.inspect_selected() and ui.inspection_text.text.contains("三百年"), "the fire of three hundred years")
	ui.dismiss_current_panel()
	await _settle(tree)
	var questions: ActService = temple.service(&"fanfang.fire_hall.questions") as ActService
	_check(questions != null and questions.context_title().is_empty(), "nothing to ask of one who has not heard of the tablet")
	_check(await MapPlaces.drive_through(tree, temple, [&"fanfang.priest_room", &"fanfang.fire_hall"]), "into the priest's cell and back")
	bazaar = await MapPlaces.go_to(tree, session, &"fanfang.bazaar_east")
	_check(bazaar != null, "out onto the street")
	# Down the lane to 日陀罗寺: 龙若法王 under the banyan, master.c's 剃度.
	_check(await MapPlaces.drive_through(tree, bazaar, [&"fanfang.bazaar_slope"]), "down the slope")
	var monastery: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.temple_yard")
	_check(monastery != null and monastery.map_id() == &"fanfang.lama_temple", "into 日陀罗寺's yard")
	_check(monastery.select_landmark(&"fanfang.temple_yard.landmark.banyan") and monastery.inspect_selected() and ui.inspection_text.text.contains("气根"), "the banyan's air roots")
	ui.dismiss_current_panel()
	await _settle(tree)
	var lama: NpcRuntimeState = MapPlaces.npc_at(session, &"fanfang.temple_yard.lama_master.1")
	_check(lama != null and await MapPlaces.drive(tree, monastery, MapPlaces.spot(monastery, &"fanfang.temple_yard", monastery.runtime_body_for_character(lama.character_id).global_position + Vector2(-60, 0), 48.0)) and monastery.select_npc(lama.character_id), "beside 龙若法王")
	var join: Array[String] = monastery.ask_selected("剃度")
	_check((join.any(func(line: String) -> bool: return line.contains("请跪下(kneel)受戒")) and session.player_runtime().temp_marks.get("pending/join_bonze", 0) == 1) or join.any(func(line: String) -> bool: return line.contains("尼庵")), "master.c's ask_for_join: a man is told to kneel, a woman sent to the 尼庵: %s" % [join])
	_check(monastery.ask_selected("山烟寺").any(func(line: String) -> bool: return line.contains("一个根")), "the 山烟寺 line: one root (剧情总纲 §4 第 7 条)")
	_check(await MapPlaces.drive_through(tree, monastery, [&"fanfang.shrine"]), "into the shrine")
	_check(monastery.select_landmark(&"fanfang.shrine.landmark.buddha") and monastery.inspect_selected() and ui.inspection_text.text.contains("天竺"), "the Buddha from 天竺")
	ui.dismiss_current_panel()
	await _settle(tree)
	bazaar = await MapPlaces.go_to(tree, session, &"fanfang.bazaar_slope")
	_check(bazaar != null and await MapPlaces.drive_through(tree, bazaar, [&"fanfang.bazaar_east", &"fanfang.bazaar_west"]), "back up the slope and west along the street")
	var office: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.office")
	_check(office != null and office.map_id() == &"fanfang.customs", "into the 市舶司")
	_check(office.select_landmark(&"fanfang.office.landmark.notice") and office.inspect_selected() and ui.inspection_text.text.contains("於兰天武"), "京师's wanted notice, copied")
	ui.dismiss_current_panel()
	await _settle(tree)
	var papers: ActService = office.service(&"fanfang.office.papers") as ActService
	_check(papers != null and await MapPlaces.drive(tree, office, MapPlaces.service_spot(office, &"fanfang.office.papers")) and papers.in_reach() and papers.verb() == "看", "兵部文书 · 看 at the desk")
	papers.interact()
	await _settle(tree)
	_check(state.marks.get("看过清人文书", 0) == 1 and not state.marks.has("看出文书是假的") and ui.log_lines().any(func(line: String) -> bool: return line.contains("着市舶司即日清出")), "the order read; without the 印色 nothing is seen in the seal")
	state.marks["学过印色"] = 1 # TEST-ONLY: 关北 A's 比印 (story_chapter6_test)
	papers.interact()
	await _settle(tree)
	_check(state.marks.get("看出文书是假的", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("印是假的")), "with the 印色 learned the seal is seen to be false")
	var feng: NpcRuntimeState = MapPlaces.npc_at(session, &"fanfang.office.feng_lu.1")
	_check(feng != null and await MapPlaces.drive(tree, office, MapPlaces.spot(office, &"fanfang.office", office.runtime_body_for_character(feng.character_id).global_position + Vector2(-60, 0), 48.0)) and office.select_npc(feng.character_id), "beside 冯禄")
	_check(office.ask_selected("文书").any(func(line: String) -> bool: return line.contains("懂什么印色")), "冯禄 bristles at one who has seen through the seal")
	_check(await MapPlaces.drive_through(tree, office, [&"fanfang.yard", &"fanfang.office"]), "into the back yard and back")
	# Save and Continue from the office.
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null, "a save from the 市舶司")
	if snapshot != null:
		var walker: RefCounted = Work.new()
		await walker.round_trip(tree, session, snapshot, "番坊 A in the 市舶司")
		_check(walker._failures.is_empty(), "Save/Continue restores exactly: " + str(walker._failures))
	# 关北 done (TEST-ONLY): 卢卡 stands at the gate and greets the player once.
	state.marks["关北一章"] = 1
	var dock_again: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.dock")
	_check(dock_again != null and dock_again.map_id() == &"fanfang.port", "back out to the dock")
	bazaar = await MapPlaces.go_to(tree, session, &"fanfang.bazaar_west")
	_check(bazaar != null and _count_in(session, &"fanfang.bazaar_north", &"native.npc.luca") == 1, "after 关北, 卢卡 at 铁盾会's gate")
	_check(await MapPlaces.drive_through(tree, bazaar, [&"fanfang.bazaar_east", &"fanfang.bazaar_north"]), "up the lane to him")
	for second: int in 2:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(state.marks.get("卢卡在番坊见到你", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("路，不近")), "卢卡: 你来了。路，不近。")
	var luca: NpcRuntimeState = MapPlaces.npc_at(session, &"fanfang.bazaar_north.luca.1")
	_check(luca != null and await MapPlaces.drive(tree, bazaar, MapPlaces.spot(bazaar, &"fanfang.bazaar_north", bazaar.runtime_body_for_character(luca.character_id).global_position + Vector2(0, 60), 64.0)) and bazaar.select_npc(luca.character_id), "beside 卢卡")
	_check(bazaar.ask_selected("番坊").any(func(line: String) -> bool: return line.contains("就是这里")), "卢卡 on 番坊, now he is here")
	state.marks.erase("关北一章")


func _count_in(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> int:
	var found: int = 0
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if npc.definition().definition_id == definition_id and npc.world_location().zone_id == zone_id and npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE):
				found += 1
	return found


func _settle(tree: SceneTree) -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
