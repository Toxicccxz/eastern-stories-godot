extends RefCounted

const Entry := preload("res://tests/qa/nge4_source_entry.gd")
const PriorRoute := preload("res://tests/runtime/snow_outdoor_route_test.gd")
var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var entry: Entry = (load("res://tests/qa/nge4_source_entry.tscn") as PackedScene).instantiate()
	tree.root.add_child(entry)
	var session: OldPineWorldSessionController = entry.session
	_check(session.is_initialized(), "production source Session initializes")
	if not session.is_initialized():
		entry.free()
		return {"assertions": _count, "failures": _failures}
	_check(session.bootstrap_mode() == OldPineWorldSessionController.BootstrapMode.SOURCE_ENTRY, "explicit third profile")
	_check(not session.configure_source_entry("Again", CharacterState.GENDER_MALE), "late profile configuration rejected")
	var identities: Array[Object] = _identities(session)
	var player: WorldPlayerRuntimeState = session.player_runtime()
	var owner: ContainmentEndpoint = ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id)
	var cloth: StringName = session.inventory_state().direct_children(owner)[0]
	var npc_ids: Array[NpcRuntimeState] = session.outdoor_map().npc_runtimes()
	var npc_rng: int = session.npc_random_source().capture_random_state().state
	var combat_rng: int = session.combat_random_source().capture_random_state().state
	var world_rng: int = session.world_interaction_random_source().capture_random_state().state
	_check(session.active_map_id() == &"snow.inn" and player.world_location().same_location(SnowWorldDefinitions.birth_location()), "inactive Old Pine initialization leaves authoritative Inn birth")
	_check(npc_ids.size() == 5 and session.outdoor_map().initialization_count() == 1, "existing five authored human NPCs initialized exactly once")
	_check(session.resident_map_count() == 4, "source profile includes existing Cave dependency")
	_check(session.inventory_state().registered_item_ids().size() == 12, "source cloth plus unchanged eleven NPC loadout items")
	_check(session.encounter_display_name(player.character_id) == "Snow Player", "presentation projects source name")
	_check((session.active_map().runtime_player_body().get_node("NameLabel") as Label).text == "Snow Player", "body label projects source identity")
	_continuity(session, identities, cloth)
	var south: PortalDefinition = SnowOldPineConnectionDefinitions.to_oldpine()
	var north: PortalDefinition = SnowOldPineConnectionDefinitions.to_snow()
	_check(south.is_valid() and south.source_map_id == &"snow.outdoor" and south.source_zone_id == &"snow.eroad3" and south.legacy_action_verb == &"south" and south.legacy_source_path == "/d/snow/eroad3", "exact LPC eroad3 south")
	_check(south.destination_map_id == &"oldpine.outdoor" and south.destination_zone_id == &"oldpine.outdoor.north_approach" and south.destination_spawn_point_id == &"oldpine.outdoor.north_approach.snow_entry", "North Approach destination, not clearing")
	_check(north.is_valid() and north.source_zone_id == &"oldpine.outdoor.north_approach" and north.legacy_action_verb == &"north" and north.legacy_source_path == "/d/oldpine/npath1" and north.destination_zone_id == &"snow.eroad3" and north.destination_spawn_point_id == &"snow.eroad3.oldpine_return", "exact reverse portal")
	_check(OldPineWorldDefinitions.zone_by_id(OldPineWorldDefinitions.NORTH_APPROACH_ZONE_ID).legacy_room_ids() == ["d/oldpine/npath1.c", "d/oldpine/npath2.c", "d/oldpine/npath3.c"], "existing three-room clustering unchanged")
	_check(session.outdoor_map().spawn_matches_zone(south.destination_spawn_point_id, south.destination_zone_id), "north marker physically inside North Approach")
	var snow: WorldResidentMapController = session.resident_map(&"snow.outdoor")
	_check(snow.spawn_matches_zone(north.destination_spawn_point_id, north.destination_zone_id), "return marker physically inside eroad3")
	_check(snow._passages.size() == 2 and session.outdoor_map()._passages.size() == 1, "two independently typed Snow passages")
	_check(not snow.is_passage_current(south), "inactive/remote passage rejected")
	var capture: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(session, &"development", "2026-09-11T00:00:00Z")
	_check(capture.outcome == OldPineWorldCaptureResult.Outcome.UNREPRESENTED_CHARACTER_STATE and capture.path == "player.facts", "real source Session v1 fails closed")
	# Explicit boundary tests, separate from fresh physical acceptance below.
	var source: WorldLocationState = player.world_location()
	var invalids: Array[OldPineMapHandoffResult] = [
		session.handoff_to(&"unknown", south.destination_zone_id, south.destination_zone_id, south.destination_spawn_point_id),
		session.handoff_to(south.destination_map_id, south.destination_zone_id, south.destination_zone_id, &"missing"),
		session.handoff_to(south.destination_map_id, &"oldpine.outdoor.central_clearing", &"oldpine.outdoor.central_clearing", south.destination_spawn_point_id),
	]
	var expected: Array[int] = [OldPineMapHandoffResult.Outcome.UNKNOWN_DESTINATION_MAP, OldPineMapHandoffResult.Outcome.DESTINATION_MARKER_MISSING, OldPineMapHandoffResult.Outcome.DESTINATION_LOCATION_INVALID]
	for i: int in range(invalids.size()):
		_check(invalids[i].outcome == expected[i] and not invalids[i].location_committed, "invalid cross-region destination fails before mutation")
	player.set_world_location(WorldLocationState.new(&"snow", &"snow.inn", &"invalid", &"invalid"))
	_check(_handoff(session, south).outcome == OldPineMapHandoffResult.Outcome.SOURCE_LOCATION_INVALID, "wrong source rejected")
	player.set_world_location(source)
	session.world_simulation_gate().acquire(&"test")
	_check(_handoff(session, south).outcome == OldPineMapHandoffResult.Outcome.WORLD_SIMULATION_FROZEN, "frozen gate rejects cross-region transfer")
	session.world_simulation_gate().release(&"test")
	var rejected: PriorRoute.RejectPreparation = PriorRoute.RejectPreparation.new()
	session.register_resident_map(rejected)
	_check(session.handoff_to(&"test.reject", &"test.zone", &"test.zone", &"marker").outcome == OldPineMapHandoffResult.Outcome.DESTINATION_PREPARATION_FAILED, "prepare failure retains source")
	session._resident_maps.erase(rejected.map_id())
	rejected.free()
	_check(session.active_map_child_count() == 1 and session.active_map().is_inside_tree() and player.world_location().same_location(source), "all failures preserve source location and active map")
	_continuity(session, identities, cloth)
	# Technical profile uses identical NPC RNG path but still exactly two maps.
	var technical: OldPineWorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	technical.deterministic_npc_seed = true
	technical.deterministic_combat_seed = true
	technical.deterministic_world_interaction_seed = true
	tree.root.add_child(technical)
	_check(technical.resident_map_count() == 2 and technical.resident_map(&"snow.inn") == null and technical.active_map_id() == &"oldpine.outdoor", "technical map set unchanged")
	_check(technical.player_runtime().facts.age == 20 and technical.player_runtime().state.progression.combat_experience == 600 and technical.player_runtime().state.equipment.primary_weapon_skill_type() == &"sword" and technical.inventory_state().registered_item_ids().size() == 12, "technical age/experience/sword/items unchanged")
	_check((technical.outdoor_map().get_node("Terrain/Boundaries/WorldBounds/SnowBlocker") as CollisionShape2D).disabled == false and technical.outdoor_map()._passages.is_empty(), "technical north exit remains physically closed")
	_check(technical.npc_random_source().capture_random_state().state == npc_rng, "source birth consumes zero NPC RNG; same five-NPC initialization draw sequence")
	_check(OldPineWorldSaveCapture.new().capture(technical, &"development", "2026-09-11T00:00:00Z").succeeded(), "technical v1 capture preserved")
	technical.free()
	await tree.process_frame
	# Production bodies/Input/Areas only from this point. No location or position writes.
	await _walk_until_map(tree, session, &"snow.outdoor", "move_right")
	await _walk_axis(tree, session, 0.0, "move_right")
	await _walk_axis(tree, session, 550.0, "move_down")
	await _walk_axis(tree, session, 1100.0, "move_right")
	_check(player.world_location().zone_id == &"snow.eroad3", "physical Snow route")
	await _walk_until_map(tree, session, &"oldpine.outdoor", "move_down")
	_check(player.world_location().zone_id == &"oldpine.outdoor.north_approach", "first Old Pine location is North Approach")
	_check(session.last_map_handoff_result().destination_spawn_point_id == south.destination_spawn_point_id and session.outdoor_map().player_body.position.distance_to(Vector2(450, -380)) < 25.0, "first physical spawn at north entry")
	var binding: CombatSliceCharacterBinding = CombatSliceProjectionBuilder.find_binding(session.outdoor_map()._build_participants(), player.character_id)
	_check(binding != null and binding.state == player.state and binding.state.equipment.primary_weapon() == null, "source exp0/unarmed binds existing combat")
	_continuity(session, identities, cloth)
	await _walk_axis(tree, session, 150.0, "move_down")
	_check(player.world_location().zone_id == OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID and session.active_map_id() == &"oldpine.outdoor", "clearing reached by same-map physical movement")
	await _walk_until_map(tree, session, &"snow.outdoor", "move_up")
	_check(player.world_location().zone_id == &"snow.eroad3" and session.last_map_handoff_result().destination_spawn_point_id == north.destination_spawn_point_id, "reverse passage returns eroad3, not Square")
	_continuity(session, identities, cloth)
	# Re-entry checks the graph rather than reinitializing or rerolling it.
	await _walk_until_map(tree, session, &"oldpine.outdoor", "move_down")
	_check(session.outdoor_map().npc_runtimes() == npc_ids and session.outdoor_map().initialization_count() == 1 and session.npc_random_source().capture_random_state().state == npc_rng, "same five NPC objects/no reroll on re-entry")
	await _walk_until_map(tree, session, &"snow.outdoor", "move_up")
	await _walk_axis(tree, session, 550.0, "move_up")
	await _walk_axis(tree, session, 0.0, "move_left")
	await _walk_axis(tree, session, 0.0, "move_up")
	await _walk_until_map(tree, session, &"snow.inn", "move_left")
	_check(session.last_map_handoff_result().destination_spawn_point_id == SnowWorldDefinitions.INN_RETURN_SPAWN_ID, "Inn returns via east marker, not birth")
	_check(entry.zone_history == [&"snow.inn.main_floor", &"snow.square", &"snow.sroad1", &"snow.eroad1", &"snow.eroad2", &"snow.eroad3", &"oldpine.outdoor.north_approach", &"oldpine.outdoor.central_clearing", &"oldpine.outdoor.north_approach", &"snow.eroad3", &"oldpine.outdoor.north_approach", &"snow.eroad3", &"snow.eroad2", &"snow.eroad1", &"snow.sroad1", &"snow.square", &"snow.inn.main_floor"], "exact physical zone sequence: " + str(entry.zone_history))
	_continuity(session, identities, cloth)
	_check(session.npc_random_source().capture_random_state().state == npc_rng and session.combat_random_source().capture_random_state().state == combat_rng and session.world_interaction_random_source().capture_random_state().state == world_rng, "route consumes no gameplay RNG")
	_check(session.outdoor_map().npc_runtimes() == npc_ids, "NPC identities retained after final return")
	var residents: Array[WorldResidentMapController] = []
	for id: StringName in session._resident_maps:
		residents.append(session.resident_map(id))
	entry.free()
	await tree.process_frame
	for map: WorldResidentMapController in residents:
		_check(not is_instance_valid(map), "Session frees both attached and detached residents including Snow")
	return {"assertions": _count, "failures": _failures}


