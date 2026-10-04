class_name BuryLandmarkPolicy
extends WorldLandmarkPolicy

## cave5.c do_bury("skeleton"): only with the `buried` item lying here (else
## 这里没有这样东西。). The bones are buried and gone (moved to /obj/void, back with
## the room's reset); then BuryRoll: the `reward` item falls at the player's feet,
## or the floor gives way and the player falls through the portal (after the
## paper, when some flutters down).
class Result:
	extends RefCounted
	var buried: bool = false
	var outcome: BuryRoll.Outcome = BuryRoll.Outcome.FALL
	var reward_item_id: StringName = &""
	var moved: RefCounted = null


func keeps_selection() -> bool:
	return false


func use(map: WorldMapController, landmark: WorldLandmarkDefinition) -> RefCounted:
	var result: Result = Result.new()
	var player: WorldPlayerRuntimeState = map.player_runtime()
	var session: OldPineWorldSessionController = map.session
	var random_source: WorldInteractionRandomSource = map.world_interaction_random_source()
	if player == null or session == null or random_source == null or landmark == null:
		return result
	if player.life_status != CharacterRuntimeLifeStatus.Value.ACTIVE or session.is_transitioning() or session.active_map_id() != map.map_id():
		return result
	var location: WorldLocationState = player.world_location()
	if location == null or location.zone_id != landmark.zone_id:
		return result
	var hud: SharedGameplayUI = session.shared_ui()
	var bones: StringName = map.floor_item_of(landmark.item("buried"), landmark.zone_id)
	if bones.is_empty():
		hud.append_log_lines([TranslationServer.translate("这里没有这样东西。")])
		return result
	hud.append_log_lines([TranslationServer.translate(landmark.message("bury"))])
	if not map.destroy_floor_item(bones):
		return result
	result.buried = true
	result.outcome = BuryRoll.roll(player.state.attributes.karma, random_source)
	if result.outcome == BuryRoll.Outcome.BOOK:
		hud.append_log_lines([TranslationServer.translate(landmark.message("book"))])
		result.reward_item_id = map.place_new_floor_item(landmark.item("reward"))
		return result
	if result.outcome == BuryRoll.Outcome.PAPER:
		hud.append_log_lines([TranslationServer.translate(landmark.message("paper"))])
	hud.append_log_lines([TranslationServer.translate(landmark.message("fall"))])
	result.moved = move_through(map, GameContent.catalog().portal(landmark.portal_id))
	return result
