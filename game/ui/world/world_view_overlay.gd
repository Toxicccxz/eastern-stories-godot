class_name WorldViewOverlay
extends CanvasLayer

## The view around a map change (DECISIONS「手感」): it goes dark before a passage the
## player walked into (the session's view_leaving), comes back on the new map (or where it
## was) and names the place there: the region and the zone. A room the player comes
## into shows its title and description in the top right for a while (DECISIONS「说话和交互」;
## 消息 keeps them). While a map's world is built the view stays dark, with the loading screen
## over it if that takes long, and one fade brings the world back (DECISIONS「加载画面」). Only
## how it looks; the session holds world time and the player's walk meanwhile.

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
var _loading_screen: WorldLoadingScreen
## A world's build is under way, or its cover not yet lifted.
var _loading: bool = false
## Counts the builds; one being lifted gives way to a later one.
var _builds: int = 0
## What the arrival would have done, for the lift to do: its fade and its banner.
var _arrival_fade: float = -1.0
var _arrival_banner: float = 0.0
## A room's text that came during the build, shown once the view is back.
var _room_waiting: Callable = Callable()
## The text showing now, for a build that begins while it fades in.
var _room_showing: Callable = Callable()


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
	_loading_screen = WorldLoadingScreen.new()
	_loading_screen.name = "LoadingScreen"
	add_child(_loading_screen)
	# 界面重做 3: the banner and a room's text on dark plates (GameTheme's BannerPanel), the
	# place's name in the brush hand as on the title.
	_banner = PanelContainer.new()
	_banner.theme = GameTheme.shared()
	_banner.name = "MapBanner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.theme_type_variation = &"BannerPanel"
	_banner.modulate.a = 0.0
	add_child(_banner)
	_banner_text = Label.new()
	_banner_text.name = "MapBannerText"
	_banner_text.theme_type_variation = &"PlaceCaption"
	_banner_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_text)
	_room = PanelContainer.new()
	_room.name = "RoomText"
	_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room.theme = GameTheme.shared()
	_room.theme_type_variation = &"BannerPanel"
	_room.modulate.a = 0.0
	add_child(_room)
	var room_rows: VBoxContainer = VBoxContainer.new()
	room_rows.add_theme_constant_override("separation", 4)
	_room.add_child(room_rows)
	_room_title = Label.new()
	_room_title.name = "RoomTitle"
	_room_title.theme_type_variation = &"HeadingLabel"
	# Already in the shown language (the log's line holds the same).
	_room_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	room_rows.add_child(_room_title)
	_room_text = Label.new()
	_room_text.name = "RoomDescription"
	_room_text.add_theme_font_size_override("font_size", GameTheme.text_size(16))
	_room_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_room_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	room_rows.add_child(_room_text)
	if _session != null:
		_session.view_leaving.connect(_on_view_leaving)
		_session.view_arriving.connect(_on_view_arriving)
		_session.world_building_changed.connect(_on_world_building)
		if _session.world_building():
			_on_world_building(true)


func shade_alpha() -> float:
	return _shade.modulate.a


## The cover of a world's build is up (DECISIONS「加载画面」).
func loading() -> bool:
	return _loading


func loading_screen() -> WorldLoadingScreen:
	return _loading_screen


func banner_text() -> String:
	return _banner_text.text if _banner.modulate.a > 0.0 else ""


## The room's title and description at the top now ("" when none shows).
func room_text() -> String:
	return "" if _room.modulate.a <= 0.0 else "%s %s" % [_room_title.text, _room_text.text]


## `title` and `description` (shown language) at the top for `seconds`, fading in and out.
func show_room(title: String, description: String, seconds: float) -> void:
	_room_showing = show_room.bind(title, description, seconds)
	if _loading:
		_room_waiting = _room_showing
		return
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
## shows it keeps the height its wrapped lines take (known only once they are laid out). The
## banner follows the status card, whose height changes with its objective line; it stays put
## when the card goes.
func _process(_delta: float) -> void:
	var hud: SharedGameplayUI = null if _session == null else _session.shared_ui()
	_room.visible = hud != null and hud.visible and not hud.panel_open() and not hud.menu.is_presented() and not _loading
	if _room.visible and _room.modulate.a > 0.0:
		_place_room()
	if _room.visible and _banner.modulate.a > 0.0:
		_place_banner()


## In the top right corner beside the status card, clear of the middle where the player and
## those they talk to are; under the card when the screen is too narrow beside it. The text
## wraps at the panel's width (a wrapping label has none alone).
func _place_room() -> void:
	var view: Rect2 = get_viewport().get_visible_rect()
	var top: float = view.position.y + BANNER_MARGIN
	var hud: SharedGameplayUI = null if _session == null else _session.shared_ui()
	var card: Rect2 = hud.card_rect() if hud != null and hud.visible else Rect2()
	var width: float = _room_width_beside(view, card)
	if width <= 0.0:
		width = minf(ROOM_TEXT_WIDTH, view.size.x - 2.0 * BANNER_MARGIN)
		top = card.end.y + BANNER_MARGIN
	_room_text.custom_minimum_size.x = width - _room.get_theme_stylebox("panel").get_minimum_size().x
	_room.reset_size()
	_room.position = Vector2(view.end.x - _room.size.x - BANNER_MARGIN, top).round()


