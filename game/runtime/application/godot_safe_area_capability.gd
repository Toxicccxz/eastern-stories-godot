class_name GodotSafeAreaCapability
extends SafeAreaCapability


func measure(viewport: Viewport) -> SafeAreaMetrics:
	var logical: Rect2 = viewport.get_visible_rect()
	var mobile: bool = OS.has_feature("android") or OS.has_feature("ios")
	if not mobile or DisplayServer.get_name() == "headless":
		return SafeAreaMetrics.normalize(logical, logical, logical, Transform2D.IDENTITY, mobile)
	# Screen-space content includes stretch/window offset; never use the world camera transform.
	var screen_transform: Transform2D = viewport.get_screen_transform()
	return SafeAreaMetrics.normalize(
		logical, screen_transform * logical, Rect2(DisplayServer.get_display_safe_area()),
		screen_transform, mobile,
	)
