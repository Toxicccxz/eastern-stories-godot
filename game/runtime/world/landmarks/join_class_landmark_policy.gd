class_name JoinClassLandmarkPolicy
extends WorldLandmarkPolicy

## std/room/class_guild.c do_join(): a player who has a class already reads
## 你已经参加了其他公会。; one without takes the landmark's class (fighter) and reads
## 恭喜，从今天起您已经成为一名武者！. Its startroom has nothing to do here: Continue
## starts where the player saved.
class Result:
	extends RefCounted
	var joined: bool = false
	var refused: bool = false


func use(map: WorldMapController, landmark: WorldLandmarkDefinition) -> RefCounted:
	var result: Result = Result.new()
	var player: WorldPlayerRuntimeState = map.player_runtime()
	var session: OldPineWorldSessionController = map.session
	if player == null or session == null or landmark == null or landmark.class_id.is_empty():
		return result
	if player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or session.is_transitioning() or session.active_map_id() != map.map_id():
		return result
	var location: WorldLocationState = player.world_location()
	if location == null or location.zone_id != landmark.zone_id:
		return result
	var hud: SharedGameplayUI = session.shared_ui()
	if not player.state.affiliation.class_id.is_empty():
		result.refused = true
		hud.append_log_lines([TranslationServer.translate(landmark.message("refused"))])
		return result
	player.state.affiliation.class_id = landmark.class_id
	result.joined = true
	hud.append_log_lines([TranslationServer.translate(landmark.message("joined"))])
	return result
