extends WorldLandmarkPolicy

## `climb pine`, `down`, `climb cliff`: the verb always takes the one portal.


func use(map: WorldMapController, landmark: WorldLandmarkDefinition) -> RefCounted:
	var result: RefCounted = move_through(map, GameContent.catalog().portal(landmark.portal_id))
	var completed: bool = (
		result is WorldPortalTraversalResult and (result as WorldPortalTraversalResult).completed()
		or result is OldPineMapHandoffResult and (result as OldPineMapHandoffResult).succeeded()
	)
	if completed and map.session != null:
		map.session.shared_ui().append_log_lines(["%s: %s" % [landmark.action_label, landmark.display_name]])
	return result
