class_name WorldCharacterBody2D
extends CharacterBody2D

const WorldPlayerRuntimeType := preload(
	"res://runtime/characters/world_player_runtime_state.gd"
)

signal selection_requested(character_id: StringName)

@export var player_controlled: bool = false
@export var movement_speed: float = 220.0

var _player: WorldPlayerRuntimeType
var _npc: NpcRuntimeState
var _character_id: StringName = &""

var character_id: StringName:
	get: return _character_id


func bind_player(value: WorldPlayerRuntimeType) -> bool:
	if value == null or not value.is_valid():
		return false
	_player = value
	_npc = null
	_character_id = value.character_id
	_update_label("Player")
	refresh_runtime_state()
	return true


func bind_npc(value: NpcRuntimeState) -> bool:
	if value == null or not value.is_valid():
		return false
	_npc = value
	_player = null
	_character_id = value.character_id
	_update_label(value.definition().display_name)
	refresh_runtime_state()
	return true


func set_world_location(value: WorldLocationState) -> bool:
	if _player != null:
		return _player.set_world_location(value)
	if _npc != null:
		return _npc.set_world_location(value)
	return false


func refresh_runtime_state() -> void:
	var exists: bool = _exists()
	var dead: bool = _life_status() == CharacterRuntimeLifeStatus.Value.DEAD
	visible = exists and not dead
	input_pickable = (
		not player_controlled
		and exists
		and not dead
	)
	if not exists or dead:
		velocity = Vector2.ZERO
		collision_layer = 0
		collision_mask = 0


func _physics_process(_delta: float) -> void:
	if (
		not player_controlled
		or not _exists()
		or _life_status() != CharacterRuntimeLifeStatus.Value.ACTIVE
	):
		velocity = Vector2.ZERO
		return
	var direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down",
	)
	velocity = direction * movement_speed
	move_and_slide()


func _input_event(
	_viewport: Viewport,
	event: InputEvent,
	_shape_idx: int,
) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if (
		mouse_event != null
		and mouse_event.pressed
		and mouse_event.button_index == MOUSE_BUTTON_LEFT
		and not player_controlled
		and _exists()
		and _life_status() != CharacterRuntimeLifeStatus.Value.DEAD
	):
		selection_requested.emit(_character_id)


func _exists() -> bool:
	if _player != null:
		return _player.exists_in_world
	return _npc != null and _npc.exists_in_map


func _life_status() -> int:
	if _player != null:
		return _player.life_status
	if _npc != null:
		return _npc.life_status
	return CharacterRuntimeLifeStatus.Value.DEAD


func _update_label(value: String) -> void:
	var label: Label = get_node_or_null("NameLabel") as Label
	if label != null:
		label.text = value
