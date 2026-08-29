class_name OldPineResidentMapController
extends Node2D

## Narrow contract shared only by the resident maps in the Old Pine playable
## session. It deliberately does not model portals, persistence, or scheduling.


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
	_item_instance_scope: StringName,
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


func replace_combat_random_source(_value: CombatRandomSource) -> bool:
	return false


func replace_world_interaction_random_source(
	_value: WorldInteractionRandomSource,
) -> bool:
	return false
