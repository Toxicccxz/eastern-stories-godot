extends RefCounted

## 茅山's people in a fight: each kind exchanges blows with the player for a while (their
## mapped 谷衣心法 hits with std/force.c's force, the taoists' three bolts, 林忌's
## 咒剑王禅) without the fight breaking off; 林忌's 召护法 brings a 阴鬼卒 to his side,
## who leaves with its lines when the fight is over. TEST-ONLY fixtures are marked.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const Specials := preload("res://tests/runtime/combat_specials_test.gd")
const MASTER: StringName = &"common.npc.taoist.taolord"
const GUARD: StringName = &"common.npc.hell_guard"
const KINDS: Array[StringName] = [
	&"temple.npc.guest", &"temple.npc.little_taoist1", MASTER, &"temple.npc.trainer", &"temple.npc.tfighter",
	&"temple.npc.little_taoist2", &"temple.npc.old_taoist", &"temple.npc.taoist", &"temple.npc.taoist2",
]


## Draws by bound: each bound's queue first, then the highest value (no chat fires).
class Forced extends CombatRandomSource:
	var queues: Dictionary[int, Array] = {}
	func next_below(bound: int) -> int:
		var queue: Array = queues.get(bound, [])
		if not queue.is_empty():
			return clampi(queue.pop_front(), 0, bound - 1)
		return bound - 1


