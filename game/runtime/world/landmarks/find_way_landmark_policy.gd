class_name FindWayLandmarkPolicy
extends WorldLandmarkPolicy

## The clue that finds a hidden way (native; DECISIONS「老松林的林径与藏起来的寨门」): the
## bandits' knife marks on the pines by the thicket that hides 老松寨's path. Its action
## gives the player the landmark's `mark` and says `found`; every door whose `found_by` is
## that mark opens on this map and on any other that places it, and stays open, since the
## mark is saved and _bind_doors() opens such a door for a player who holds it. Used again,
## it only says `again`.
class Result:
	extends RefCounted
	var used: bool = false
	var found: bool = false


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
	result.used = true
	if player.state.marks.get(landmark.mark, 0) != 0:
		hud.append_log_lines([TranslationServer.translate(landmark.message("again"))])
		return result
	player.state.marks[landmark.mark] = 1
	result.found = true
	hud.append_log_lines([TranslationServer.translate(landmark.message("found"))])
	map.open_found_ways(landmark.mark)
	session.record_journal()
	return result
