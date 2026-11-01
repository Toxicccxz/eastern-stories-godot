class_name FocusTip
extends CanvasLayer
## The hover of the keys and the pad (现代基线 C; DECISIONS「数值用到才出现」): Godot shows a
## tooltip to the mouse only. A control the player walked to with a direction shows its
## tooltip_text beside it after DELAY_SECONDS. A panel opening puts the focus somewhere by
## itself and shows nothing, so nothing covers a fight that was not asked about; any other
## press or the mouse puts it away until the next step. PadSupport feeds it.

## Above the shell (100).
const LAYER: int = 110
const DELAY_SECONDS: float = 0.4
const MAX_WIDTH: float = 380.0
## Between the control and the tip, and the tip and the screen's edge.
const GAP: float = 6.0
const DIRECTIONS: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev"]

var panel: PanelContainer
var _text: Label
## The control walked to; null while no tip is wanted.
var _control: Control
var _waited: float = 0.0
## A direction was pressed this frame: the focus change it brings is the player's.
var _stepped: bool = false


func _init() -> void:
	name = "FocusTip"
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The mouse's tooltip as the project theme draws it.
	panel.theme_type_variation = &"TooltipPanel"
	panel.hide()
	add_child(panel)
	_text = Label.new()
	_text.name = "Text"
	_text.theme_type_variation = &"TooltipLabel"
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_text)


## Every input event, before the interface takes it.
func observe(event: InputEvent) -> void:
	var kind: int = InputDevices.kind_of(event)
	if kind == InputDevices.Kind.TOUCH or event is InputEventMouseButton or (event is InputEventMouseMotion and kind >= 0):
		_put_away()
		return
	for action: StringName in DIRECTIONS:
		if event.is_action_pressed(action, true):
			_stepped = true
			return
	if kind >= 0:
		_put_away()


## The focus moved to `control` (null: nowhere).
func focus_moved(control: Control) -> void:
	_put_away()
	if _stepped:
		_control = control


func _put_away() -> void:
	_control = null
	_waited = 0.0
	panel.hide()


func _process(delta: float) -> void:
	_stepped = false
	if _control == null:
		return
	if not is_instance_valid(_control) or not _control.is_visible_in_tree() or not _control.has_focus():
		_put_away()
		return
	_waited += delta
	var shown: String = "" if _waited < DELAY_SECONDS else tr(_control.tooltip_text)
	panel.visible = not shown.is_empty()
	if panel.visible:
		_show(shown)


## Beside the control, never over it while the screen has room: under it, over it, then to its
## right or left (a battle card is too tall for the first two). The text may change while it
## shows (a card's numbers): sized and placed every frame.
func _show(shown: String) -> void:
	_text.text = shown
	var font: Font = _text.get_theme_font("font")
	var font_size: int = _text.get_theme_font_size("font_size")
	_text.custom_minimum_size.x = minf(MAX_WIDTH, font.get_multiline_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 1.0)
	panel.reset_size()
	var screen: Vector2 = panel.get_viewport_rect().size
	var tip: Vector2 = panel.size
	var around: Rect2 = _control.get_global_rect()
	var x: float = clampf(around.position.x, GAP, maxf(GAP, screen.x - tip.x - GAP))
	if around.end.y + GAP + tip.y <= screen.y - GAP:
		panel.position = Vector2(x, around.end.y + GAP)
	elif around.position.y - GAP - tip.y >= GAP:
		panel.position = Vector2(x, around.position.y - GAP - tip.y)
	else:
		var y: float = clampf(around.position.y, GAP, maxf(GAP, screen.y - tip.y - GAP))
		var right: float = around.end.x + GAP
		panel.position = Vector2(right if right + tip.x <= screen.x - GAP else maxf(GAP, around.position.x - GAP - tip.x), y)
