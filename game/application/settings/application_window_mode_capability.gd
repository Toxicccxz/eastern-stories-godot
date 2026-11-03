class_name ApplicationWindowModeCapability
extends RefCounted


func can_edit_window_mode() -> bool:
	return false


func current_window_mode() -> int:
	return ApplicationWindowMode.Value.WINDOWED


func apply_window_mode(_mode: int) -> bool:
	return false


## The 分辨率 (ApplicationWindowSize): a window's size, or how sharply the map is drawn while
## the window covers the monitor. A window the player has resized keeps its size until
## another 分辨率 is chosen.
func apply_resolution(_resolution: Vector2i) -> void:
	pass


## The largest picture `mode` has room for on the monitor the game is on.
func resolution_room(_mode: int) -> Vector2i:
	return Vector2i.ZERO


## The monitor the game is on.
func current_screen() -> int:
	return 0


## Carries the window to that monitor; one that is no longer there leaves it where it is.
func show_on_screen(_screen: int) -> void:
	pass


## Whether 全屏 (exclusive) differs from 无边框窗口 here; where it does not, only the
## borderless kind is offered.
func offers_exclusive_fullscreen() -> bool:
	return true


## What the platform itself asks of the window before any setting applies.
func prepare_platform_window() -> void:
	pass


## Draws the whole interface at `percent` (ApplicationUiScale); every platform has it.
func apply_ui_scale(_percent: int) -> void:
	pass
