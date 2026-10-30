extends RefCounted

## 逆灵宫 B (owner's plan, 2026-10-29; DECISIONS「逆灵宫 B」): from A's end (StoryFixtures: in the
## yard, the 黑冠 on) — the 殿门 opened and the 前殿 entered (the `hall` step), the five chanting
## 道士 taking the crowned player for their own, the scripture looked at, the 丹房 and the 账房,
## the ledger and the 兵部 papers picked up and read (their acts write the marks the `ledger`
## and `papers` steps wait for), the stair down, the jailers, the `dungeon` step and the
## chapter waiting at `altar`; the cell's iron door refused without the key (DoorDefinition.key,
## the line), opened with it (TEST-ONLY: given) and never shut again; 霍铮 asked through it;
## the save; and the crown off in the 前殿: the whole room comes down on the player (室内一起上).

const MapPlaces := preload("res://tests/support/map_places.gd")
const CROWN: StringName = &"native:niling/black_crown"
const KEY: StringName = &"native:niling/cell_key"
const LEDGER: StringName = &"native:niling/tribute_ledger"
const PAPERS: StringName = &"native:niling/war_ministry_papers"
const HALL_DOOR: StringName = &"niling.front.door"
const CELL_DOOR: StringName = &"niling.cell_huo.door"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: WorldSessionController = await _session(tree)
	await _test_hall_and_dungeon(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_hall_and_dungeon(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var quests: Array[StoryQuestDefinition] = GameContent.catalog().story_quests()
	var quest: StoryQuestDefinition = GameContent.catalog().story_quest(&"main.chapter3")
	StoryFixtures.chapter3_yard_done(session)
	session.record_journal()
	_check(StoryQuestLog.is_active(state, quest) and StoryQuestLog.objective(state, quests).begins_with("前殿的门关着。"), "at the hall step: %s" % [StoryQuestLog.objective(state, quests)])
	# On the goods road before the gate, the crown on (TEST-ONLY: given, as 黄霸 would; bareheaded
	# in the yard the guards would rise at once), then in through the 山门 to the yard.
	_check(session.handoff_to(&"niling.slope", &"niling.goods_path", &"niling.goods_path", &"niling.goods_path.gate_return").succeeded(), "on the goods road before the gate")
	var slope: WorldMapController = session.active_map() as WorldMapController
	await _settle(tree)
	var crown: StringName = slope.give_new_item_to_player(CROWN)
	_check(not crown.is_empty() and session.wear_player_item(crown).succeeded and session.player_worn_item_ids().has(CROWN), "the 黑冠 on")
	var gate: WorldMapController = await MapPlaces.go_to(tree, session, &"niling.yard")
	_check(gate != null and gate.map_id() == &"niling.gate", "through the 山门 into the yard")
	await _settle(tree)
	# The 殿门: shut, opened by hand, and the way through it.
	var door: WorldDoor = gate.door(HALL_DOOR)
	_check(door != null and not door.is_open(), "the 殿门 stands shut on the yard's north wall")
	_check(await MapPlaces.drive(tree, gate, MapPlaces.door_spot(gate, HALL_DOOR, &"niling.yard")) and gate.can_operate_door(HALL_DOOR) and gate.open_door(HALL_DOOR), "the 殿门 opens")
	_check(await MapPlaces.take_passage(tree, gate, &"niling.yard.north"), "through it")
	var hall: WorldMapController = session.active_map() as WorldMapController
	await _settle(tree)
	_check(hall != null and hall.map_id() == &"niling.hall" and session.player_runtime().world_location().zone_id == &"niling.front", "in the 前殿: %s" % [session.active_map_id()])
	_check(hall.door(HALL_DOOR) != null and hall.door(HALL_DOOR).is_open(), "the same door, open from this side too")
	session.record_journal()
	_check(state.quests.has("main.chapter3/hall") and StoryQuestLog.objective(state, quests).begins_with("殿西是丹房和账房"), "the hall step done, the ledger next: %s" % [StoryQuestLog.objective(state, quests)])
	_check(_count_in(session, &"niling.front", &"native.npc.niling_chanter") == 4 and _count_in(session, &"niling.front", &"native.npc.niling_lead_chanter") == 1, "five 道士 at their cushions")
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "they take one in the crown for their own: nobody looks up")
	_check(hall.select_landmark(&"niling.front.landmark.scripture") and hall.inspect_selected() and ui.inspection_text.text.contains("字像是在动"), "the scripture on the table, looked at: %s" % ui.inspection_text.text.left(30))
	ui.dismiss_current_panel()
	await _settle(tree)
	# The 丹房 and the 账房: the ledger and the papers, picked up and read.
	_check(await MapPlaces.drive_to_zone(tree, hall, &"niling.alchemy"), "west into the 丹房")
	_check(hall.select_landmark(&"niling.alchemy.landmark.furnace") and hall.inspect_selected() and ui.inspection_text.text.contains("火苗是青色的"), "the 丹炉 looked at")
	ui.dismiss_current_panel()
	await _settle(tree)
	_check(await MapPlaces.drive_to_zone(tree, hall, &"niling.counting"), "north into the 账房")
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "the 管事 too")
	var ledger: StringName = await _pick_up(tree, hall, LEDGER, &"niling.counting")
	_check(not ledger.is_empty() and session.player_held_item_ids().has(LEDGER), "the ledger taken off the desk")
	_check(hall.act_with_item(ledger), "翻看 the ledger")
	await _settle(tree)
	_check(ui.log_lines().any(func(line: String) -> bool: return line.contains("傅家坡，孩童一名")) and state.marks.get("看过账册", 0) == 1, "it names the people, not the goods: 看过账册")
	session.record_journal()
	_check(state.quests.has("main.chapter3/ledger") and StoryQuestLog.objective(state, quests).begins_with("案上还有一叠"), "the ledger step done, the papers next: %s" % [StoryQuestLog.objective(state, quests)])
	var papers: StringName = await _pick_up(tree, hall, PAPERS, &"niling.counting")
	_check(not papers.is_empty() and hall.act_with_item(papers), "the papers taken and read")
	await _settle(tree)
	_check(ui.log_lines().any(func(line: String) -> bool: return line.contains("着逆灵宫代为收管")) and state.marks.get("看过兵部文书", 0) == 1, "the 兵部 seal on them: 看过兵部文书")
	session.record_journal()
	_check(state.quests.has("main.chapter3/papers") and StoryQuestLog.objective(state, quests).begins_with("丹房西南角有石阶往下"), "the papers step done, the dungeon next: %s" % [StoryQuestLog.objective(state, quests)])
	# Down the stair: the passage, the jailers, the cells.
	_check(await MapPlaces.drive_to_zone(tree, hall, &"niling.alchemy") and await MapPlaces.take_passage(tree, hall, &"niling.alchemy.down"), "down the stone stair")
	var dungeon: WorldMapController = session.active_map() as WorldMapController
	await _settle(tree)
	_check(dungeon != null and dungeon.map_id() == &"niling.dungeon" and session.player_runtime().world_location().zone_id == &"niling.corridor", "in the passage under the 丹房: %s" % [session.active_map_id()])
	_check(_count_in(session, &"niling.corridor", &"native.npc.niling_jailer") == 2 and _count_in(session, &"niling.cell_huo", &"native.npc.huo_zheng") == 1 and _count_in(session, &"niling.cell_shitou", &"native.npc.shitou") == 1 and _count_in(session, &"niling.cell_others", &"native.npc.guanbei_corvee") == 2, "two jailers; 霍铮, 石头 and the two 关北 men in their cells")
	for second: int in 3:
		session.advance_npc_heartbeat(1.0)
	await _settle(tree)
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "the jailers let one in the crown be")
	session.record_journal()
	_check(state.quests.has("main.chapter3/dungeon") and StoryQuestLog.objective(state, quests).begins_with("牢门开不了，钥匙在大弟子玄冥子腰上") and not StoryQuestLog.is_done(state, quest), "the dungeon step done; the chapter waits at the 后殿 (C): %s" % [StoryQuestLog.objective(state, quests)])
	ui.menu_tab_shown(GameMenu.Tab.JOURNAL)
	var page: String = ui.quest_page.shown_text()
	_check(page.contains("纳供的不只是金帛") and page.contains("钥匙在大弟子玄冥子腰上"), "the 任务 page tells what the ledger said and where the key is: " + page.left(200))
	ui.close_menu()
	await _settle(tree)
	# The iron door: refused without the key, opened with it, never shut again.
	var cell: WorldDoor = dungeon.door(CELL_DOOR)
	_check(cell != null and not cell.is_open() and not dungeon.door_unlocked(CELL_DOOR), "西牢房's iron door shut and locked")
	_check(await MapPlaces.drive(tree, dungeon, MapPlaces.door_spot(dungeon, CELL_DOOR, &"niling.corridor")) and dungeon.can_operate_door(CELL_DOOR), "before it: the door is offered")
	_check(not dungeon.open_door(CELL_DOOR) and not cell.is_open() and _last_log(ui).contains("铁栅门锁着"), "tried without the key: %s" % _last_log(ui))
	_check(dungeon.select_landmark(&"niling.corridor.landmark.scratches") and dungeon.inspect_selected() and ui.inspection_text.text.contains("最后一组只有三道"), "the tally on the cell's wall")
	ui.dismiss_current_panel()
	await _settle(tree)
	var key: StringName = dungeon.give_new_item_to_player(KEY)
	_check(not key.is_empty() and dungeon.door_unlocked(CELL_DOOR) and dungeon.open_door(CELL_DOOR) and cell.is_open(), "with the key (TEST-ONLY: given; 玄冥子's in C) it opens")
	_check(not dungeon.close_door(CELL_DOOR) and cell.is_open() and not dungeon.can_operate_door(CELL_DOOR), "and is not shut again")
	_check(await MapPlaces.drive_to_zone(tree, dungeon, &"niling.cell_huo"), "into 霍铮's cell")
	var huo: NpcRuntimeState = MapPlaces.npc_at(session, &"niling.cell_huo.huo_zheng.1")
	_check(huo != null and dungeon.select_npc(huo.character_id) and dungeon.ask_selected("石头").any(func(line: String) -> bool: return line.contains("先开他的")), "霍铮 asked about the boy")
	var snapshot: GameSaveSnapshot = _capture(session)
	var encoded: GameSaveResult = GameSaveJsonCodec.encode(snapshot)
	var decoded: GameSaveResult = GameSaveJsonCodec.decode(encoded.text)
	_check(snapshot != null and decoded.snapshot != null and decoded.snapshot.player.character.quests == state.quests and decoded.snapshot.player.character.marks.get("看过账册", 0) == 1, "saved and read back: %s" % [decoded.detail])
	# Back up, the crown off in the 前殿: the room comes down on the player.
	_check(await MapPlaces.drive_to_zone(tree, dungeon, &"niling.corridor") and await MapPlaces.take_passage(tree, dungeon, &"niling.corridor.up"), "up the stair")
	hall = session.active_map() as WorldMapController
	await _settle(tree)
	_check(hall != null and hall.map_id() == &"niling.hall" and await MapPlaces.drive_to_zone(tree, hall, &"niling.front"), "back in the 前殿")
	_check(session.remove_player_item(crown).succeeded and not session.player_worn_item_ids().has(CROWN), "the crown taken off")
	for second: int in 4:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	var encounter: CombatEncounter = session.combat_encounter_coordinator().active_encounter()
	_check(encounter != null and encounter.participants().size() >= 4, "bareheaded before the five: the room rises together (%s in the fight)" % ("none" if encounter == null else str(encounter.participants().size())))


## The floor item of `definition_id` in `zone_id`, walked to and taken; "" when none.
func _pick_up(tree: SceneTree, map: WorldMapController, definition_id: StringName, zone_id: StringName) -> StringName:
	var item_id: StringName = map.floor_item_of(definition_id, zone_id)
	if item_id.is_empty():
		return &""
	var view: WorldFloorItemView = map.floor_item_view(item_id)
	if view == null or not await MapPlaces.drive(tree, map, view.global_position + Vector2(0, 40)):
		return &""
	if not map.select_floor_item(item_id) or map.take_selected_floor_item() != FloorItemPickup.Outcome.TAKEN:
		return &""
	return item_id


func _count_in(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> int:
	var found: int = 0
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if npc.definition().definition_id == definition_id and npc.world_location().zone_id == zone_id and npc.exists_in_map:
				found += 1
	return found


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
	var result: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"test", "2026-10-30T00:00:00Z")
	if result.snapshot == null:
		print("capture rejected: ", result.path, " ", result.detail)
	return result.snapshot


func _check(ok: bool, label: String) -> void:
	_count += 1
	if not ok:
		_failures.append(label)
