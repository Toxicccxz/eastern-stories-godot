class_name OldPineWorldSessionController
extends Node

const PLAYER_ID: StringName = &"oldpine.player"
const OUTDOOR_SCENE: PackedScene = preload(
	"res://scenes/world/oldpine/oldpine_outdoor.tscn"
)
const CAVE_SCENE: PackedScene = preload(
	"res://scenes/world/oldpine/oldpine_cave.tscn"
)
const WorldPlayerRuntimeType := preload(
	"res://runtime/characters/world_player_runtime_state.gd"
)
const SessionItemIdScopeFactoryType := preload(
	"res://core/persistence/session_item_id_scope_factory.gd"
)

enum BootstrapMode {
	NEW_GAME,
	RESTORE,
}

@export var deterministic_npc_seed: bool = false
@export var npc_seed: int = 7_021
@export var deterministic_combat_seed: bool = false
@export var combat_seed: int = 5_232
@export var deterministic_world_interaction_seed: bool = false
@export var world_interaction_seed: int = 93_232

@onready var active_map_slot: Node = %ActiveMapSlot

var _player: WorldPlayerRuntimeType
var _inventory: InventoryState
var _stacks: CombinedStackCollection
var _item_index: WorldItemInstanceIndex
var _npc_random: NpcInitializationRandomSource
var _combat_random: CombatRandomSource
var _world_interaction_random: WorldInteractionRandomSource
var _item_instance_scope: StringName = &""
var _item_id_allocator: SessionItemIdAllocator
var _resident_maps: Dictionary[StringName, OldPineResidentMapController] = {}
var _active_map_id: StringName = &""
var _initialized: bool = false
var _transitioning: bool = false
var _last_passage_exit_handoff: OldPineMapHandoffResult
var _bootstrap_mode: int = BootstrapMode.NEW_GAME
var _restore_preparation: OldPineWorldRestorePreparation
var _restore_failure_outcome: int = OldPineWorldRestoreResult.Outcome.SUCCESS
var _restore_candidate_staged: bool = false


func _ready() -> void:
	initialize_session()


func _exit_tree() -> void:
	for map_id: StringName in _resident_maps.keys():
		var value: Variant = _resident_maps.get(map_id)
		if not is_instance_valid(value):
			continue
		var resident: OldPineResidentMapController = (
			value as OldPineResidentMapController
		)
		if resident != null and resident.get_parent() == null:
			resident.free()
	_resident_maps.clear()


func initialize_session() -> bool:
	if _initialized:
		return true
	if active_map_slot == null:
		return false
	if _bootstrap_mode == BootstrapMode.RESTORE:
		if not _initialize_restore_authorities():
			_restore_failure_outcome = OldPineWorldRestoreResult.Outcome.RECONSTRUCTION_FAILED
			return false
	elif not _initialize_authorities():
		return false
	var cave: OldPineResidentMapController = (
		CAVE_SCENE.instantiate() as OldPineResidentMapController
	)
	var outdoor: OldPineResidentMapController = (
		OUTDOOR_SCENE.instantiate() as OldPineResidentMapController
	)
	if cave == null or outdoor == null:
		return false
	if not _register_and_configure_map(cave) or not _register_and_configure_map(outdoor):
		return false

	if _bootstrap_mode == BootstrapMode.RESTORE:
		return _initialize_restore_residents(cave, outdoor)

	# Ready-time binding is performed once for both resident maps. The inactive
	# cave is then detached without being freed or simulated.
	cave.process_mode = Node.PROCESS_MODE_DISABLED
	active_map_slot.add_child(cave)
	if not cave.initialize_map():
		return false
	cave.prepare_for_deactivation()
	active_map_slot.remove_child(cave)
	cave.process_mode = Node.PROCESS_MODE_INHERIT

	active_map_slot.add_child(outdoor)
	if not outdoor.initialize_map() or not outdoor.complete_activation():
		return false
	_active_map_id = outdoor.map_id()
	_initialized = true
	return _reconcile_active_residents()


func configure_restore(preparation: OldPineWorldRestorePreparation) -> bool:
	if (
		is_inside_tree()
		or _initialized
		or _bootstrap_mode != BootstrapMode.NEW_GAME
		or preparation == null
		or not preparation.is_valid()
	):
		return false
	_bootstrap_mode = BootstrapMode.RESTORE
	_restore_preparation = preparation
	process_mode = Node.PROCESS_MODE_DISABLED
	return true


