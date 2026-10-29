extends RefCounted

## 逆灵宫 A (owner, 2026-10-29; DECISIONS「逆灵宫 A」): the three ways up the crack from 旧案's
## end and the chapter's entrance (StoryFixtures) — the rope refused to a stranger while the
## escort stands there, 跟车 under the oil-cloth (asked first) up to the winch platform, the rope
## back down, 强攻 (the escort gone: the rope's first branch, the oil-cloth useless), 黄霸's 黑冠
## for one who heard of the tribute, the rope climbed in it, the gate's 道士 taking the wearer
## for their own (the 门房's word, no fight indoors) and falling on them the moment it comes
## off, the quest's `way` and `yard` steps, the 任务 page and the save.

const MapPlaces := preload("res://tests/support/map_places.gd")
const CROWN: StringName = &"native:niling/black_crown"
const ESCORT: StringName = &"native.npc.tribute_taoist"
const TURN: StringName = &"goathill.mroad4"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: WorldSessionController = await _session(tree)
	await _test_ways(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_ways(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter3")
	StoryFixtures.chapter3_entry_done(session, true)
	session.record_journal()
	_check(StoryQuestLog.is_active(state, quest) and StoryQuestLog.objective(state, quests).begins_with("逆灵宫就在裂口上头。"), "at the gate step: %s" % [StoryQuestLog.objective(state, quests)])
	# The turn: the escort and the cart on the stage; the bandits go (TEST-ONLY, as the entry suite).
	var mountain: WorldMapController = await _onto_the_turn(tree, session)
	var rope: ActService = mountain.service(&"goathill.mroad4.rope") as ActService
	var tarp: ActService = mountain.service(&"goathill.mroad4.tarp") as ActService
	_check(rope != null and tarp != null and rope.in_reach() and tarp.in_reach() and rope.verb() == "攀绳上去" and tarp.verb() == "钻进车里", "绳索 · 攀绳上去 and 油布 · 钻进车里 at the turn")
	# A stranger: the escort refuses the rope.
	rope.interact()
	await _settle(tree)
	_check(session.active_map_id() == &"goathill.mountain" and _last_log(ui).contains("此处无路"), "the rope refused while the escort stands there: %s" % _last_log(ui))
	# 跟车: under the oil-cloth, asked first, hoisted up with the boxes.
	tarp.interact()
	await tree.physics_frame
	_check(ui.is_asking() and ui.confirm_prompt.message.text.begins_with("油布底下是供品的箱子"), "asked before going under the cloth: %s" % ui.confirm_prompt.message.text)
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	var slope: WorldMapController = session.active_map() as WorldMapController
	_check(slope != null and slope.map_id() == &"niling.slope" and session.player_runtime().world_location().zone_id == &"niling.winch", "hoisted up to the winch platform: %s" % [session.active_map_id()])
	_check(state.marks.get("进了逆灵宫", 0) == 1 and state.marks.get("跟车进了逆灵宫", 0) == 1, "进了逆灵宫, 跟车")
	session.record_journal()
	_check(state.quests.has("main.chapter3/gate") and state.quests.has("main.chapter3/way/sneak") and StoryQuestLog.objective(state, quests).begins_with("顺着货道往北"), "the gate passed, the way recorded, the yard next: %s" % [StoryQuestLog.objective(state, quests)])
	var winch: NpcRuntimeState = MapPlaces.npc_at(session, &"niling.winch.winch_taoist.1")
	_check(winch != null and winch.exists_in_map, "the 绞盘道士 at the winch")
	_check(await MapPlaces.drive(tree, slope, slope.runtime_body_for_character(winch.character_id).global_position + Vector2(-60, 0)) and slope.select_npc(winch.character_id), "beside him")
	_check(slope.ask_selected("裂口").any(func(line: String) -> bool: return line.contains("只走这根绳")), "he takes the player for one of the house")
	_check(slope.select_landmark(&"niling.winch.landmark.crates") and slope.inspect_selected() and ui.inspection_text.text.contains("野羊寨的记号"), "the boxes looked at")
	ui.dismiss_current_panel()
	await _settle(tree)
	# The rope back down to the turn.
	var down: ActService = slope.service(&"niling.winch.rope") as ActService
	_check(down != null and await MapPlaces.drive(tree, slope, MapPlaces.service_spot(slope, &"niling.winch.rope")) and down.in_reach() and down.verb() == "下到山路", "绳索 · 下到山路")
	down.interact()
	await _settle(tree)
	mountain = session.active_map() as WorldMapController
	_check(mountain != null and mountain.map_id() == &"goathill.mountain" and session.player_runtime().world_location().zone_id == TURN, "down on the turn again")
	# 强攻: the escort gone (TEST-ONLY: leave_for_good stands for beaten), the oil-cloth is no way up
	# and the rope's first branch climbs.
	for npc: NpcRuntimeState in _escorts(mountain):
		mountain.npcs.leave_for_good(npc)
	session.record_journal()
	_check(state.marks.get("押车道士倒了", 0) == 1, "押车道士倒了 (the spawn cleared)")
	_check(mountain.place_player(TURN, Vector2(640, 1224)), "by the cart")
	await _settle(tree)
	tarp = mountain.service(&"goathill.mroad4.tarp") as ActService
	rope = mountain.service(&"goathill.mroad4.rope") as ActService
	tarp.interact()
	await _settle(tree)
	_check(not ui.is_asking() and session.active_map_id() == &"goathill.mountain" and _last_log(ui).contains("没人拉绳"), "nobody hauls: the cloth is no way up: %s" % _last_log(ui))
	rope.interact()
	await _settle(tree)
	slope = session.active_map() as WorldMapController
	_check(slope != null and slope.map_id() == &"niling.slope" and ui.log_lines().any(func(line: String) -> bool: return line.contains("绞盘吱吱的响声")), "climbed the rope the escort left")
	_check(await MapPlaces.drive(tree, slope, MapPlaces.service_spot(slope, &"niling.winch.rope")), "back at the rim")
	(slope.service(&"niling.winch.rope") as ActService).interact()
	await _settle(tree)
	# 穿衣: 黄霸's crown for one who heard of the tribute; the rope climbed in it past a fresh escort.
	var temple: WorldMapController = MapPlaces.enter(session, &"goathill.temple1", &"goathill.temple1.mroad3_entry")
	_check(temple != null, "in the 土地庙")
	await _settle(tree)
	var hwang: NpcRuntimeState = MapPlaces.npc_at(session, &"goathill.temple1.bandit_hwang.1")
	_check(hwang != null and temple.place_player(&"goathill.temple1", temple.runtime_body_for_character(hwang.character_id).global_position + Vector2(0, 60)), "beside 黄霸")
	await _settle(tree)
	_check(temple.select_npc(hwang.character_id) and temple.ask_topics_selected().has("黑衣"), "黑衣 to ask")
	var said: Array[String] = temple.ask_selected("黑衣")
	_check(said.any(func(line: String) -> bool: return line.contains("戴上这顶冠")) and session.player_held_item_ids().has(CROWN) and state.marks.get("黄霸给了黑冠", 0) == 1, "he gives the 黑冠 (刘安禄's word is enough): %s" % [said])
	_check(temple.select_npc(hwang.character_id) and temple.ask_selected("黑衣").any(func(line: String) -> bool: return line.contains("就那一顶")), "and only once")
	var crown: StringName = _held_instance(session, temple, CROWN)
	_check(not crown.is_empty() and session.wear_player_item(crown).succeeded and session.player_worn_item_ids().has(CROWN), "the crown worn")
	# Back at the turn (the escort gone; TEST-ONLY: the cleared mark erased, so the rope's crown
	# branch is the one that climbs).
	mountain = MapPlaces.enter(session, &"goathill.mroad3", &"goathill.mroad3.temple1_return")
	_check(mountain != null and mountain.place_player(TURN, Vector2(640, 1224)), "by the cart again")
	await _settle(tree)
	state.marks.erase("押车道士倒了")
	rope = mountain.service(&"goathill.mroad4.rope") as ActService
	rope.interact()
	await _settle(tree)
	slope = session.active_map() as WorldMapController
	_check(slope != null and slope.map_id() == &"niling.slope" and ui.log_lines().any(func(line: String) -> bool: return line.contains("没人拦你")), "in the crown, nobody stops the player at the rope")
	# The gate: the 门房 and the guards take the crowned player for one of their own.
	var gate: WorldMapController = await MapPlaces.go_to(tree, session, &"niling.gatehouse")
	_check(gate != null and gate.map_id() == &"niling.gate", "through the 黑砖山门")
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "the 门房 does not attack one in the crown")
	_check(ui.log_lines().any(func(line: String) -> bool: return line.contains("新来的？进去别乱走")) and state.marks.get("门房道士打过招呼", 0) == 1, "and has a word for the newcomer")
	_check(await MapPlaces.drive_to_zone(tree, gate, &"niling.yard"), "into the yard")
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "nor do the guards")
	session.record_journal()
	_check(state.quests.has("main.chapter3/yard") and StoryQuestLog.objective(state, quests) == "前殿的门关着。找路进前殿，找到霍铮。" and not StoryQuestLog.is_done(state, quest), "the yard reached; the chapter waits at the hall (B)")
	ui.menu_tab_shown(GameMenu.Tab.JOURNAL)
	var page: String = ui.quest_page.shown_text()
	_check(page.contains("你缩在供品箱子中间") and page.contains("黑砖的前院"), "the 任务 page tells the way in: " + page.left(300))
	var snapshot: GameSaveSnapshot = _capture(session)
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(encoded.text)
	_check(snapshot != null and decoded.snapshot != null and decoded.snapshot.player.character.quests == state.quests and decoded.snapshot.player.character.marks.get("跟车进了逆灵宫", 0) == 1, "saved and read back: %s" % [decoded.detail])
	# The crown off: the guards fall on the player.
	_check(session.remove_player_item(crown).succeeded and not session.player_worn_item_ids().has(CROWN), "the crown taken off")
	for second: int in 4:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(session.combat_encounter_coordinator().has_active_encounter(), "bareheaded in the yard: the guards attack")


