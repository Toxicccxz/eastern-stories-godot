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
	return true


func _physics_process(_delta: float) -> void:
	if not player_controlled or _binding == null:
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
	):
		selection_requested.emit(_binding.character_id)