func bootstrap_mode() -> int:
	return _bootstrap_mode


func is_restore_candidate_staged() -> bool:
	return _restore_candidate_staged


func restore_failure_outcome() -> int:
	return _restore_failure_outcome


func restored_player_position() -> Vector2:
	return Vector2.ZERO if _restore_preparation == null else _restore_preparation.player_position


func restored_npc_entries() -> Array[OldPineRestoredNpcEntry]:
	return [] if _restore_preparation == null else _restore_preparation.npc_entries()


func restored_corpse_entries() -> Array[OldPineRestoredCorpseEntry]:
	return [] if _restore_preparation == null else _restore_preparation.corpse_entries()


func activate_restore_candidate() -> bool:
	if (
		_bootstrap_mode != BootstrapMode.RESTORE
		or not _initialized
		or not _restore_candidate_staged
	):
		return false
	var map: OldPineResidentMapController = active_map()
	if map == null:
		return false
	process_mode = Node.PROCESS_MODE_INHERIT
	map.set_restore_staging(false)
	if not map.complete_activation() or not _reconcile_active_residents():
		map.prepare_for_deactivation()
		map.set_restore_staging(true)
		process_mode = Node.PROCESS_MODE_DISABLED
		_restore_failure_outcome = OldPineWorldRestoreResult.Outcome.ACTIVATION_FAILED
		return false
	map.resume_after_relationship_reconciliation()
	_restore_candidate_staged = false
	return true


func player_runtime() -> WorldPlayerRuntimeType:
	return _player


func inventory_state() -> InventoryState:
	return _inventory


func stack_collection() -> CombinedStackCollection:
	return _stacks


func item_instance_index() -> WorldItemInstanceIndex:
	return _item_index


func npc_random_source() -> NpcInitializationRandomSource:
	return _npc_random


func combat_random_source() -> CombatRandomSource:
	return _combat_random


func world_interaction_random_source() -> WorldInteractionRandomSource:
	return _world_interaction_random


func item_instance_scope() -> StringName:
	return _item_instance_scope


func item_id_allocator() -> SessionItemIdAllocator:
	return _item_id_allocator


func active_map_id() -> StringName:
	return _active_map_id


func active_map() -> OldPineResidentMapController:
	return _resident_maps.get(_active_map_id)


func outdoor_map() -> OldPineOutdoorController:
	return _resident_maps.get(OldPineWorldDefinitions.OUTDOOR_MAP_ID)


func cave_map() -> OldPineCavePassageController:
	return _resident_maps.get(OldPineWorldDefinitions.CAVE_MAP_ID)


func resident_map(map_id: StringName) -> OldPineResidentMapController:
	return _resident_maps.get(map_id)


func resident_map_count() -> int:
	return _resident_maps.size()


func active_map_child_count() -> int:
	return 0 if active_map_slot == null else active_map_slot.get_child_count()


func is_transitioning() -> bool:
	return _transitioning


func last_passage_exit_handoff_result() -> OldPineMapHandoffResult:
	return _last_passage_exit_handoff


func configure_combat_random_source(value: CombatRandomSource) -> bool:
	if value == null:
		return false
	_combat_random = value
	for map: OldPineResidentMapController in _resident_maps.values():
		if not map.replace_combat_random_source(value):
			return false
	return true


func configure_world_interaction_random_source(
	value: WorldInteractionRandomSource,
) -> bool:
	if value == null:
		return false
	_world_interaction_random = value
	for map: OldPineResidentMapController in _resident_maps.values():
		if not map.replace_world_interaction_random_source(value):
			return false
	return true


