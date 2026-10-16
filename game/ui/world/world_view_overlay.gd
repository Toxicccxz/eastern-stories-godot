class_name WorldViewOverlay
extends CanvasLayer

## The view around a map change (DECISIONS「手感」): it goes dark before a passage the
## player walked into (the session's view_leaving), comes back on the new map (or where it
## was) and names the place there: the region and the zone, as on the status card. Only how
## it looks; the session holds world time and the player's walk meanwhile.

const BANNER_FADE_SHARE: float = 0.2
const BANNER_MARGIN: float = 16.0
## The frame a map changes in is a long one: the view comes back from the frames after it.
const SETTLE_FRAMES: int = 2

var _session: WorldSessionController
var _shade: ColorRect
var _banner: PanelContainer
var _banner_text: Label
var _shade_tween: Tween
var _banner_tween: Tween
## Counts arrivals; one waiting out SETTLE_FRAMES gives way to a later one.
var _arrivals: int = 0


func configure(session: WorldSessionController) -> void:
	_session = session


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shade = ColorRect.new()
	_shade.name = "ViewShade"
	_shade.color = Color.BLACK
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.modulate.a = 0.0
	add_child(_shade)
	_banner = PanelContainer.new()
	_banner.name = "MapBanner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.06, 0.72)
	style.set_corner_radius_all(10)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	_banner.add_theme_stylebox_override("panel", style)
	_banner.modulate.a = 0.0
	add_child(_banner)
	_banner_text = Label.new()
	_banner_text.name = "MapBannerText"
	_banner_text.add_theme_font_size_override("font_size", 24)
	_banner_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_text)
	if _session != null:
		_session.view_leaving.connect(_on_view_leaving)
		_session.view_arriving.connect(_on_view_arriving)


func shade_alpha() -> float:
	return _shade.modulate.a


func banner_text() -> String:
	return _banner_text.text if _banner.modulate.a > 0.0 else ""


func _on_view_leaving(seconds: float) -> void:
	_arrivals += 1
	_shade_tween = _fade(_shade_tween, _shade, 1.0, seconds)


func _on_view_arriving(_map_id: StringName, arrived: bool) -> void:
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	if feel.map_fade_in_seconds <= 0.0:
		_kill(_shade_tween)
		_shade.modulate.a = 0.0
		if arrived:
			_show_banner(feel.map_banner_seconds)
		return
	# A map change the player did not walk (a spell, waking at the temple) cuts to dark.
	_kill(_shade_tween)
	if arrived:
		_shade.modulate.a = 1.0
	_arrivals += 1
	var arrival: int = _arrivals
	for frame: int in SETTLE_FRAMES:
		await get_tree().process_frame
	if arrival != _arrivals:
		return
	_shade_tween = _fade(_shade_tween, _shade, 0.0, feel.map_fade_in_seconds)
	if arrived:
		_show_banner(feel.map_banner_seconds)


func _show_banner(seconds: float) -> void:
	var title: String = _place_title()
	if seconds <= 0.0 or title.is_empty():
		return
	_banner_text.text = title
	_kill(_banner_tween)
	_banner.modulate.a = 0.0
	_place_banner()
	var fade: float = seconds * BANNER_FADE_SHARE
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, fade)
	_banner_tween.tween_interval(seconds - 2.0 * fade)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, fade)


## Over the map at the top, in the middle of what the status card leaves free.
func _place_banner() -> void:
	_banner.reset_size()
	var view: Rect2 = get_viewport().get_visible_rect()
	var left: float = view.position.x
	var top: float = view.position.y + BANNER_MARGIN
	var hud: SharedGameplayUI = null if _session == null else _session.shared_ui()
	if hud != null and hud.visible:
		var card: Rect2 = hud.card_rect()
		left = card.end.x
		top = card.position.y
	var middle: float = (left + view.end.x) / 2.0
	_banner.position = Vector2(clampf(middle - _banner.size.x / 2.0, left + BANNER_MARGIN, view.end.x - _banner.size.x - BANNER_MARGIN), top).round()


## 「绮云镇 · 卧龙岗」: the region the player is now in and the zone they stand in.
func _place_title() -> String:
	var player: WorldPlayerRuntimeState = null if _session == null else _session.player_runtime()
	var location: WorldLocationState = null if player == null else player.world_location()
	if location == null:
		return ""
	var catalog: ContentCatalog = GameContent.catalog()
	var region: RegionDefinition = catalog.region(location.region_id)
	var zone: ZoneDefinition = catalog.zone(location.zone_id)
	var region_name: String = "" if region == null else tr(region.display_name)
	var zone_name: String = "" if zone == null else tr(zone.display_name)
	if region_name.is_empty() or zone_name.is_empty() or region_name == zone_name:
		return zone_name if not zone_name.is_empty() else region_name
	# TRANSLATORS: the banner on arriving on another map: {region} the region (绮云镇), {place} where the player stands (卧龙岗).
	return tr("{region} · {place}").format({"region": region_name, "place": zone_name})


func _fade(tween: Tween, target: CanvasItem, alpha: float, seconds: float) -> Tween:
	_kill(tween)
	if seconds <= 0.0:
		target.modulate.a = alpha
		return null
	var fresh: Tween = create_tween()
	fresh.tween_property(target, "modulate:a", alpha, seconds)
	return fresh


func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
