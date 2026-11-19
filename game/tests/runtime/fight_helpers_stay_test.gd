extends RefCounted

## DECISIONS「帮手等仗打完」: the helpers a scene summons beside the player (fights_beside_player) stay
## while a foe of that fight still stands, so a fight lost (or fled) is come back to with them; they
## go once it is won. Each place loses its first fight with a fresh character, gets up (TEST-ONLY) and
## meets the same foes again:
## - 太和殿 (第九章 揭发): the real scene, 冯策 beside; lost; Save and Continue (no save holds who
##   called him); 庾子建 falls on the player again and 冯策 comes in.
## - 冰龙厅 (终章): 商玦 and whoever drew 旋芒 (冯策, 於兰天武, 萧辟尘), as his scene summons them.
## - 关北 工地: the six officers and the 王府's six riders, as 吕隼's scene summons them.
## - 番坊 铁盾会: the clerk's 动手 lost, then pressed again while the four 浪人 still stand: nobody new
##   comes, nothing is logged as an error, the three swordsmen are in the fight.
## - won: the helpers leave as before.

const MapPlaces := preload("res://tests/support/map_places.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const LETTER: StringName = &"native:city/courier_letter"
const FENG: StringName = &"native.npc.feng_ce_beside"
const YU: StringName = &"native.npc.yu_zijian_drawn"

## [label, zone, point, foes' spawns, helpers' spawns, spawns standing by that are no part of it].
const SUMMONED: Array[Array] = [
	["冰龙厅", &"village.lakebottom2", &"village.lakebottom2.shang_jue_fighting.1", [&"native.lakebottom2.shang_jue_fighting"], [&"native.lakebottom2.feng_ce_beside", &"native.lakebottom2.yulan_tianwu_beside", &"native.lakebottom2.xiao_pichen_beside"], [&"village.icecave.lakebottom2.dragons"]],
	["关北工地", &"guanbei.fence_gate", &"guanbei.fence_gate.officer_fighting.1", [&"guanbei.fence_gate.officers_fighting"], [&"guanbei.fence_gate.riders"], []],
]

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var throne: WorldSessionController = await _session(tree)
	await _test_throne_hall(tree, throne)
	for place: Array in SUMMONED:
		var session: WorldSessionController = await _session(tree)
		await _test_summoned(tree, session, place)
		session.free()
		await tree.process_frame
	var yard: WorldSessionController = await _session(tree)
	await _test_shield_yard(tree, yard)
	yard.free()
	await tree.process_frame
	var won: WorldSessionController = await _session(tree)
	await _test_won(tree, won)
	won.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures.duplicate()}


