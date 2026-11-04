extends RefCounted

## 第七章「番坊」 so far (番坊 A, DECISIONS「番坊 A」): 关北's last step asked of 卢卡 in the 马市 ends that
## chapter while he still stands by the pen — he keeps his 马市 lines there and greets no one (his 番坊
## lines wait for the gate). Once 关北 is done the chapter opens with the way —
## out of 忘情谷 south down the 海崖道 (the portal marks 到了番坊) — on both of 关北's ledgers (the raid,
## the night); its next objective is 铁盾会's gate in the bazaar, where 卢卡 now stands and greets the
## player once (the gate itself, 安敦 and the rest of the chapter are 番坊 B's). 卢卡 is gone from the
## 马市. The 市舶司's 兵部文书 reads false to one who learned the 印色 in 关北 A.
const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const LUCA: StringName = &"native.npc.luca"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	for raid: bool in [true, false]:
		var session: WorldSessionController = await _session(tree, CharacterState.GENDER_FEMALE if raid else CharacterState.GENDER_MALE)
		await _test_way_down(tree, session, raid)
		session.free()
		await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _test_way_down(tree: SceneTree, session: WorldSessionController, raid: bool) -> void:
	var ledger: String = "the raid" if raid else "the night"
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter7")
	StoryFixtures.chapter6_site_done(session, raid)
	session.record_journal()
	# 关北's last step in the 马市: 卢卡's ghost and his 会首 end the chapter while he stands by the pen.
	var market: WorldMapController = MapPlaces.enter(session, &"guanbei.market", &"guanbei.market.street_arrival")
	_check(market != null, "%s: in the 马市" % ledger)
	await _settle(tree)
	var seller: NpcRuntimeState = MapPlaces.npc_at(session, &"guanbei.market.luca.1")
	var body: Node2D = null if seller == null else market.runtime_body_for_character(seller.character_id)
	_check(body != null and market.place_player(&"guanbei.market", body.global_position + Vector2(0, 56)) and market.select_npc(seller.character_id), "%s: beside 卢卡 by the pen" % ledger)
	await _settle(tree)
	market.ask_selected("鬼")
	_check(market.ask_selected("会首").any(func(line: String) -> bool: return line.contains("他在番坊")), "%s: 会首安敦, in 番坊" % ledger)
	session.record_journal()
	_check(state.marks.get("关北一章", 0) == 1, "%s: 关北 is done" % ledger)
	_check(market.ask_selected("番坊").any(func(line: String) -> bool: return line.contains("出忘情谷")) and market.ask_selected("会首").any(func(line: String) -> bool: return line.contains("他在番坊")) and market.ask_selected("路费").any(func(line: String) -> bool: return line.contains("二十两")), "%s: still by the pen, 卢卡 keeps his 马市 lines (the way there, the fare)" % ledger)
	for second: int in 2:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(not state.marks.has("卢卡在番坊见到你") and not ui.log_lines().any(func(line: String) -> bool: return line.contains("路，不近")), "%s: and greets no one in the 马市" % ledger)
	_check(StoryQuestLog.is_active(state, quest) and StoryQuestLog.objective(state, quests).begins_with("去番坊找大秦人的会首安敦"), "%s: the seventh chapter open: %s" % [ledger, StoryQuestLog.objective(state, quests)])
	var target: StoryQuestDefinition.Target = StoryQuestLog.target(state, quests)
	_check(target != null and target.zone_id == &"village.valley1", "%s: its marker on the path outside 忘情谷" % ledger)
	_check(not StoryQuestLog.objective(state, quests).contains("村东"), "%s: the objective names no wrong side (owner Q1: the sea lies south-west)" % ledger)
	# Once the player has left, 卢卡 has left the 马市 too.
	var away: WorldMapController = MapPlaces.enter(session, &"village.valley1", &"village.valley1.cave_return")
	_check(away != null, "%s: away from the 马市" % ledger)
	await _settle(tree)
	market = MapPlaces.enter(session, &"guanbei.market", &"guanbei.market.street_arrival")
	await _settle(tree)
	_check(market != null and _count_in(session, &"guanbei.market", LUCA) == 0, "%s: back in the 马市, 卢卡 is gone" % ledger)
	# Down from the valley.
	var valley: WorldMapController = MapPlaces.enter(session, &"village.valley1", &"village.valley1.cave_return")
	_check(valley != null and valley.map_id() == &"village.main", "%s: on the path outside 忘情谷" % ledger)
	await _settle(tree)
	var road: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.cliff_top")
	_check(road != null and road.map_id() == &"fanfang.cliff_road" and state.marks.get("到了番坊", 0) == 1, "%s: south out of the woods onto the 海崖口" % ledger)
	session.record_journal()
	var step: StoryQuestDefinition.Step = StoryQuestLog.current_step(state, quest)
	_check(step != null and step.step_id == &"hall" and StoryQuestLog.objective(state, quests).contains("两面大盾"), "%s: the way done; next 铁盾会's gate: %s" % [ledger, StoryQuestLog.objective(state, quests)])
	var hall: StoryQuestDefinition.Target = StoryQuestLog.target(state, quests)
	_check(hall != null and hall.zone_id == &"fanfang.bazaar_north", "%s: the marker moves to the lane's end" % ledger)
	# Through the port to the bazaar: 卢卡 at the gate greets the player once.
	_check(await MapPlaces.drive_through(tree, road, [&"fanfang.cliff_path", &"fanfang.cliff_foot"]), "%s: down the cliff road" % ledger)
	var port: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.dock")
	_check(port != null and port.map_id() == &"fanfang.port", "%s: down the steps to the port" % ledger)
	var bazaar: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.bazaar_west")
	_check(bazaar != null and bazaar.map_id() == &"fanfang.bazaar", "%s: through the port into the bazaar" % ledger)
	_check(_count_in(session, &"fanfang.bazaar_north", LUCA) == 1, "%s: 卢卡 at 铁盾会's gate" % ledger)
	_check(await MapPlaces.drive_through(tree, bazaar, [&"fanfang.bazaar_east", &"fanfang.bazaar_north"]), "%s: up the lane to him" % ledger)
	for second: int in 2:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(state.marks.get("卢卡在番坊见到你", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("会首在里头")), "%s: 卢卡: 你来了……会首在里头" % ledger)
	var greeted: int = ui.log_lines().filter(func(line: String) -> bool: return line.contains("路，不近")).size()
	var dock: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.dock")
	_check(dock != null, "%s: back out to the dock" % ledger)
	bazaar = await MapPlaces.go_to(tree, session, &"fanfang.bazaar_west")
	_check(bazaar != null and await MapPlaces.drive_through(tree, bazaar, [&"fanfang.bazaar_east", &"fanfang.bazaar_north"]), "%s: and up the lane again" % ledger)
	for second: int in 2:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(ui.log_lines().filter(func(line: String) -> bool: return line.contains("路，不近")).size() == greeted, "%s: he greets the player only the once" % ledger)
	var luca: NpcRuntimeState = MapPlaces.npc_at(session, &"fanfang.bazaar_north.luca.1")
	_check(luca != null and await MapPlaces.drive(tree, bazaar, MapPlaces.spot(bazaar, &"fanfang.bazaar_north", bazaar.runtime_body_for_character(luca.character_id).global_position + Vector2(0, 60), 64.0)) and bazaar.select_npc(luca.character_id), "%s: beside 卢卡" % ledger)
	_check(bazaar.ask_selected("安敦").any(func(line: String) -> bool: return line.contains("会首在里头")), "%s: 安敦 is inside" % ledger)
	_check(bazaar.ask_selected("路费").any(func(line: String) -> bool: return line.contains("到了")), "%s: no more talk of the fare: he is here" % ledger)
	_check(bazaar.ask_selected("会首").any(func(line: String) -> bool: return line.contains("会首在里头")) and not bazaar.ask_selected("会首").any(func(line: String) -> bool: return line.contains("你去，说卢卡让你去")), "%s: 会首 is inside, no more sending the player to 番坊" % ledger)
	# The 兵部文书 in the 市舶司: 关北 A taught the 印色, so the seal reads false.
	_check(await MapPlaces.drive_through(tree, bazaar, [&"fanfang.bazaar_east", &"fanfang.bazaar_west"]), "%s: back down to the street's west end" % ledger)
	var office: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.office")
	_check(office != null and office.map_id() == &"fanfang.customs", "%s: into the 市舶司" % ledger)
	var papers: ActService = office.service(&"fanfang.office.papers") as ActService
	_check(papers != null and await MapPlaces.drive(tree, office, MapPlaces.service_spot(office, &"fanfang.office.papers")) and papers.in_reach(), "%s: at the desk" % ledger)
	papers.interact()
	await _settle(tree)
	_check(state.marks.get("看出文书是假的", 0) == 1 and ui.log_lines().any(func(line: String) -> bool: return line.contains("印是假的")), "%s: the 兵部文书's seal is false" % ledger)


func _session(tree: SceneTree, gender: StringName) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("番坊", gender)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	return session


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
