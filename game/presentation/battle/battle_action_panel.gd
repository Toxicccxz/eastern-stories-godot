class_name BattleActionPanel
extends PanelContainer

signal action_requested(action_id: StringName)
signal cancel_requested(expected_request_id: StringName)
## enforce.c: set at once, not queued (it has no busy check).
signal enforce_requested(points: int)

var catalog: BattleActionPresentationCatalog = BattleActionPresentationCatalog.new()
var _actions: HFlowContainer
var _empty: Label
var _queue: Label
var _cancel: Button
var _shown_ids: Array[StringName] = []
var _displayed_request_id: StringName = &""
var enforce_row: HBoxContainer
var enforce_text: Label
var enforce_amount: SpinBox
var enforce_button: Button
var _shown_factor: int = -1
var _shown_encounter: StringName = &""
## (action_id) -> PackedStringArray: [question, choice] when the action is asked
## first (owner: 天邪虎啸, powerfade), empty otherwise.
var confirm_text: Callable
## The question in place of the action buttons; the fight goes on meanwhile.
var prompt: ConfirmPrompt
var _asking_id: StringName = &""


func _ready() -> void:
	var content := HBoxContainer.new()
	add_child(content)
	var action_column := VBoxContainer.new()
	action_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(action_column)
	var heading := Label.new()
	heading.text = "快捷操作"
	action_column.add_child(heading)
	_empty = Label.new()
	_empty.text = "现在没有可用的操作。"
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_column.add_child(_empty)
	_actions = HFlowContainer.new()
	_actions.add_theme_constant_override("h_separation", 8)
	_actions.add_theme_constant_override("v_separation", 8)
	action_column.add_child(_actions)
	prompt = ConfirmPrompt.new()
	prompt.name = "ActionQuestion"
	prompt.hide()
	prompt.confirmed.connect(_on_prompt_answered.bind(true))
	prompt.cancelled.connect(_on_prompt_answered.bind(false))
	action_column.add_child(prompt)
	enforce_row = HBoxContainer.new()
	enforce_row.name = "Enforce"
	enforce_row.add_theme_constant_override("separation", 8)
	action_column.add_child(enforce_row)
	enforce_text = Label.new()
	enforce_row.add_child(enforce_text)
	enforce_amount = SpinBox.new()
	enforce_amount.name = "EnforceAmount"
	enforce_amount.min_value = 0
	enforce_amount.step = 1
	enforce_row.add_child(enforce_amount)
	enforce_button = Button.new()
	enforce_button.name = "EnforceButton"
	enforce_button.text = "加力"
	enforce_button.custom_minimum_size = Vector2(64, 64)
	enforce_button.pressed.connect(_enforce_pressed)
	enforce_row.add_child(enforce_button)
	var queue_column := VBoxContainer.new()
	queue_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(queue_column)
	_queue = Label.new()
	_queue.clip_text = true
	_queue.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_queue.add_theme_font_size_override("font_size", 16)
	queue_column.add_child(_queue)
	_cancel = Button.new()
	_cancel.name = "CancelQueue"
	_cancel.text = "取消已排定的操作"
	_cancel.custom_minimum_size = Vector2(64, 64)
	_cancel.pressed.connect(_cancel_pressed)
	queue_column.add_child(_cancel)


func present(projection: BattlePresentationProjection) -> void:
	var infos: Array[CombatTacticalActionInfo] = projection.actions()
	var ids: Array[StringName] = []
	for info: CombatTacticalActionInfo in infos:
		ids.append(info.action_id)
	_present_enforce(projection)
	if is_asking() and not ids.has(_asking_id):
		# The action went away (the force it needs was disabled): the question goes too.
		prompt.cancel()
	_empty.visible = ids.is_empty() and not enforce_row.visible and not is_asking()
	_actions.visible = not ids.is_empty() and not is_asking()
	if ids != _shown_ids:
		_shown_ids = ids
		for child: Node in _actions.get_children():
			_actions.remove_child(child)
			child.queue_free()
		for id: StringName in ids:
			var button := Button.new()
			button.name = "Action%d" % _actions.get_child_count()
			button.text = catalog.label_for(id)
			button.custom_minimum_size = Vector2(64, 64)
			button.pressed.connect(_action_pressed.bind(id))
			_actions.add_child(button)
	var queued: CombatQueuedAction = projection.queued_action()
	_displayed_request_id = &"" if queued == null else queued.request.request_id
	_queue.text = tr("排定：%s") % _queue_status(projection.queue_status)
	if queued != null:
		_queue.text += "\n" + tr("{action} · 目标：{target}").format({"action": catalog.label_for(queued.request.action_id), "target": tr(projection.display_name(queued.resolved_target_id))})
	_queue.tooltip_text = _queue.text
	_cancel.visible = queued != null


## enforce.c's factor now (hp.c's +N) and the amount to set, from 0 to its limit;
## the amount follows the factor whenever the factor changes or a fight begins.
func _present_enforce(projection: BattlePresentationProjection) -> void:
	var player: BattleParticipantProjection = projection.participant(projection.player_id)
	enforce_row.visible = projection.enforce_limit >= 0 and player != null
	if not enforce_row.visible or projection.encounter_id != _shown_encounter:
		_shown_factor = -1
		_shown_encounter = projection.encounter_id
	if not enforce_row.visible:
		return
	enforce_amount.max_value = projection.enforce_limit
	# TRANSLATORS: the battle panel: enforce.c's force_factor now, as hp.c shows it.
	enforce_text.text = tr("加力 +%d") % player.force_factor
	if player.force_factor != _shown_factor:
		_shown_factor = player.force_factor
		enforce_amount.set_value_no_signal(mini(player.force_factor, projection.enforce_limit))


func _enforce_pressed() -> void:
	enforce_requested.emit(int(enforce_amount.value))


func _queue_status(status: int) -> String:
	match status:
		CombatQueuedAction.Status.READY:
			return tr("就绪")
		CombatQueuedAction.Status.WAITING_FOR_BUSY:
			return tr("等你空下来")
	return tr("无")


func first_action_button() -> Button:
	return null if _actions.get_child_count() == 0 else _actions.get_child(0) as Button


func _action_pressed(id: StringName) -> void:
	var question: PackedStringArray = confirm_text.call(id) if confirm_text.is_valid() else PackedStringArray()
	if question.size() < 2:
		action_requested.emit(id)
		return
	_asking_id = id
	_actions.hide()
	prompt.show()
	prompt.ask(question[0], question[1])
	prompt.focus_default()


## Whether the panel asks about an action now.
func is_asking() -> bool:
	return not _asking_id.is_empty()


func _on_prompt_answered(yes: bool) -> void:
	var id: StringName = _asking_id
	_asking_id = &""
	prompt.hide()
	_actions.visible = not _shown_ids.is_empty()
	if yes and not id.is_empty():
		action_requested.emit(id)


func _cancel_pressed() -> void:
	cancel_requested.emit(_displayed_request_id)
