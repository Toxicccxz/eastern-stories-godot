class_name WorldResidentMapController
extends Node2D

## Shared physical-map contract. Authorities are injected references, never born here.
## No Session implementation, service locator or copied gameplay state.

var _player: WorldPlayerRuntimeState
var _inventory: InventoryState
var _stacks: CombinedStackCollection
var _item_index: WorldItemInstanceIndex
var _npc_random: NpcInitializationRandomSource
var _combat_random: CombatRandomSource
var _world_interaction_random: WorldInteractionRandomSource
var _item_id_allocator: SessionItemIdAllocator
var _world_simulation_gate: WorldSimulationGate
var _configured: bool = false

var _staged_area_monitoring: Dictionary[int, bool] = {}
var _staged_area_monitorable: Dictionary[int, bool] = {}
var _staged_area_input: Dictionary[int, bool] = {}


func map_id() -> StringName:
	return &""


func configure_world_authorities(
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
	_player = p_player
	_inventory = p_inventory
	_stacks = p_stacks
	_item_index = p_item_index
	_npc_random = p_npc_random
	_combat_random = p_combat_random
	_world_interaction_random = p_world_interaction_random
	_item_id_allocator = p_item_id_allocator
	_world_simulation_gate = p_world_simulation_gate
	_configured = true
	return true


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


func encounter_combat_bindings(
	_encounter: CombatEncounter,
) -> Array[CombatSliceCharacterBinding]:
	return []


func encounter_skill_effect_registry() -> SkillImprovementEffectRegistry:
	return null


func encounter_opportunity_interval_seconds() -> float:
	return 0.0


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
