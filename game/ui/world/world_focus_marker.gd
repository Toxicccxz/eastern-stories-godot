class_name WorldFocusMarker
extends Control

## The ring and the prompt on what the place's A goes to (DECISIONS「手感」): a ring round
## the thing (WorldMapSelection.focus()) and under it the button and what it does — the
## door's or service's action, or the name of the nearest thing in reach, whose group on
## the card A goes into. Drawn over the map, under the HUD's panels; hidden while a panel,
## the menu or a fight has the screen. Only shows; A is still the HUD's.

const RING_COLOR: Color = Color(0.95, 0.8, 0.35, 0.9)
const RING_RADIUS: float = 26.0
## The prompt's top edge below the thing's middle.
const PROMPT_DROP: float = 30.0
const REFRESH_SECONDS: float = 0.1

var _ui: SharedGameplayUI
var _focus: WorldFocus
var _since_refresh: float = INF
var _prompt: PanelContainer
var _prompt_text: Label
var _ring_at: Vector2 = Vector2.INF


func configure(ui: SharedGameplayUI) -> void:
	_ui = ui


func _ready() -> void:
	name = "WorldFocusMarker"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt = PanelContainer.new()
	_prompt.name = "FocusPrompt"
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	_prompt.add_child(row)
	var glyph: TextureRect = TextureRect.new()
	glyph.texture = InputGlyphTexture.new(&"ui_accept")
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)
	_prompt_text = Label.new()
	_prompt_text.name = "FocusPromptText"
	_prompt_text.add_theme_font_size_override("font_size", 14)
	row.add_child(_prompt_text)
	_prompt.visible = false


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
		_focus = map.selection.focus()
		if _focus != null:
			_prompt_text.text = _focus.title if not _focus.title.is_empty() else _ui.nearby.shown_name(_focus.thing)
	var at: Vector2 = Vector2.INF if _focus == null else _focus.at()
	if not at.is_finite():
		_hide()
		return
	var screen: Vector2 = get_viewport().get_canvas_transform() * at
	_prompt.visible = true
	_prompt.reset_size()
	_prompt.position = (screen + Vector2(-_prompt.size.x / 2.0, PROMPT_DROP)).round()
	if not _ring_at.is_equal_approx(screen):
		_ring_at = screen
		queue_redraw()


func _draw() -> void:
	if _ring_at.is_finite():
		draw_arc(_ring_at, RING_RADIUS * get_viewport().get_canvas_transform().get_scale().x, 0.0, TAU, 40, RING_COLOR, 2.0, true)


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
