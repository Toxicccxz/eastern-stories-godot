class_name CombatSliceCharacterBody
extends CharacterBody2D

signal selection_requested(character_id: StringName)

@export var player_controlled: bool = false
@export var movement_speed: float = 220.0
@export var display_name: String = "Combatant"

var _binding: CombatSliceCharacterBinding

var binding: CombatSliceCharacterBinding:
	get:
		return _binding


func bind_character(value: CombatSliceCharacterBinding) -> bool:
	if value == null or not value.is_valid():
		return false
	_binding = value
	var name_label: Label = get_node_or_null("NameLabel") as Label
	if name_label != null:
		name_label.text = display_name
	refresh_runtime_state()
	return true


func refresh_runtime_state() -> void:
	if _binding == null:
		return
	var is_dead: bool = _binding.life_status == CombatSliceLifeStatus.Value.DEAD
	visible = not is_dead
	input_pickable = (
		_binding.exists_in_encounter
		and _binding.life_status == CombatSliceLifeStatus.Value.ACTIVE
	)
	if is_dead:
		velocity = Vector2.ZERO
		collision_layer = 0
		collision_mask = 0


func _physics_process(_delta: float) -> void:
	if (
		not player_controlled
		or _binding == null
		or not _binding.exists_in_encounter
		or _binding.life_status != CombatSliceLifeStatus.Value.ACTIVE
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
		and _binding != null
		and _binding.exists_in_encounter
		and _binding.life_status == CombatSliceLifeStatus.Value.ACTIVE
	):
		selection_requested.emit(_binding.character_id)
