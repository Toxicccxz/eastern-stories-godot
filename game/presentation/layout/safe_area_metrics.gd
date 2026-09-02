class_name SafeAreaMetrics
extends RefCounted

const PADDING: float = 16.0
const TOUCH_TARGET: float = 64.0
const GAP: float = 8.0

var _viewport: Rect2
var _safe: Rect2
var _fallback: bool
var _mobile: bool


func _init(viewport: Rect2, safe: Rect2, fallback: bool = false, mobile: bool = false) -> void:
	_viewport = viewport
	_safe = safe
	_fallback = fallback
	_mobile = mobile


static func normalize(
	logical_viewport: Rect2,
	physical_content: Rect2,
	physical_safe: Rect2,
	logical_to_screen: Transform2D,
	mobile: bool = false,
) -> SafeAreaMetrics:
	var viewport: Rect2 = logical_viewport
	if not _valid_rect(viewport):
		viewport = Rect2(0, 0, 1, 1)
		return SafeAreaMetrics.new(viewport, viewport, true, mobile)
	if (
		not _valid_rect(physical_content)
		or not _valid_rect(physical_safe)
		or not logical_to_screen.is_finite()
		or absf(logical_to_screen.determinant()) < 0.000001
	):
		return SafeAreaMetrics.new(viewport, viewport, true, mobile)
	var intersection: Rect2 = physical_content.intersection(physical_safe)
	if not _valid_rect(intersection):
		return SafeAreaMetrics.new(viewport, viewport, true, mobile)
	var safe: Rect2 = (logical_to_screen.affine_inverse() * intersection).intersection(viewport)
	if not _valid_rect(safe):
		return SafeAreaMetrics.new(viewport, viewport, true, mobile)
	return SafeAreaMetrics.new(viewport, safe, false, mobile)


static func _valid_rect(rect: Rect2) -> bool:
	return rect.position.is_finite() and rect.size.is_finite() and rect.size.x > 0.0 and rect.size.y > 0.0


func viewport_rect() -> Rect2:
	return _viewport


func safe_rect() -> Rect2:
	return _safe


func content_rect() -> Rect2:
	var padding: Vector2 = Vector2(minf(PADDING, _safe.size.x / 4.0), minf(PADDING, _safe.size.y / 4.0))
	return Rect2(_safe.position + padding, _safe.size - padding * 2.0)


func used_fallback() -> bool:
	return _fallback


func is_compact() -> bool:
	return _safe.size.x < 1100.0 or _safe.size.y < 640.0


func touch_sized() -> bool:
	return _mobile or is_compact()


func is_qualified() -> bool:
	return _safe.size.x >= 800.0 and _safe.size.y >= 480.0


func future_movement_rect() -> Rect2:
	var content: Rect2 = content_rect()
	var extent: Vector2 = Vector2(minf(192.0, content.size.x), minf(192.0, content.size.y))
	return Rect2(Vector2(content.position.x, content.end.y - extent.y), extent)


func future_pause_rect() -> Rect2:
	var content: Rect2 = content_rect()
	var extent: Vector2 = Vector2(minf(64.0, content.size.x), minf(64.0, content.size.y))
	return Rect2(Vector2(content.end.x - extent.x, content.position.y), extent)


func equivalent(other: SafeAreaMetrics) -> bool:
	return other != null and _viewport.is_equal_approx(other._viewport) and _safe.is_equal_approx(other._safe) and _fallback == other._fallback and _mobile == other._mobile