func request_passage_south_exit() -> OldPineMapHandoffResult:
	var portal: PortalDefinition = OldPineWorldDefinitions.portal_by_id(
		OldPineWorldDefinitions.PASSAGE_SOUTH_PORTAL_ID
	)
	var result: OldPineMapHandoffResult = OldPineMapHandoffResult.new()
	if portal == null:
		return result
	var source_zone: ZoneDefinition = OldPineWorldDefinitions.zone_by_id(
		portal.source_zone_id
	)
	var destination_zone: ZoneDefinition = OldPineWorldDefinitions.zone_by_id(
		portal.destination_zone_id
	)
	if source_zone == null or destination_zone == null:
		return result
	result._source_map_id = _active_map_id
	result._destination_map_id = portal.destination_map_id
	result._destination_zone_id = portal.destination_zone_id
	result._destination_combat_location_id = destination_zone.combat_location_id
	result._destination_spawn_point_id = portal.destination_spawn_point_id
	var location: WorldLocationState = null if _player == null else _player.world_location()
	if (
		not _initialized
		or _transitioning
		or _active_map_id != portal.source_map_id
		or location == null
		or location.region_id != OldPineWorldDefinitions.REGION_ID
		or location.map_id != portal.source_map_id
		or location.zone_id != portal.source_zone_id
		or location.combat_location_id != source_zone.combat_location_id
	):
		result._outcome = OldPineMapHandoffResult.Outcome.SOURCE_LOCATION_INVALID
		return result
	return handoff_to(
		portal.destination_map_id,
		portal.destination_zone_id,
		destination_zone.combat_location_id,
		portal.destination_spawn_point_id,
	)


func handoff_to(
	destination_map_id: StringName,
	destination_zone_id: StringName,
	destination_combat_location_id: StringName,
	destination_spawn_point_id: StringName,
) -> OldPineMapHandoffResult:
	var result: OldPineMapHandoffResult = OldPineMapHandoffResult.new()
	result._source_map_id = _active_map_id
	result._destination_map_id = destination_map_id
	result._destination_zone_id = destination_zone_id
	result._destination_combat_location_id = destination_combat_location_id
	result._destination_spawn_point_id = destination_spawn_point_id
	if (
		not _initialized
		or _transitioning
		or _player == null
		or active_map_slot == null
	):
		result._outcome = OldPineMapHandoffResult.Outcome.SESSION_NOT_READY
		return result
	if (
		destination_map_id.is_empty()
		or destination_zone_id.is_empty()
		or destination_combat_location_id.is_empty()
		or destination_spawn_point_id.is_empty()
	):
		return result
	if _player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		result._outcome = OldPineMapHandoffResult.Outcome.PLAYER_NOT_ACTIVE
		return result
	if destination_map_id == _active_map_id:
		result._outcome = OldPineMapHandoffResult.Outcome.ALREADY_ACTIVE
		return result
	var destination: OldPineResidentMapController = _resident_maps.get(
		destination_map_id
	)
	if destination == null:
		result._outcome = OldPineMapHandoffResult.Outcome.UNKNOWN_DESTINATION_MAP
		return result
	var destination_location: WorldLocationState = destination.resolve_location(
		destination_zone_id,
		destination_combat_location_id,
	)
	if destination_location == null:
		result._outcome = OldPineMapHandoffResult.Outcome.DESTINATION_LOCATION_INVALID
		return result
	if destination.resolve_spawn_marker(destination_spawn_point_id) == null:
		result._outcome = OldPineMapHandoffResult.Outcome.DESTINATION_MARKER_MISSING
		return result
	if not destination.spawn_matches_zone(
		destination_spawn_point_id,
		destination_zone_id,
	):
		result._outcome = OldPineMapHandoffResult.Outcome.DESTINATION_LOCATION_INVALID
		return result
	var source: OldPineResidentMapController = active_map()
	if (
		source == null
		or source.get_parent() != active_map_slot
		or active_map_slot.get_child_count() != 1
		or destination.get_parent() != null
	):
		result._outcome = OldPineMapHandoffResult.Outcome.SESSION_NOT_READY
		return result

	_transitioning = true
	result._failure_stage = OldPineMapHandoffResult.FailureStage.PREPARATION
	if not destination.prepare_for_activation(destination_spawn_point_id):
		destination.prepare_for_deactivation()
		result._outcome = OldPineMapHandoffResult.Outcome.DESTINATION_PREPARATION_FAILED
		_transitioning = false
		return result
	result._destination_prepared = true
	source.prepare_for_deactivation()
	active_map_slot.remove_child(source)
	result._source_detached = true

	result._failure_stage = OldPineMapHandoffResult.FailureStage.LOCATION_COMMIT
	if not _player.set_world_location(destination_location):
		result._outcome = OldPineMapHandoffResult.Outcome.LOCATION_COMMIT_FAILED
		result._source_restored = _restore_source_after_failed_commit(source)
		_transitioning = false
		return result
	result._location_committed = true
	_active_map_id = destination_map_id

	result._failure_stage = OldPineMapHandoffResult.FailureStage.ACTIVATION
	active_map_slot.add_child(destination)
	result._destination_attached = true
	if not destination.complete_activation():
		destination.prepare_for_deactivation()
		result._outcome = OldPineMapHandoffResult.Outcome.DESTINATION_ACTIVATION_FAILED
		_transitioning = false
		return result

	result._failure_stage = OldPineMapHandoffResult.FailureStage.RECONCILIATION
	if not _reconcile_active_residents():
		destination.prepare_for_deactivation()
		result._outcome = (
			OldPineMapHandoffResult.Outcome.RELATIONSHIP_RECONCILIATION_FAILED
		)
		_transitioning = false
		return result
	result._relationship_reconciled = true
	destination.resume_after_relationship_reconciliation()
	result._outcome = OldPineMapHandoffResult.Outcome.COMPLETED
	result._failure_stage = OldPineMapHandoffResult.FailureStage.NONE
	_transitioning = false
	return result


