class_name BattleActionPanel
extends PanelContainer

signal action_requested(action_id: StringName)
signal cancel_requested(expected_request_id: StringName)

var catalog: BattleActionPresentationCatalog = BattleActionPresentationCatalog.new()
var _actions: HFlowContainer
var _empty: Label
var _queue: Label
var _cancel: Button
var _shown_ids: Array[StringName] = []
var _displayed_request_id: StringName = &""


func _ready() -> void:
	var content := HBoxContainer.new()
	add_child(content)
	var action_column := VBoxContainer.new()
	action_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(action_column)
	var heading := Label.new()
	heading.text = "Quick Actions"
	action_column.add_child(heading)
	_empty = Label.new()
	_empty.text = "No tactical actions are currently available."
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_column.add_child(_empty)
	_actions = HFlowContainer.new()
	_actions.add_theme_constant_override("h_separation", 8)
	_actions.add_theme_constant_override("v_separation", 8)
	action_column.add_child(_actions)
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
	_cancel.text = "Cancel queued action"
	_cancel.custom_minimum_size = Vector2(64, 64)
	_cancel.pressed.connect(_cancel_pressed)
	queue_column.add_child(_cancel)


func present(projection: BattlePresentationProjection) -> void:
	var infos: Array[CombatTacticalActionInfo] = projection.actions()
	var ids: Array[StringName] = []
	for info: CombatTacticalActionInfo in infos:
		ids.append(info.action_id)
	_empty.visible = ids.is_empty()
	_actions.visible = not ids.is_empty()
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
	_queue.text = "Queue · %s" % CombatQueuedAction.Status.keys()[projection.queue_status]
	if queued != null:
		_queue.text += "\n%s · Queued Target: %s" % [catalog.label_for(queued.request.action_id), projection.display_name(queued.resolved_target_id)]
	_queue.tooltip_text = _queue.text
	_cancel.visible = queued != null


func first_action_button() -> Button:
	return null if _actions.get_child_count() == 0 else _actions.get_child(0) as Button


func _action_pressed(id: StringName) -> void:
	action_requested.emit(id)


func _cancel_pressed() -> void:
	cancel_requested.emit(_displayed_request_id)