func _identities(session: OldPineWorldSessionController) -> Array[Object]:
	var player: WorldPlayerRuntimeState = session.player_runtime()
	return [player, player.state, player.state.equipment, player.armor, player.facts, player.body_facts, session.inventory_state(), session.stack_collection(), session.item_instance_index(), session.item_id_allocator(), session.npc_random_source(), session.combat_random_source(), session.world_interaction_random_source(), session.world_simulation_gate(), session.combat_encounter_coordinator()]


func _continuity(session: OldPineWorldSessionController, identities: Array[Object], cloth: StringName) -> void:
	_check(_identities(session) == identities, "all fifteen Session authority identities including Player body unchanged")
	var player: WorldPlayerRuntimeState = session.player_runtime()
	_check(player.body_facts.body_weight == 80000 and player.body_facts.maximum_encumbrance == 150000, "same established body across Inn/Snow/Old Pine/return handoffs")
	_check(player.facts.age == 14 and player.state.attributes.strength == 30 and player.state.progression.combat_experience == 0 and player.state.recovery.food == 400 and player.state.recovery.water == 400, "source age/attributes/exp/food/water preserved")
	var owner: ContainmentEndpoint = ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, player.character_id)
	_check(session.inventory_state().direct_children(owner) == [cloth] and player.state.equipment.primary_weapon() == null and player.armor.occupied_slots().size() == 1 and player.armor.is_worn(cloth), "one same worn cloth/empty hands/no starter sword")
	_check(session.item_id_allocator().next_dynamic_sequence == 1, "no extra dynamic allocation")
	_check(session.active_map_child_count() == 1, "one active map")
	for map: WorldResidentMapController in session._resident_maps.values():
		_check(map._player == player and map._inventory == session.inventory_state() and map._stacks == session.stack_collection() and map._item_index == session.item_instance_index() and map._item_id_allocator == session.item_id_allocator() and map._world_simulation_gate == session.world_simulation_gate() and map._npc_random == session.npc_random_source() and map._combat_random == session.combat_random_source() and map._world_interaction_random == session.world_interaction_random_source(), "map binds exact Session authorities")
		_check(map == session.active_map() or (not map.is_inside_tree() and not map.runtime_player_body().player_controlled and not (map.runtime_player_body().get_node("Camera2D") as Camera2D).enabled), "inactive maps detached/input/camera off")


