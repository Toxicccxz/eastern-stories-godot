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
var _passage_request_pending: bool = false
## A handoff the player leads is under way (handoff_led()).
var _leading: bool = false
var _last_map_handoff: OldPineMapHandoffResult
## Counts the view's fades; a fade-in's end releases the hold only if no fade began since.
var _view_serial: int = 0


func active_map() -> WorldResidentMapController:
	return _resident_maps.get(_active_map_id)


func register_resident_map(map: WorldResidentMapController) -> bool:
	if map == null or map.map_id().is_empty() or _resident_maps.has(map.map_id()):
		return false
	_resident_maps[map.map_id()] = map
	map.passage_requested.connect(_on_passage_requested.bind(map))
	return true


func has_resident_map(map_id: StringName) -> bool:
	return _resident_maps.has(map_id)


## The view goes dark for `seconds` before a passage the player walked into changes the
## map (DECISIONS「手感」); nothing else changes then: the world is held (_hold_view()).
signal view_leaving(seconds: float)
## The view comes back: on `map_id` after a handoff (`arrived`), or where it was when a
## walked passage did not go after all; `door`: the way was a building's door (is_door()).
signal view_arriving(map_id: StringName, arrived: bool, door: bool)
## The walked passage under way is a door (set around its handoff).
var _door_transition: bool = false


func _on_passage_requested(portal: PortalDefinition, source: WorldResidentMapController) -> void:
	if _passage_request_pending:
		return
	# Never detach a physics Area while its query is flushing.
	_passage_request_pending = true
	var seconds: float = _fade_out_seconds(is_door(portal))
	if seconds <= 0.0:
		call_deferred("_execute_passage_request", portal, source)
		return
	_view_serial += 1
	_hold_view(true)
	view_leaving.emit(seconds)
	get_tree().create_timer(seconds, false).timeout.connect(_on_faded_out.bind(portal, source))


func _on_faded_out(portal: PortalDefinition, source: WorldResidentMapController) -> void:
	var before: OldPineMapHandoffResult = _last_map_handoff
	_execute_passage_request(portal, source)
	if _last_map_handoff == before or not _last_map_handoff.succeeded():
		# The passage did not go after all: it can be taken again.
		source.clear_passage_contacts()
		_hold_view(false)
		view_arriving.emit(_active_map_id, false, is_door(portal))


## A Session overrides these narrow hooks (the feel's map_fade_* or, through a door,
## door_fade_*, and holding world time and the player's walk while the view is dark). A
## physical-only fixture changes maps at once.
func _fade_out_seconds(_door: bool) -> float:
	return 0.0


func _fade_in_seconds(_door: bool) -> float:
	return 0.0


## A passage between a building's own map and another (MapDefinition.interior on either
## side): going through it is going through a door.
static func is_door(portal: PortalDefinition) -> bool:
	if portal == null:
		return false
	for map_id: StringName in [portal.source_map_id, portal.destination_map_id]:
		var map: MapDefinition = GameContent.catalog().map(map_id)
		if map != null and map.interior:
			return true
	return false


func _hold_view(_on: bool) -> void:
	pass


## The view came back on the new map: the world goes on once it has faded in.
func _arrived_on(map_id: StringName) -> void:
	var door: bool = _door_transition
	# One arrival's: a later one (a spell, an act) is no door unless its own passage says so.
	_door_transition = false
	var seconds: float = _fade_in_seconds(door)
	_view_serial += 1
	view_arriving.emit(map_id, true, door)
	if seconds <= 0.0:
		_hold_view(false)
		return
	_hold_view(true)
	get_tree().create_timer(seconds, false).timeout.connect(_on_faded_in.bind(_view_serial))


func _on_faded_in(serial: int) -> void:
	# A later passage keeps the view held.
	if serial == _view_serial:
		_hold_view(false)


## handoff_to() for a way the player takes (a passage, a landmark's portal, an act's move):
## who follows them every way comes along (owner, 黑松山 plan F2), however far the way.
func handoff_led(map_id: StringName, zone_id: StringName, combat_location_id: StringName, spawn_point_id: StringName) -> OldPineMapHandoffResult:
	_leading = true
	var result: OldPineMapHandoffResult = handoff_to(map_id, zone_id, combat_location_id, spawn_point_id)
	_leading = false
	return result


## Whether the handoff under way is one the player leads (handoff_led()).
func leading() -> bool:
	return _leading


## A passage asked for a handoff that has not run yet.
func passage_request_pending() -> bool:
	return _passage_request_pending


func _execute_passage_request(portal: PortalDefinition, source: WorldResidentMapController) -> void:
	_passage_request_pending = false
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
	_door_transition = is_door(portal)
	handoff_led(portal.destination_map_id, target.zone_id, target.combat_location_id, portal.destination_spawn_point_id)
	_door_transition = false


## A Session overrides this narrow hook: who follows the player out of `left` on `source`
## comes onto `destination` with them. A physical-only fixture has nobody to bring.
func _carry_followers(_source: WorldResidentMapController, _destination: WorldResidentMapController, _left: WorldLocationState) -> void:
	pass


## A Session overrides this narrow hook: `destination` is about to be the player's map
## (its time away is caught up, DECISIONS「别的地图时间补算」). Before the handoff's
## preparation, so a handoff that fails leaves it caught up, not changed otherwise.
func _entering(_destination: WorldResidentMapController) -> void:
	pass


## A Session overrides this narrow hook: the player left `source` for `destination` (a
## handoff that completed).
func _departed(_source: WorldResidentMapController, _destination: WorldResidentMapController) -> void:
	pass


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


## The same handoff to a spot (`destination_point`, inside the destination zone) instead
## of a spawn marker: a move to where someone stands (drift_sense.c's
## me->move(environment(ob))), in a room that may have no marker.
func handoff_to_point(
	destination_map_id: StringName,
	destination_zone_id: StringName,
	destination_combat_location_id: StringName,
	destination_point: Vector2,
) -> OldPineMapHandoffResult:
	_last_map_handoff = _handoff_to_impl(
		destination_map_id,
		destination_zone_id,
		destination_combat_location_id,
		&"",
		destination_point,
	)
	return _last_map_handoff


func _handoff_to_impl(
	destination_map_id: StringName,
	destination_zone_id: StringName,
	destination_combat_location_id: StringName,
	destination_spawn_point_id: StringName,
	destination_point: Vector2 = Vector2.INF,
) -> OldPineMapHandoffResult:
	var at_point: bool = destination_point.is_finite()
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
		or (destination_spawn_point_id.is_empty() and not at_point)
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
	if at_point:
		if not destination.point_in_zone(destination_point, destination_zone_id):
			result._outcome = OldPineMapHandoffResult.Outcome.DESTINATION_LOCATION_INVALID
			return result
	elif destination.resolve_spawn_marker(destination_spawn_point_id) == null:
		result._outcome = OldPineMapHandoffResult.Outcome.DESTINATION_MARKER_MISSING
		return result
	elif not destination.spawn_matches_zone(
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

	_entering(destination)
	_transitioning = true
	result._failure_stage = OldPineMapHandoffResult.FailureStage.PREPARATION
	var prepared: bool = (
		destination.prepare_for_activation_at(destination_point) if at_point
		else destination.prepare_for_activation(destination_spawn_point_id)
	)
	if not prepared:
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
	_carry_followers(source, destination, source_location)
	source.player_departed()
	_departed(source, destination)
	result._outcome = OldPineMapHandoffResult.Outcome.COMPLETED
	result._failure_stage = OldPineMapHandoffResult.FailureStage.NONE
	_transitioning = false
	_arrived_on(destination_map_id)
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
