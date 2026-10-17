class_name GodotWindowModeCapability
extends ApplicationWindowModeCapability

var _sized: bool = false


func can_edit_window_mode() -> bool:
	return (
		OS.get_name() in ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]
		and DisplayServer.get_name() != "headless"
		and not Engine.is_embedded_in_editor()
	)


func current_window_mode() -> int:
	match DisplayServer.window_get_mode():
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			return ApplicationWindowMode.Value.BORDERLESS
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			return ApplicationWindowMode.Value.FULLSCREEN
	return ApplicationWindowMode.Value.WINDOWED


func apply_window_mode(mode: int) -> bool:
	if not can_edit_window_mode() or not ApplicationWindowMode.is_valid(mode):
		return false
	var was_windowed: bool = current_window_mode() == ApplicationWindowMode.Value.WINDOWED
	var display_mode: int = DisplayServer.WINDOW_MODE_WINDOWED
	match mode:
		ApplicationWindowMode.Value.FULLSCREEN:
			display_mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		ApplicationWindowMode.Value.BORDERLESS:
			display_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(display_mode)
	# The window opens, or comes back from full screen, at its size for this screen; a
	# window the player has resized keeps its size while it stays a window.
	if mode == ApplicationWindowMode.Value.WINDOWED and (not _sized or not was_windowed):
		_size_window()
	# An embedded editor game cannot change desktop mode. For a native desktop
	# window, persist only a mode the display backend reports as applied.
	return current_window_mode() == mode


## Phones and tablets always play full screen, in landscape (project.godot's orientation).
func prepare_platform_window() -> void:
	if (OS.has_feature("android") or OS.has_feature("ios")) and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


## The root window's content scale: every Control and the world grow by it, and the
## world camera divides it back out (WorldMapController.frame_camera).
func apply_ui_scale(percent: int) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.content_scale_factor = ApplicationUiScale.factor(percent)


func _size_window() -> void:
	_sized = true
	var screen: int = DisplayServer.window_get_current_screen()
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen)
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	if screen_size.x <= 0 or screen_size.y <= 0 or usable.size.x <= 0 or usable.size.y <= 0:
		return
	var size: Vector2i = ApplicationWindowSize.initial(screen_size)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(usable.position + ((usable.size - size) / 2).max(Vector2i.ZERO))
