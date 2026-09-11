extends RefCounted

const Entry := preload("res://tests/qa/nge3_snow_route.gd")
var _count: int = 0
var _failures: Array[String] = []

class RejectPreparation:
	extends WorldResidentMapController
	var marker: WorldSpawnMarker2D = WorldSpawnMarker2D.new()
	func map_id() -> StringName:
		return &"test.reject"
	func resolve_location(_zone: StringName, _combat: StringName) -> WorldLocationState:
		return WorldLocationState.new(&"snow", map_id(), &"test.zone", &"test.zone")
	func resolve_spawn_marker(_id: StringName) -> WorldSpawnMarker2D:
		return marker
	func spawn_matches_zone(_id: StringName, _zone: StringName) -> bool:
		return true
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE and is_instance_valid(marker):
			marker.free()


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var unbound: SnowInnController = SnowInnController.new()
	_check(not unbound.complete_activation(), "uninitialized activation fails closed before Player access")
	_check(not unbound.prepare_for_activation(SnowWorldDefinitions.BIRTH_SPAWN_ID), "uninitialized preparation fails closed before scene access")
	unbound.free()
	var entry: Entry = (load("res://tests/qa/nge3_snow_route.tscn") as PackedScene).instantiate()
	tree.root.add_child(entry)
	_check(entry._initialized, "two-map QA composition initializes")
	if not entry._initialized:
		entry.free()
		return {"assertions": _count, "failures": _failures}
	var player: WorldPlayerRuntimeState = entry._player
	var identities: Array[Object] = [player, player.state, player.state.equipment, player.armor, entry.birth.inventory, entry.birth.stacks, entry.birth.item_index, entry.allocator, entry.npc_random, entry.combat_random, entry.world_random, entry._world_simulation_gate]
	_check(SnowWorldDefinitions.outdoor_map().zone_ids() == SnowWorldDefinitions.ROUTE_ZONE_IDS, "one map / five ordered native zones")
	for zone: ZoneDefinition in SnowWorldDefinitions.route_zones():
		_check(zone.is_valid() and zone.map_id == &"snow.outdoor" and zone.combat_location_id == zone.zone_id, "valid authored zone and combat identity")
	var expected_exits: Dictionary[String, String] = {
		"square:north":"/d/snow/mstreet1", "square:west":"/d/snow/inn", "square:south":"/d/snow/sroad1", "square:east":"/d/snow/temple",
		"sroad1:north":"/d/snow/square", "sroad1:east":"/d/snow/eroad1", "sroad1:west":"/d/snow/sroad2", "sroad1:south":"/u/cloud/dragonhill/nroad",
		"eroad1:west":"/d/snow/sroad1", "eroad1:east":"/d/snow/eroad2", "eroad1:north":"/d/snow/temple",
		"eroad2:west":"/d/snow/eroad1", "eroad2:east":"/d/snow/eroad3",
		"eroad3:west":"/d/snow/eroad2", "eroad3:east":"/d/temple/sroad", "eroad3:south":"/d/oldpine/npath1",
	}
	_check(SnowWorldDefinitions.authored_outdoor_exits() == expected_exits, "all sixteen inspected LPC exits exact")
	_check(SnowWorldDefinitions.outdoor_map().portal_ids() == [SnowWorldDefinitions.INN_RETURN_PORTAL_ID], "only west Inn transition executable")
	_check(SnowWorldDefinitions.portal_by_id(&"eroad3:south") == null, "Old Pine not a native portal")
	_check(SnowWorldDefinitions.LEGACY_SQUARE_TRAV_BLADE_COUNT == 3 and SnowWorldDefinitions.LEGACY_EROAD2_DOG_COUNT == 2, "authored population counts")
	_check(entry.inn.resident_npcs().is_empty() and entry.outdoor.resident_npcs().is_empty(), "no dummy NPCs")
	_check(entry.outdoor.find_children("*", "CharacterBody2D", true, false).size() == 1, "outdoor only Player body")
	_check(entry.inn.birth_marker.position != entry.inn.resolve_spawn_marker(SnowWorldDefinitions.INN_RETURN_SPAWN_ID).position, "return marker is not fresh birth")
	_continuity(entry, identities)
	var source: WorldLocationState = player.world_location()
	var invalids: Array[OldPineMapHandoffResult] = [
		entry.handoff_to(&"unknown", &"snow.square", &"snow.square", SnowWorldDefinitions.SQUARE_ENTRY_SPAWN_ID),
		entry.handoff_to(&"snow.outdoor", &"snow.square", &"snow.square", &"missing"),
		entry.handoff_to(&"snow.outdoor", &"snow.eroad1", &"snow.eroad1", SnowWorldDefinitions.SQUARE_ENTRY_SPAWN_ID),
		entry.handoff_to(&"snow.outdoor", &"snow.square", &"wrong", SnowWorldDefinitions.SQUARE_ENTRY_SPAWN_ID),
	]
	var outcomes: Array[int] = [OldPineMapHandoffResult.Outcome.UNKNOWN_DESTINATION_MAP, OldPineMapHandoffResult.Outcome.DESTINATION_MARKER_MISSING, OldPineMapHandoffResult.Outcome.DESTINATION_LOCATION_INVALID, OldPineMapHandoffResult.Outcome.DESTINATION_LOCATION_INVALID]
	for index: int in range(invalids.size()):
		_check(invalids[index].outcome == outcomes[index] and not invalids[index].location_committed, "invalid destination fails before mutation")
	player.set_world_location(WorldLocationState.new(&"snow", &"snow.inn", &"bad", &"bad"))
	_check(_to_square(entry).outcome == OldPineMapHandoffResult.Outcome.SOURCE_LOCATION_INVALID, "invalid source rejected")
	player.set_world_location(source)
	entry._world_simulation_gate.acquire(&"test.freeze")
	_check(_to_square(entry).outcome == OldPineMapHandoffResult.Outcome.WORLD_SIMULATION_FROZEN, "frozen world refuses handoff")
	entry._world_simulation_gate.release(&"test.freeze")
	var rejected: RejectPreparation = RejectPreparation.new()
	_check(entry.register_resident_map(rejected), "failure seam registered")
	_check(entry.handoff_to(&"test.reject", &"test.zone", &"test.zone", &"marker").outcome == OldPineMapHandoffResult.Outcome.DESTINATION_PREPARATION_FAILED, "preparation failure retains source")
	entry._resident_maps.erase(rejected.map_id())
	rejected.free()
	_check(entry.active_map() == entry.inn and entry.active_map_child_count() == 1 and player.world_location().same_location(source), "failures preserve source containment/location")
	_continuity(entry, identities)
	_check(_to_square(entry).succeeded(), "shared explicit boundary Inn to Square")
	_check(not entry.inn.is_inside_tree() and not entry.inn.player_body.player_controlled and not (entry.inn.player_body.get_node("Camera2D") as Camera2D).enabled, "inactive Inn detached/input/camera off")
	_check(entry.outdoor.player_body.position == entry.outdoor.birth_marker.position, "Square authored entry marker")
	_check(not entry.outdoor.accept_zone_presence(entry.outdoor.get_node("Zones/EastRoad3")), "remote nonadjacent zone cannot be selected")
	_continuity(entry, identities)
	# A return must preserve deliberately changed state, not merely match defaults.
	player.state.recovery.food = 123
	player.state.recovery.water = 234
	player.state.progression.combat_experience = 7
	_check(entry.handoff_to(SnowWorldDefinitions.INN_MAP_ID, SnowWorldDefinitions.MAIN_FLOOR_ZONE_ID, SnowWorldDefinitions.MAIN_FLOOR_COMBAT_LOCATION_ID, SnowWorldDefinitions.INN_RETURN_SPAWN_ID).succeeded(), "Square to Inn boundary")
	_check(entry.inn.player_body.position == Vector2(350, 0), "return east marker, not origin")
	_check(player.state.recovery.food == 123 and player.state.recovery.water == 234 and player.state.progression.combat_experience == 7 and entry.allocator.next_dynamic_sequence == 1, "return never rebirth/refill/reallocate")
	_continuity(entry, identities)
	entry.free()
	await tree.process_frame
	# Separate clean birth fixture exercises physical input/Area transitions end to end.
	entry = (load("res://tests/qa/nge3_snow_route.tscn") as PackedScene).instantiate()
	tree.root.add_child(entry)
	await tree.physics_frame
	await _walk(tree, entry, "move_right", 125)
	_check(entry.active_map_id() == &"snow.outdoor", "real physics east doorway triggers handoff")
	# Stop at square center before turning south. No position/zone setters in this route.
	await _walk_to_x(tree, entry, 0.0, "move_right")
	await _walk_to_y(tree, entry, 550.0, "move_down")
	_check(entry._player.world_location().zone_id == &"snow.sroad1", "physical south turn")
	await _walk_to_x(tree, entry, 1100.0, "move_right")
	_check(entry._player.world_location().zone_id == &"snow.eroad3", "all east road Areas traversed")
	await _walk(tree, entry, "move_down", 120)
	_check(entry._player.world_location().zone_id == &"snow.eroad3" and entry.outdoor.player_body.position.y < 850.0, "Old Pine south boundary collides, no transition")
	await _walk_to_y(tree, entry, 550.0, "move_up")
	await _walk_to_x(tree, entry, 0.0, "move_left")
	await _walk_to_y(tree, entry, 0.0, "move_up")
	await _walk(tree, entry, "move_left", 85)
	_check(entry.active_map_id() == &"snow.inn", "real west trigger returns to Inn")
	await tree.process_frame
	_check(entry.zone_history == [&"snow.inn.main_floor", &"snow.square", &"snow.sroad1", &"snow.eroad1", &"snow.eroad2", &"snow.eroad3", &"snow.eroad2", &"snow.eroad1", &"snow.sroad1", &"snow.square", &"snow.inn.main_floor"], "complete physical zone order, no extra map load: " + str(entry.zone_history))
	_check(entry._player.state.recovery.food == 400 and entry._player.state.recovery.water == 400 and entry._player.state.progression.combat_experience == 0, "walking consumes no invented food/RNG/progression")
	_check(entry.allocator.next_dynamic_sequence == 1 and entry.birth.inventory.registered_item_ids().size() == 1, "one cloth still exact on round trip")
	_check(entry.inn.initialization_count() == 1 and entry.outdoor.initialization_count() == 1, "no scene reinitialization during physical route")
	_check(entry.combat_random.capture_random_state().state == GodotCombatRandomSource.new(22, true).capture_random_state().state and entry.world_random.capture_random_state().state == GodotWorldInteractionRandomSource.new(23, true).capture_random_state().state and entry.npc_random.capture_random_state().state == GodotNpcInitializationRandomSource.new(21, true).capture_random_state().state, "route consumes zero gameplay RNG")
	entry.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _to_square(entry: Entry) -> OldPineMapHandoffResult:
	return entry.handoff_to(&"snow.outdoor", &"snow.square", &"snow.square", SnowWorldDefinitions.SQUARE_ENTRY_SPAWN_ID)


