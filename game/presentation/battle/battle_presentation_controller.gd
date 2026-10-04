class_name BattlePresentationController
extends Control

## Session-owned projection/intent adapter. Never executes or advances combat.
signal intent_submitting
signal intent_received(result: CombatTacticalResult)
signal target_submitting
signal target_received(result: CombatTargetResult)

@export var action_catalog: BattleActionPresentationCatalog
@export var visual_theme: Theme
var _session: OldPineWorldSessionController
var _intent: BattleIntentAdapter
var _reader := BattleFeedbackReader.new()
var _projection := BattlePresentationProjection.new()
var _displayed_id: StringName = &""
var _reported_completion_id: StringName = &""
var _safe: SafeAreaPresenter
var _content: VBoxContainer
var _participants: HBoxContainer
var _cards: Array[BattleParticipantCard] = []
var _shown_participants: Array[StringName] = []
var _title: Label
## kill_ob()'s 看起来X想杀死你！ lines, pinned under the title for the whole fight.
var _warning: Label
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
	_reader.catalog = action_catalog
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
	_present_completed_result()
	_projection = BattleProjectionBuilder.build(_session)
	var changed: bool = _displayed_id != _projection.encounter_id
	if changed:
		_displayed_id = _projection.encounter_id
		log_panel.close_log()
		_receipt.text = ""
		if _projection.active:
			log_panel.clear_entries()
			var warnings: Array[String] = _session.combat_encounter_coordinator().opening_warnings(_projection.encounter_id)
			_warning.text = "\n".join(PackedStringArray(warnings))
			_warning.visible = not warnings.is_empty()
			if _intent == null:
				_intent = BattleIntentAdapter.new(_session.combat_encounter_coordinator(), _projection.player_id)
			_yield_world_hud()
			show()
		else:
			hide()
			_restore_world_hud()
	var entries: Array[BattleFeedbackProjection] = []
	if _session.is_initialized():
		entries = _reader.read_new(_session.combat_encounter_coordinator(), _projection)
	if not _projection.active:
		return
	var heading: String = _mode_name(_projection.mode)
	if not _receipt.text.is_empty():
		heading += " · " + _receipt.text
	_title.text = heading + "\n" + tr("目标：%s") % tr(_projection.display_name(_projection.current_target_id))
	if _projection.completion_outcome >= 0:
		_title.text = "战斗无法正常结束，不会自动重试。"
	_title.tooltip_text = _title.text
	_present_participants()
	action_panel.present(_projection)
	if not entries.is_empty():
		log_panel.append_entries(entries)
		_present_recent(_reader.recent())
	elif changed:
		_present_recent([BattleNarrationLine.new(tr("战斗描写会显示在这里。"))])
	if changed:
		_focus_battle.call_deferred()
	elif not log_panel.visible:
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused == null or not focused.is_visible_in_tree():
			_focus_battle()


func _present_completed_result() -> void:
	if _session == null or not _session.is_initialized():
		return
	var receipt: CombatEncounterCompletionResult = _session.combat_encounter_coordinator().last_completion()
	if receipt == null or receipt.encounter_id == _reported_completion_id:
		return
	var text: String = BattleFeedbackReader.completion_text(receipt, _session.player_runtime().life_status)
	if text.is_empty():
		return
	var hud: SharedGameplayUI = _session.shared_ui()
	if hud == null:
		return

	_reported_completion_id = receipt.encounter_id
	# Parent Session finishes before this child processes. Drain the final suffix
	# using the last display names before replacing the now-inactive projection.
	var feedback_projection: BattlePresentationProjection = _projection
	if feedback_projection.encounter_id != receipt.encounter_id:
		# A large first frame can finish before the first UI refresh: take the
		# player, names and genders from the Session instead.
		feedback_projection = BattleProjectionBuilder.completed_cast(_session, receipt.encounter_id)
		log_panel.clear_entries()
	var entries: Array[BattleFeedbackProjection] = _reader.read_new(_session.combat_encounter_coordinator(), feedback_projection)
	log_panel.append_entries(entries)
	for line: BattleNarrationLine in _reader.recent():
		text += "\n" + line.text
	hud.show_combat_result(text)


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
	log_button.text = "战斗记录"
	log_button.custom_minimum_size = Vector2(144, 64)
	log_button.pressed.connect(_open_log)
	header.add_child(log_button)
	# Reserve shared Shell TouchPause space, including desktop touch-capability QA.
	var pause_space := Control.new()
	pause_space.custom_minimum_size = Vector2(64, 64)
	pause_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(pause_space)
	# The panel covers the log the warning was printed to, and the first round's
	# lines would push it out of the recent strip: it stays here instead.
	_warning = Label.new()
	_warning.name = "KillWarning"
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning.add_theme_color_override("font_color", SharedGameplayUI.ALERT_COLOR)
	_warning.visible = false
	_content.add_child(_warning)
	var participant_scroll := ScrollContainer.new()
	participant_scroll.name = "ParticipantScroll"
	participant_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	participant_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	participant_scroll.follow_focus = true
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
	action_panel.enforce_requested.connect(_enforce)
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
	for index: int in BattleFeedbackReader.RECENT_LINES:
		# One row per line: the words, cut short with an ellipsis, and the damage
		# small and grey at the end of the row.
		var row := HBoxContainer.new()
		_recent.add_child(row)
		var line := Label.new()
		line.name = "Text"
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_theme_font_size_override("font_size", 16)
		line.clip_text = true
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(line)
		var damage := Label.new()
		damage.name = "Damage"
		damage.add_theme_font_size_override("font_size", 12)
		damage.add_theme_color_override("font_color", Color("8b959e"))
		row.add_child(damage)
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
			card.target_requested.connect(_change_target)
			_participants.add_child(card)
			_cards.append(card)
	for index: int in values.size():
		var queued: CombatQueuedAction = _projection.queued_action()
		_cards[index].present(values[index], _projection.player_id, _projection.current_target_id, &"" if queued == null else queued.resolved_target_id)


