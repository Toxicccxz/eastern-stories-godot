class_name WorldDialogueBox
extends Control

## The dialogue box at the foot of the screen (DECISIONS「对话框」): what the player reads
## goes here, line by line, the speaker's name above it; what only sets the mood stays in
## the bubbles over people's heads. A scene's lines and a told story come as pages (say()),
## each waiting for 继续; 打听 hosts its topics under the text (host()). While it shows, the
## world holds still and the player does not walk: reading takes nobody's time.

## The box closed: what was told goes on (the HUD hurries the next line).
signal read_out

const HOLD: StringName = &"dialogue"
const WIDTH_SHARE: float = 0.62
const MIN_WIDTH: float = 560.0
const MAX_WIDTH: float = 900.0
const BOTTOM_MARGIN: float = 18.0
const MAX_HEIGHT_SHARE: float = 0.5
const NAME_SIZE: int = 17
const TEXT_SIZE: int = 18
const FILL: Color = Color(0.09, 0.08, 0.07, 0.94)
const EDGE: Color = Color(0.72, 0.56, 0.3, 0.9)
const TEXT_COLOR: Color = Color(0.95, 0.92, 0.85)
## What the speaker does rather than says.
const DEED_COLOR: Color = Color(0.72, 0.7, 0.65)

var _ui: SharedGameplayUI
var _panel: PanelContainer
var _name: Label
var _text: Label
var _hint: Button
var _mount: VBoxContainer
## Pages still to read, the one shown first: [speaker, text, is it said].
var _pages: Array[Array] = []
var _hosted: Control
var _hosted_parent: Node
## Characters shown so far of the page.
var _typed: float = 0.0


func configure(ui: SharedGameplayUI) -> void:
	_ui = ui


