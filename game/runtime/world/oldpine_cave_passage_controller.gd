class_name OldPineCavePassageController
extends OldPineResidentMapController

signal map_exit_requested(portal_id: StringName)

const VINE_LANDING_SPAWN_ID: StringName = (
	OldPineWorldDefinitions.CAVE_VINE_LANDING_SPAWN_POINT_ID
)

@onready var player_body: WorldCharacterBody2D = %Player
@onready var spawn_points: Node2D = %SpawnPoints
@onready var south_exit: Area2D = %SouthExit

var _player: WorldPlayerRuntimeState
var _inventory: InventoryState
var _stacks: CombinedStackCollection
var _item_index: WorldItemInstanceIndex
var _npc_random: NpcInitializationRandomSource
var _combat_random: CombatRandomSource
var _world_interaction_random: WorldInteractionRandomSource
var _item_id_allocator: SessionItemIdAllocator
var _world_simulation_gate: WorldSimulationGate
var _encounter_freeze_owner_id: StringName = &""
var _item_instance_scope: StringName = &""
var _configured: bool = false
var _initialized: bool = false
var _initialization_count: int = 0
var _session_owner: OldPineWorldSessionController
var _exit_request_pending: bool = false


func _ready() -> void:
	initialize_map()


func map_id() -> StringName:
	return OldPineWorldDefinitions.CAVE_MAP_ID


func configure_session_authorities(
	p_session: OldPineWorldSessionController,
	p_player: WorldPlayerRuntimeState,
	p_inventory: InventoryState,
	p_stacks: CombinedStackCollection,
	p_item_index: WorldItemInstanceIndex,
	p_npc_random: NpcInitializationRandomSource,
	p_combat_random: CombatRandomSource,
	p_world_interaction_random: WorldInteractionRandomSource,
	p_item_id_allocator: SessionItemIdAllocator,
	p_world_simulation_gate: WorldSimulationGate,
) -> bool:
	if (
		_configured
		or p_session == null
		or p_player == null
		or not p_player.is_valid()
		or p_inventory == null
		or p_stacks == null
		or p_item_index == null
		or p_npc_random == null
		or p_combat_random == null
		or p_world_interaction_random == null
		or p_item_id_allocator == null
		or not p_item_id_allocator.is_valid()
		or p_world_simulation_gate == null
	):
		return false
	_session_owner = p_session
	_player = p_player
	_inventory = p_inventory
	_stacks = p_stacks
	_item_index = p_item_index
	_npc_random = p_npc_random
	_combat_random = p_combat_random
	_world_interaction_random = p_world_interaction_random
	_item_id_allocator = p_item_id_allocator
	_item_instance_scope = p_item_id_allocator.scope
	_world_simulation_gate = p_world_simulation_gate
	_configured = true
	return true


func initialize_map() -> bool:
	if _initialized:
		return true
	if (
		not _configured
		or player_body == null
		or spawn_points == null
		or south_exit == null
	):
		return false
	var marker: WorldSpawnMarker2D = resolve_spawn_marker(VINE_LANDING_SPAWN_ID)
	if (
		marker == null
		or not player_body.bind_player(_player)
		or not player_body.bind_world_simulation_gate(_world_simulation_gate)
	):
		return false
	var player_location: WorldLocationState = _player.world_location()
	player_body.global_position = (
		_session_owner.restored_player_position()
		if (
			_session_owner.bootstrap_mode()
			== OldPineWorldSessionController.BootstrapMode.RESTORE
			and player_location.map_id == map_id()
		)
		else marker.global_position
	)
	player_body.player_controlled = false
	var camera: Camera2D = player_body.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.enabled = false
	_initialized = true
	_initialization_count += 1
	return true


func is_map_initialized() -> bool:
	return _initialized


func initialization_count() -> int:
	return _initialization_count


func runtime_player_body() -> WorldCharacterBody2D:
	return player_body


func player_runtime() -> WorldPlayerRuntimeState:
	return _player


func resolve_spawn_marker(spawn_point_id: StringName) -> WorldSpawnMarker2D:
	if spawn_points == null:
		return null
	for child: Node in spawn_points.get_children():
		var marker: WorldSpawnMarker2D = child as WorldSpawnMarker2D
		if marker != null and marker.spawn_point_id == spawn_point_id:
			return marker
	return null


func spawn_matches_zone(
	spawn_point_id: StringName,
	zone_id: StringName,
) -> bool:
	return (
		spawn_point_id == VINE_LANDING_SPAWN_ID
		and zone_id == OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID
	)