func _present_recent(lines: Array[BattleNarrationLine]) -> void:
	for index: int in _recent.get_child_count():
		var row: Node = _recent.get_child(index)
		var line: BattleNarrationLine = lines[index] if index < lines.size() else null
		var text: Label = row.get_node("Text")
		text.text = "" if line == null else line.text
		text.tooltip_text = text.text
		if line != null and SharedGameplayUI.ES2_COLORS.has(line.color):
			text.add_theme_color_override("font_color", SharedGameplayUI.ES2_COLORS[line.color])
		else:
			text.remove_theme_color_override("font_color")
		var damage: Label = row.get_node("Damage")
		damage.text = tr("（-%d）") % line.damage if line != null and line.has_damage else ""


func _mode_name(mode: int) -> String:
	match mode:
		CombatEncounterMode.Value.SPAR:
			return tr("切磋")
		CombatEncounterMode.Value.LETHAL:
			return tr("厮杀")
	return tr("战斗")


func _change_target(id: StringName) -> void:
	if _intent == null:
		return
	target_submitting.emit()
	var result: CombatTargetResult = _intent.change_target(_projection.encounter_id, id)
	_receipt.text = tr("换目标：%s") % BattleFeedbackReader.target_reason(result.code)
	target_received.emit(result)


func _submit_action(id: StringName) -> void:
	if _intent == null:
		return
	var target: StringName = &""
	for info: CombatTacticalActionInfo in _projection.actions():
		if info.action_id == id and info.target_rule == CombatTacticalRequest.TargetRule.SINGLE_HOSTILE:
			target = _projection.current_target_id # Declared displayed intent, not validity/retargeting.
	intent_submitting.emit()
	var result: CombatTacticalResult = _intent.submit(id, target)
	_receipt.text = tr("下令：%s") % BattleFeedbackReader.reason(result.code)
	intent_received.emit(result)


## enforce.c in the fight: set now; its lines join the battle log.
func _enforce(points: int) -> void:
	if not _projection.active or _session == null or not _session.is_initialized():
		return
	var lines: Array[BattleNarrationLine] = []
	for line: ColoredLine in _session.martial_arts().enforce(points):
		lines.append(BattleNarrationLine.new(line.text, -1, line.color))
	if lines.is_empty():
		return
	log_panel.append_entries([BattleFeedbackProjection.new(_reader.last_consumed_order, lines)])
	_present_recent(_reader.note(lines))


func _cancel_action(expected_request_id: StringName) -> void:
	if _intent == null:
		return
	intent_submitting.emit()
	var result: CombatTacticalResult = _intent.cancel(expected_request_id)
	_receipt.text = tr("取消：%s") % BattleFeedbackReader.reason(result.code)
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
	_yielded_hud = _session.shared_ui()
	if _yielded_hud != null:
		_hud_was_visible = _yielded_hud.visible
		_yielded_hud.hide()


func _restore_world_hud() -> void:
	if is_instance_valid(_yielded_hud):
		_yielded_hud.visible = _session.can_process() and not _session.is_restore_candidate_staged() and _session.application_gameplay_allows_encounter_advance()
	_yielded_hud = null
	if _saved_focus != null:
		var focus: Control = _saved_focus.get_ref() as Control
		if is_instance_valid(focus) and focus.is_visible_in_tree():
			focus.grab_focus()
	_saved_focus = null
