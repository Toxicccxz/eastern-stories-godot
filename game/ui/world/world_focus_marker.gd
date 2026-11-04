class_name WorldFocusMarker
extends Control

## The ring and the prompt on what E / A goes to (DECISIONS「手感」,「说话和交互」): a ring
## round the target (SharedUiNearby.target_focus()) and under it the key and what it does
## (交互, or a door's 打开 …) on a dark plate; 界面重做 3 moved it from over the thing, where
## it covered the name over its head and the bubble. Drawn over the map, under the HUD's
## panels; hidden while a panel, the menu or a fight has the screen. A click or tap on the
## prompt is E.

const RING_COLOR: Color = Color(UiPalette.LANTERN, 0.9)
const RING_RADIUS: float = 26.0
## Over the thing (no room under it: the screen's bottom), the prompt's bottom edge this far
## above the thing's middle.
const PROMPT_LIFT: float = 50.0
## The prompt's top this far below the ring (screen units).
const PROMPT_DROP: float = 6.0
const REFRESH_SECONDS: float = 0.1

var _ui: SharedGameplayUI
var _focus: WorldFocus
var _since_refresh: float = INF
var _prompt: PanelContainer
var _prompt_text: Label
var _ring_at: Vector2 = Vector2.INF
## Where the prompt shows: under the ring, beside it, or over the thing.
enum Place { BELOW, SIDE, ABOVE }
var _place: Place = Place.BELOW
## The player's figure on the screen, from the feet to over the name (projected units).
const PLAYER_HEIGHT: float = 110.0
const PLAYER_HALF_WIDTH: float = 26.0
var _ring_scale: float = 1.0


func configure(ui: SharedGameplayUI) -> void:
	_ui = ui


func _ready() -> void:
	name = "WorldFocusMarker"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = GameTheme.shared()
	_prompt = PanelContainer.new()
	_prompt.name = "FocusPrompt"
	_prompt.theme_type_variation = &"ToastPanel"
	_prompt.mouse_filter = Control.MOUSE_FILTER_STOP
	_prompt.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_prompt.gui_input.connect(_on_prompt_input)
	add_child(_prompt)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	_prompt.add_child(row)
	var glyph: TextureRect = TextureRect.new()
	glyph.texture = InputGlyphTexture.new(&"interact")
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)
	_prompt_text = Label.new()
	_prompt_text.name = "FocusPromptText"
	# Already in the shown language (SharedUiNearby.prompt_text()).
	_prompt_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_prompt_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_text.add_theme_font_size_override("font_size", 16)
	row.add_child(_prompt_text)
	_prompt.visible = false


## How far over its middle the marked thing's top is now, with the prompt (0: unmarked).
func lift_over(node: Node2D) -> float:
	# The thing itself, or a service it offers from where it stands.
	if not _prompt.visible or _place != Place.ABOVE or _focus == null or (_focus.node != node and _focus.at().distance_to(node.global_position) > RING_RADIUS):
		return 0.0
	return PROMPT_LIFT + _prompt.size.y


## How far under its middle the marked thing's prompt reaches when it shows below it (0: not).
func drop_under(node: Node2D) -> float:
	if not _prompt.visible or _place != Place.BELOW or _focus == null or (_focus.node != node and _focus.at().distance_to(node.global_position) > RING_RADIUS):
		return 0.0
	return _prompt.position.y + _prompt.size.y - _ring_at.y


## The prompt's text now ("" when nothing is marked).
func prompt_text() -> String:
	return _prompt_text.text if _prompt.visible else ""


func focus() -> WorldFocus:
	return _focus if _prompt.visible else null


func _process(delta: float) -> void:
	var map: WorldMapController = _shown_map()
	if map == null:
		_hide()
		return
	_since_refresh += delta
	if _since_refresh >= REFRESH_SECONDS:
		_since_refresh = 0.0
		_focus = _ui.nearby.target_focus()
		if _focus != null:
			_prompt_text.text = _focus.title
	var at: Vector2 = Vector2.INF if _focus == null else _focus.at()
	if not at.is_finite():
		_hide()
		return
	var screen: Vector2 = map.screen_position(at)
	_ring_scale = map.screen_scale().x
	_prompt.visible = true
	_prompt.reset_size()
	var view: Rect2 = get_viewport().get_visible_rect().grow(-4.0)
	var scale: Vector2 = map.screen_scale()
	var spots: Dictionary[Place, Vector2] = {
		Place.BELOW: screen + Vector2(-_prompt.size.x / 2.0, RING_RADIUS * scale.y + PROMPT_DROP),
		Place.SIDE: screen + Vector2(RING_RADIUS * scale.x + PROMPT_DROP, -_prompt.size.y / 2.0),
		Place.ABOVE: screen + Vector2(-_prompt.size.x / 2.0, -PROMPT_LIFT - _prompt.size.y),
	}
	var avoid: Array[Rect2] = [_ui.card_rect(), _player_rect(map)]
	_place = Place.BELOW
	for spot: Place in spots:
		var rect := Rect2(spots[spot], _prompt.size)
		if view.encloses(rect) and not avoid.any(func(other: Rect2) -> bool: return other.has_area() and other.intersects(rect)):
			_place = spot
			break
	var place: Vector2 = spots[_place]
	place.x = clampf(place.x, view.position.x, maxf(view.position.x, view.end.x - _prompt.size.x))
	place.y = clampf(place.y, view.position.y, maxf(view.position.y, view.end.y - _prompt.size.y))
	_prompt.position = place.round()
	if not _ring_at.is_equal_approx(screen):
		_ring_at = screen
		queue_redraw()


## The player's figure on the screen (feet to name), which the prompt keeps clear of.
func _player_rect(map: WorldMapController) -> Rect2:
	var body: Node2D = map.runtime_player_body()
	if body == null:
		return Rect2()
	var feet: Vector2 = map.screen_position(body.global_position)
	var top: Vector2 = map.screen_position(body.global_position, PLAYER_HEIGHT)
	var half: float = PLAYER_HALF_WIDTH * map.screen_scale().x
	return Rect2(Vector2(feet.x - half, minf(top.y, feet.y)), Vector2(half * 2.0, absf(feet.y - top.y) + 4.0))


func _on_prompt_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		accept_event()
		_ui.interact()


func _draw() -> void:
	if _ring_at.is_finite():
		draw_arc(_ring_at, RING_RADIUS * _ring_scale, 0.0, TAU, 40, RING_COLOR, 2.0, true)


func _hide() -> void:
	_focus = null
	_since_refresh = INF
	if _prompt.visible or _ring_at.is_finite():
		_prompt.visible = false
		_ring_at = Vector2.INF
		queue_redraw()


## The active map while the player walks it with nothing else on the screen.
func _shown_map() -> WorldMapController:
	if _ui == null or not _ui.visible or _ui.menu.is_presented() or _ui.panel_open():
		return null
	var session: WorldSessionController = _ui.session()
	var map: WorldMapController = null if session == null else session.active_map() as WorldMapController
	if map == null or not map.gameplay_open() or not session.portable_inventory_available():
		return null
	return map
