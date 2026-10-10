class_name NoteMazeLandmarkPolicy
extends WorldLandmarkPolicy

## d/choyin/taolin.c do_read("note"): message_vision("$N看见:" + the note) with the note
## the room shows now (WorldMapMazes). Reading moves nobody; the ways out are walked.
class Result:
	extends RefCounted
	var read: bool = false
	var note: String = ""


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
	result.read = true
	result.note = map.mazes.note(landmark).text
	var line: String = TranslationServer.translate(landmark.message("read")).format({"note": TranslationServer.translate(result.note)})
	session.shared_ui().append_log_lines([line])
	return result
