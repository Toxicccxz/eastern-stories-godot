extends RefCounted

## 进门一起上 (DECISIONS): attack.c init() runs for every NPC in the room the player comes
## into, so everyone there who attacks the player on sight falls on them together, in one
## fight. Here: 京师's 东一门 (outdoors, three 守城兵 on a player with a vendetta: one in
## reach brings all three, none from the street beside or the next gate); having fought, they
## wait until the player has left their place; a 守城兵 who hunts the player kills one way, with
## catch_hunt_msg; the player's own 攻击 there takes the gang along; 乔阴's 北门 lets its
## ghost and its 巡捕 be. No multi-room zone holds attackers from two ES2 rooms.
const Work := preload("res://tests/runtime/snow_work_income_test.gd")
const SouthRoad := preload("res://tests/runtime/snow_south_road_test.gd")
const GATE: StringName = &"city.eastdoor1"
const STREET: StringName = &"city.street9"
const NEXT_GATE: StringName = &"city.eastdoor2"
const GUARD: StringName = &"city.npc.guard"
const WARNING: String = "看起来京师守城兵想杀死你！"

var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	_test_data()
	var session: WorldSessionController = Work.create_session(tree)
	await tree.process_frame
	session.configure_npc_ambience_random_source(SouthRoad.Still.new()) # TEST-ONLY: nobody wanders off
	session.player_runtime().state.vitality = CharacterResourceState.new(10000000, 10000000, 10000000) # TEST-ONLY: the fights are not the point
	session.player_runtime().state.vendetta["authority"] = 1 # TEST-ONLY: the guards' grudge (garrison.c)
	await _test_gate(tree, session)
	await _test_hatred(tree, session)
	await _test_own_attack(tree, session)
	await _test_bystanders(tree, session)
	session.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


## The gang is the zone: a zone of several ES2 rooms must not hold attackers from two of them
## (else it would need splitting, or a decision).
func _test_data() -> void:
	var catalog: ContentCatalog = GameContent.catalog()
	var rooms: Dictionary[StringName, Dictionary] = {}
	for spawn: NpcSpawnDefinition in catalog.spawns():
		var zone: ZoneDefinition = catalog.zone(spawn.zone_id)
		var npc: NpcDefinition = catalog.npc(spawn.npc_definition_id)
		if zone == null or npc == null or zone.room_ids().size() < 2:
			continue
		var dealings: NpcDealings = npc.dealings()
		if npc.has_capability(NpcDefinition.CAPABILITY_AGGRESSIVE_ON_PLAYER_PRESENCE) or not dealings.vendetta_mark.is_empty() or dealings.takes_toll():
			if not rooms.has(spawn.zone_id):
				rooms[spawn.zone_id] = {}
			rooms[spawn.zone_id][spawn.legacy_source_room_path] = true
	for zone_id: StringName in rooms:
		_check(rooms[zone_id].size() == 1, "%s: its attackers all come from one ES2 room: %s" % [zone_id, rooms[zone_id].keys()])
	_check(rooms.has(&"oldpine.outdoor.slope"), "the slope's 探哨 are counted (a zone of four rooms)")