func _restore_source_after_failed_commit(
	source: OldPineResidentMapController,
) -> bool:
	if source == null or active_map_slot == null:
		return false
	if source.get_parent() == null:
		active_map_slot.add_child(source)
	if source.get_parent() != active_map_slot or not source.complete_activation():
		source.prepare_for_deactivation()
		return false
	if not _reconcile_active_residents():
		source.prepare_for_deactivation()
		return false
	source.resume_after_relationship_reconciliation()
	return true


func reset_session() -> void:
	get_tree().reload_current_scene()


func _initialize_authorities() -> bool:
	_item_instance_scope = _new_item_instance_scope()
	_item_id_allocator = SessionItemIdAllocator.new(_item_instance_scope)
	if not _item_id_allocator.is_valid():
		return false
	_inventory = InventoryState.new()
	_stacks = CombinedStackCollection.new()
	_item_index = WorldItemInstanceIndex.new()
	_npc_random = GodotNpcInitializationRandomSource.new(
		npc_seed,
		deterministic_npc_seed,
	)
	_combat_random = GodotCombatRandomSource.new(
		combat_seed,
		deterministic_combat_seed,
	)
	_world_interaction_random = GodotWorldInteractionRandomSource.new(
		world_interaction_seed,
		deterministic_world_interaction_seed,
	)
	var prototype: CombatSliceCharacterBinding = CombatSliceDemoFactory.create_player()
	var start_zone: ZoneDefinition = OldPineWorldDefinitions.zone_by_id(
		OldPineWorldDefinitions.CENTRAL_CLEARING_ZONE_ID
	)
	if prototype == null or start_zone == null:
		return false
	_player = WorldPlayerRuntimeType.new(
		PLAYER_ID,
		prototype.state,
		CombatRelationshipState.new(PLAYER_ID),
		ActionBusyState.new(),
		ArmorState.new(),
		WorldLocationState.new(
			OldPineWorldDefinitions.REGION_ID,
			OldPineWorldDefinitions.OUTDOOR_MAP_ID,
			start_zone.zone_id,
			start_zone.combat_location_id,
		),
		CharacterRuntimeLifeStatus.Value.ACTIVE,
		true,
		true,
		CharacterDerivedValues.maximum_encumbrance(
			prototype.state.attributes.strength
		),
	)
	var demo_primary: EquippedWeaponRef = _player.state.equipment.primary_weapon()
	if demo_primary == null:
		return false
	if not _player.state.equipment.unwield(demo_primary.instance_id).succeeded:
		return false
	var definition: WeaponDefinition = WeaponDefinition.new(
		CombatSliceContentProfile.LONG_SWORD_ID,
		CombatSliceContentProfile.LONG_SWORD_SKILL_ID,
		false,
		false,
		CombatSliceContentProfile.LONG_SWORD_SOURCE,
	)
	var primary: EquippedWeaponRef = EquippedWeaponRef.new(
		StringName("%s.player-long-sword" % String(_item_instance_scope)),
		definition,
	)
	if not _player.state.equipment.wield(primary, false).succeeded:
		return false
	var player_item: ItemInstance = ItemInstance.new(primary.instance_id, primary.weapon_id)
	if (
		not _inventory.register_item(
			player_item,
			CombatSliceContentProfile.LONG_SWORD_WEIGHT,
		)
		or not _item_index.register_snapshot(player_item)
	):
		return false
	var destination: InventoryTransferDestination = InventoryTransferDestination.new(
		ContainmentEndpoint.new(ContainmentEndpoint.Kind.CHARACTER, PLAYER_ID),
		true,
		true,
		_player.maximum_encumbrance,
	)
	return InventoryTransferService.new().transfer(
		_inventory,
		player_item.item_instance_id,
		destination,
	).succeeded


