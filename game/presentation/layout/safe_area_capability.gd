class_name SafeAreaCapability
extends RefCounted


func measure(viewport: Viewport) -> SafeAreaMetrics:
	var rect: Rect2 = viewport.get_visible_rect()
	return SafeAreaMetrics.normalize(rect, rect, rect, Transform2D.IDENTITY)
