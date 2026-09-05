class_name BattlePresentationController
extends Control

## Session-owned projection/intent adapter. Never executes or advances combat.
signal intent_submitting
signal intent_received(result: CombatTacticalResult)

@export var action_catalog: BattleActionPresentationCatalog
@export var visual_theme: Theme
var _session: OldPineWorldSessionController
var _intent: BattleIntentAdapter
var _reader := BattleFeedbackReader.new()
var _projection := BattlePresentationProjection.new()
var _displayed_id: StringName = &""
var _safe: SafeAreaPresenter
var _content: VBoxContainer
var _participants: HBoxContainer
var _cards: Array[BattleParticipantCard] = []
var _shown_participants: Array[StringName] = []
var _title: Label
var _recent: VBoxContainer
var _receipt: Label
var _yielded_hud: CanvasLayer
var _hud_was_visible: bool = false
var _saved_focus: WeakRef
var action_panel: BattleActionPanel
var log_panel: BattleLogPanel
var log_button: Button


func _enter_tree() -> void:
	if is_instance_valid(_content):
		_attach_metrics.call_deferred() # Same UI survives staging -> current Session.


func _ready() -> void:
	_session = get_parent().get_parent() as OldPineWorldSessionController
	theme = visual_theme if visual_theme != null else BattleVisualTheme.new()
	if action_catalog == null:
		action_catalog = BattleActionPresentationCatalog.new()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	var blocker := ExplorationPresentationBlocker.new()
	blocker.name = "ExplorationInputContext"
	add_child(blocker)
	_attach_metrics()
	hide()


func _attach_metrics() -> void:
	if not is_inside_tree():
		return
	_safe = SafeAreaPresenter.find_or_create(self)
	if not _safe.metrics_changed.is_connected(_apply_metrics):
		_safe.metrics_changed.connect(_apply_metrics)
	_apply_metrics(_safe.current_metrics())


func _exit_tree() -> void:
	if is_instance_valid(_safe) and _safe.metrics_changed.is_connected(_apply_metrics):
		_safe.metrics_changed.disconnect(_apply_metrics)
	_restore_world_hud()


func _process(_delta: float) -> void:
	refresh_projection()


func current_projection() -> BattlePresentationProjection:
	return _projection


func feedback_reader() -> BattleFeedbackReader:
	return _reader


func refresh_projection() -> void:
	_projection = BattleProjectionBuilder.build(_session)
	var changed: bool = _displayed_id != _projection.encounter_id
	if changed:
		_displayed_id = _projection.encounter_id
		log_panel.close_log()
		log_panel.clear_entries()
		_receipt.text = ""
		if _projection.active:
			if _intent == null:
				_intent = BattleIntentAdapter.new(_session.combat_encounter_coordinator(), _projection.player_id)
			_yield_world_hud()
			show()
		else:
			hide()
			_restore_world_hud()
	var entries: Array[BattleFeedbackProjection] = _reader.read_new(_session.combat_encounter_coordinator(), _projection) if _session.is_initialized() else []
	if not _projection.active:
		return
	_title.text = "ENCOUNTER · %s · %s\nCurrent Target: %s" % [CombatEncounterMode.Value.keys()[_projection.mode], _receipt.text, _projection.display_name(_projection.current_target_id)]
	_title.tooltip_text = _title.text
	_present_participants()
	action_panel.present(_projection)
	if not entries.is_empty():
		log_panel.append_entries(entries)
		var recent: Array[BattleFeedbackProjection] = _reader.recent()
		for index: int in 3:
			var line: Label = _recent.get_child(index)
			line.text = recent[index].text if index < recent.size() else ""
			line.tooltip_text = line.text
	elif changed:
		for index: int in 3:
			(_recent.get_child(index) as Label).text = "Combat feedback will appear as opportunities resolve." if index == 0 else ""
	if changed:
		_focus_battle.call_deferred()
	elif not log_panel.visible:
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused == null or not focused.is_visible_in_tree():
			_focus_battle()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "FrozenWorldShade"
	backdrop.color = Color(0.025, 0.035, 0.045, 0.68)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_content = VBoxContainer.new()
	_content.name = "SafeBattleContent"
	_content.minimum_size_changed.connect(_refit_content.call_deferred)
	add_child(_content)
	var header := HBoxContainer.new()
	_content.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.add_theme_color_override("font_color", Color("efc77b"))
	header.add_child(_title)
	log_button = Button.new()
	log_button.name = "CombatLogButton"
	log_button.text = "Combat Log"
	log_button.custom_minimum_size = Vector2(144, 64)
	log_button.pressed.connect(_open_log)
	header.add_child(log_button)
	# Reserve shared Shell TouchPause space, including desktop touch-capability QA.
	var pause_space := Control.new()
	pause_space.custom_minimum_size = Vector2(64, 64)
	pause_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(pause_space)
	var participant_scroll := ScrollContainer.new()
	participant_scroll.name = "ParticipantScroll"
	participant_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	participant_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	participant_scroll.custom_minimum_size.y = 144
	participant_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(participant_scroll)
	_participants = HBoxContainer.new()
	_participants.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_participants.size_flags_vertical = Control.SIZE_EXPAND_FILL
	participant_scroll.add_child(_participants)
	action_panel = BattleActionPanel.new()
	action_panel.name = "QuickActions"
	action_panel.catalog = action_catalog
	action_panel.action_requested.connect(_submit_action)
	action_panel.cancel_requested.connect(_cancel_action)
	_content.add_child(action_panel)
	_receipt = Label.new()
	_receipt.name = "IntentReceipt"
	_receipt.visible = false # Text is projected into the header, not an extra narrow-screen row.
	_receipt.add_theme_font_size_override("font_size", 14)
	_content.add_child(_receipt)
	_recent = VBoxContainer.new()
	_recent.name = "RecentFeedback"
	_recent.add_theme_constant_override("separation", 0)
	_recent.custom_minimum_size.y = 60
	_content.add_child(_recent)
	for index: int in 3:
		var line := Label.new()
		line.add_theme_font_size_override("font_size", 16)
		line.clip_text = true
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_recent.add_child(line)
	log_panel = BattleLogPanel.new()
	log_panel.name = "CombatLog"
	log_panel.closed.connect(_focus_battle)
	add_child(log_panel)


