extends SafeAreaCapability

var metrics: SafeAreaMetrics = SafeAreaMetrics.normalize(
	Rect2(0, 0, 960, 540), Rect2(0, 0, 960, 540), Rect2(0, 0, 960, 540), Transform2D.IDENTITY
)


func measure(_viewport: Viewport) -> SafeAreaMetrics:
	return metrics
