class_name ConfirmPrompt
extends VBoxContainer

## The one way the game asks before an important or deadly choice (owner,
## 2026-10-06): the question, then the choice and 取消. 取消 takes the focus, so a
## stray Enter or tap does not make the choice. A host shows it inside its own panel
## or opens it in the shared frame; hiding it while it asks answers 取消, so closing
## the panel (关闭, Back) never makes the choice. tell() shows a notice with one
## button instead (the menu's results).
signal confirmed
signal cancelled

## The question's least height and centring (the menu's dialog: 76, centred).
@export var message_min_height: float = 0.0:
	set(value):
		message_min_height = value
		message.custom_minimum_size.y = value
@export var centered: bool = false:
	set(value):
		centered = value
		message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if value else HORIZONTAL_ALIGNMENT_LEFT
		message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER if value else VERTICAL_ALIGNMENT_TOP

var message: Label
var confirm_button: Button
var cancel_button: Button
var _asking: bool = false


func _init() -> void:
	name = "ConfirmPrompt"
	add_theme_constant_override("separation", 12)
	message = Label.new()
	message.name = "Message"
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(message)
	var actions := HFlowContainer.new()
	actions.name = "Actions"
	actions.alignment = FlowContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("h_separation", 12)
	actions.add_theme_constant_override("v_separation", 12)
	add_child(actions)
	confirm_button = _button(actions, "Confirm")
	cancel_button = _button(actions, "Cancel")
	confirm_button.pressed.connect(_answer.bind(true))
	cancel_button.pressed.connect(_answer.bind(false))
	# Room for the focused button's outline: a scrolling host clips at its content's edge.
	var room := Control.new()
	room.name = "OutlineRoom"
	room.custom_minimum_size.y = 4
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(room)
	visibility_changed.connect(_on_visibility_changed)


func _button(parent: Node, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = Vector2(120, 44)
	parent.add_child(button)
	return button


## Asks. `text` is the question (a source text, or one already put together in the
## shown language); `choice` and `cancel` are source texts the buttons translate.
func ask(text: String, choice: String, cancel: String = "取消") -> void:
	_show(text)
	confirm_button.text = choice
	cancel_button.text = cancel
	cancel_button.show()
	_asking = true


## A notice with one button, which answers `confirmed`.
func tell(text: String, acknowledge: String = "确定") -> void:
	_show(text)
	confirm_button.text = acknowledge
	cancel_button.hide()
	_asking = true


func _show(text: String) -> void:
	message.text = text
	message.visible = not text.is_empty()
	show()


func is_asking() -> bool:
	return _asking


## The safe answer has the focus: 取消, or the notice's only button.
func focus_default() -> void:
	(cancel_button if cancel_button.visible else confirm_button).grab_focus()


## Answers 取消 when it is asking (a host's Back).
func cancel() -> void:
	_answer(false)


## Hides without an answer: the host has settled the question itself.
func dismiss() -> void:
	_asking = false
	hide()


func _answer(choice: bool) -> void:
	if not _asking:
		return
	_asking = false
	if choice:
		confirmed.emit()
	else:
		cancelled.emit()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		cancel()
