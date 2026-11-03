class_name GodotWindowModeCapability
extends ApplicationWindowModeCapability

var _sized: bool = false
var _resolution: Vector2i = ApplicationWindowSize.AUTO
## The title bar and borders, read while the window has them: asked for 窗口's room from
## full screen, they are not there to measure.
var _frame: Vector2i = Vector2i.ZERO


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
	_draw_picture()
	# An embedded editor game cannot change desktop mode. For a native desktop
	# window, persist only a mode the display backend reports as applied.
	return current_window_mode() == mode


func apply_resolution(resolution: Vector2i) -> void:
	if not can_edit_window_mode() or resolution == _resolution:
		return
	_resolution = resolution
	if current_window_mode() == ApplicationWindowMode.Value.WINDOWED:
		_size_window()
	_draw_picture()


func resolution_room(mode: int) -> Vector2i:
	if not can_edit_window_mode():
		return Vector2i.ZERO
	var screen: int = DisplayServer.window_get_current_screen()
	if mode != ApplicationWindowMode.Value.WINDOWED:
		return DisplayServer.screen_get_size(screen)
	_measure_frame()
	return DisplayServer.screen_get_usable_rect(screen).size - _frame


func current_screen() -> int:
	return DisplayServer.window_get_current_screen()


## window_set_current_screen keeps the window's offset and may leave most of it on the old
## monitor, which then stays the current one; its corner on the new one moves it for certain.
func show_on_screen(screen: int) -> void:
	if can_edit_window_mode() and screen >= 0 and screen < DisplayServer.get_screen_count():
		DisplayServer.window_set_position(DisplayServer.screen_get_usable_rect(screen).position)


## Wayland has no exclusive full screen: Godot shows it as the ordinary (borderless) kind.
func offers_exclusive_fullscreen() -> bool:
	return DisplayServer.get_name() != "Wayland"


## Phones and tablets always play full screen, in landscape (project.godot's orientation).
func prepare_platform_window() -> void:
	if (OS.has_feature("android") or OS.has_feature("ios")) and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif can_edit_window_mode():
		_measure_frame() # A game that opens in full screen has no frame to read later.


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
	_measure_frame()
	var size: Vector2i = ApplicationWindowSize.fitted(_resolution, usable.size - _frame)
	if size == ApplicationWindowSize.AUTO:
		size = ApplicationWindowSize.initial(screen_size)
	DisplayServer.window_set_size(size)
	# Centred with its frame, so the title bar stays on the monitor. The position is the
	# inside's; the side borders are as wide as the bottom one.
	var outer: Vector2i = size + _frame
	var border: int = _frame.x / 2
	DisplayServer.window_set_position(usable.position + ((usable.size - outer) / 2).max(Vector2i.ZERO) + Vector2i(border, _frame.y - border))


func _measure_frame() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		_frame = (DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()).max(Vector2i.ZERO)


## Godot never changes the display's own mode: covering the monitor, the 分辨率 draws the
## map that sharply (the interface stays at the monitor's); a window draws at its own size.
func _draw_picture() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var windowed: bool = current_window_mode() == ApplicationWindowMode.Value.WINDOWED
	var screen: Vector2i = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	tree.root.scaling_3d_scale = 1.0 if windowed else ApplicationWindowSize.picture_scale(_resolution, screen)
