class_name ApplicationWindowModeCapability
extends RefCounted


func can_edit_window_mode() -> bool:
	return false


func current_window_mode() -> int:
	return ApplicationWindowMode.Value.WINDOWED


func apply_window_mode(_mode: int) -> bool:
	return false


## What the platform itself asks of the window before any setting applies.
func prepare_platform_window() -> void:
	pass


## Draws the whole interface at `percent` (ApplicationUiScale); every platform has it.
func apply_ui_scale(_percent: int) -> void:
	pass
