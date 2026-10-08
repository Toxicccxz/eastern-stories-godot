class_name PushStoneLandmarkPolicy
extends WorldLandmarkPolicy

## closed.c do_push("stone"): below the landmark's `force`, `max_force` or
## `force_factor` the stone does not move (`weak`). Otherwise the push costs gin, kee
## and sen (receive_damage(), from nobody) and is told (`push`); when random(`random`)
## is 0 the stone rolls away (`rolled`) and the player goes through the portal. The
## lines others would see (the stone rolling back, the player coming out of the hole)
## have nobody to see them. Below zero, the player falls on the next heart beat.
class Result:
	extends RefCounted
	var pushed: bool = false
	var rolled: bool = false
	var moved: RefCounted = null


func keeps_selection() -> bool:
	return false


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
	var state: CharacterState = player.state
	if (
		state.recovery.inner_force.current < landmark.setting("force")
		or state.recovery.inner_force.maximum < landmark.setting("max_force")
		or state.attributes.force_factor < landmark.setting("force_factor")
	):
		hud.append_log_lines([TranslationServer.translate(landmark.message("weak"))])
		return result
	state.essence.apply_damage(landmark.setting("gin"))
	state.vitality.apply_damage(landmark.setting("kee"))
	state.spirit.apply_damage(landmark.setting("sen"))
	result.pushed = true
	hud.append_log_lines([TranslationServer.translate(landmark.message("push"))])
	if random_source.legacy_random(landmark.setting("random")) == 0:
		result.rolled = true
		hud.append_log_lines([TranslationServer.translate(landmark.message("rolled"))])
		result.moved = move_through(map, GameContent.catalog().portal(landmark.portal_id))
	# std/char.c heart_beat(): gone below zero, the player falls where they now are.
	var active: WorldMapController = session.active_map() as WorldMapController
	if active != null and state.life_threshold() != CharacterState.LifeThreshold.ACTIVE:
		active.player_fall_below_zero()
	return result