func _apply_metrics(metrics: SafeAreaMetrics) -> void:
	if metrics == null:
		return
	_content.position = metrics.content_rect().position
	_content.size = metrics.content_rect().size
	log_panel.apply_metrics(metrics)


func _refit_content() -> void:
	# Initial text/container minimums can temporarily grow the Control. Restore the
	# same SafeArea bounds after native layout converges, without a second sampler.
	if not is_inside_tree() or not is_instance_valid(_safe):
		return
	var metrics: SafeAreaMetrics = _safe.current_metrics()
	if metrics != null:
		_content.position = metrics.content_rect().position
		_content.size = metrics.content_rect().size


func _present_participants() -> void:
	var values: Array[BattleParticipantProjection] = _projection.participants()
	var ids: Array[StringName] = []
	for value: BattleParticipantProjection in values:
		ids.append(value.participant_id)
	if ids != _shown_participants:
		_shown_participants = ids
		for card: BattleParticipantCard in _cards:
			_participants.remove_child(card)
			card.queue_free()
		_cards.clear()
		for id: StringName in ids:
			var card := BattleParticipantCard.new()
			card.name = "Participant%d" % _cards.size()
			card.custom_minimum_size.x = 300
			_participants.add_child(card)
			_cards.append(card)
	for index: int in values.size():
		_cards[index].present(values[index], _projection.player_id, _projection.current_target_id)


func _submit_action(id: StringName) -> void:
	if _intent == null:
		return
	var target: StringName = &""
	for info: CombatTacticalActionInfo in _projection.actions():
		if info.action_id == id and info.target_rule == CombatTacticalRequest.TargetRule.SINGLE_HOSTILE:
			target = _projection.current_target_id # Declared displayed intent, not validity/retargeting.
	intent_submitting.emit()
	var result: CombatTacticalResult = _intent.submit(id, target)
	_receipt.text = "Request: " + BattleFeedbackReader.reason(result.code)
	intent_received.emit(result)


func _cancel_action(expected_request_id: StringName) -> void:
	if _intent == null:
		return
	intent_submitting.emit()
	var result: CombatTacticalResult = _intent.cancel(expected_request_id)
	_receipt.text = "Cancel: " + BattleFeedbackReader.reason(result.code)
	intent_received.emit(result)


func _open_log() -> void:
	log_panel.open_log()


func _focus_battle() -> void:
	if not is_inside_tree() or not is_visible_in_tree() or get_tree().paused or log_panel.visible:
		return
	var first: Button = action_panel.first_action_button()
	(first if first != null else log_button).grab_focus()


func _yield_world_hud() -> void:
	var focus: Control = get_viewport().gui_get_focus_owner()
	_saved_focus = weakref(focus) if focus != null else null
	if focus != null:
		focus.release_focus()
	_yielded_hud = _session.active_map().get_node_or_null("HUD") as CanvasLayer
	if _yielded_hud != null:
		_hud_was_visible = _yielded_hud.visible
		_yielded_hud.hide()


func _restore_world_hud() -> void:
	if is_instance_valid(_yielded_hud):
		_yielded_hud.visible = _hud_was_visible
	_yielded_hud = null
	if _saved_focus != null:
		var focus: Control = _saved_focus.get_ref() as Control
		if is_instance_valid(focus) and focus.is_visible_in_tree():
			focus.grab_focus()
	_saved_focus = null