func _handoff(session: OldPineWorldSessionController, portal: PortalDefinition) -> OldPineMapHandoffResult:
	return session.handoff_to(portal.destination_map_id, portal.destination_zone_id, portal.destination_zone_id, portal.destination_spawn_point_id)


func _walk_until_map(tree: SceneTree, session: OldPineWorldSessionController, target: StringName, action: String) -> void:
	Input.action_press(action)
	for _step: int in range(400):
		await tree.physics_frame
		if session.active_map_id() == target:
			break
	Input.action_release(action)
	await tree.physics_frame
	await tree.process_frame
	_check(session.active_map_id() == target, "physical passage reaches " + String(target))


func _walk_axis(tree: SceneTree, session: OldPineWorldSessionController, target: float, action: String) -> void:
	var horizontal: bool = action in ["move_left", "move_right"]
	var direction: float = 1.0 if action in ["move_down", "move_right"] else -1.0
	Input.action_press(action)
	var reached: bool = false
	for _step: int in range(500):
		await tree.physics_frame
		var position: Vector2 = session.active_map().runtime_player_body().position
		if ((position.x if horizontal else position.y) - target) * direction >= 0:
			reached = true
			break
	Input.action_release(action)
	await tree.physics_frame
	await tree.process_frame
	_check(reached, "physical axis target " + str(target))


func _check(value: bool, label: String) -> void:
	_count += 1
	if not value:
		_failures.append("NGE4: " + label)