## How wide the room's text is beside the status card; 0 when it goes under the card.
func _room_width_beside(view: Rect2, card: Rect2) -> float:
	var left: float = card.end.x if card.has_area() else view.position.x
	var beside: float = view.end.x - left - 2.0 * BANNER_MARGIN
	return minf(ROOM_TEXT_WIDTH, beside) if beside >= ROOM_TEXT_MIN_WIDTH else 0.0


## Nothing goes to the world under the cover: a key pressed there would act unseen. A paused
## tree (a phone sent to the background) stops the build: the shell's pause panel takes the keys.
func _input(event: InputEvent) -> void:
	if event.is_pressed() and blocks_input():
		get_viewport().set_input_as_handled()


func blocks_input() -> bool:
	return _loading and not get_tree().paused


func _on_view_leaving(seconds: float) -> void:
	_arrivals += 1
	_shade_tween = _fade(_shade_tween, _shade, 1.0, seconds)


## Through a door (into or out of a building's own map) the fade is the door's, and no
## banner names the place: the room's description does.
func _on_view_arriving(_map_id: StringName, arrived: bool, door: bool) -> void:
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	var fade_in: float = feel.door_fade_in_seconds if door else feel.map_fade_in_seconds
	var banner: float = 0.0 if door else feel.map_banner_seconds
	_arrival_fade = fade_in
	_arrival_banner = banner if arrived else 0.0
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
	if arrival != _arrivals or _loading:
		return
	_shade_tween = _fade(_shade_tween, _shade, 0.0, fade_in)
	if arrived:
		_show_banner(banner)


## A build began: dark at once whatever came before (a New Game has no fade of its own). A
## build that ended here lifts the cover once its first frame, the long one, has been drawn.
func _on_world_building(on: bool) -> void:
	# The session going away lets its build go after this layer has left the tree.
	if not is_inside_tree():
		return
	_builds += 1
	var build: int = _builds
	if on:
		_loading = true
		_kill(_shade_tween)
		_shade.modulate.a = 1.0
		# The last place's banner does not stay over the new map's cover.
		_kill(_banner_tween)
		_banner.modulate.a = 0.0
		# A room told in the handoff's own frame waits like one told during the build: it
		# would run out its time hidden.
		if _room_tween != null and _room_tween.is_running():
			_kill(_room_tween)
			_room.modulate.a = 0.0
			_room_waiting = _room_showing
		_loading_screen.begin()
		return
	_loading_screen.settle()
	for frame: int in SETTLE_FRAMES:
		await get_tree().process_frame
	# Its minimum is wall-clock time, as the picture's frames are: wait on that clock, not on
	# a game-time timer.
	while _loading_screen.seconds_left() > 0.0:
		await get_tree().process_frame
	if build == _builds:
		_lift(build)


## One fade from the cover to the world: the picture and the dark under it go together, so the
## view never dips to black between them. A small room's build showed no picture, and its
## fade is the door's or the passage's own.
func _lift(build: int) -> void:
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	var seconds: float = feel.map_loading_fade_seconds if _loading_screen.shown() or _arrival_fade < 0.0 else _arrival_fade
	_loading = false
	_loading_screen.end(seconds)
	_shade_tween = _fade(_shade_tween, _shade, 0.0, seconds)
	_show_banner(_arrival_banner)
	_arrival_fade = -1.0
	_arrival_banner = 0.0
	if _room_waiting.is_valid():
		_room_waiting.call()
		_room_waiting = Callable()
	if seconds > 0.0:
		await get_tree().create_timer(seconds, true).timeout
	if build == _builds:
		_session.hold_presentation(WorldSessionController.WORLD_BUILD_HOLD, false)


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


## Over the map at the top, in the middle of what the status card and the room's text leave
## free; under the card when it does not fit there (the 界面缩放 at 125% and 150%, a long
## name). The room's column counts whether its text shows yet or not: the two come in either
## order, and the banner stays where it first appeared.
func _place_banner() -> void:
	_banner.reset_size()
	var view: Rect2 = get_viewport().get_visible_rect()
	var left: float = view.position.x
	var right: float = view.end.x
	var top: float = view.position.y + BANNER_MARGIN
	var hud: SharedGameplayUI = null if _session == null else _session.shared_ui()
	if hud != null and hud.visible:
		var card: Rect2 = hud.card_rect()
		left = card.end.x
		right -= _room_width_beside(view, card) + BANNER_MARGIN
		top = card.position.y
		if right - left < _banner.size.x + 2.0 * BANNER_MARGIN:
			left = card.position.x
			right = card.end.x
			top = card.end.y + BANNER_MARGIN
	var middle: float = (left + right) / 2.0
	var at := Vector2(clampf(middle - _banner.size.x / 2.0, view.position.x + BANNER_MARGIN, view.end.x - _banner.size.x - BANNER_MARGIN), top)
	# Under the card a long name can reach under the room's text beside it (像素界面's taller
	# lines): then it goes below that too.
	var room := Rect2(_room.position, _room.size)
	if _room.visible and not _room_text.text.is_empty() and Rect2(at, _banner.size).intersects(room):
		at.y = room.end.y + BANNER_MARGIN
	_banner.position = at.round()


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
