extends Node

## Bounded launcher only: all gameplay authorities belong to the production Session.
var session: OldPineWorldSessionController
var zone_history: Array[StringName] = []
var first_oldpine_position: Vector2
var first_oldpine_spawn: StringName = &""


func _ready() -> void:
	session = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate() as OldPineWorldSessionController
	session.deterministic_npc_seed = true
	session.deterministic_combat_seed = true
	session.deterministic_world_interaction_seed = true
	if not session.configure_source_entry("Snow Player", CharacterState.GENDER_MALE):
		push_error("NGE4 QA configuration failed")
		return
	add_child(session)
	if not session.is_initialized():
		push_error("NGE4 QA Session initialization failed")


func _process(_delta: float) -> void:
	if session == null or not session.is_initialized():
		return
	var zone: StringName = session.player_runtime().world_location().zone_id
	if zone_history.is_empty() or zone_history.back() != zone:
		zone_history.append(zone)
		if zone == OldPineWorldDefinitions.NORTH_APPROACH_ZONE_ID and first_oldpine_spawn.is_empty():
			first_oldpine_position = session.active_map().runtime_player_body().global_position
			first_oldpine_spawn = session.last_map_handoff_result().destination_spawn_point_id
