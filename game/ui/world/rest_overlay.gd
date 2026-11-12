class_name RestOverlay
extends CanvasLayer

## 歇到回满 over the world (DECISIONS「歇到回满」): while the player rests the world dims a little
## and a band says how long so far, with 起身 (B / Esc) to stop. The world runs on beneath it
## (the session's rest); a window opened meanwhile hides the band while it holds world time.
## When the rest ends with 精, 气 and 神 full, the page it was begun from opens again.

const DIM: Color = Color(0.0, 0.0, 0.05, 0.28)

var _session: WorldSessionController
var _dim: ColorRect
var _band: PanelContainer
var _text: Label
var _stop: Button
var _fade: Tween
## What runs once the rest ends full (the page it was begun from), if it does.
var _after: Callable = Callable()


func configure(session: WorldSessionController) -> void:
	_session = session


func _ready() -> void:
	layer = 14
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim = ColorRect.new()
	_dim.name = "RestDim"
	_dim.color = DIM
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.theme = GameTheme.shared()
	add_child(_dim)
	var bottom: CenterContainer = CenterContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 0.62
	bottom.anchor_bottom = 0.62
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.add_child(bottom)
	_band = PanelContainer.new()
	_band.name = "RestBand"
	_band.theme_type_variation = &"MenuWindow"
	bottom.add_child(_band)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_band.add_child(row)
	_text = Label.new()
	_text.name = "RestText"
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_text)
	_stop = Button.new()
	_stop.name = "RestStop"
	_stop.custom_minimum_size = Vector2(0, 44)
	_stop.pressed.connect(stop)
	row.add_child(_stop)
	visible = false
	if _session != null:
		_session.rest_ended.connect(_on_rest_ended)


## The player sits down to rest; `after` runs if the rest ends with all three full. "" when they
## do, else why not (said nowhere: the caller shows it).
func begin(after: Callable = Callable()) -> String:
	if _session == null:
		return ""
	var refused: String = _session.begin_rest()
	if not refused.is_empty():
		return refused
	_after = after
	_text.text = RestLines.under_way(0)
	_stop.text = tr(RestLines.STOP)
	_show(true)
	return ""


## 起身: the rest stops.
func stop() -> void:
	if _session != null and _session.resting():
		_session.stop_rest()


func shown() -> bool:
	return visible and _session != null and _session.resting()


func _process(_delta: float) -> void:
	if _session == null or not visible:
		return
	if not _session.resting():
		_show(false)
		return
	_text.text = RestLines.under_way(_session.rest_minutes())
	# A window holds the world (and the rest with it): the band steps back under it.
	var held: bool = _session.world_time_held()
	_dim.visible = not held
	if not held and not _stop.has_focus() and get_viewport().gui_get_focus_owner() == null:
		_stop.grab_focus()


func _input(event: InputEvent) -> void:
	if shown() and _dim.visible and event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		stop()


func _on_rest_ended(outcome: int, _line: String) -> void:
	_show(false)
	var after: Callable = _after
	_after = Callable()
	if outcome == RestRules.Outcome.RESTED and after.is_valid():
		after.call()


func _show(on: bool) -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	var seconds: float = GameContent.catalog().pacing().feel.menu_fade_seconds if GameContent.catalog() != null else 0.0
	if on:
		visible = true
		_dim.visible = true
		_dim.modulate.a = 0.0 if seconds > 0.0 else 1.0
		if seconds > 0.0:
			_fade = create_tween()
			_fade.tween_property(_dim, "modulate:a", 1.0, seconds)
		_stop.grab_focus()
	else:
		if _stop.has_focus():
			_stop.release_focus()
		visible = false
