class_name BattleActionPanel
extends PanelContainer

signal action_requested(action_id: StringName)
signal cancel_requested(expected_request_id: StringName)
## enforce.c: set at once, not queued (it has no busy check).
signal enforce_requested(points: int)
## 战斗决策层 1B: the move chosen for this round, the stance, the 自动 switch.
signal move_requested(action_id: StringName)
signal stance_requested(stance: int)
signal manual_toggled(on: bool)

var catalog: BattleActionPresentationCatalog = BattleActionPresentationCatalog.new()
var _actions: HBoxContainer
var _empty: Label
var _queue: Label
var _cancel: Button
var _shown_ids: Array[StringName] = []
## The actions that cannot run now (CombatTacticalActionInfo.unavailable_reason).
var _unavailable: Dictionary[StringName, String] = {}
var _displayed_request_id: StringName = &""
var enforce_row: HBoxContainer
var enforce_text: Label
var enforce_amount: SpinBox
var enforce_button: Button
var _shown_factor: int = -1
var _shown_encounter: StringName = &""
## 战斗决策层 1B: the move buttons (by action ID), the stance buttons, the 自动 switch.
var moves_heading: Label
var _moves: HBoxContainer
var _shown_move_ids: Array[StringName] = []
var move_buttons: Dictionary[StringName, Button] = {}
var stance_row: HBoxContainer
var stance_buttons: Dictionary[int, Button] = {}
var manual_button: Button
## 快捷操作, hidden while the decision row names the rows itself.
var _heading: Label
## (action_id) -> PackedStringArray: [question, choice] when the action is asked
## first (owner: 天邪虎啸, powerfade), empty otherwise.
var confirm_text: Callable
## The question in place of the action buttons; the fight goes on meanwhile.
var prompt: ConfirmPrompt
var _asking_id: StringName = &""


func _ready() -> void:
	var column := VBoxContainer.new()
	add_child(column)
	# 战斗决策层 1B: one row for the round's choice — the moves, the stances, the 自动 switch —
	# across the whole panel, scrolling sideways where it does not fit (包 2 lays the panel out anew).
	var decision_scroll := ScrollContainer.new()
	decision_scroll.name = "DecisionRow"
	decision_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	decision_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	decision_scroll.custom_minimum_size.y = 40
	decision_scroll.follow_focus = true
	column.add_child(decision_scroll)
	stance_row = HBoxContainer.new()
	stance_row.name = "Decisions"
	stance_row.add_theme_constant_override("separation", 8)
	stance_row.visible = false
	decision_scroll.add_child(stance_row)
	var content := HBoxContainer.new()
	column.add_child(content)
	var action_column := VBoxContainer.new()
	action_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(action_column)
	moves_heading = Label.new()
	moves_heading.name = "MovesHeading"
	moves_heading.text = tr("出招")
	moves_heading.visible = false
	stance_row.add_child(moves_heading)
	_moves = HBoxContainer.new()
	_moves.name = "Moves"
	_moves.add_theme_constant_override("separation", 8)
	_moves.visible = false
	stance_row.add_child(_moves)
	var stance_text := Label.new()
	stance_text.name = "StanceHeading"
	stance_text.text = tr("姿态")
	stance_row.add_child(stance_text)
	for value: int in [CombatStance.Value.ATTACK, CombatStance.Value.GUARD, CombatStance.Value.EVADE]:
		var button := Button.new()
		button.name = "Stance%s" % CombatStance.STORAGE[value].capitalize()
		button.text = CombatStance.label(value)
		button.tooltip_text = CombatStance.description(value)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(56, 40)
		button.pressed.connect(_stance_pressed.bind(value))
		stance_row.add_child(button)
		stance_buttons[value] = button
	manual_button = Button.new()
	manual_button.name = "ManualTurns"
	manual_button.custom_minimum_size = Vector2(96, 40)
	manual_button.visible = false
	manual_button.pressed.connect(_manual_pressed)
	stance_row.add_child(manual_button)
	_heading = Label.new()
	_heading.text = "快捷操作"
	action_column.add_child(_heading)
	_empty = Label.new()
	_empty.text = "现在没有可用的操作。"
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_column.add_child(_empty)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	action_column.add_child(_actions)
	prompt = ConfirmPrompt.new()
	prompt.name = "ActionQuestion"
	# In a fight Esc is the pause: B / Backspace answer 取消.
	prompt.cancel_action = &"battle_back"
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
	var queue_column := HBoxContainer.new()
	queue_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_column.add_theme_constant_override("separation", 8)
	content.add_child(queue_column)
	_queue = Label.new()
	_queue.clip_text = true
	_queue.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_queue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_queue.add_theme_font_size_override("font_size", 16)
	queue_column.add_child(_queue)
	_cancel = Button.new()
	_cancel.name = "CancelQueue"
	_cancel.text = "取消已排定的操作"
	_cancel.custom_minimum_size = Vector2(64, 52)
	_cancel.pressed.connect(_cancel_pressed)
	queue_column.add_child(_cancel)
	InputGlyphs.decorate(_cancel, &"battle_back")