## 第九章 揭发: lost to 庾子建 with 冯策 beside; Save, Continue; he draws again and 冯策 comes in.
func _test_throne_hall(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	StoryFixtures.chapter9_compared(session, true, false, true, true)
	session.record_journal()
	var hall: WorldMapController = MapPlaces.enter(session, &"imperial.front_hall", &"imperial.front_hall.emperor.1") # TEST-ONLY
	await _settle(tree)
	var expose: ActService = hall.service(&"imperial.front_hall.expose") as ActService
	_check(expose != null and await MapPlaces.drive(tree, hall, MapPlaces.service_spot(hall, &"imperial.front_hall.expose")) and expose.in_reach(), "太和殿: at the boy's side")
	_check(not hall.give_new_item_to_player(LETTER).is_empty(), "太和殿: the 密信 (TEST-ONLY), three proofs")
	await _settle(tree)
	expose.interact()
	await _settle(tree)
	_check(ui.is_asking(), "太和殿: the 揭发 asked first")
	ui.confirm_prompt.confirm_button.pressed.emit()
	await _settle(tree)
	await _settle(tree)
	var throne: WorldMapController = session.active_map() as WorldMapController
	_check(throne != null and throne.map_id() == &"imperial.taihe_hall", "太和殿: in")
	if throne == null:
		return
	await _until_fight(tree, session, throne)
	var feng: NpcRuntimeState = _first(throne, FENG)
	_check(feng != null and coordinator.has_active_encounter() and coordinator.active_encounter().participant_for(feng.character_id) != null, "太和殿: 庾子建 draws, 冯策 beside")
	_lose(session)
	await _settle(tree)
	var yu: NpcRuntimeState = _first(throne, YU)
	_check(state.marks.get("庾子建下狱", 0) == 0 and yu != null and yu.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "太和殿: lost, 庾子建 stands")
	_check(feng != null and feng.exists_in_map and feng.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE, "太和殿: 冯策 stays while 庾子建 stands")
	_get_up(session)
	await _settle(tree)
	# Save and Continue: nothing saved says who called 冯策; he is the player's all the same.
	var snapshot: GameSaveSnapshot = Work.capture(session)
	_check(snapshot != null, "太和殿: saved after the loss")
	session.free()
	await tree.process_frame
	if snapshot == null:
		return
	var restored: OldPineWorldRestoreResult = OldPineWorldRestoreService.build_candidate(GameSaveJsonCodec.decode(GameSaveJsonCodec.encode(snapshot).text).snapshot, tree.root)
	_check(restored.succeeded() and restored.candidate.activate_restore_candidate(), "太和殿: Continue")
	if not restored.succeeded():
		return
	var again: WorldSessionController = restored.candidate
	for frame: int in 4:
		await tree.process_frame
	again.set_process(false)
	again.configure_npc_ambience_random_source(SouthRoad.Still.new())
	var back: WorldMapController = again.active_map() as WorldMapController
	var feng_again: NpcRuntimeState = _first(back, FENG)
	_check(feng_again != null and back.npcs.summoner_of(feng_again.character_id) == again.player_runtime().character_id, "太和殿: after Continue, 冯策 is the player's")
	await _until_fight(tree, again, back)
	var encounter: CombatEncounter = again.combat_encounter_coordinator().active_encounter()
	_check(encounter != null and feng_again != null and encounter.participant_for(feng_again.character_id) != null, "太和殿: 庾子建 draws again, 冯策 in the fight")
	again.free()
	await tree.process_frame


## A scene's summons as it makes them (WorldMapNpcs.summon(): the helpers the player's); lost, got up,
## the foes fall on the player again: every helper is in it.
func _test_summoned(tree: SceneTree, session: WorldSessionController, place: Array) -> void:
	var label: String = place[0]
	var map: WorldMapController = MapPlaces.enter(session, place[1], place[2]) # TEST-ONLY: where the scene plays
	_check(map != null, "%s: on the map" % label)
	if map == null:
		return
	for spawn_id: StringName in place[5]:
		var spawn: NpcSpawnDefinition = GameContent.catalog().spawn(spawn_id)
		for point: StringName in spawn.spawn_point_ids():
			map.npcs.withdraw(map.npcs.npc_at_point(point)) # TEST-ONLY: no part of this fight
	await _settle(tree)
	var helpers: Array[NpcRuntimeState] = []
	for spawn_id: StringName in place[4]:
		helpers.append_array(map.summon(spawn_id))
	for spawn_id: StringName in place[3]:
		_check(not map.summon(spawn_id).is_empty(), "%s: %s comes" % [label, spawn_id])
	_check(not helpers.is_empty() and helpers.all(func(npc: NpcRuntimeState) -> bool: return map.npcs.summoner_of(npc.character_id) == session.player_runtime().character_id), "%s: the helpers are the player's" % label)
	await _until_fight(tree, session, map)
	_check(_in_fight(session, helpers), "%s: the first fight, the helpers in it" % label)
	_lose(session)
	await _settle(tree)
	_check(helpers.all(func(npc: NpcRuntimeState) -> bool: return npc.exists_in_map), "%s: lost, the helpers stay" % label)
	_get_up(session)
	# Away and back (as one who woke at the temple walks in again).
	MapPlaces.enter(session, &"snow.nyard", &"snow.nyard.girl.1") # TEST-ONLY
	await _settle(tree)
	map = MapPlaces.enter(session, place[1], place[2]) # TEST-ONLY
	await _settle(tree)
	_check(helpers.all(func(npc: NpcRuntimeState) -> bool: return npc.exists_in_map and map.npcs.find_resident_npc(npc.character_id) == npc), "%s: back, the helpers still there" % label)
	await _until_fight(tree, session, map)
	_check(_in_fight(session, helpers), "%s: come back, the helpers in the fight again" % label)
	_lose(session)


## 番坊: the clerk's 动手 lost; pressed again while the four still stand: quiet, the three swordsmen in.
func _test_shield_yard(tree: SceneTree, session: WorldSessionController) -> void:
	var state: CharacterState = session.player_runtime().state
	var ui: SharedGameplayUI = session.shared_ui()
	StoryFixtures.chapter7_sided(session, true, true)
	if not state.quests.has("main.chapter7/rome"):
		state.quests["main.chapter7/rome"] = state.quests.size() + 1
	for mark: String in ["火前说了真话", "铜牒到手"]:
		state.marks[mark] = 1
	state.marks.erase("学过印色")
	session.record_journal()
	MapPlaces.enter(session, &"fanfang.bazaar_north", &"fanfang.bazaar_north.hall_return")
	await _settle(tree)
	var hall: WorldMapController = await MapPlaces.go_to(tree, session, &"fanfang.shield_yard")
	_check(hall != null, "番坊: into the yard")
	if hall == null:
		return
	for second: int in 9:
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
	var papers: ActService = hall.service(&"fanfang.shield_yard.papers") as ActService
	var swordsmen: Array[NpcRuntimeState] = []
	# The first press, lost; the second while the four still stand (the player got up where they fell).
	for press: int in 2:
		if press == 1:
			# One of the four was finished off (了结) before the loss: pressed again he is made anew,
			# and the three still standing come at the player with him.
			_of_spawn(hall, &"fanfang.shield_yard.ronin_fighting")[0].set_life_status(CharacterRuntimeLifeStatus.Value.DEAD) # TEST-ONLY
		_check(await MapPlaces.drive(tree, hall, MapPlaces.service_spot(hall, &"fanfang.shield_yard.papers")) and papers.in_reach(), "番坊: at the papers (%d)" % press)
		papers.interact()
		await _settle(tree)
		_check(ui.is_asking() and ui.confirm_prompt.confirm_button.text == "动手", "番坊: 动手 asked (%d)" % press)
		ui.confirm_prompt.confirm_button.pressed.emit()
		await _settle(tree)
		await _until_fight(tree, session, hall)
		swordsmen = _of_spawn(hall, &"fanfang.shield_yard.swordsmen_beside")
		_check(swordsmen.size() == 3 and _in_fight(session, swordsmen), "番坊: the three swordsmen in the fight (%d)" % press)
		var ronin: Array[NpcRuntimeState] = _of_spawn(hall, &"fanfang.shield_yard.ronin_fighting")
		_check(ronin.size() == 4 and _in_fight(session, ronin), "番坊: four 浪人, no more, all in the fight (%d)" % press)
		_lose(session)
		await _settle(tree)
		_check(state.marks.get("冯禄的浪人倒了", 0) == 0 and not hall.npcs.standing_of(&"fanfang.shield_yard.ronin_fighting").is_empty() and swordsmen.all(func(npc: NpcRuntimeState) -> bool: return npc.exists_in_map), "番坊: lost, the four stand, the three stay (%d)" % press)
		_get_up(session)
		await _settle(tree)
	# Out of the yard and back in: the four fall on the player, the three with them.
	await MapPlaces.go_to(tree, session, &"fanfang.bazaar_north")
	hall = await MapPlaces.go_to(tree, session, &"fanfang.shield_yard")
	await _until_fight(tree, session, hall)
	_check(_in_fight(session, swordsmen), "番坊: back in, the four draw, the three in the fight")
	_lose(session)


## Won: the helpers leave as the fight ends, as before.
func _test_won(tree: SceneTree, session: WorldSessionController) -> void:
	var place: Array = SUMMONED[1]
	var map: WorldMapController = MapPlaces.enter(session, place[1], place[2]) # TEST-ONLY
	await _settle(tree)
	var helpers: Array[NpcRuntimeState] = map.summon(place[4][0])
	map.summon(place[3][0])
	_strong(session.player_runtime())
	await _until_fight(tree, session, map)
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
	_check(_of_spawn(map, place[3][0]).all(func(npc: NpcRuntimeState) -> bool: return npc.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE), "won: the officers down")
	_check(not helpers.is_empty() and helpers.all(func(npc: NpcRuntimeState) -> bool: return not npc.exists_in_map), "won: the riders gone")


## The fight runs out on 自动 with the player a fresh character: lost.
func _lose(session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	coordinator.set_manual_turns(false) # TEST-ONLY
	var rounds: int = 0
	while coordinator.has_active_encounter() and rounds < 3000:
		coordinator.advance_scheduler(1.0)
		rounds += 1
	session.shared_ui().dismiss_current_panel()
	_check(not coordinator.has_active_encounter(), "the fight over in %d rounds" % rounds)


## TEST-ONLY: the player up and whole again where they lie (as one who came to, or came back from the
## temple, would stand there).
func _get_up(session: WorldSessionController) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	player.state.ghost = false
	for track: CharacterResourceState in [player.state.essence, player.state.vitality, player.state.spirit]:
		track.effective = track.maximum
		track.current = track.maximum
	player.set_life_status(CharacterRuntimeLifeStatus.Value.ACTIVE)
	player.set_exists_in_world(true)
	player.set_combat_available(true)
	session._life_flow.finish()
	var body: WorldCharacterBody2D = session.active_map().runtime_player_body()
	if body != null:
		body.refresh_runtime_state()


func _strong(player: WorldPlayerRuntimeState) -> void:
	player.state.vitality = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	player.state.essence = CharacterResourceState.new(1000000, 1000000, 1000000) # TEST-ONLY
	player.state.progression.combat_experience = 10000000 # TEST-ONLY: the blows land


func _until_fight(tree: SceneTree, session: WorldSessionController, map: WorldMapController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	for second: int in 40:
		if coordinator.has_active_encounter():
			break
		session.advance_npc_heartbeat(1.0)
		await _settle(tree)
		map.hostilities.process_pending_aggression()
	_check(coordinator.has_active_encounter(), "a fight opens on %s" % map.map_id())


func _in_fight(session: WorldSessionController, npcs: Array[NpcRuntimeState]) -> bool:
	var encounter: CombatEncounter = session.combat_encounter_coordinator().active_encounter()
	return encounter != null and not npcs.is_empty() and npcs.all(func(npc: NpcRuntimeState) -> bool: return encounter.participant_for(npc.character_id) != null)


func _of_spawn(map: WorldMapController, spawn_id: StringName) -> Array[NpcRuntimeState]:
	var out: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.spawn_id == spawn_id and npc.exists_in_map and npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD:
			out.append(npc)
	return out


func _first(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	if map == null:
		return null
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.exists_in_map and NpcDefinition.unnamed_id(npc.definition().definition_id) == definition_id:
			return npc
	return null


func _session(tree: SceneTree) -> WorldSessionController:
	var session: WorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("帮手", CharacterState.GENDER_MALE)
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
		_failures.append("helpers stay: " + message)
