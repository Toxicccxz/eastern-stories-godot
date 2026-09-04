class_name OldPineResidentMapController
extends Node2D

## Narrow contract shared only by the resident maps in the Old Pine playable
## session.

var _staged_area_monitoring: Dictionary[int, bool] = {}
var _staged_area_monitorable: Dictionary[int, bool] = {}
var _staged_area_input: Dictionary[int, bool] = {}


func map_id() -> StringName:
	return &""


func configure_session_authorities(
	_session: OldPineWorldSessionController,
	_player: WorldPlayerRuntimeState,
	_inventory: InventoryState,
	_stacks: CombinedStackCollection,
	_item_index: WorldItemInstanceIndex,
	_npc_random: NpcInitializationRandomSource,
	_combat_random: CombatRandomSource,
	_world_interaction_random: WorldInteractionRandomSource,
	_item_id_allocator: SessionItemIdAllocator,
	_world_simulation_gate: WorldSimulationGate,
) -> bool:
	return false


func initialize_map() -> bool:
	return false


func is_map_initialized() -> bool:
	return false


func initialization_count() -> int:
	return 0


func runtime_player_body() -> WorldCharacterBody2D:
	return null


func resident_npcs() -> Array[NpcRuntimeState]:
	return []


func find_resident_npc(_character_id: StringName) -> NpcRuntimeState:
	return null


func resolve_spawn_marker(_spawn_point_id: StringName) -> WorldSpawnMarker2D:
	return null


func spawn_matches_zone(
	_spawn_point_id: StringName,
	_zone_id: StringName,
) -> bool:
	return false


func resolve_location(
	_zone_id: StringName,
	_combat_location_id: StringName,
) -> WorldLocationState:
	return null


func prepare_for_activation(_spawn_point_id: StringName) -> bool:
	return false


func complete_activation() -> bool:
	return false


func prepare_for_deactivation() -> void:
	pass


func resume_after_relationship_reconciliation() -> void:
	pass


func freeze_world_gameplay(_encounter_id: StringName) -> bool:
	return false


func thaw_world_gameplay(_encounter_id: StringName) -> bool:
	return false


func suspend_for_session_swap() -> bool:
	return false


func resume_after_session_swap_rollback() -> bool:
	return false


func replace_combat_random_source(_value: CombatRandomSource) -> bool:
	return false


func replace_world_interaction_random_source(
	_value: WorldInteractionRandomSource,
) -> bool:
	return false


## RESTORE candidates use the real authored scenes while keeping every Area,
## input surface, and process callback inert until the candidate is activated.
func set_restore_staging(staged: bool) -> void:
	process_mode = Node.PROCESS_MODE_DISABLED if staged else Node.PROCESS_MODE_INHERIT
	for node: Node in find_children("*", "Area2D", true, false):
		var area: Area2D = node as Area2D
		if area == null:
			continue
		var key: int = area.get_instance_id()
		if staged:
			if not _staged_area_monitoring.has(key):
				_staged_area_monitoring[key] = area.monitoring
				_staged_area_monitorable[key] = area.monitorable
				_staged_area_input[key] = area.input_pickable
			area.monitoring = false
			area.monitorable = false
			area.input_pickable = false
		elif _staged_area_monitoring.has(key):
			area.monitoring = _staged_area_monitoring[key]
			area.monitorable = _staged_area_monitorable[key]
			area.input_pickable = _staged_area_input[key]
	if not staged:
		_staged_area_monitoring.clear()
		_staged_area_monitorable.clear()
		_staged_area_input.clear()
