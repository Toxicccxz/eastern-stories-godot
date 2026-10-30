extends RefCounted

## 逆灵宫 D (owner's plan, 2026-10-29; DECISIONS「逆灵宫 D」): what the third chapter's endings
## leave behind, from the two ledgers (StoryFixtures):
## - rescued (霍铮 home): the turn's four bandits let the player be (ignores_when 霍铮回了寨, under
##   the modern pace's story_parley; a 经典 session still gets ES2's attack on sight), 刘安禄
##   gone from 淳风武馆's gate and standing in the 土地庙 as 二寨主 (spared and 霍铮 home), 霍铮
##   there too; the 农妇's scene at 傅家坡 (thanks for the son the stockade sent home: her mood
##   团圆, 石头 in the yard from the next visit);
## - chased (玄冥子 down): 黄霸 grown (野羊山寨主, lasting) with his word for it, 刘安禄 still the
##   门房; 玄冥子 spared on the cliff answers 六阴剑 to one who carries the 残卷.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SCROLL: StringName = &"native:niling/scroll_fragment"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var rescued: WorldSessionController = await _session(tree)
	await _test_rescued(tree, rescued)
	rescued.free()
	await tree.process_frame
	var chased: WorldSessionController = await _session(tree)
	await _test_chased(tree, chased)
	chased.free()
	await tree.process_frame
	var classic: WorldSessionController = await _session(tree, CharacterState.PACE_CLASSIC)
	await _test_classic(tree, classic)
	classic.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


