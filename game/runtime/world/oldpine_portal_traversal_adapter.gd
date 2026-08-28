class_name OldPinePortalTraversalAdapter
extends RefCounted

const WorldPlayerRuntimeType := preload(
	"res://runtime/characters/world_player_runtime_state.gd"
)
const WorldCharacterBodyType := preload(
	"res://runtime/world/world_character_body_2d.gd"
)
const WorldSpawnMarkerType := preload(
	"res://runtime/world/world_spawn_marker_2d.gd"
)


func traverse(
	player: WorldPlayerRuntimeType,
	body: WorldCharacterBodyType,
	portal: PortalDefinition,
	destination_marker: WorldSpawnMarkerType,
	destination_location: WorldLocationState,
) -> WorldPortalTraversalResult:
	var result: WorldPortalTraversalResult = WorldPortalTraversalResult.new()
	if portal != null:
		result._portal_id = portal.portal_id
	if player == null or body == null or portal == null or not portal.is_valid():
		return result
	result._previous_location = player.world_location()
	if (
		not player.is_valid()
		or not player.exists_in_world
		or body.character_id != player.character_id
	):
		result._outcome = WorldPortalTraversalResult.Outcome.PLAYER_NOT_AVAILABLE
		return result
	if player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		result._outcome = WorldPortalTraversalResult.Outcome.PLAYER_NOT_ACTIVE
		return result
	var source: WorldLocationState = player.world_location()
	if (
		source == null
		or source.map_id != portal.source_map_id
		or source.zone_id != portal.source_zone_id
	):
		result._outcome = WorldPortalTraversalResult.Outcome.SOURCE_LOCATION_MISMATCH
		return result
	if not portal.policy_id.is_empty():
		result._outcome = WorldPortalTraversalResult.Outcome.UNSUPPORTED_POLICY
		return result
	if (
		destination_marker == null
		or not destination_marker.is_configured()
		or destination_marker.spawn_point_id != portal.destination_spawn_point_id
	):
		result._outcome = WorldPortalTraversalResult.Outcome.DESTINATION_MARKER_MISMATCH
		return result
	if (
		destination_location == null
		or not destination_location.is_valid()
		or destination_location.region_id != OldPineWorldDefinitions.REGION_ID
		or destination_location.map_id != portal.destination_map_id
		or destination_location.zone_id != portal.destination_zone_id
		or not _destination_combat_location_matches(
			portal,
			destination_location,
		)
	):
		result._outcome = WorldPortalTraversalResult.Outcome.DESTINATION_LOCATION_MISMATCH
		return result

	# LPC clearing.c moves the living object directly. Physical embodiment is
	# committed before the native logical projection, so the result records both.
	body.global_position = destination_marker.global_position
	result._physical_position_updated = true
	if not player.set_world_location(destination_location):
		result._outcome = (
			WorldPortalTraversalResult.Outcome.LOGICAL_LOCATION_UPDATE_FAILED
		)
		return result
	result._logical_location_updated = true
	result._current_location = player.world_location()
	result._outcome = WorldPortalTraversalResult.Outcome.COMPLETED
	return result


func _destination_combat_location_matches(
	portal: PortalDefinition,
	destination_location: WorldLocationState,
) -> bool:
	var destination_zone: ZoneDefinition = OldPineWorldDefinitions.zone_by_id(
		portal.destination_zone_id
	)
	return (
		destination_zone != null
		and destination_zone.map_id == portal.destination_map_id
		and destination_location.combat_location_id
		== destination_zone.combat_location_id
	)
