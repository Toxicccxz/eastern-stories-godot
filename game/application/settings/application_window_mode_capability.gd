class_name ApplicationWindowModeCapability
extends RefCounted


func can_edit_window_mode() -> bool:
	return false


func current_window_mode() -> int:
	return ApplicationWindowMode.Value.WINDOWED


func apply_window_mode(_mode: int) -> bool:
	return false
