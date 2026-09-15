class_name SnowSchoolContact
extends Node

## Resident-owned narrow contact/gate. No NPC spawn slot, death, AI or saved door.
var session: OldPineWorldSessionController
var map: SnowOutdoorController
var ui: SnowSchoolInteraction
var _door_open: bool = false
var last_learn: LearnResult
var _policy: SkillLearnPolicy = SnowSchoolTeacher.unarmed_policy()
var _skill: SkillDefinition = SnowSchoolTeacher.unarmed_definition()


func configure(p_session: OldPineWorldSessionController, p_map: SnowOutdoorController) -> void:
	session = p_session
	map = p_map
	ui = SnowSchoolInteraction.new()
	ui.name = "TeachingUI"
	ui.configure(self)
	add_child(ui)


func available() -> bool:
	return is_inside_tree() and session != null and not get_tree().paused and session.liquid_interaction_available() and session.active_map() == map and not session.player_runtime().busy.is_busy() and not session.player_runtime().relationship.is_fighting() and not session.combat_encounter_coordinator().has_active_encounter()


func can_teach() -> bool:
	if not available():
		return false
	var player: WorldPlayerRuntimeState = session.player_runtime()
	return player.world_location().zone_id == SnowWorldDefinitions.SCHOOLHALL_ZONE_ID and map.player_body.global_position.distance_squared_to((map.get_node("SchoolTeacher") as Marker2D).global_position) <= 96.0 * 96.0 and OldPineMapPlacementValidator.is_valid_character_position(map, player.world_location().zone_id, map.player_body.global_position)


func can_operate_door() -> bool:
	if not available():
		return false
	var zone: StringName = session.player_runtime().world_location().zone_id
	return zone in [SnowWorldDefinitions.SCHOOL1_ZONE_ID, SnowWorldDefinitions.SCHOOL2_ZONE_ID] and map.player_body.global_position.distance_squared_to((map.get_node("Walls/SchoolDoor") as CollisionShape2D).global_position) <= 90.0 * 90.0 and OldPineMapPlacementValidator.is_valid_character_position(map, zone, map.player_body.global_position)


func door_is_open() -> bool:
	return _door_open


func open_door() -> bool:
	if not can_operate_door() or _door_open:
		return false
	_set_door(true)
	return true


func close_door() -> bool:
	# Placement excludes the closed footprint even while open: never close onto Player.
	if not can_operate_door() or not _door_open:
		return false
	_set_door(false)
	return true


func _set_door(open: bool) -> void:
	_door_open = open
	(map.get_node("Walls/SchoolDoor") as CollisionShape2D).set_deferred("disabled", open)
	(map.get_node("Ground/SchoolShutter") as Polygon2D).visible = not open


func request_apprentice() -> SwordsmanApprenticeship.Outcome:
	if not can_teach():
		return SwordsmanApprenticeship.Outcome.AUTHORITY_FAILURE
	return session.player_runtime().request_school_apprenticeship(int(Time.get_unix_time_from_system()))


func cancel_apprentice() -> SwordsmanApprenticeship.Outcome:
	if not can_teach():
		return SwordsmanApprenticeship.Outcome.AUTHORITY_FAILURE
	return session.player_runtime().school_apprenticeship.cancel()


func request_learn() -> LearnResult:
	if not can_teach() or session.world_interaction_random_source() == null:
		last_learn = LearnResult.new(&"unarmed")
		last_learn.failure_reason = LearnResult.FailureReason.TEACHER_UNAVAILABLE
		return last_learn
	# Fresh facts on every request. No quote or panel state authorizes mutation.
	last_learn = LearnService.learn(session.player_runtime().state, SnowSchoolTeacher.unarmed_context(), _skill, _policy, null, session.world_interaction_random_source())
	return last_learn
