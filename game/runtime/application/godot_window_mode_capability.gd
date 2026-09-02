class_name GodotWindowModeCapability
extends ApplicationWindowModeCapability


func can_edit_window_mode() -> bool:
	return (
		OS.get_name() in ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]
		and DisplayServer.get_name() != "headless"
		and not Engine.is_embedded_in_editor()
	)


func current_window_mode() -> int:
	var mode: int = DisplayServer.window_get_mode()
	if mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]:
		return ApplicationWindowMode.Value.FULLSCREEN
	return ApplicationWindowMode.Value.WINDOWED


func apply_window_mode(mode: int) -> bool:
	if not can_edit_window_mode() or not ApplicationWindowMode.is_valid(mode):
		return false
	var display_mode: int = (
		DisplayServer.WINDOW_MODE_FULLSCREEN
		if mode == ApplicationWindowMode.Value.FULLSCREEN
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	DisplayServer.window_set_mode(display_mode)
	# An embedded editor game cannot change desktop mode. For a native desktop
	# window, persist only a mode the display backend reports as applied.
	return current_window_mode() == mode
