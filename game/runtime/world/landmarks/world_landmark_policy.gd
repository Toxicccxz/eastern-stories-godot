class_name WorldLandmarkPolicy
extends RefCounted

## The rule behind a landmark's action (WorldLandmarkDefinition.policy). The
## map checks selection and reach first; the policy moves the player and
## writes the ES2 messages. Returns its own typed result.


func use(_map: WorldMapController, _landmark: WorldLandmarkDefinition) -> RefCounted:
	return null


## What looking at the landmark shows (look.c: item_desc, which a function may make):
## its authored text unless the policy says otherwise.
func look(_map: WorldMapController, landmark: WorldLandmarkDefinition) -> String:
	return landmark.description


## Whether the landmark stays selected after it moved the player.
func keeps_selection() -> bool:
	return true


## Moves the player through `portal`: on this map directly, else by handoff.
static func move_through(map: WorldMapController, portal: PortalDefinition) -> RefCounted:
	if portal != null and portal.destination_map_id != map.map_id():
		var zone: ZoneDefinition = GameContent.catalog().zone(portal.destination_zone_id)
		if map.session == null or zone == null:
			return OldPineMapHandoffResult.new()
		# The verb only works in its own room, as the same-map adapter checks.
		var location: WorldLocationState = map.player_runtime().world_location()
		if location == null or location.map_id != portal.source_map_id or location.zone_id != portal.source_zone_id:
			var refused: OldPineMapHandoffResult = OldPineMapHandoffResult.new()
			refused._outcome = OldPineMapHandoffResult.Outcome.SOURCE_LOCATION_INVALID
			return refused
		return map.session.handoff_to(portal.destination_map_id, zone.zone_id, zone.combat_location_id, portal.destination_spawn_point_id)
	var moved: WorldPortalTraversalResult = WorldPortalTraversalAdapter.new().traverse(
		map.player_runtime(),
		map.player_body,
		portal,
		null if portal == null else map.resolve_spawn_marker(portal.destination_spawn_point_id),
		null if portal == null else map.location_for_zone(portal.destination_zone_id),
	)
	# A jump on one map (the 迷阵's exits): the camera is there at once, not gliding across the map.
	var camera: Camera2D = null if map.player_body == null else map.player_body.get_node_or_null("Camera2D") as Camera2D
	if moved.completed() and camera != null:
		camera.reset_smoothing()
	return moved
