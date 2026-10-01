class_name WorldLandmarkPolicy
extends RefCounted

## The rule behind a landmark's action (WorldLandmarkDefinition.policy). The
## map checks selection and reach first; the policy moves the player and
## writes the ES2 messages. Returns its own typed result.


func use(_map: WorldMapController, _landmark: WorldLandmarkDefinition) -> RefCounted:
	return null


## Whether the landmark stays selected after it moved the player.
func keeps_selection() -> bool:
	return true


## Moves the player through `portal`: on this map directly, else by handoff.
static func move_through(map: WorldMapController, portal: PortalDefinition) -> RefCounted:
	if portal != null and portal.destination_map_id != map.map_id():
		var zone: ZoneDefinition = GameContent.catalog().zone(portal.destination_zone_id)
		if map.session == null or zone == null:
			return OldPineMapHandoffResult.new()
		return map.session.handoff_to(portal.destination_map_id, zone.zone_id, zone.combat_location_id, portal.destination_spawn_point_id)
	return WorldPortalTraversalAdapter.new().traverse(
		map.player_runtime(),
		map.player_body,
		portal,
		null if portal == null else map.resolve_spawn_marker(portal.destination_spawn_point_id),
		null if portal == null else map.location_for_zone(portal.destination_zone_id),
	)