func resolve_location(
	zone_id: StringName,
	combat_location_id: StringName,
) -> WorldLocationState:
	var zone: ZoneDefinition = OldPineWorldDefinitions.zone_by_id(zone_id)
	if (
		zone == null
		or zone_id != OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID
		or zone.map_id != map_id()
		or zone.combat_location_id != combat_location_id
	):
		return null
	return WorldLocationState.new(
		OldPineWorldDefinitions.REGION_ID,
		map_id(),
		zone.zone_id,
		zone.combat_location_id,
	)


func prepare_for_activation(spawn_point_id: StringName) -> bool:
	if not _initialized:
		return false
	var marker: WorldSpawnMarker2D = resolve_spawn_marker(spawn_point_id)
	if (
		marker == null
		or not player_body.bind_player(_player)
		or not player_body.bind_world_simulation_gate(_world_simulation_gate)
	):
		return false
	player_body.global_position = marker.global_position
	player_body.player_controlled = false
	_exit_request_pending = false
	return true


func complete_activation() -> bool:
	if not _initialized or player_body == null:
		return false
	player_body.player_controlled = true
	player_body.refresh_runtime_state()
	var camera: Camera2D = player_body.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.enabled = true
	return true


func prepare_for_deactivation() -> void:
	if player_body == null:
		return
	player_body.player_controlled = false
	player_body.velocity = Vector2.ZERO
	var camera: Camera2D = player_body.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.enabled = false


func freeze_world_gameplay(encounter_id: StringName) -> bool:
	if (
		not _initialized
		or encounter_id.is_empty()
		or not _encounter_freeze_owner_id.is_empty()
		or _world_simulation_gate == null
		or _world_simulation_gate.freeze_owner_id() != encounter_id
	):
		return false
	_encounter_freeze_owner_id = encounter_id
	player_body.quarantine_current_movement_input()
	return true


func thaw_world_gameplay(encounter_id: StringName) -> bool:
	if (
		encounter_id.is_empty()
		or _encounter_freeze_owner_id != encounter_id
		or _world_simulation_gate == null
		or _world_simulation_gate.freeze_owner_id() != encounter_id
	):
		return false
	_encounter_freeze_owner_id = &""
	player_body.quarantine_current_movement_input()
	return true


func suspend_for_session_swap() -> bool:
	if not _initialized or player_body == null:
		return false
	player_body.player_controlled = false
	player_body.velocity = Vector2.ZERO
	var camera: Camera2D = player_body.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.enabled = false
	return true


func resume_after_session_swap_rollback() -> bool:
	if not _initialized or player_body == null:
		return false
	player_body.player_controlled = true
	player_body.refresh_runtime_state()
	var camera: Camera2D = player_body.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.enabled = true
	return true


func replace_combat_random_source(value: CombatRandomSource) -> bool:
	if value == null:
		return false
	_combat_random = value
	return true


func replace_world_interaction_random_source(
	value: WorldInteractionRandomSource,
) -> bool:
	if value == null:
		return false
	_world_interaction_random = value
	return true


func world_interaction_random_source() -> WorldInteractionRandomSource:
	return _world_interaction_random


func exit_request_pending() -> bool:
	return _exit_request_pending


func complete_exit_request(_result: OldPineMapHandoffResult) -> void:
	# The duplicate-request gate describes only the deferred request that has
	# now completed. A committed or committed-partial handoff has its own typed
	# result and must not leave this transient flag stuck on the detached Cave.
	_exit_request_pending = false


func _on_passage_zone_body_entered(body: Node2D) -> void:
	if body != player_body or not _world_gameplay_is_open():
		return
	var location: WorldLocationState = resolve_location(
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
		OldPineWorldDefinitions.WATERFALL_PASSAGE_ZONE_ID,
	)
	if location != null:
		player_body.set_world_location(location)


func _on_south_exit_body_entered(body: Node2D) -> void:
	if (
		body != player_body
		or _exit_request_pending
		or _session_owner == null
		or _player == null
		or _player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE
		or not player_body.player_controlled
		or _session_owner.is_transitioning()
		or _session_owner.active_map_id() != map_id()
		or not _world_gameplay_is_open()
	):
		return
	_exit_request_pending = true
	map_exit_requested.emit(OldPineWorldDefinitions.PASSAGE_SOUTH_PORTAL_ID)


func _world_gameplay_is_open() -> bool:
	return _world_simulation_gate == null or _world_simulation_gate.is_open()
