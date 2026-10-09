class_name TakeLandmarkPolicy
extends WorldLandmarkPolicy

## d/latemoon/park/moonc.c do_pick() and latemoon2.c do_take("cloth"): while fewer than
## `limit` were taken since the room's reset (reset(): pick_available 2, take_available
## 2), the `reward` item goes to the player (`take`); after that `empty` (latemoon2.c's
## 橱子内的衣服好像被拿光了。; moonc.c said nothing: owner, 晚月庄 B, a line). Counted as
## look_spawn's calls are: not saved.
class Result:
	extends RefCounted
	var taken_item_id: StringName = &""
	var empty: bool = false


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
	if map.landmark_uses(landmark.landmark_id) >= landmark.setting("limit"):
		result.empty = true
		hud.append_log_lines([TranslationServer.translate(landmark.message("empty"))])
		return result
	map.count_landmark_use(landmark.landmark_id)
	result.taken_item_id = map.give_new_item_to_player(landmark.item("reward"))
	hud.append_log_lines([TranslationServer.translate(landmark.message("take"))])
	if hud.inventory_is_open():
		hud.show_inventory(session.player_inventory_rows())
	return result
