extends WorldLandmarkPolicy

## `climb pine`, `down`, `climb cliff`: the verb always takes the one portal.
## The mover reads the room's message_vision() line when the landmark has one.


func use(map: WorldMapController, landmark: WorldLandmarkDefinition) -> RefCounted:
	var result: RefCounted = move_through(map, GameContent.catalog().portal(landmark.portal_id))
	var completed: bool = (
		result is WorldPortalTraversalResult and (result as WorldPortalTraversalResult).completed()
		or result is OldPineMapHandoffResult and (result as OldPineMapHandoffResult).succeeded()
	)
	if completed and map.session != null and not landmark.message("use").is_empty():
		map.session.shared_ui().append_log_lines([TranslationServer.translate(landmark.message("use"))])
	elif completed and map.session != null:
		# TRANSLATORS: a landmark used to move on: {action} (爬树) and the landmark (大松树).
		map.session.shared_ui().append_log_lines([TranslationServer.translate("{action}：{landmark}").format({
			"action": TranslationServer.translate(landmark.action_label),
			"landmark": TranslationServer.translate(landmark.display_name),
		})])
	return result
