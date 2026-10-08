class_name JoinClassLandmarkPolicy
extends WorldLandmarkPolicy

## The 正厅's join (std/room/class_guild.c) from its landmark: the player must stand in
## its zone; ClassGuild decides, and the landmark's line for the outcome is told.
class Result:
	extends RefCounted
	var outcome: ClassGuild.Outcome = ClassGuild.Outcome.INVALID


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
	result.outcome = ClassGuild.join(player.state, landmark.class_id)
	if result.outcome == ClassGuild.Outcome.JOINED:
		session.shared_ui().append_log_lines([TranslationServer.translate(landmark.message("joined"))])
	elif result.outcome == ClassGuild.Outcome.REFUSED:
		session.shared_ui().append_log_lines([TranslationServer.translate(landmark.message("refused"))])
	return result
