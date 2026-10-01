extends RefCounted

const EntryScene := preload("res://tests/qa/nge2_snow_entry.tscn")
const EntryScript := preload("res://tests/qa/nge2_snow_entry.gd")
var _count: int = 0
var _failures: Array[String] = []


func run_all(tree: SceneTree) -> Dictionary[String, Variant]:
	var entry: EntryScript = EntryScene.instantiate() as EntryScript
	tree.root.add_child(entry)
	_check(entry.initialized, "source QA entry initializes")
	if not entry.initialized:
		entry.free()
		return {"assertions": _count, "failures": _failures}
	var map: WorldResidentMapController = entry.inn
	var player: WorldPlayerRuntimeState = entry.player
	var born: NewPlayerInitialization = entry.birth.player
	_check(map is WorldMapController, "Snow uses the generic map controller")
	_check(player.state == born.state and player.facts == born.facts, "same CharacterState and identity")
	_check(player.armor == born.armor and player.state.equipment == born.state.equipment, "same Armor and Equipment")
	_check(map._player == player and map._inventory == entry.birth.inventory, "map receives same Player/Inventory")
	_check(map._stacks == entry.birth.stacks and map._item_index == entry.birth.item_index, "same stacks/index")
	_check(map._item_id_allocator == entry.allocator, "same allocator")
	_check(map._npc_random == entry.npc_random and map._combat_random == entry.combat_random and map._world_interaction_random == entry.world_random, "same RNG authorities")
	_check(map._world_simulation_gate == entry.gate, "same simulation gate")
	for legacy_map: WorldMapController in [WorldMapController.new(), WorldMapController.new()]:
		_check(legacy_map.configure_world_authorities(player, entry.birth.inventory, entry.birth.stacks, entry.birth.item_index, entry.npc_random, entry.combat_random, entry.world_random, entry.allocator, entry.gate), "neutral authority injection remains explicit")
		_check(not legacy_map.initialize_map(), "Old Pine bootstrap still requires its specialized Session adapter")
		legacy_map.free()
	_check(NewPlayerRuntimeComposition.create(&"", born, SnowWorldDefinitions.birth_location()) == null, "empty runtime identity rejected")
	_check(NewPlayerRuntimeComposition.create(&"fixture", null, SnowWorldDefinitions.birth_location()) == null, "missing birth rejected")
	_check(NewPlayerRuntimeComposition.create(&"fixture", born, WorldLocationState.new()) == null, "invalid entry location rejected")
	# d/snow/inn.c places two travellers (4A): gender, age, combat_exp, then eight attributes each.
	var traveller_draws: GodotNpcInitializationRandomSource = GodotNpcInitializationRandomSource.new(21, true)
	for draw: int in range(22):
		traveller_draws.next_below(10)
	_check(entry.npc_random.capture_random_state().state == traveller_draws.capture_random_state().state, "Inn draws only for its two travellers")
	_check(entry.combat_random.capture_random_state().state == GodotCombatRandomSource.new(22, true).capture_random_state().state, "Inn consumes zero combat RNG draws")
	_check(entry.world_random.capture_random_state().state == GodotWorldInteractionRandomSource.new(23, true).capture_random_state().state, "Inn consumes zero world RNG draws")
	_check(player.facts.age == 14 and player.facts.title == "普通百姓" and player.facts.race_id == &"human", "source Player facts")
	_check(player.state.attributes.strength == 30 and player.state.progression.combat_experience == 0, "source birth not demo factory")
	_check(player.state.essence.current == 100 and player.state.vitality.current == 100 and player.state.spirit.current == 100, "source resources")
	_check(player.state.recovery.food == 400 and player.state.recovery.water == 400, "one birth refill")
	_check(player.armor.item_instance_id_in_slot(&"cloth") == entry.birth.cloth.item_instance_id, "same actual cloth instance ID")
	_check(map._item_index.resolve(entry.birth.cloth.item_instance_id).item_instance_id == entry.birth.cloth.item_instance_id, "cloth resolves through injected index")
	_check(player.armor.aggregate_numeric_modifiers().armor == 1 and player.state.equipment.are_both_hands_empty(), "cloth worn with no weapon")
	_check(map._inventory.registered_item_ids().size() == 5, "cloth plus the travellers' cloth and coins")
	_check(player.world_location().same_location(SnowWorldDefinitions.birth_location()), "Snow region/map/zone/combat location exact")
	_check(player.world_location().region_id == &"snow", "not disguised as Old Pine")
	var body: WorldCharacterBody2D = map.runtime_player_body()
	_check(body._player == player and body.character_id == player.character_id, "existing real body bound once")
	_check(body._world_simulation_gate == entry.gate, "body uses same gate")
	var marker: WorldSpawnMarker2D = map.resolve_spawn_marker(SnowWorldDefinitions.BIRTH_SPAWN_ID)
	_check(marker != null and body.global_position == marker.global_position, "spawn from physical marker")
	_check(map.spawn_matches_zone(marker.spawn_point_id, SnowWorldDefinitions.MAIN_FLOOR_ZONE_ID), "spawn inside actual zone shape")
	_check(not map.spawn_matches_zone(marker.spawn_point_id, &"wrong"), "wrong zone rejected")
	var authored_spawn: Vector2 = marker.position
	marker.position = Vector2(2000, 2000)
	_check(not map.spawn_matches_zone(marker.spawn_point_id, SnowWorldDefinitions.MAIN_FLOOR_ZONE_ID), "marker must physically belong to zone")
	marker.position = authored_spawn
	_check(map.resolve_spawn_marker(&"wrong") == null, "unknown spawn rejected")
	_check(map.resolve_location(&"wrong", &"wrong") == null, "unknown location rejected")
	var before: Vector2 = body.global_position
	_check(not map.prepare_for_activation(&"wrong") and body.global_position == before, "invalid activation has no position mutation")
	_check(map.initialization_count() == 1 and map.initialize_map() and map.initialization_count() == 1, "initialize exactly once")
	_check(not map.configure_world_authorities(player, entry.birth.inventory, entry.birth.stacks, entry.birth.item_index, entry.npc_random, entry.combat_random, entry.world_random, entry.allocator, entry.gate), "reconfiguration rejected")
	_check(entry.allocator.next_dynamic_sequence == 1, "map initialized no items")
	var residents: Array[StringName] = []
	for npc: NpcRuntimeState in map.resident_npcs():
		residents.append(npc.definition_id)
	_check(residents == [&"snow.npc.traveller", &"snow.npc.traveller"], "the Inn's authored population: two travellers")
	_check(map.find_children("*", "CharacterBody2D", true, false).size() == 3, "Player plus one body per traveller, no dummies")
	var inn_portals: Array[PortalDefinition] = GameContent.catalog().portals_for_map(SnowWorldDefinitions.INN_MAP_ID)
	_check(inn_portals.size() == 1 and inn_portals[0].portal_id == SnowWorldDefinitions.INN_EXIT_PORTAL_ID, "NGE3 enables only the authored east exit; up/NW deferred")
	var exits: Dictionary[String, StringName] = GameContent.catalog().room(&"es2:d/snow/inn").exits()
	_check(exits.get("east") == &"es2:d/snow/square" and exits.get("up") == &"es2:d/snow/inn_2f" and exits.get("northwest") == &"es2:d/wiz/entrance", "exact source exits")
	_check(GameContent.catalog().zone(SnowWorldDefinitions.MAIN_FLOOR_ZONE_ID).is_valid() and GameContent.catalog().map(SnowWorldDefinitions.INN_MAP_ID).is_valid(), "typed definitions valid")
	_check((body.get_node("Camera2D") as Camera2D).enabled and body.player_controlled, "camera/input activated")
	await tree.physics_frame
	await tree.physics_frame
	for motion: Vector2 in [Vector2(2000, 0), Vector2(-2000, 0), Vector2(0, 2000), Vector2(0, -2000)]:
		_check(body.test_move(body.global_transform, motion), "physical boundary blocks movement: " + str(motion))
	_check(entry.gate.acquire(&"fixture"), "external gate owner acquires")
	_check(not map.freeze_world_gameplay(&"other"), "wrong freeze owner rejected")
	_check(map.freeze_world_gameplay(&"fixture"), "map respects shared freeze owner")
	Input.action_press("move_right")
	await tree.physics_frame
	await tree.physics_frame
	_check(body.global_position == before, "shared gate stops actual physics movement")
	_check(map.thaw_world_gameplay(&"fixture") and entry.gate.release(&"fixture"), "ordered thaw then release")
	await tree.physics_frame
	_check(body.global_position == before, "held input remains quarantined on thaw")
	Input.action_release("move_right")
	await tree.physics_frame
	map.prepare_for_deactivation()
	_check(not body.player_controlled and not (body.get_node("Camera2D") as Camera2D).enabled, "deactivation disables input/camera")
	map.set_restore_staging(true)
	_check(map.process_mode == Node.PROCESS_MODE_DISABLED and not (entry.inn.get_node("%MainFloor") as Area2D).monitoring, "shared staging freezes map/area")
	map.set_restore_staging(false)
	_check((entry.inn.get_node("%MainFloor") as Area2D).monitoring and map.complete_activation(), "staging restores original state")
	player.state.recovery.food = 13
	_check(map.prepare_for_activation(marker.spawn_point_id) and map.complete_activation(), "valid reactivation")
	_check(player.state.recovery.food == 13 and entry.allocator.next_dynamic_sequence == 1, "activation never rebirth/refill/allocate")
	var old: OldPineWorldSessionController = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	old.deterministic_npc_seed = true
	old.deterministic_combat_seed = true
	old.deterministic_world_interaction_seed = true
	tree.root.add_child(old)
	var old_pine_map_ids: Array[StringName] = []
	for definition: MapDefinition in GameContent.catalog().maps():
		if definition.region_id == OldPineWorldDefinitions.REGION_ID:
			old_pine_map_ids.append(definition.map_id)
	_check(old_pine_map_ids.has(OldPineWorldDefinitions.OUTDOOR_MAP_ID) and old_pine_map_ids.has(OldPineWorldDefinitions.CAVE_MAP_ID), "Old Pine maps authored in the catalog")
	for old_pine_map_id: StringName in old_pine_map_ids:
		_check(old.world_map_of(old_pine_map_id) is WorldResidentMapController, "every Old Pine map uses neutral contract: " + String(old_pine_map_id))
	_check(old.resident_map_count() == old_pine_map_ids.size() and old.active_map_child_count() == 1, "technical world is exactly the Old Pine maps / one active")
	var legacy: WorldPlayerRuntimeState = old.player_runtime()
	_check(legacy.state.progression.combat_experience == 600 and legacy.facts.age == 20 and legacy.state.equipment.primary_weapon_skill_type() == &"sword", "technical New Game unchanged")
	_check(old.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)._inventory == old.world_map_of(OldPineWorldDefinitions.CAVE_MAP_ID)._inventory and old.world_map_of(OldPineWorldDefinitions.OUTDOOR_MAP_ID)._player == old.world_map_of(OldPineWorldDefinitions.CAVE_MAP_ID)._player, "Old Pine shares authority storage")
	_check(OldPineWorldSaveCapture.new().capture(old, &"development", "2026-09-11T00:00:00Z").succeeded(), "technical v1 capture succeeds")
	# QA-only Player injection cannot upgrade an existing legacy world profile.
	old._player = player
	var blocked: OldPineWorldCaptureResult = OldPineWorldSaveCapture.new().capture(old, &"development", "2026-09-11T00:00:00Z")
	_check(not blocked.succeeded(), "source Player injection into legacy Session fails closed")
	old._player = legacy
	old.free()
	entry.free()
	await tree.process_frame
	return {"assertions": _count, "failures": _failures}


func _check(value: bool, label: String) -> void:
	_count += 1
	if not value:
		_failures.append("NGE2: " + label)
