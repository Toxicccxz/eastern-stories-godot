class_name AndroidBackAdapter
extends Node

const SOURCE_DEVICE: int = 10_203


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree():
		for pressed: bool in [true, false]:
			var event: InputEventAction = InputEventAction.new()
			event.device = SOURCE_DEVICE
			event.action = &"system_back"
			event.pressed = pressed
			Input.parse_input_event(event)
