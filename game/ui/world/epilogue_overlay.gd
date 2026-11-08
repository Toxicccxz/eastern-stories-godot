class_name EpilogueOverlay
extends CanvasLayer

## The ending told over the 沙盘 (终章 C; DECISIONS「结局讲述」): the title screen's own 沙盘 (TitleSand)
## fills the screen, the camera flies to each card's place, and the card's title and lines stand at
## the foot; E, A or a click goes on to the next. It waits for the dialogue box to be read out
## before it begins (the lines said before it are read first), fades in and, after the last card,
## fades out and calls back with whether the journey ends with it. Presentation only: what is said
## is the EpilogueDefinition's, chosen by the rule (WorldSessionController.play_epilogue()).

signal finished(final: bool)

const ZOOM: float = 0.95
const FLY_SECONDS: float = 1.6
const FADE_SECONDS: float = 0.8

var sand: TitleSand
var title_label: Label
var lines_label: Label
var hint_label: Label
var _root: Control
var _veil: ColorRect
var _cards: Array[Array] = []
var _index: int = -1
var _final: bool = false
var _pending: bool = false
var _active: bool = false
var _wait_for: Callable = Callable()
var _fly: Tween


func _init() -> void:
	name = "EpilogueOverlay"
	layer = 40
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	sand = TitleSand.new()
	_root.add_child(sand)
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.05, 0.04, 0.03, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.anchor_left = 0.0
	shade.anchor_right = 1.0
	shade.anchor_top = 0.66
	shade.anchor_bottom = 1.0
	_root.add_child(shade)
	var column := VBoxContainer.new()
	column.name = "Card"
	column.anchor_left = 0.12
	column.anchor_right = 0.88
	column.anchor_top = 0.69
	column.anchor_bottom = 0.97
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(column)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.theme_type_variation = &"HeadingLabel"
	title_label.add_theme_color_override("font_color", UiPalette.LANTERN)
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	column.add_child(title_label)
	lines_label = Label.new()
	lines_label.name = "Lines"
	lines_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lines_label.add_theme_font_size_override("font_size", 18)
	lines_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	column.add_child(lines_label)
	hint_label = Label.new()
	hint_label.name = "Hint"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.add_theme_color_override("font_color", UiPalette.MUTED)
	# TRANSLATORS: native (终章 C): under a card of the ending told over the 沙盘: go on.
	hint_label.text = "E 继续"
	column.add_child(hint_label)
	_veil = ColorRect.new()
	_veil.name = "Veil"
	_veil.color = Color.BLACK
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_veil)
	visible = false


## Tells `cards` ([[EpilogueDefinition.Card, lines], ...]) once `wait_for` (a Callable -> bool:
## still busy) says nothing else is being read; `final` is passed back on finished.
func play(cards: Array[Array], final: bool, wait_for: Callable = Callable()) -> void:
	_cards = cards
	_final = final
	_index = -1
	_wait_for = wait_for
	_pending = true
	_active = true


func active() -> bool:
	return _active


## The card shown now ("" before the first and after the last).
func shown_title() -> String:
	return title_label.text if visible and _index >= 0 else ""


func shown_lines() -> String:
	return lines_label.text if visible and _index >= 0 else ""


func card_index() -> int:
	return _index


func _process(_delta: float) -> void:
	if not _pending:
		return
	if _wait_for.is_valid() and bool(_wait_for.call()):
		return
	_pending = false
	_begin()


func _begin() -> void:
	visible = true
	_veil.modulate.a = 1.0
	sand.zoom = ZOOM
	if _cards.is_empty():
		_end()
		return
	_show(0)
	create_tween().tween_property(_veil, "modulate:a", 0.0, FADE_SECONDS)


## The next card; after the last, the end.
func advance() -> void:
	if not _active or _pending:
		return
	if _index + 1 >= _cards.size():
		_end()
		return
	_show(_index + 1)


func _show(index: int) -> void:
	_index = index
	var card: EpilogueDefinition.Card = _cards[index][0]
	var lines: Array = _cards[index][1]
	title_label.text = TranslationServer.translate(card.title)
	var said: PackedStringArray = []
	for line: String in lines:
		said.append(TranslationServer.translate(line))
	lines_label.text = "\n".join(said)
	if not card.place.is_empty():
		if _fly != null:
			_fly.kill()
		_fly = create_tween()
		_fly.tween_property(sand, "centre", sand.place_of(card.place), FLY_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _end() -> void:
	_active = false
	var fade := create_tween()
	fade.tween_property(_veil, "modulate:a", 1.0, FADE_SECONDS)
	fade.tween_callback(func() -> void:
		visible = false
		_index = -1
		finished.emit(_final))


## While it is told, every key and button is its own: E, A or a click goes on.
func _input(event: InputEvent) -> void:
	if not _active or _pending or event.is_echo() or not event.is_pressed():
		return
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		var click: bool = event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
		if click or event.is_action_pressed(&"interact") or event.is_action_pressed("ui_accept"):
			advance()
