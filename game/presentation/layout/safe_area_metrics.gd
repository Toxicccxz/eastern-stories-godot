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
	_viewport = viewport if _valid_rect(viewport) else Rect2(0, 0, 1, 1)
	_safe = safe.intersection(_viewport) if _valid_rect(safe) else Rect2()
	_fallback = fallback or _viewport != viewport or not _valid_rect(_safe)
	if not _valid_rect(_safe):
		_safe = _viewport
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
	var determinant: float = logical_to_screen.determinant()
	if (
		not _valid_rect(physical_content)
		or not _valid_rect(physical_safe)
		or not logical_to_screen.is_finite()
		or not is_finite(determinant)
		or determinant == 0.0
	):
		return SafeAreaMetrics.new(viewport, viewport, true, mobile)
	var intersection: Rect2 = physical_content.intersection(physical_safe)
	if not _valid_rect(intersection):
		return SafeAreaMetrics.new(viewport, viewport, true, mobile)
	var inverse: Transform2D = logical_to_screen.affine_inverse()
	if not inverse.is_finite():
		return SafeAreaMetrics.new(viewport, viewport, true, mobile)
	var transformed: Rect2 = inverse * intersection
	if not _valid_rect(transformed):
		return SafeAreaMetrics.new(viewport, viewport, true, mobile)
	var safe: Rect2 = transformed.intersection(viewport)
	if not _valid_rect(safe):
		return SafeAreaMetrics.new(viewport, viewport, true, mobile)
	return SafeAreaMetrics.new(viewport, safe, false, mobile)


static func _valid_rect(rect: Rect2) -> bool:
	# Finite components alone do not imply a finite/representable endpoint in real_t.
	return rect.position.is_finite() and rect.size.is_finite() and rect.end.is_finite() and rect.size.x > 0.0 and rect.size.y > 0.0 and rect.end.x > rect.position.x and rect.end.y > rect.position.y


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
