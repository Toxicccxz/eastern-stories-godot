class_name WorldViewOverlay
extends CanvasLayer

## The view around a map change (DECISIONS「手感」): it goes dark before a passage the
## player walked into (the session's view_leaving), comes back on the new map (or where it
## was) and names the place there: the region and the zone. A room the player comes
## into shows its title and description in the top right for a while (DECISIONS「说话和交互」;
## 消息 keeps them). Only how it looks; the session holds world time and the player's walk
## meanwhile.

const BANNER_FADE_SHARE: float = 0.2
const BANNER_MARGIN: float = 16.0
## The frame a map changes in is a long one: the view comes back from the frames after it.
const SETTLE_FRAMES: int = 2
const ROOM_TEXT_WIDTH: float = 440.0
## Narrower than this beside the status card, the room's text goes under it instead.
const ROOM_TEXT_MIN_WIDTH: float = 280.0

var _session: WorldSessionController
var _shade: ColorRect
var _banner: PanelContainer
var _banner_text: Label
var _shade_tween: Tween
var _banner_tween: Tween
var _room: PanelContainer
var _room_title: Label
var _room_text: Label
var _room_tween: Tween
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
	var style: StyleBoxFlat = UiSkin.overlay(0.8)
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
	_room = PanelContainer.new()
	_room.name = "RoomText"
	_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room.add_theme_stylebox_override("panel", style.duplicate())
	_room.modulate.a = 0.0
	add_child(_room)
	var room_rows: VBoxContainer = VBoxContainer.new()
	room_rows.add_theme_constant_override("separation", 4)
	_room.add_child(room_rows)
	_room_title = Label.new()
	_room_title.name = "RoomTitle"
	_room_title.add_theme_font_size_override("font_size", 17)
	_room_title.add_theme_color_override("font_color", SharedGameplayLayout.ACCENT_COLOR)
	# Already in the shown language (the log's line holds the same).
	_room_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	room_rows.add_child(_room_title)
	_room_text = Label.new()
	_room_text.name = "RoomDescription"
	_room_text.add_theme_font_size_override("font_size", 14)
	_room_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_room_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	room_rows.add_child(_room_text)
	if _session != null:
		_session.view_leaving.connect(_on_view_leaving)
		_session.view_arriving.connect(_on_view_arriving)


func shade_alpha() -> float:
	return _shade.modulate.a


func banner_text() -> String:
	return _banner_text.text if _banner.modulate.a > 0.0 else ""


## The room's title and description at the top now ("" when none shows).
func room_text() -> String:
	return "" if _room.modulate.a <= 0.0 else "%s %s" % [_room_title.text, _room_text.text]


## `title` and `description` (shown language) at the top for `seconds`, fading in and out.
func show_room(title: String, description: String, seconds: float) -> void:
	_room_title.text = title
	_room_text.text = description
	_kill(_room_tween)
	_place_room()
	var fade: float = minf(0.3, seconds * BANNER_FADE_SHARE)
	_room_tween = create_tween()
	_room_tween.tween_property(_room, "modulate:a", 1.0, fade)
	_room_tween.tween_interval(maxf(0.0, seconds - 2.0 * fade))
	_room_tween.tween_property(_room, "modulate:a", 0.0, fade)


## The room's text gives way to a panel, the menu or a fight (its time runs on); while it
## shows it keeps the height its wrapped lines take (known only once they are laid out).
func _process(_delta: float) -> void:
	var hud: SharedGameplayUI = null if _session == null else _session.shared_ui()
	_room.visible = hud != null and hud.visible and not hud.panel_open() and not hud.menu.is_presented()
	if _room.visible and _room.modulate.a > 0.0:
		_place_room()


## In the top right corner beside the status card, clear of the middle where the player and
## those they talk to are; under the card when the screen is too narrow beside it (the
## 界面缩放 at 150%). The text wraps at the panel's width (a wrapping label has none alone).
func _place_room() -> void:
	var view: Rect2 = get_viewport().get_visible_rect()
	var top: float = view.position.y + BANNER_MARGIN
	var beside: float = view.size.x - 2.0 * BANNER_MARGIN
	var hud: SharedGameplayUI = null if _session == null else _session.shared_ui()
	if hud != null and hud.visible:
		var card: Rect2 = hud.card_rect()
		beside = view.end.x - card.end.x - 2.0 * BANNER_MARGIN
		if beside < ROOM_TEXT_MIN_WIDTH:
			beside = view.size.x - 2.0 * BANNER_MARGIN
			top = card.end.y + BANNER_MARGIN
	var width: float = minf(ROOM_TEXT_WIDTH, beside)
	_room_text.custom_minimum_size.x = width - _room.get_theme_stylebox("panel").get_minimum_size().x
	_room.reset_size()
	_room.position = Vector2(view.end.x - _room.size.x - BANNER_MARGIN, top).round()


func _on_view_leaving(seconds: float) -> void:
	_arrivals += 1
	_shade_tween = _fade(_shade_tween, _shade, 1.0, seconds)


## Through a door (into or out of a building's own map) the fade is the door's, and no
## banner names the place: the room's description does.
func _on_view_arriving(_map_id: StringName, arrived: bool, door: bool) -> void:
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	var fade_in: float = feel.door_fade_in_seconds if door else feel.map_fade_in_seconds
	var banner: float = 0.0 if door else feel.map_banner_seconds
	if fade_in <= 0.0:
		_kill(_shade_tween)
		_shade.modulate.a = 0.0
		if arrived:
			_show_banner(banner)
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
	_shade_tween = _fade(_shade_tween, _shade, 0.0, fade_in)
	if arrived:
		_show_banner(banner)


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