## In reach of one 守城兵 only, on the street side of the gate first (his circle crosses the
## seam: nothing, another place), then inside it: all three fall on the player at once, the
## next gate's stay where they are.
func _test_gate(tree: SceneTree, session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var map: WorldMapController = MapPlaces.enter(session, &"city.nroad2", &"city.nroad2.village_arrival") # TEST-ONLY: at the city
	if not _check(map != null and map.map_id() == MapPlaces.map_of(GATE), "TEST-ONLY: on 京师's map"):
		return
	var guards: Array[NpcRuntimeState] = _guards(map, GATE)
	if not _check(guards.size() == 3, "three 守城兵 at the 东一门: %d" % guards.size()):
		return
	var nearest: NpcRuntimeState = _westmost(map, guards)
	var at: Vector2 = map.runtime_body_for_character(nearest.character_id).global_position
	var seam: float = MapPlaces.zone_rect(map, GATE).position.x
	await _place(tree, map, STREET, Vector2(seam - 8.0, at.y))
	_check(map.hostilities.complete_entry_contact(nearest.character_id), "on the street, within his circle")
	await _frames(tree, coordinator)
	_check(not coordinator.has_active_encounter(), "on the street beside the gate: another place, nobody comes")
	var said: int = session.shared_ui().log_lines().size()
	await _place(tree, map, GATE, Vector2(seam + 16.0, at.y))
	var others: Array[NpcRuntimeState] = guards.filter(func(npc: NpcRuntimeState) -> bool: return npc != nearest and not map.hostilities.complete_entry_contact(npc.character_id))
	_check(others.size() >= 1, "inside the gate, out of reach of the others: %d" % others.size())
	await _frames(tree, coordinator)
	var encounter: CombatEncounter = coordinator.active_encounter()
	if not _check(encounter != null and encounter.participants().size() == 4, "one fight, the player and all three: %s" % ("none" if encounter == null else str(encounter.participants().size()))):
		await _finish(tree, session)
		return
	for npc: NpcRuntimeState in guards:
		_check(npc.relationship.has_lethal_target(player.character_id) and player.relationship.has_lethal_target(npc.character_id), "start_vendetta()'s kill_ob(): %s" % npc.character_id)
	for npc: NpcRuntimeState in _guards(map, NEXT_GATE):
		_check(encounter.participant_for(npc.character_id) == null and not npc.relationship.is_fighting(), "the next gate's 守城兵 stay where they are")
	var lines: Array[String] = session.shared_ui().log_lines().slice(said)
	_check(lines.count(WARNING) == 3, "kill_ob()'s warning from each: %s" % [lines])
	await _flee(tree, session)
	_check(not coordinator.has_active_encounter() and player.world_location().zone_id == GATE, "fled, still at the gate")
	await _place(tree, map, GATE, MapPlaces.zone_centre(map, GATE) + Vector2(0, 40))
	await _frames(tree, coordinator)
	_check(not coordinator.has_active_encounter(), "having fought, they let the player be while they stay in the gate")
	await _place(tree, map, STREET, Vector2(seam - 80.0, at.y))
	await _frames(tree, coordinator)
	_check(map.hostilities.spent.is_empty(), "out on the street: they may meet the player anew")
	await _place(tree, map, GATE, Vector2(seam + 16.0, at.y))
	await _frames(tree, coordinator)
	encounter = coordinator.active_encounter()
	_check(encounter != null and guards.all(func(npc: NpcRuntimeState) -> bool: return encounter.participant_for(npc.character_id) != null), "back in the gate: all three again")
	await _flee(tree, session)


## A 守城兵 who hunts the player (TEST-ONLY: attack.c is_killing()) comes first in init()'s
## order: start_hatred()'s line, a kill the player only fights back; the others kill both ways.
func _test_hatred(tree: SceneTree, session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var map: WorldMapController = session.active_map() as WorldMapController
	var guards: Array[NpcRuntimeState] = _guards(map, GATE)
	var hunter: NpcRuntimeState = guards[0]
	hunter.set_flag(NpcDefinition.FLAG_HUNTS_PLAYER, true) # TEST-ONLY
	var at: Vector2 = map.runtime_body_for_character(_westmost(map, guards).character_id).global_position
	var seam: float = MapPlaces.zone_rect(map, GATE).position.x
	await _place(tree, map, STREET, Vector2(seam - 80.0, at.y))
	await _frames(tree, coordinator)
	var said: int = session.shared_ui().log_lines().size()
	await _place(tree, map, GATE, Vector2(seam + 16.0, at.y))
	await _frames(tree, coordinator)
	var encounter: CombatEncounter = coordinator.active_encounter()
	if _check(encounter != null and encounter.participants().size() == 4, "the hunter comes with the gang"):
		_check(hunter.relationship.has_lethal_target(player.character_id) and not player.relationship.has_lethal_target(hunter.character_id), "start_hatred(): he kills, the player fights back")
		_check(guards.slice(1).all(func(npc: NpcRuntimeState) -> bool: return player.relationship.has_lethal_target(npc.character_id)), "the others kill both ways")
		var lines: Array[String] = session.shared_ui().log_lines().slice(said)
		var hunts: Array[String] = []
		for template: String in WorldMapHostilities.CATCH_HUNT:
			hunts.append(template.replace("$N", "京师守城兵").replace("$n", "你"))
		_check(lines.any(func(line: String) -> bool: return hunts.has(line)), "catch_hunt_msg: %s" % [lines])
	await _flee(tree, session)
	hunter.set_flag(NpcDefinition.FLAG_HUNTS_PLAYER, false)
	await _place(tree, map, STREET, Vector2(seam - 80.0, at.y))
	await _frames(tree, coordinator)


## The player's own 攻击 at a 守城兵 the player stands beside after a flight: the others of
## the gate, who fought them just now, come too.
func _test_own_attack(tree: SceneTree, session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var map: WorldMapController = session.active_map() as WorldMapController
	var guards: Array[NpcRuntimeState] = _guards(map, GATE)
	var target: NpcRuntimeState = _westmost(map, guards)
	var at: Vector2 = map.runtime_body_for_character(target.character_id).global_position
	var seam: float = MapPlaces.zone_rect(map, GATE).position.x
	await _place(tree, map, GATE, Vector2(seam + 16.0, at.y))
	await _frames(tree, coordinator)
	await _flee(tree, session)
	if not _check(not coordinator.has_active_encounter() and map.select_npc(target.character_id), "fled, the 守城兵 beside the player selected"):
		return
	var started: CombatSliceInitiationResult = map.attack_selected()
	var encounter: CombatEncounter = coordinator.active_encounter()
	_check(started.outcome == CombatSliceInitiationResult.Outcome.COMPLETED and encounter != null and encounter.participants().size() == 4, "攻击 one of them: the gate's three fight the player")
	await _flee(tree, session)
	await _place(tree, map, STREET, Vector2(seam - 80.0, at.y))
	await _frames(tree, coordinator)


## 乔阴's 北门: its four guards fall on a player with a vendetta; its 孤魂野鬼 and any
## 慕容巡捕 there, who attack nobody on sight, are not in it.
func _test_bystanders(tree: SceneTree, session: WorldSessionController) -> void:
	var coordinator: CombatEncounterCoordinator = session.combat_encounter_coordinator()
	var map: WorldMapController = MapPlaces.enter(session, &"choyin.n_gate", &"choyin.n_gate.road_arrival") # TEST-ONLY: at 乔阴's north gate
	if not _check(map != null, "TEST-ONLY: at 乔阴's 北门"):
		return
	var guards: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		if npc.exists_in_map and npc.world_location().zone_id == &"choyin.n_gate" and npc.definition().attacks_on_sight(npc.flags(), session.player_runtime().state):
			guards.append(npc)
	_check(guards.size() == 4, "four guards at the gate: %d" % guards.size())
	var others: Array[NpcRuntimeState] = map.npc_runtimes().filter(func(npc: NpcRuntimeState) -> bool: return npc.exists_in_map and npc.world_location().zone_id == &"choyin.n_gate" and not guards.has(npc))
	_check(not others.is_empty(), "someone else stands at the gate (its 孤魂野鬼): %d" % others.size())
	await _frames(tree, coordinator)
	if not coordinator.has_active_encounter():
		await MapPlaces.drive(tree, map, map.runtime_body_for_character(guards[0].character_id).global_position + Vector2(0, 48))
		await _frames(tree, coordinator)
	var encounter: CombatEncounter = coordinator.active_encounter()
	if not _check(encounter != null and encounter.participants().size() == 5, "the four in one fight: %s" % ("none" if encounter == null else str(encounter.participants().size()))):
		await _finish(tree, session)
		return
	for participant: CombatParticipant in encounter.participants():
		var npc: NpcRuntimeState = map.npcs.find_resident_npc(participant.participant_id)
		_check(npc == null or guards.has(npc), "only those who attack on sight: %s" % participant.participant_id)
	for npc: NpcRuntimeState in others:
		_check(encounter.participant_for(npc.character_id) == null, "%s is not in it" % npc.definition().display_name)
	await _flee(tree, session)


func _guards(map: WorldMapController, zone_id: StringName) -> Array[NpcRuntimeState]:
	var found: Array[NpcRuntimeState] = []
	for npc: NpcRuntimeState in map.npc_runtimes():
		if NpcDefinition.unnamed_id(npc.definition_id) == GUARD and npc.world_location().zone_id == zone_id and npc.exists_in_map:
			found.append(npc)
	return found


func _westmost(map: WorldMapController, npcs: Array[NpcRuntimeState]) -> NpcRuntimeState:
	var best: NpcRuntimeState = null
	for npc: NpcRuntimeState in npcs:
		if best == null or map.runtime_body_for_character(npc.character_id).global_position.x < map.runtime_body_for_character(best.character_id).global_position.x:
			best = npc
	return best


## TEST-ONLY: the player stands at `at` in `zone_id`.
func _place(tree: SceneTree, map: WorldMapController, zone_id: StringName, at: Vector2) -> void:
	map.runtime_player_body().global_position = MapPlaces.spot(map, zone_id, at, 24.0)
	map.player_runtime().set_world_location(map.location_for_zone(zone_id))
	await tree.physics_frame
	await tree.physics_frame


func _frames(tree: SceneTree, coordinator: CombatEncounterCoordinator) -> void:
	for _frame: int in range(4):
		if coordinator.has_active_encounter():
			return
		await tree.process_frame
		await tree.physics_frame


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


func _finish(tree: SceneTree, session: WorldSessionController) -> void:
	await _flee(tree, session)


func _check(ok: bool, label: String) -> bool:
	_count += 1
	if not ok:
		_failures.append("hostile gang: " + label)
	return ok