func _test_rescued(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	StoryFixtures.chapter3_rescued(session)
	session.record_journal()
	_check(StoryQuestLog.is_done(state, GameContent.catalog().story_quest(&"main.chapter3")), "the chapter done by the rescue")
	# The turn: the bandits let the player be.
	var bandit: NpcDefinition = GameContent.catalog().npc(&"goathill.npc.bandit")
	_check(bandit.dealings().ignores_when != null and bandit.dealings().ignores_when.key == "霍铮回了寨" and bandit.dealings().ignores_with_parley and GameContent.catalog().npc(&"goathill.npc.bandit_leader").dealings().ignores_with_parley, "the turn's bandits ignore one 霍铮 vouches for, under the parley")
	var mountain: WorldMapController = MapPlaces.enter(session, &"goathill.mroad4", &"goathill.mroad4.rope_return")
	_check(mountain != null and _count_in(session, &"goathill.mroad4", &"goathill.npc.bandit") >= 1, "at the turn among the bandits (TEST-ONLY: straight there)")
	await _settle(tree)
	for second: int in 4:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(not session.combat_encounter_coordinator().has_active_encounter(), "nobody draws on the player 霍铮 vouched for")
	# 雪亭镇: the 门房 is gone from 淳风武馆's gate.
	var snow: WorldMapController = MapPlaces.enter(session, &"snow.school1", &"snow.school1.guard.1")
	_check(snow != null, "at 淳风武馆's gate (TEST-ONLY: straight there)")
	await _settle(tree)
	_check(_count_in(session, &"snow.school1", &"snow.npc.guard") == 0, "刘安禄 is no longer the 门房 (his spawn's until: spared, and 霍铮 home)")
	# The 土地庙: 霍铮 and 刘安禄 as 二寨主.
	var temple: WorldMapController = MapPlaces.enter(session, &"goathill.temple1", &"goathill.temple1.mroad3_entry")
	_check(temple != null, "in the 土地庙")
	await _settle(tree)
	_check(_count_in(session, &"goathill.temple1", &"native.npc.huo_zheng") == 1 and _count_in(session, &"goathill.temple1", &"native.npc.liu_anlu_home") == 1, "霍铮 and 刘安禄 in the 土地庙")
	var liu: NpcRuntimeState = MapPlaces.npc_at(session, &"goathill.temple1.liu_anlu.1")
	_check(liu != null and temple.place_player(&"goathill.temple1", temple.runtime_body_for_character(liu.character_id).global_position + Vector2(0, 50)) and temple.select_npc(liu.character_id) and temple.ask_selected("回寨").any(func(said: String) -> bool: return said.contains("另找人吧")), "刘安禄 on coming home")
	_check(temple.select_npc(liu.character_id) and temple.ask_selected("血手").any(func(said: String) -> bool: return said.contains("欠你两条命")), "and on 血手刘三")
	var hwang: NpcRuntimeState = MapPlaces.npc_at(session, &"goathill.temple1.bandit_hwang.1")
	_check(hwang != null and temple.place_player(&"goathill.temple1", temple.runtime_body_for_character(hwang.character_id).global_position + Vector2(0, 50)) and temple.select_npc(hwang.character_id) and temple.ask_selected("霍铮").any(func(said: String) -> bool: return said.contains("大哥在里屋")), "黄霸: 大哥在里屋")
	# 傅家坡: the 农妇's thanks, her mood; 石头 in the yard on the next visit.
	var farm: WorldMapController = MapPlaces.enter(session, &"village.farmhouse1", &"village.farmhouse1.road4_entry")
	_check(farm != null and await MapPlaces.drive_to_zone(tree, farm, &"village.fmhousback"), "into the farmhouse's back yard (TEST-ONLY: straight to its door)")
	await _settle(tree)
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	_check(session.scene_held() and farm.scene_running() and state.marks.get("农妇谢过", 0) == 1, "the 农妇's scene as the player comes in")
	var log_before: int = ui.log_lines().size()
	for second: int in 20:
		if not farm.scene_running():
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	var woman: NpcRuntimeState = MapPlaces.npc_at(session, &"village.fmhousback.woman1.1")
	_check(not farm.scene_running() and ui.log_lines().slice(log_before).any(func(said: String) -> bool: return said.contains("野羊寨的两个弟兄把石头送回来的")), "her thanks: the stockade's men brought the boy")
	_check(woman != null and woman.has_flag(StringName(NpcMood.FLAG_PREFIX + "reunited")) and woman.definition().hooks().moods["reunited"].lasting, "团圆: her mood, lasting")
	_check(_count_in(session, &"village.fmhousback", &"native.npc.shitou") == 1, "石头 in the yard (home before the player came: the stage put him there)")
	var road: WorldMapController = MapPlaces.enter(session, &"village.road4", &"village.road4.farmhouse1_return")
	farm = MapPlaces.enter(session, &"village.farmhouse1", &"village.farmhouse1.road4_entry")
	await _settle(tree)
	_check(road != null and farm != null and _count_in(session, &"village.fmhousback", &"native.npc.shitou") == 1, "and there on the next visit")
	var snapshot: GameSaveSnapshot = _capture(session)
	_check(snapshot != null, "Save")


func _test_chased(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	StoryFixtures.chapter3_chased(session)
	session.record_journal()
	_check(StoryQuestLog.is_done(state, GameContent.catalog().story_quest(&"main.chapter3")), "the chapter done by the chase")
	# The 土地庙: 黄霸 grown; 刘安禄 still the 门房 elsewhere.
	var temple: WorldMapController = MapPlaces.enter(session, &"goathill.temple1", &"goathill.temple1.mroad3_entry")
	_check(temple != null, "in the 土地庙")
	await _settle(tree)
	session.advance_npc_heartbeat(0.5)
	await _settle(tree)
	var hwang: NpcRuntimeState = MapPlaces.npc_at(session, &"goathill.temple1.bandit_hwang.1")
	_check(hwang != null and hwang.has_flag(StringName(NpcMood.FLAG_PREFIX + "grown")) and state.marks.get("黄霸坐大了", 0) == 1 and ui.log_lines().any(func(said: String) -> bool: return said.contains("寨子是老子的")), "黄霸 grown: 野羊山寨主, his word for it")
	_check(temple.place_player(&"goathill.temple1", temple.runtime_body_for_character(hwang.character_id).global_position + Vector2(0, 50)) and temple.select_npc(hwang.character_id) and temple.ask_selected("霍铮").any(func(said: String) -> bool: return said.contains("野羊山现在姓黄")), "黄霸: 野羊山现在姓黄")
	_check(_count_in(session, &"goathill.temple1", &"native.npc.huo_zheng") == 0 and _count_in(session, &"goathill.temple1", &"native.npc.liu_anlu_home") == 0, "no 霍铮, no 刘安禄 here")
	var snow: WorldMapController = MapPlaces.enter(session, &"snow.school1", &"snow.school1.guard.1")
	await _settle(tree)
	_check(snow != null and _count_in(session, &"snow.school1", &"snow.npc.guard") == 1, "刘安禄 keeps 淳风武馆's gate")
	# The turn: the bandits are as ES2 made them.
	var mountain: WorldMapController = MapPlaces.enter(session, &"goathill.mroad4", &"goathill.mroad4.rope_return")
	await _settle(tree)
	for second: int in 4:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(mountain != null and session.combat_encounter_coordinator().has_active_encounter(), "the turn's bandits fall on the player as ever")
	await _flee(tree, session)
	# The cliff: 玄冥子 spared answers 六阴剑 to one with the 残卷 (owner Q3: the hook only).
	var backhill: WorldMapController = MapPlaces.enter(session, &"niling.cliff_path", &"niling.cliff_path.door_arrival")
	_check(backhill != null and _count_in(session, &"niling.cliff_path", &"native.npc.xuan_mingzi_cliff") == 1, "玄冥子 on the cliff path")
	await _settle(tree)
	var xuan: NpcRuntimeState = MapPlaces.npc_at(session, &"niling.cliff_path.xuan_mingzi.1")
	session.npc_spared(xuan) # TEST-ONLY: as 放过 on the fight's panel
	await _flee(tree, session)
	_check(xuan.has_flag(StringName(NpcMood.FLAG_PREFIX + "owed")), "spared: 欠你一命")
	_check(backhill.place_player(&"niling.cliff_path", backhill.runtime_body_for_character(xuan.character_id).global_position + Vector2(0, 60)) and backhill.select_npc(xuan.character_id) and backhill.ask_selected("六阴剑").any(func(said: String) -> bool: return said.contains("残卷不在你身上")), "without the 残卷: no")
	var scroll: StringName = backhill.give_new_item_to_player(SCROLL)
	_check(not scroll.is_empty() and backhill.select_npc(xuan.character_id) and backhill.ask_selected("六阴剑").any(func(said: String) -> bool: return said.contains("带着残卷来后山找我")), "with it: the hook for the 魔道 line")
	_check(backhill.select_npc(xuan.character_id) and backhill.ask_selected("商玦").any(func(said: String) -> bool: return said.contains("他不要我了")), "and his word on 商玦")


## 经典: the turn's bandits attack on sight, 霍铮 home or not (no story parley).
func _test_classic(tree: SceneTree, session: WorldSessionController) -> void:
	StoryFixtures.chapter3_rescued(session)
	session.record_journal()
	_check(not GameContent.catalog().pacing().story_parley, "经典: no story parley")
	var mountain: WorldMapController = MapPlaces.enter(session, &"goathill.mroad4", &"goathill.mroad4.rope_return")
	await _settle(tree)
	for second: int in 4:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	_check(mountain != null and session.combat_encounter_coordinator().has_active_encounter(), "经典: the bandits attack as ES2, 霍铮 or no 霍铮")
	await _flee(tree, session)


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


func _where(session: WorldSessionController, definition_id: StringName) -> Array:
	var found: Array = []
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if npc.definition().definition_id == definition_id:
				found.append([map.map_id(), npc.world_location().zone_id, npc.exists_in_map, npc.has_flag(NpcDefinition.FLAG_GONE)])
	return found


func _count_in(session: WorldSessionController, zone_id: StringName, definition_id: StringName) -> int:
	var found: int = 0
	for map: WorldMapController in session.world_maps():
		for npc: NpcRuntimeState in map.npc_runtimes():
			if npc.definition().definition_id == definition_id and npc.world_location().zone_id == zone_id and npc.exists_in_map and not npc.has_flag(NpcDefinition.FLAG_GONE):
				found += 1
	return found


func _session(tree: SceneTree, pace: StringName = CharacterState.PACE_MODERN) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("逆灵宫", CharacterState.GENDER_MALE, pace)
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
