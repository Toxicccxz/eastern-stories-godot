class_name WorldResidentMapCoordinator
extends Node

## Physical residency/handoff only. The owning Session supplies gameplay authorities.
## No birth, inventory, RNG, save, combat scheduler or application lifecycle.
## OldPineMapHandoffResult retains its public historical name for compatibility.
@onready var active_map_slot: Node = %ActiveMapSlot
var _player: WorldPlayerRuntimeState
var _world_simulation_gate: WorldSimulationGate
var _resident_maps: Dictionary[StringName, WorldResidentMapController] = {}
var _active_map_id: StringName = &""
var _initialized: bool = false
var _transitioning: bool = false
var _last_map_handoff: OldPineMapHandoffResult


func active_map() -> WorldResidentMapController:
	return _resident_maps.get(_active_map_id)


func register_resident_map(map: WorldResidentMapController) -> bool:
	if map == null or map.map_id().is_empty() or _resident_maps.has(map.map_id()):
		return false
	_resident_maps[map.map_id()] = map
	map.passage_requested.connect(_on_passage_requested.bind(map))
	return true


func _on_passage_requested(portal: PortalDefinition, source: WorldResidentMapController) -> void:
	# Never detach a physics Area while its query is flushing.
	call_deferred("_execute_passage_request", portal, source)


func _execute_passage_request(portal: PortalDefinition, source: WorldResidentMapController) -> void:
	if source != active_map() or portal == null or not portal.is_valid() or not source.is_passage_current(portal):
		return
	var location: WorldLocationState = _player.world_location()
	if location == null or location.map_id != portal.source_map_id or location.zone_id != portal.source_zone_id:
		return
	var destination: WorldResidentMapController = _resident_maps.get(portal.destination_map_id)
	if destination == null:
		return
	var target: WorldLocationState = destination.location_for_zone(portal.destination_zone_id)
	if target == null:
		return
	handoff_to(portal.destination_map_id, target.zone_id, target.combat_location_id, portal.destination_spawn_point_id)


## A Session overrides this narrow hook with its existing relationship cleanup.
## A physical-only fixture has no NPCs or encounter relationships to reconcile.
func _reconcile_active_residents() -> bool:
	return true


func active_map_id() -> StringName:
	return _active_map_id


func resident_map_count() -> int:
	return _resident_maps.size()


func active_map_child_count() -> int:
	return 0 if active_map_slot == null else active_map_slot.get_child_count()


func is_transitioning() -> bool:
	return _transitioning


func last_map_handoff_result() -> OldPineMapHandoffResult:
	return _last_map_handoff


func handoff_to(
	destination_map_id: StringName,
	destination_zone_id: StringName,
	destination_combat_location_id: StringName,
	destination_spawn_point_id: StringName,
) -> OldPineMapHandoffResult:
	_last_map_handoff = _handoff_to_impl(
		destination_map_id,
		destination_zone_id,
		destination_combat_location_id,
		destination_spawn_point_id,
	)
	return _last_map_handoff


func _handoff_to_impl(
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
		or (_world_simulation_gate != null and _world_simulation_gate.is_frozen())
		or _player == null
		or active_map_slot == null
	):
		result._outcome = (
			OldPineMapHandoffResult.Outcome.WORLD_SIMULATION_FROZEN
			if _world_simulation_gate != null and _world_simulation_gate.is_frozen()
			else OldPineMapHandoffResult.Outcome.SESSION_NOT_READY
		)
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
	var destination: WorldResidentMapController = _resident_maps.get(
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
	var source: WorldResidentMapController = active_map()
	if (
		source == null
		or source.get_parent() != active_map_slot
		or active_map_slot.get_child_count() != 1
		or destination.get_parent() != null
	):
		result._outcome = OldPineMapHandoffResult.Outcome.SESSION_NOT_READY
		return result

	var source_location: WorldLocationState = _player.world_location()
	var resolved_source: WorldLocationState = null if source_location == null else source.resolve_location(source_location.zone_id, source_location.combat_location_id)
	if source_location == null or resolved_source == null or not source_location.same_location(resolved_source) or source_location.map_id != _active_map_id:
		result._outcome = OldPineMapHandoffResult.Outcome.SOURCE_LOCATION_INVALID
		return result

	_transitioning = true
	result._failure_stage = OldPineMapHandoffResult.FailureStage.PREPARATION
	if not destination.prepare_for_activation(destination_spawn_point_id):
		destination.prepare_for_deactivation()
		result._outcome = OldPineMapHandoffResult.Outcome.DESTINATION_PREPARATION_FAILED
		_transitioning = false
		return result
	result._destination_prepared = true
	# A resident map that was inactive when a RESTORE candidate activated is
	# still staged and process-disabled. It becomes live only when this handoff
	# selects it as the destination; unstaging here also restores its Areas.
	destination.set_restore_staging(false)
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
	source: WorldResidentMapController,
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