func _continuity(entry: Entry, ids: Array[Object]) -> void:
	for map: WorldResidentMapController in [entry.inn, entry.outdoor]:
		var actual: Array[Object] = [map._player, map._player.state, map._player.state.equipment, map._player.armor, map._inventory, map._stacks, map._item_index, map._item_id_allocator, map._npc_random, map._combat_random, map._world_interaction_random, map._world_simulation_gate]
		for index: int in range(ids.size()):
			_check(actual[index] == ids[index], "exact authority reference " + str(index))
	_check(entry.active_map_child_count() == 1 and entry.resident_map_count() == 2, "two residents / one active")


func _walk(tree: SceneTree, entry: Entry, action: String, frames: int) -> void:
	Input.action_press(action)
	for _frame: int in range(frames):
		await tree.physics_frame
		if not entry._player.world_location().is_valid() or entry.active_map_child_count() != 1:
			_failures.append("invalid location/map during physical boundary crossing")
	Input.action_release(action)
	await tree.physics_frame
	await tree.physics_frame


func _walk_to_x(tree: SceneTree, entry: Entry, target: float, action: String) -> void:
	var direction: float = 1.0 if action == "move_right" else -1.0
	Input.action_press(action)
	for _step: int in range(400):
		if (entry.active_map().runtime_player_body().position.x - target) * direction >= 0:
			Input.action_release(action)
			await tree.physics_frame
			await tree.physics_frame
			return
		await tree.physics_frame
	Input.action_release(action)
	_failures.append("x target unreachable")


func _walk_to_y(tree: SceneTree, entry: Entry, target: float, action: String) -> void:
	var direction: float = 1.0 if action == "move_down" else -1.0
	Input.action_press(action)
	for _step: int in range(400):
		if (entry.active_map().runtime_player_body().position.y - target) * direction >= 0:
			Input.action_release(action)
			await tree.physics_frame
			await tree.physics_frame
			return
		await tree.physics_frame
	Input.action_release(action)
	_failures.append("y target unreachable")


func _check(value: bool, label: String) -> void:
	_count += 1
	if not value:
		_failures.append("NGE3: " + label)
