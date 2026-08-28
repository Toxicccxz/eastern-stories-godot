class_name WorldLandmarkArea2D
extends Area2D

signal selection_requested(landmark_id: StringName)

@export var landmark_id: StringName = &""


func is_configured() -> bool:
	return not landmark_id.is_empty()


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
		and is_configured()
	):
		selection_requested.emit(landmark_id)