func _initialize_restore_authorities() -> bool:
	if _restore_preparation == null or not _restore_preparation.is_valid():
		return false
	_player = _restore_preparation.player
	_inventory = _restore_preparation.item_domain.inventory
	_stacks = _restore_preparation.item_domain.combined_stacks
	_item_index = _restore_preparation.item_index
	_item_id_allocator = _restore_preparation.item_allocator
	_item_instance_scope = _item_id_allocator.scope
	_npc_random = _restore_preparation.npc_random
	_combat_random = _restore_preparation.combat_random
	_world_interaction_random = _restore_preparation.world_interaction_random
	return true


func _initialize_restore_residents(
	cave: OldPineResidentMapController,
	outdoor: OldPineResidentMapController,
) -> bool:
	for resident: OldPineResidentMapController in [cave, outdoor]:
		resident.set_restore_staging(true)
		active_map_slot.add_child(resident)
		if not resident.initialize_map():
			_restore_failure_outcome = OldPineWorldRestoreResult.Outcome.BODY_BINDING_FAILED
			return false
		# Runtime binding may create fresh interaction Areas (for example CorpseView).
		# Re-apply staging after initialization so the candidate remains fully inert.
		resident.set_restore_staging(true)
		active_map_slot.remove_child(resident)
	var player_location: WorldLocationState = _player.world_location()
	if player_location == null or player_location.map_id not in _resident_maps:
		_restore_failure_outcome = OldPineWorldRestoreResult.Outcome.INVALID_WORLD_LOCATION
		return false
	_active_map_id = player_location.map_id
	var active: OldPineResidentMapController = _resident_maps[_active_map_id]
	active_map_slot.add_child(active)
	if not _validate_restore_positions():
		_restore_failure_outcome = OldPineWorldRestoreResult.Outcome.INVALID_PHYSICAL_POSITION
		return false
	_initialized = true
	_restore_candidate_staged = true
	return active_map_slot.get_child_count() == 1


func _validate_restore_positions() -> bool:
	var player_location: WorldLocationState = _player.world_location()
	var player_map: OldPineResidentMapController = _resident_maps.get(
		player_location.map_id
	)
	if not OldPineMapPlacementValidator.is_valid_character_position(
		player_map,
		player_location.zone_id,
		_restore_preparation.player_position,
	):
		return false
	for entry: OldPineRestoredNpcEntry in _restore_preparation.npc_entries():
		var location: WorldLocationState = entry.runtime.world_location()
		if not OldPineMapPlacementValidator.is_valid_character_position(
			_resident_maps.get(location.map_id),
			location.zone_id,
			entry.map_position,
		):
			return false
	for entry: OldPineRestoredCorpseEntry in _restore_preparation.corpse_entries():
		if not OldPineMapPlacementValidator.is_valid_corpse_position(
			_resident_maps.get(entry.world_location.map_id),
			entry.world_location.zone_id,
			entry.map_position,
		):
			return false
	return true


func _register_and_configure_map(map: OldPineResidentMapController) -> bool:
	if map == null or map.map_id().is_empty() or _resident_maps.has(map.map_id()):
		return false
	if not map.configure_session_authorities(
		self,
		_player,
		_inventory,
		_stacks,
		_item_index,
		_npc_random,
		_combat_random,
		_world_interaction_random,
		_item_id_allocator,
	):
		return false
	_resident_maps[map.map_id()] = map
	map.tree_exiting.connect(_on_resident_map_tree_exiting.bind(map.map_id()))
	if map is OldPineOutdoorController:
		var outdoor: OldPineOutdoorController = map as OldPineOutdoorController
		outdoor.reset_requested.connect(reset_session)
	if map is OldPineCavePassageController:
		var cave: OldPineCavePassageController = map as OldPineCavePassageController
		cave.map_exit_requested.connect(_on_cave_map_exit_requested)
	return true