func present(projection: BattlePresentationProjection) -> void:
	var infos: Array[CombatTacticalActionInfo] = projection.actions()
	var ids: Array[StringName] = []
	for info: CombatTacticalActionInfo in infos:
		ids.append(info.action_id)
	_present_enforce(projection)
	_present_moves(projection)
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
	# Every refresh (an action can become unavailable without the list changing): an
	# action that cannot run now is greyed with why; the others say what they do.
	_unavailable.clear()
	for index: int in mini(infos.size(), _actions.get_child_count()):
		var shown: Button = _actions.get_child(index) as Button
		var reason: String = infos[index].unavailable_reason
		if not reason.is_empty():
			_unavailable[infos[index].action_id] = reason
		shown.disabled = not reason.is_empty()
		shown.tooltip_text = reason if not reason.is_empty() else catalog.tooltip_for(infos[index].action_id)
	var queued: CombatQueuedAction = projection.queued_action()
	_displayed_request_id = &"" if queued == null else queued.request.request_id
	_queue.text = tr("排定：%s") % _queue_status(projection.queue_status)
	if projection.waiting:
		# TRANSLATORS: the battle panel's status while the fight's clock waits for the player's order (on 排定's line).
		_queue.text = tr("等你出招 · ") + _queue.text
	if queued != null:
		_queue.text += "\n" + tr("{action} · 目标：{target}").format({"action": catalog.label_for(queued.request.action_id), "target": tr(projection.display_name(queued.resolved_target_id))})
	_queue.tooltip_text = _queue.text
	_cancel.visible = queued != null
	_wire_focus()


## DECISIONS「战斗界面」: the hover of a move button — the move's own ES2 line as the player
## would read it ($N 你, $n 对手, $l 要害, $w 兵刃), then what its tag does.
static func move_tooltip(move: CombatActionDefinition) -> String:
	var tag: String = CombatMoveTags.description(move.tag)
	if move.legacy_action_text.is_empty():
		return tag
	# TRANSLATORS: the words standing for the one hit, the limb and the weapon in a move's hover line (no one is hit yet).
	var line: String = (TranslationServer.translate("{action}！").format({"action": TranslationServer.translate(move.legacy_action_text)})
		.replace("$N", TranslationServer.translate("你")).replace("$P", TranslationServer.translate("你"))
		.replace("$n", TranslationServer.translate("对手")).replace("$p", TranslationServer.translate("对手"))
		.replace("$l", TranslationServer.translate("要害")).replace("$w", TranslationServer.translate("兵刃")))
	return "%s\n%s" % [line, tag]


## The keys and the pad walk the two rows (DECISIONS「战斗界面」): left and right along the
## decision row (the moves, the stances, the 自动 switch), down from any of them to the first
## quick action, up from a quick action to the chosen move (or the first).
func _wire_focus() -> void:
	var row: Array[Button] = []
	if _moves.visible:
		for id: StringName in _shown_move_ids:
			if move_buttons.has(id):
				row.append(move_buttons[id])
	for value: int in [CombatStance.Value.ATTACK, CombatStance.Value.GUARD, CombatStance.Value.EVADE]:
		if stance_row.visible and stance_buttons[value].visible:
			row.append(stance_buttons[value])
	if stance_row.visible and manual_button.visible:
		row.append(manual_button)
	var below: Button = first_action_button() if _actions.visible else null
	for index: int in row.size():
		var button: Button = row[index]
		button.focus_neighbor_left = button.get_path_to(row[index - 1]) if index > 0 else NodePath()
		button.focus_neighbor_right = button.get_path_to(row[index + 1]) if index + 1 < row.size() else NodePath()
		button.focus_neighbor_bottom = button.get_path_to(below) if below != null else NodePath()
	var above: Button = first_move_button()
	if above == null and not row.is_empty():
		above = row[0]
	for child: Node in _actions.get_children():
		var button: Button = child as Button
		if button != null:
			button.focus_neighbor_top = button.get_path_to(above) if above != null else NodePath()