func _ready() -> void:
	name = "WorldDialogueBox"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.name = "Box"
	var style := StyleBoxFlat.new()
	style.bg_color = FILL
	style.border_color = EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	_panel.add_theme_stylebox_override("panel", style)
	_panel.gui_input.connect(_on_panel_input)
	add_child(_panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	_panel.add_child(rows)
	_name = Label.new()
	_name.name = "Speaker"
	_name.add_theme_font_size_override("font_size", NAME_SIZE)
	_name.add_theme_color_override("font_color", SharedGameplayLayout.ACCENT_COLOR)
	# A name from the content, shown as given (the speaker's tr() was made).
	_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	rows.add_child(_name)
	_text = Label.new()
	_text.name = "Line"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", TEXT_SIZE)
	_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	rows.add_child(_text)
	_mount = VBoxContainer.new()
	_mount.name = "Choices"
	rows.add_child(_mount)
	_hint = Button.new()
	_hint.name = "Continue"
	# TRANSLATORS: at the foot of the dialogue box: goes to the next line.
	_hint.text = "继续"
	_hint.flat = true
	_hint.focus_mode = Control.FOCUS_NONE
	_hint.size_flags_horizontal = Control.SIZE_SHRINK_END
	_hint.pressed.connect(advance)
	InputGlyphs.decorate(_hint, &"interact")
	rows.add_child(_hint)
	_panel.hide()
	get_viewport().size_changed.connect(_place)
	_panel.minimum_size_changed.connect(_place)
	_place()


func is_open() -> bool:
	return _panel != null and _panel.visible


## 打听 and the like: the box stays until closed, its choices under the text.
func hosting() -> bool:
	return _hosted != null


func hosted() -> Control:
	return _hosted


## The speaker shown now ("" with none).
func speaker() -> String:
	return _name.text if is_open() else ""


## The page shown now, whole, however far it has been typed.
func line() -> String:
	return _text.text if is_open() else ""


## The pages after the one shown.
func pages_left() -> int:
	return maxi(_pages.size() - 1, 0)


## `speaker_name` says `lines` (as the log shows them): a page each, after those still unread.
func say(speaker_name: String, lines: Array[String]) -> void:
	# Over 打听's topics a page would wait for a 继续 that is not there.
	if hosting():
		answer(lines)
		return
	var unread: bool = not _pages.is_empty()
	for text: String in lines:
		var page: String = WorldSpeechBubbles.bubble_text(text)
		if not page.is_empty():
			_pages.append([speaker_name, page, WorldSpeechBubbles.is_speech(text)])
	if not _pages.is_empty() and not unread:
		_open()
		_show_page()


## `content` (its buttons) shows under the text until close().
func host(speaker_name: String, content: Control) -> void:
	_release_hosted()
	_hosted = content
	_hosted_parent = content.get_parent()
	content.reparent(_mount, false)
	content.show()
	_name.text = speaker_name
	_name.show()
	_open()
	_hint.hide()


## `lines` show at once above the hosted choices (an answer).
func answer(lines: Array[String]) -> void:
	var said: Array[String] = []
	for text: String in lines:
		var page: String = WorldSpeechBubbles.bubble_text(text)
		if not page.is_empty():
			said.append(page)
	_text.text = "\n".join(said)
	_text.add_theme_color_override("font_color", TEXT_COLOR)
	_start_typing()
	_text.visible = not said.is_empty()


## A hosted box turns to telling: its choices go, `lines` read on as pages.
func tell(speaker_name: String, lines: Array[String]) -> void:
	_release_hosted()
	_text.text = ""
	_pages.clear()
	say(speaker_name, lines)
	if _pages.is_empty():
		close()


## 继续: the page typed out, else the next page, else the box closes. False when shut.
func advance() -> bool:
	if not is_open() or hosting():
		return false
	if _typing():
		_finish_typing()
		return true
	_pages.pop_front()
	if _pages.is_empty():
		close()
		read_out.emit()
	else:
		_show_page()
	return true


## Closes it at once: what was unread stays in 消息.
func close() -> void:
	_pages.clear()
	_release_hosted()
	if _panel != null:
		_panel.hide()
		_place()
	var session: WorldSessionController = null if _ui == null else _ui.session()
	if session != null:
		session.hold_presentation(HOLD, false)


func _open() -> void:
	_panel.show()
	_hint.visible = not hosting()
	_ui.session().hold_presentation(HOLD, true)
	_place()


func _show_page() -> void:
	var page: Array = _pages[0]
	# What happens is told by nobody (一名武官捧出石匣): no name over it.
	_name.text = page[0] if page[2] else ""
	_name.visible = page[2]
	_text.text = page[1]
	_text.visible = true
	_text.add_theme_color_override("font_color", TEXT_COLOR if page[2] else DEED_COLOR)
	_start_typing()
	_place()


func _start_typing() -> void:
	_typed = 0.0
	_text.visible_characters = 0 if GameContent.catalog().pacing().feel.dialogue_char_seconds() > 0.0 else -1


func _typing() -> bool:
	return _text.visible_characters >= 0


func _finish_typing() -> void:
	_text.visible_characters = -1


func _process(delta: float) -> void:
	if not is_open():
		return
	# A fight, a fall or a death takes the screen: the lines are in 消息.
	var session: WorldSessionController = _ui.session()
	if session == null or session.combat_encounter_coordinator().has_active_encounter() or session.player_runtime().life_status != CharacterRuntimeLifeStatus.Value.ACTIVE:
		close()
		return
	if _typing():
		_typed += delta / maxf(GameContent.catalog().pacing().feel.dialogue_char_seconds(), 0.001)
		_text.visible_characters = -1 if int(_typed) >= _text.text.length() else int(_typed)


func _release_hosted() -> void:
	var content: Control = _hosted
	var parent: Node = _hosted_parent
	_hosted = null
	_hosted_parent = null
	if is_instance_valid(content):
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused != null and content.is_ancestor_of(focused):
			focused.release_focus()
		content.hide()
		if is_instance_valid(parent):
			content.reparent(parent, false)


func _on_panel_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		advance()


func _place() -> void:
	if _panel == null:
		return
	var view: Rect2 = get_viewport_rect()
	var width: float = clampf(view.size.x * WIDTH_SHARE, minf(MIN_WIDTH, view.size.x - 16.0), MAX_WIDTH)
	_panel.custom_minimum_size = Vector2(width, 0.0)
	_panel.reset_size()
	_panel.size.x = width
	var height: float = _panel.get_combined_minimum_size().y
	_panel.position = Vector2((view.size.x - width) / 2.0, view.size.y - height - BOTTOM_MARGIN)
	if _ui != null:
		_ui.toasts_lift(height + BOTTOM_MARGIN if _panel.visible else 0.0)
