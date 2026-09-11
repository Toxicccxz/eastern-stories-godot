extends Node

## Isolated source launcher. Save uses the production coordinator/repository.
## A subsequent fresh process uses the unchanged Application Continue button.
const PROFILE_ID: String = "nge5a-live-source"
var session: OldPineWorldSessionController
var last_save: OldPineRuntimeSaveLoadResult

func _ready() -> void:
	Engine.max_fps = 60
	session = (load("res://scenes/world/oldpine/oldpine_world_session.tscn") as PackedScene).instantiate()
	session.configure_source_entry("续雪", CharacterState.GENDER_FEMALE)
	session.deterministic_combat_seed = true
	session.deterministic_npc_seed = true
	session.deterministic_world_interaction_seed = true
	add_child(session)
	session.player_runtime().state.recovery.food = 123
	session.player_runtime().state.recovery.water = 234
	var layer := CanvasLayer.new()
	add_child(layer)
	var button := Button.new()
	button.text = "QA: Save through production coordinator"
	button.position = Vector2(300, 12)
	button.pressed.connect(_save)
	layer.add_child(button)

func _save() -> void:
	last_save = OldPineSessionLoadCoordinator.new(GameSaveRepository.new(GameSaveStorageProfile.isolated_test(PROFILE_ID))).save_current(session)
	print("NGE5A live Save outcome: ", last_save.outcome)