var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.set_process(false)
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody chats or wanders
	for kind: StringName in KINDS:
		await _test_fight(tree, session, kind)
	await _test_guards_fight(tree, session)
	await _test_hell_guard(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


## Twenty rounds with seeded draws, then the player flees: nothing breaks the fight off.
func _test_fight(tree: SceneTree, session: WorldSessionController, kind: StringName) -> void:
	var map: WorldMapController = _map_of(session, kind)
	var npc: NpcRuntimeState = _first(map, kind)
	await _fight_a_while(tree, session, map, npc)


## road2.c's guards on duty (whichever were drawn): 50000 combat_exp and their bolts.
func _test_guards_fight(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.world_map_of(&"temple.grounds")
	for npc: NpcRuntimeState in map.resident_npcs():
		if String(npc.definition().definition_id).contains("guard") and npc.exists_in_map:
			await _fight_a_while(tree, session, map, npc)


func _fight_a_while(tree: SceneTree, session: WorldSessionController, map: WorldMapController, npc: NpcRuntimeState) -> void:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(npc != null, "found")
	if npc == null:
		return
	map = await _beside(tree, session, map, npc)
	player.state.vitality = CharacterResourceState.new(100000, 100000, 100000) # TEST-ONLY: outlast them
	player.state.spirit = CharacterResourceState.new(100000, 100000, 100000)
	player.state.essence = CharacterResourceState.new(100000, 100000, 100000)
	session.configure_combat_random_source(Specials.Seeded.new(11)) # TEST-ONLY
	CombatEncounterCoordinator.take_aborted_total()
	map.select_npc(npc.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks %s" % npc.definition().display_name)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	for _round: int in range(20):
		if not coordinator.has_active_encounter():
			break
		coordinator.advance_scheduler(1.0)
	_check(CombatEncounterCoordinator.take_aborted_total() == 0, "%s: twenty rounds, no break: %s" % [npc.definition().display_name, coordinator.last_abort_detail()])
	_check(player.state.vitality.current < 100000 or npc.character_state.vitality.current < npc.character_state.vitality.effective, "%s: blows were struck" % npc.definition().display_name)
	await _flee(tree, session)
	npc.character_state.vitality.current = npc.character_state.vitality.effective # TEST-ONLY: whole for the next one
	npc.character_state.spirit.current = npc.character_state.spirit.effective
	npc.character_state.essence.current = npc.character_state.essence.effective


## 林忌's chat: random(100) 0 < 30, entry 3 (invocation); random(2000) 1999, random(3) 1:
## a 阴鬼卒 comes to his side; the player flees and it leaves with its HIB lines.
func _test_hell_guard(tree: SceneTree, session: WorldSessionController) -> void:
	var map: WorldMapController = session.world_map_of(&"temple.grounds")
	var master: NpcRuntimeState = _first(map, MASTER)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	map = await _beside(tree, session, map, master)
	player.state.vitality = CharacterResourceState.new(100000, 100000, 100000) # TEST-ONLY
	master.character_state.recovery.mana.current = 4000
	master.character_state.spirit.current = master.character_state.spirit.effective
	var forced := Forced.new()
	forced.queues[100] = [0]
	forced.queues[4] = [3]
	forced.queues[2000] = [1999]
	forced.queues[3] = [1]
	session.configure_combat_random_source(forced) # TEST-ONLY
	CombatEncounterCoordinator.take_aborted_total()
	map.select_npc(master.character_id)
	_check(map.attack_selected().outcome == CombatSliceInitiationResult.Outcome.COMPLETED, "the player attacks 林忌")
	var before: Array[StringName] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		before.append(npc.character_id)
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var guard_id: StringName = &""
	for _round: int in range(10):
		coordinator.advance_scheduler(1.0)
		(session.get_node("BattlePresentationLayer/BattleSurface") as BattlePresentationController).refresh_projection()
		for npc: NpcRuntimeState in map.npc_runtimes():
			if not before.has(npc.character_id):
				guard_id = npc.character_id
		if not guard_id.is_empty() or not coordinator.has_active_encounter():
			break
	var guard: NpcRuntimeState = map.find_resident_npc(guard_id)
	_check(guard != null and SummonedNpc.definition_id_of(guard_id) == GUARD and guard.definition().name_pick().has(guard.definition().display_name), "a 阴鬼卒 came: %s" % ("" if guard == null else guard.definition().display_name))
	if guard != null:
		var encounter: CombatEncounter = coordinator.active_encounter()
		_check(encounter.participant_for(guard_id) != null and encounter.participant_for(guard_id).side_id == encounter.participant_for(master.character_id).side_id, "on 林忌's side")
		_check(_battle_log(session).contains("一道蓝光从地底升起，蓝光中出现一个手执钢叉、面目狰狞的鬼卒。"), "its coming is told in the battle log")
	_check(CombatEncounterCoordinator.take_aborted_total() == 0, "no break: " + coordinator.last_abort_detail())
	await _flee(tree, session)
	_check(map.find_resident_npc(guard_id) == null, "it left once the fight was over")
	_check(session.shared_ui().log_lines().any(func(line: String) -> bool: return line.contains("沈入地下不见了")), "with its lines")


func _flee(tree: SceneTree, session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	session.configure_combat_random_source(Forced.new()) # TEST-ONLY: no more chat
	for attempt: int in range(400):
		if not coordinator.has_active_encounter():
			break
		if coordinator.active_encounter().queued_player_action() == null:
			var info: CombatTacticalActionInfo = coordinator.action_infos()[0]
			coordinator.submit_player_action(CombatTacticalRequest.new(StringName("flee:%d" % attempt), coordinator.active_encounter().encounter_id, player.character_id, info.action_id, info.category))
		coordinator.advance_scheduler(1.0)
	_check(not coordinator.has_active_encounter() and CombatEncounterCoordinator.take_aborted_total() == 0, "fled: " + coordinator.last_abort_detail())
	await tree.process_frame


## TEST-ONLY: the player on the NPC's spawn marker (its map first, when another).
func _beside(tree: SceneTree, session: WorldSessionController, map: WorldMapController, npc: NpcRuntimeState) -> WorldMapController:
	var zone_id: StringName = npc.world_location().zone_id
	if session.active_map() != map:
		_check(session.handoff_to(map.map_id(), zone_id, zone_id, npc.spawn_point_id).succeeded(), "TEST-ONLY: to %s" % npc.definition().display_name)
		await tree.physics_frame
		await tree.physics_frame
	else:
		_check(map.relocate_player(zone_id, npc.spawn_point_id), "TEST-ONLY: beside %s" % npc.definition().display_name)
		await tree.physics_frame
	return session.active_map() as WorldMapController


func _battle_log(session: WorldSessionController) -> String:
	var battle: BattlePresentationController = session.get_node("BattlePresentationLayer/BattleSurface")
	return battle.log_panel._text.get_parsed_text()


func _map_of(session: WorldSessionController, kind: StringName) -> WorldMapController:
	for map_id: StringName in [&"temple.mountain", &"temple.grounds"]:
		if _first(session.world_map_of(map_id), kind) != null:
			return session.world_map_of(map_id)
	return null


func _first(map: WorldMapController, definition_id: StringName) -> NpcRuntimeState:
	if map == null:
		return null
	for npc: NpcRuntimeState in map.resident_npcs():
		if npc.definition().definition_id == definition_id:
			return npc
	return null


func _check(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures.append(message)