## The move the player chose for this round, else the first move; null without moves.
func first_move_button() -> Button:
	if not _moves.visible or _shown_move_ids.is_empty():
		return null
	for id: StringName in _shown_move_ids:
		if move_buttons.has(id) and move_buttons[id].button_pressed:
			return move_buttons[id]
	return move_buttons.get(_shown_move_ids[0])


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


## 战斗决策层 1B: the move buttons (name and tag; the chosen one pressed; all greyed while
## the round plays or the clock rolls on 自动), the stances (in place of 加力 when offered)
## and the 自动 switch.
func _present_moves(projection: BattlePresentationProjection) -> void:
	var ids: Array[StringName] = []
	for move: CombatActionDefinition in projection.moves:
		ids.append(move.action_id)
	var offered: bool = projection.turns_offered and not ids.is_empty()
	moves_heading.visible = offered and not is_asking()
	_moves.visible = offered and not is_asking()
	if ids != _shown_move_ids:
		_shown_move_ids = ids
		move_buttons.clear()
		for child: Node in _moves.get_children():
			_moves.remove_child(child)
			child.queue_free()
		for move: CombatActionDefinition in projection.moves:
			var button := Button.new()
			button.name = "Move%d" % _moves.get_child_count()
			var shown_name: String = move.display_name if not move.display_name.is_empty() else String(move.action_id).get_slice("/", String(move.action_id).get_slice_count("/") - 1)
			# TRANSLATORS: a move button: {name} the move, {tag} its one-character tag (快 / 重 / 虚 / 守 / 平).
			button.text = tr("{name} · {tag}").format({"name": tr(shown_name), "tag": CombatMoveTags.label(move.tag)})
			button.tooltip_text = move_tooltip(move)
			button.toggle_mode = true
			button.custom_minimum_size = Vector2(64, 40)
			button.pressed.connect(_move_pressed.bind(move.action_id))
			_moves.add_child(button)
			move_buttons[move.action_id] = button
	for id: StringName in move_buttons:
		var button: Button = move_buttons[id]
		button.set_pressed_no_signal(id == projection.chosen_action_id)
		button.disabled = not (projection.waiting and projection.manual)
	stance_row.visible = (projection.stances_offered or projection.turns_offered) and not is_asking()
	_heading.visible = not stance_row.visible
	(stance_row.get_node("StanceHeading") as Label).visible = projection.stances_offered
	for value: int in stance_buttons:
		stance_buttons[value].visible = projection.stances_offered
		stance_buttons[value].set_pressed_no_signal(value == projection.stance)
	if projection.stances_offered:
		enforce_row.visible = false
	manual_button.visible = projection.turns_offered
	# TRANSLATORS: the battle panel's switch between the player's turns and ES2's auto-fight: the text names what pressing it does.
	manual_button.text = tr("改为自动") if projection.manual else tr("改为手动")
	manual_button.tooltip_text = tr("现在：每回合等你出招；按下后战斗自己打，招式随机。") if projection.manual else tr("现在：战斗自己打；按下后每回合等你出招。")


func _move_pressed(action_id: StringName) -> void:
	move_requested.emit(action_id)


func _stance_pressed(value: int) -> void:
	stance_requested.emit(value)


func _manual_pressed() -> void:
	manual_toggled.emit(manual_button.text == tr("改为手动"))


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
	if _unavailable.has(id):
		return # Greyed: it cannot run now (its hover says why).
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


## Drops the planned action, when there is one (the battle's back key).
func cancel_planned() -> void:
	if _cancel.visible:
		_cancel_pressed()
