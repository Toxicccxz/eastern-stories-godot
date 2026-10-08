class_name SearchLandmarkPolicy
extends WorldLandmarkPolicy

## water.c do_search("water"): the player jumps in and looks (`search`). With the
## landmark's `mark` (eight7.c's 八卦阵, set leaving the 迷阵 south), random(`random`)
## other than 0 finds the `reward` item, which goes to the player (`found`) and the mark
## stays; else the mark is deleted. Without it, or after that, nothing (`nothing`).
class Result:
	extends RefCounted
	var searched: bool = false
	var found_item_id: StringName = &""


func use(map: WorldMapController, landmark: WorldLandmarkDefinition) -> RefCounted:
	var result: Result = Result.new()
	var player: WorldPlayerRuntimeState = map.player_runtime()
	var session: WorldSessionController = map.session
	var random_source: WorldInteractionRandomSource = map.world_interaction_random_source()
	if player == null or session == null or random_source == null or landmark == null:
		return result
	if player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or session.is_transitioning() or session.active_map_id() != map.map_id():
		return result
	var location: WorldLocationState = player.world_location()
	if location == null or location.zone_id != landmark.zone_id:
		return result
	var hud: SharedGameplayUI = session.shared_ui()
	result.searched = true
	hud.append_log_lines([TranslationServer.translate(landmark.message("search"))])
	if player.state.marks.get(landmark.mark, 0) != 0:
		if random_source.legacy_random(landmark.setting("random")) != 0:
			result.found_item_id = map.give_new_item_to_player(landmark.item("reward"))
			hud.append_log_lines([TranslationServer.translate(landmark.message("found"))])
			if hud.inventory_is_open():
				hud.show_inventory(session.player_inventory_rows())
			return result
		player.state.marks.erase(landmark.mark)
	hud.append_log_lines([TranslationServer.translate(landmark.message("nothing"))])
	return result