func _new_item_instance_scope() -> StringName:
	## The scope is durable data, not a Node ObjectID or a gameplay-RNG draw.
	## Platform cryptographic entropy remains independent across fresh processes;
	## save/load preserves this exact value thereafter.
	return SessionItemIdScopeFactoryType.create_old_pine_scope()


func _on_cave_map_exit_requested(portal_id: StringName) -> void:
	if portal_id != OldPineWorldDefinitions.PASSAGE_SOUTH_PORTAL_ID:
		return
	call_deferred("_execute_cave_map_exit_request", portal_id)


func _execute_cave_map_exit_request(portal_id: StringName) -> void:
	if portal_id != OldPineWorldDefinitions.PASSAGE_SOUTH_PORTAL_ID:
		return
	_last_passage_exit_handoff = request_passage_south_exit()
	var cave: OldPineCavePassageController = cave_map()
	if cave != null:
		cave.complete_exit_request(_last_passage_exit_handoff)


func _on_resident_map_tree_exiting(map_id: StringName) -> void:
	if (
		_initialized
		and not _transitioning
		and map_id == _active_map_id
		and not is_queued_for_deletion()
	):
		call_deferred("queue_free")


func _reconcile_active_residents() -> bool:
	if not _reconcile_relationship(_player.relationship):
		return false
	var map: OldPineResidentMapController = active_map()
	if map == null:
		return false
	for npc: NpcRuntimeState in map.resident_npcs():
		if not _reconcile_relationship(npc.relationship):
			return false
	return true


func _reconcile_relationship(relationship: CombatRelationshipState) -> bool:
	if relationship == null or not relationship.is_valid():
		return false
	var facts: Array[CombatOpponentAvailabilityFacts] = []
	for opponent_id: StringName in relationship.opponent_ids():
		facts.append(_availability_facts(opponent_id, relationship.owner_character_id))
	var result: CombatOpponentSelectionResult = CombatOpponentSelectionService.prepare(
		relationship,
		facts,
		_combat_random,
	)
	return result.outcome not in [
		CombatOpponentSelectionResult.Outcome.INVALID_AVAILABILITY_PROJECTION,
		CombatOpponentSelectionResult.Outcome.CLEANUP_INVARIANT_FAILURE,
		CombatOpponentSelectionResult.Outcome.RANDOM_SOURCE_MISSING,
		CombatOpponentSelectionResult.Outcome.RANDOM_DRAW_OUT_OF_RANGE,
		CombatOpponentSelectionResult.Outcome.LAST_OPPONENT_INVARIANT_FAILURE,
	]


func _availability_facts(
	opponent_id: StringName,
	owner_id: StringName,
) -> CombatOpponentAvailabilityFacts:
	var opponent_location: WorldLocationState
	var opponent_exists: bool = false
	var opponent_living: bool = false
	if opponent_id == _player.character_id:
		opponent_location = _player.world_location()
		opponent_exists = _player.exists_in_world
		opponent_living = _player.life_status != CharacterRuntimeLifeStatus.Value.DEAD
	else:
		var npc: NpcRuntimeState = _find_resident_npc(opponent_id)
		if npc != null:
			opponent_location = npc.world_location()
			opponent_exists = npc.exists_in_map
			opponent_living = npc.life_status != CharacterRuntimeLifeStatus.Value.DEAD
	var owner_location: WorldLocationState = _location_for_character(owner_id)
	return CombatOpponentAvailabilityFacts.new(
		opponent_id,
		opponent_exists,
		owner_location != null
		and opponent_location != null
		and owner_location.shares_combat_location(opponent_location),
		opponent_living,
	)


func _location_for_character(character_id: StringName) -> WorldLocationState:
	if character_id == _player.character_id:
		return _player.world_location()
	var npc: NpcRuntimeState = _find_resident_npc(character_id)
	return null if npc == null else npc.world_location()


func _find_resident_npc(character_id: StringName) -> NpcRuntimeState:
	for map: OldPineResidentMapController in _resident_maps.values():
		var npc: NpcRuntimeState = map.find_resident_npc(character_id)
		if npc != null:
			return npc
	return null
