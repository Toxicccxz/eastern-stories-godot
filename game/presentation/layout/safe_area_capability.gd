class_name SafeAreaCapability
extends RefCounted


func measure(viewport: Viewport) -> SafeAreaMetrics:
	var rect: Rect2 = viewport.get_visible_rect()
	return SafeAreaMetrics.normalize(rect, rect, rect, Transform2D.IDENTITY, false, ui_scale_of(viewport))


## The window's content scale (the 界面缩放), 1 for any other viewport.
static func ui_scale_of(viewport: Viewport) -> float:
	var window: Window = viewport as Window
	return window.content_scale_factor if window != null else 1.0