## Onto the turn from the temple's road, the bandits gone (TEST-ONLY), the player by the cart.
func _onto_the_turn(tree: SceneTree, session: WorldSessionController) -> WorldMapController:
	var mountain: WorldMapController = MapPlaces.enter(session, &"goathill.mroad3", &"goathill.mroad3.temple1_return")
	_check(mountain != null and mountain.map_id() == &"goathill.mountain", "on the mountain road")
	await _settle(tree)
	for definition_id: StringName in [&"goathill.npc.bandit", &"goathill.npc.bandit_leader"]:
		var bandit: NpcRuntimeState = mountain.npcs.first_npc_in_zone(definition_id, TURN)
		while bandit != null:
			mountain.npcs.leave_for_good(bandit)
			bandit = mountain.npcs.first_npc_in_zone(definition_id, TURN)
	_check(_escorts(mountain).size() == 2 and not mountain.floor_item_of(&"native:goathill/tribute_cart", TURN).is_empty(), "the escort and the cart under the crack")
	_check(mountain.place_player(TURN, Vector2(640, 1224)), "by the cart")
	await _settle(tree)
	return mountain


func _escorts(mountain: WorldMapController) -> Array[NpcRuntimeState]:
	var escorts: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in mountain.npcs.resident_npcs():
		if npc.definition().definition_id == ESCORT and npc.world_location().zone_id == TURN and npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE):
			escorts.append(npc)
	return escorts


## The instance of `definition_id` the player carries directly ("" when none).
func _held_instance(session: WorldSessionController, map: WorldMapController, definition_id: StringName) -> StringName:
	var carried := ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, session.player_runtime().character_id)
	for item_id: StringName in map.inventory_state().direct_children(carried):
		var item: ItemInstance = map.item_instance_index().resolve(item_id)
		if item != null and item.item_definition_id == definition_id:
			return item_id
	return &""


func _last_log(ui: SharedGameplayUI) -> String:
	var lines: Array[String] = ui.log_lines()
	return "" if lines.is_empty() else lines[lines.size() - 1]


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("逆灵宫", CharacterState.GENDER_MALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	tree.root.add_child(session)
	for frame: int in 4:
		await tree.process_frame
	session.set_process(false)
	return session


func _settle(tree: SceneTree) -> void:
	for frame: int in 4:
		await tree.physics_frame
	await tree.process_frame


func _capture(session: WorldSessionController) -> GameSaveSnapshot:
	var result: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-10-29T00:00:00Z")
	if result.snapshot == null:
		print("capture rejected: ", result.path, " ", result.detail)
	return result.snapshot


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
