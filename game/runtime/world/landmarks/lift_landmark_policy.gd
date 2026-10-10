class_name LiftLandmarkPolicy
extends WorldLandmarkPolicy

## d/choyin/w_street1.c do_lift("statue"): every lift is told (`lift`) and counted since the
## room's reset (lift_trigger); once the count and query("str") / `divisor` reach `limit`
## (check_trigger()) the statue moves aside (`open`) and the player falls through its portal,
## where the statue is heard closing again (`closed`). The count stays until the reset, so
## the next lift opens it at once. ES2 told the faller nothing of it (message() to the room
## without them) and wrote `$N石狮子又…` in the cave: the lines are fixed (默认, 乔阴 plan).
## While whoever lifted first lies in the cave, a lift does nothing more (liftid): only one
## player can be in either place here.
class Result:
	extends RefCounted
	var lifted: bool = false
	var opened: bool = false
	var moved: RefCounted = null


func keeps_selection() -> bool:
	return false


func use(map: WorldMapController, landmark: WorldLandmarkDefinition) -> RefCounted:
	var result: Result = Result.new()
	var player: WorldPlayerRuntimeState = map.player_runtime()
	var session: WorldSessionController = map.session
	if player == null or session == null or landmark == null:
		return result
	if player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or session.is_transitioning() or session.active_map_id() != map.map_id():
		return result
	var location: WorldLocationState = player.world_location()
	if location == null or location.zone_id != landmark.zone_id:
		return result
	var hud: SharedGameplayUI = session.shared_ui()
	hud.append_log_lines([TranslationServer.translate(landmark.message("lift"))])
	result.lifted = true
	map.count_landmark_use(landmark.landmark_id)
	@warning_ignore("integer_division")
	var strength: int = player.state.attributes.strength / landmark.setting("divisor")
	if map.landmark_uses(landmark.landmark_id) + strength < landmark.setting("limit"):
		return result
	result.opened = true
	hud.append_log_lines([TranslationServer.translate(landmark.message("open"))])
	result.moved = move_through(map, GameContent.catalog().portal(landmark.portal_id))
	var arrived: bool = (
		result.moved is WorldPortalTraversalResult and (result.moved as WorldPortalTraversalResult).completed()
		or result.moved is OldPineMapHandoffResult and (result.moved as OldPineMapHandoffResult).succeeded()
	)
	if arrived:
		# The cave's own text first (move() looks), then what is heard there.
		session.shared_ui().describe_arrival()
		session.shared_ui().append_log_lines([TranslationServer.translate(landmark.message("closed"))])
	return result
