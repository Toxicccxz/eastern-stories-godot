class_name BattleActionPanel
extends PanelContainer

## 战斗拍数 B (DECISIONS「战斗拍数」, 纪要 §九): the fight's panel at 1280×720 — the stances in
## a column on the left (changed seldom); the moves in one row, laid under their intent
## groups (封山剑法 引 / 守 / 逐) by a coloured ridge and a wider gap, the group's word small
## on its first button, each button the move's name over 「标签 · 拍价」 written against the
## target's next move (「快 · 克他这招」); a move the school locks or the beats cannot pay is
## dimmed with why (够不着, 拍不够) — the buttons never reorder, only light and dim. The
## second row: the beat chips, then the orders (绝招, 运功, 物品, 逃) and 收势; the third: what
## waits, what this round spent (「这一回合已出：快→虚」), the planned order, 改为自动 small on
## the right. ES2's one-beat round (经典) shows no chips, no costs and no 收势. The panel never
## locks input to a show: the buttons answer whenever the rule says the player may act.

signal action_requested(action_id: StringName)
signal cancel_requested(expected_request_id: StringName)
## enforce.c: set at once, not queued (it has no busy check).
signal enforce_requested(points: int)
## 战斗决策层 1B: the move chosen for this beat, the stance, the 自动 switch.
signal move_requested(action_id: StringName)
signal stance_requested(stance: int)
signal manual_toggled(on: bool)
## 战斗拍数 B: 收势, the beats left this round given up.
signal yield_requested

var catalog: BattleActionPresentationCatalog = BattleActionPresentationCatalog.new()
## The order buttons (by action ID), in the row's order; the suites walk `_actions`.
var _actions: HBoxContainer
var action_buttons: Dictionary[StringName, Button] = {}
var _shown_ids: Array[StringName] = []
## The actions that cannot run now (CombatTacticalActionInfo.unavailable_reason).
var _unavailable: Dictionary[StringName, String] = {}
var _displayed_request_id: StringName = &""
var _empty: Label
## The third row's words: 等你出招, 这一回合已出, 排定.
var _queue: Label
var _cancel: Button
var enforce_row: HBoxContainer
var enforce_text: Label
var enforce_amount: SpinBox
var enforce_button: Button
var _shown_factor: int = -1
var _shown_encounter: StringName = &""
## The move buttons (by action ID) with their lines, the stance column, the switches.
var _moves: HBoxContainer
var _shown_move_ids: Array[StringName] = []
var _shown_groups: Array[String] = []
var move_buttons: Dictionary[StringName, Button] = {}
var _move_titles: Dictionary[StringName, Label] = {}
var _move_subs: Dictionary[StringName, Label] = {}
var _move_ridges: Dictionary[StringName, ColorRect] = {}
var _move_group_words: Dictionary[StringName, Label] = {}
var stance_column: VBoxContainer
var stance_buttons: Dictionary[int, Button] = {}
var manual_button: Button
var yield_button: Button
var chips: BattleBeatChips
## The rows that dim while the round plays (DECISIONS「战斗演出」; the buttons' own disabled
## state is the rule's) and are bright while the fight waits for the player.
var decision_area: VBoxContainer
const PLAYING_DIM: float = 0.55
var _bounce: Tween
## (action_id) -> PackedStringArray: [question, choice] when the action is asked
## first (owner: 天邪虎啸, powerfade), empty otherwise.
var confirm_text: Callable
## The question in place of the action buttons; the fight goes on meanwhile.
var prompt: ConfirmPrompt
var _asking_id: StringName = &""
var _rows: HBoxContainer
var _orders: HBoxContainer
var _status_row: HBoxContainer
## On a short screen (ApplicationShellLayout.SHORT_HEIGHT) the panel closes up: lower
## buttons and the third row's words and switches on the orders' row.
var _compact: bool = false

## 像素界面: the move button (132×56: two lines of the pixel face), an order's (48 high);
## on a short screen 42 and 36.
const MOVE_SIZE := Vector2(132, 56)
const ACTION_SIZE := Vector2(64, 48)
const COMPACT_MOVE_HEIGHT: float = 42.0
const COMPACT_ACTION_HEIGHT: float = 36.0
const COMPACT_STANCE_HEIGHT: float = 28.0
const STANCE_SIZE := Vector2(64, 40)
const GROUP_GAP: int = 14
const RIDGE_WIDTH: float = 4.0
const SMALL_SIZE: int = 12
const SUB_COLOR := Color("b8a689")
const COUNTER_COLOR := Color("f2d27a")
const COUNTERED_COLOR := Color("d98a7a")
## The ridge's colour by the group's word; a word not here takes the next of the rest.
const GROUP_COLORS: Dictionary[String, Color] = {
	"引": Color("4f8f78"), "守": Color("6f7a80"), "逐": Color("a3301f"),
	"逼": Color("4f8fb8"), "压": Color("a3301f"),
}
const SPARE_GROUP_COLORS: Array[Color] = [Color("7a6034"), Color("8f4a22"), Color("4f8fb8")]


func _ready() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	_rows = HBoxContainer.new()
	_rows.name = "Body"
	_rows.add_theme_constant_override("separation", 8)
	column.add_child(_rows)
	stance_column = VBoxContainer.new()
	stance_column.name = "Stances"
	stance_column.add_theme_constant_override("separation", 4)
	stance_column.visible = false
	_rows.add_child(stance_column)
	for value: int in [CombatStance.Value.ATTACK, CombatStance.Value.GUARD, CombatStance.Value.EVADE]:
		var button := Button.new()
		button.name = "Stance%s" % CombatStance.STORAGE[value].capitalize()
		button.text = CombatStance.label(value)
		button.tooltip_text = CombatStance.description(value)
		button.toggle_mode = true
		# 界面重做 4: the stance held is lacquer.
		button.theme_type_variation = &"ToggleButton"
		button.custom_minimum_size = STANCE_SIZE
		button.pressed.connect(_stance_pressed.bind(value))
		stance_column.add_child(button)
		stance_buttons[value] = button
	decision_area = VBoxContainer.new()
	decision_area.name = "Decisions"
	decision_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decision_area.add_theme_constant_override("separation", 4)
	_rows.add_child(decision_area)
	var moves_scroll := ScrollContainer.new()
	moves_scroll.name = "MoveRow"
	moves_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	moves_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	moves_scroll.custom_minimum_size.y = MOVE_SIZE.y
	moves_scroll.follow_focus = true
	moves_scroll.visible = false
	decision_area.add_child(moves_scroll)
	_moves = HBoxContainer.new()
	_moves.name = "Moves"
	_moves.add_theme_constant_override("separation", 8)
	moves_scroll.add_child(_moves)
	var orders_scroll := ScrollContainer.new()
	orders_scroll.name = "OrderRow"
	orders_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	orders_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	orders_scroll.custom_minimum_size.y = ACTION_SIZE.y
	orders_scroll.follow_focus = true
	decision_area.add_child(orders_scroll)
	var orders := HBoxContainer.new()
	orders.name = "Orders"
	orders.add_theme_constant_override("separation", 8)
	orders_scroll.add_child(orders)
	_orders = orders
	chips = BattleBeatChips.new()
	chips.name = "BeatChips"
	chips.visible = false
	orders.add_child(chips)
	_actions = HBoxContainer.new()
	_actions.name = "Actions"
	_actions.add_theme_constant_override("separation", 8)
	orders.add_child(_actions)
	yield_button = Button.new()
	yield_button.name = "YieldRound"
	# TRANSLATORS: the battle panel's button that gives up the beats left this round (the enemies act, the next round waits for you).
	yield_button.text = tr("收势")
	# TRANSLATORS: hover of 收势.
	yield_button.tooltip_text = tr("放弃这一回合剩下的拍，让对手出招；赢来的拍照样归你。")
	yield_button.theme_type_variation = &"ChipButton"
	yield_button.custom_minimum_size = ACTION_SIZE
	yield_button.visible = false
	yield_button.pressed.connect(func() -> void: yield_requested.emit())
	orders.add_child(yield_button)
	var status_row := HBoxContainer.new()
	status_row.name = "StatusRow"
	status_row.add_theme_constant_override("separation", 8)
	decision_area.add_child(status_row)
	_status_row = status_row
	_queue = Label.new()
	_queue.name = "Status"
	_queue.clip_text = true
	_queue.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_queue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_queue.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_queue.add_theme_font_size_override("font_size", GameTheme.text_size(16))
	status_row.add_child(_queue)
	_cancel = Button.new()
	_cancel.name = "CancelQueue"
	_cancel.text = "取消已排定的操作"
	_cancel.theme_type_variation = &"ChipButton"
	_cancel.custom_minimum_size = Vector2(64, 36)
	_cancel.pressed.connect(_cancel_pressed)
	status_row.add_child(_cancel)
	InputGlyphs.decorate(_cancel, &"battle_back")
	enforce_row = HBoxContainer.new()
	enforce_row.name = "Enforce"
	enforce_row.add_theme_constant_override("separation", 8)
	status_row.add_child(enforce_row)
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
	enforce_button.custom_minimum_size = Vector2(64, 36)
	enforce_button.pressed.connect(_enforce_pressed)
	enforce_row.add_child(enforce_button)
	manual_button = Button.new()
	manual_button.name = "ManualTurns"
	manual_button.theme_type_variation = &"ChipButton"
	manual_button.custom_minimum_size = Vector2(96, 36)
	manual_button.visible = false
	manual_button.pressed.connect(_manual_pressed)
	status_row.add_child(manual_button)
	_empty = Label.new()
	_empty.text = "现在没有可用的操作。"
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_empty)
	prompt = ConfirmPrompt.new()
	prompt.name = "ActionQuestion"
	# In a fight Esc is the pause: B / Backspace answer 取消.
	prompt.cancel_action = &"battle_back"
	prompt.hide()
	prompt.confirmed.connect(_on_prompt_answered.bind(true))
	prompt.cancelled.connect(_on_prompt_answered.bind(false))
	column.add_child(prompt)


## A short screen: the panel closes up (the rows lower, the third row's words and switches
## moved onto the orders' row); back to the full layout with false.
func set_compact(on: bool) -> void:
	if on == _compact:
		return
	_compact = on
	var move_height: float = COMPACT_MOVE_HEIGHT if on else MOVE_SIZE.y
	var action_height: float = COMPACT_ACTION_HEIGHT if on else ACTION_SIZE.y
	(_moves.get_parent() as Control).custom_minimum_size.y = move_height
	(_orders.get_parent() as Control).custom_minimum_size.y = action_height
	# The rows' scrollbars take 8 units each: closed up they scroll without one (the wheel,
	# the focus); the chips lose their source word's line.
	for scroll: ScrollContainer in [_moves.get_parent() as ScrollContainer, _orders.get_parent() as ScrollContainer]:
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if on else ScrollContainer.SCROLL_MODE_AUTO
	chips.set_compact(on)
	decision_area.add_theme_constant_override("separation", 2 if on else 4)
	# The stance column is the panel's tallest piece (three buttons of the face's height):
	# closed up the three stand at the head of the orders' row instead.
	var stance_from: Node = stance_column if on else _orders
	var stance_to: Node = _orders if on else stance_column
	var at: int = 0
	for value: int in [CombatStance.Value.ATTACK, CombatStance.Value.GUARD, CombatStance.Value.EVADE]:
		var button: Button = stance_buttons[value]
		button.custom_minimum_size.y = COMPACT_STANCE_HEIGHT if on else STANCE_SIZE.y
		if button.get_parent() == stance_from:
			stance_from.remove_child(button)
			stance_to.add_child(button)
			stance_to.move_child(button, at)
		at += 1
	for id: StringName in move_buttons:
		move_buttons[id].custom_minimum_size.y = move_height
	for child: Node in _actions.get_children():
		if child is Button:
			(child as Button).custom_minimum_size.y = action_height
	yield_button.custom_minimum_size.y = action_height
	var from: Node = _status_row if on else _orders
	var to: Node = _orders if on else _status_row
	for node: Node in [_queue, _cancel, enforce_row, manual_button]:
		if node.get_parent() == from:
			from.remove_child(node)
			to.add_child(node)
	_queue.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if on else Control.SIZE_EXPAND_FILL
	_status_row.visible = not on


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
	var shown: bool = projection.beats_shown()
	_empty.visible = ids.is_empty() and not enforce_row.visible and not is_asking()
	_actions.visible = not ids.is_empty() and not is_asking()
	if ids != _shown_ids:
		_shown_ids = ids
		action_buttons.clear()
		for child: Node in _actions.get_children():
			_actions.remove_child(child)
			child.queue_free()
		for id: StringName in ids:
			var button := Button.new()
			button.name = "Action%d" % _actions.get_child_count()
			button.text = catalog.label_for(id)
			button.custom_minimum_size = Vector2(ACTION_SIZE.x, COMPACT_ACTION_HEIGHT if _compact else ACTION_SIZE.y)
			button.pressed.connect(_action_pressed.bind(id))
			# 投降 reads small (纪要 §九): a chip at the row's end.
			if id == CombatSurrenderTacticalPolicy.ACTION_ID:
				button.theme_type_variation = &"ChipButton"
			var cost := Label.new()
			cost.name = "Cost"
			cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cost.add_theme_font_size_override("font_size", SMALL_SIZE)
			cost.add_theme_color_override("font_color", SUB_COLOR)
			cost.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			cost.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			cost.grow_vertical = Control.GROW_DIRECTION_BEGIN
			cost.position = Vector2(-4, -2)
			button.add_child(cost)
			_actions.add_child(button)
			action_buttons[id] = button
	# Every refresh (an action can become unavailable without the list changing): an
	# action that cannot run now is greyed with why; the others say what they do and cost.
	_unavailable.clear()
	for index: int in mini(infos.size(), _actions.get_child_count()):
		var button: Button = _actions.get_child(index) as Button
		var info: CombatTacticalActionInfo = infos[index]
		var reason: String = info.unavailable_reason
		if not reason.is_empty():
			_unavailable[info.action_id] = reason
		button.disabled = not reason.is_empty()
		button.tooltip_text = reason if not reason.is_empty() else catalog.tooltip_for(info.action_id)
		var cost: int = projection.action_costs.get(info.action_id, 0)
		var label: Label = button.get_node("Cost") as Label
		# TRANSLATORS: the small corner of an order button: its price in beats.
		label.text = tr("%d拍") % cost if shown and cost > 0 else ""
		label.reset_size()
		label.position = Vector2(-label.size.x - 4, -label.size.y - 2)
	var queued: CombatQueuedAction = projection.queued_action()
	_displayed_request_id = &"" if queued == null else queued.request.request_id
	# 战斗拍数 B: the chips (the round running, or the one to come) and 收势.
	chips.visible = shown and projection.turns_offered
	if chips.visible:
		chips.present(projection.player_beats, projection.beat_rules, GameContent.catalog().pacing().feel.beat_chip_seconds)
	yield_button.visible = shown and projection.turns_offered and not is_asking()
	yield_button.disabled = not (projection.waiting and projection.manual)
	_queue.text = _status_text(projection, shown)
	if queued != null:
		_queue.text += "\n" + tr("{action} · 目标：{target}").format({"action": catalog.label_for(queued.request.action_id), "target": tr(projection.display_name(queued.resolved_target_id))})
	_cancel.visible = queued != null
	_wire_focus()


## The third row: 等你出招, what this round spent (or the last), the planned order.
func _status_text(projection: BattlePresentationProjection, shown: bool) -> String:
	# Nothing planned, nothing said (DECISIONS「数值用到才出现」: 「排定：无」 is gone).
	var parts := PackedStringArray()
	if projection.waiting:
		# TRANSLATORS: the battle panel's status while the fight's clock waits for the player's order.
		parts.append(tr("等你出招"))
	if shown and projection.turns_offered:
		var beats: CombatRoundBeats = projection.player_beats if projection.round_running else projection.last_round_beats
		var sequence: String = "" if beats == null else spent_text(beats)
		if not sequence.is_empty():
			# TRANSLATORS: the battle panel: what the player's beats went on this round, in order ({moves}: 快→虚).
			parts.append(tr("这一回合已出：{moves}").format({"moves": sequence}) if projection.round_running else tr("上一回合：{moves}").format({"moves": sequence}))
	if projection.queue_status != CombatQueuedAction.Status.EMPTY:
		parts.append(tr("排定：%s") % _queue_status(projection.queue_status))
	return " · ".join(parts)


## 快→虚→封: what each spent beat went on, in order (busy and waits as 忙 / 停).
static func spent_text(beats: CombatRoundBeats) -> String:
	var words := PackedStringArray()
	for key: StringName in beats.spent:
		words.append(spent_word(key))
	return "→".join(words)


static func spent_word(key: StringName) -> String:
	match key:
		CombatEncounterScheduler.SPENT_BUSY:
			return TranslationServer.translate("忙")
		CombatEncounterScheduler.SPENT_WAIT:
			return TranslationServer.translate("停")
	var function_id: StringName = CombatBeatRules.perform_of(key)
	if not function_id.is_empty():
		var perform: PerformFunction = SpecialFunctions.perform(function_id)
		return TranslationServer.translate("绝招") if perform == null else TranslationServer.translate(perform.label)
	if BattleBeatChips.GLYPHS.has(key):
		return TranslationServer.translate(BattleBeatChips.GLYPHS[key])
	return CombatMoveTags.label(CombatMoveTags.NONE if key == CombatBeatRules.COST_PLAIN else key)


static func _move_of(projection: BattlePresentationProjection, id: StringName) -> CombatActionDefinition:
	for move: CombatActionDefinition in projection.moves:
		if move.action_id == id:
			return move
	return null


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


## The keys and the pad walk the rows (DECISIONS「战斗界面」): left and right along the move
## row, down to the orders (the first, else 收势) and on down to 改为自动, up again to the
## chosen move; the stances stand in a column on the left of the first move, up and down
## among themselves.
func _wire_focus() -> void:
	var row: Array[Button] = []
	if _moves.get_parent().visible:
		# In the row's own order (the groups'), not the set's (Codex on #254).
		for id: StringName in move_order():
			row.append(move_buttons[id])
	var orders: Array[Button] = []
	if _actions.visible:
		for child: Node in _actions.get_children():
			if child is Button:
				orders.append(child)
	if yield_button.visible:
		orders.append(yield_button)
	var stances: Array[Button] = []
	for value: int in [CombatStance.Value.ATTACK, CombatStance.Value.GUARD, CombatStance.Value.EVADE]:
		if stance_buttons[value].visible:
			stances.append(stance_buttons[value])
	if _compact:
		# Closed up the stances head the orders' row: along it with the rest.
		orders = stances + orders
		stances = []
	var below: Button = orders[0] if not orders.is_empty() else (manual_button if manual_button.visible else null)
	var above: Button = first_move_button()
	if above == null and not row.is_empty():
		above = row[0]
	for index: int in row.size():
		var button: Button = row[index]
		button.focus_neighbor_left = button.get_path_to(row[index - 1]) if index > 0 else (button.get_path_to(stances[0]) if not stances.is_empty() else NodePath())
		button.focus_neighbor_right = button.get_path_to(row[index + 1]) if index + 1 < row.size() else NodePath()
		button.focus_neighbor_bottom = button.get_path_to(below) if below != null else NodePath()
		button.focus_neighbor_top = NodePath()
	for index: int in orders.size():
		var button: Button = orders[index]
		button.focus_neighbor_left = button.get_path_to(orders[index - 1]) if index > 0 else (button.get_path_to(stances[0]) if not stances.is_empty() else NodePath())
		button.focus_neighbor_right = button.get_path_to(orders[index + 1]) if index + 1 < orders.size() else NodePath()
		button.focus_neighbor_top = button.get_path_to(above) if above != null else NodePath()
		button.focus_neighbor_bottom = button.get_path_to(manual_button) if manual_button.visible else NodePath()
	if manual_button.visible:
		manual_button.focus_neighbor_top = manual_button.get_path_to(orders[0]) if not orders.is_empty() else (manual_button.get_path_to(above) if above != null else NodePath())
		manual_button.focus_neighbor_bottom = NodePath()
		manual_button.focus_neighbor_left = manual_button.get_path_to(stances[0]) if not stances.is_empty() else NodePath()
	for index: int in stances.size():
		var button: Button = stances[index]
		button.focus_neighbor_top = button.get_path_to(stances[index - 1]) if index > 0 else NodePath()
		button.focus_neighbor_bottom = button.get_path_to(stances[index + 1]) if index + 1 < stances.size() else NodePath()
		button.focus_neighbor_left = NodePath()
		button.focus_neighbor_right = button.get_path_to(row[0]) if not row.is_empty() else (button.get_path_to(below) if below != null else NodePath())


## The move the player chose for this beat, else the first move; null without moves.
## The chosen (or first) move bounces over `seconds` when the fight comes back to waiting
## (0: nothing).
func bounce_chosen(seconds: float) -> void:
	var button: Button = first_move_button()
	if button == null or seconds <= 0.0:
		return
	if _bounce != null and _bounce.is_valid():
		_bounce.kill()
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2.ONE
	_bounce = create_tween()
	_bounce.tween_property(button, "scale", Vector2.ONE * 1.08, seconds * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_bounce.tween_property(button, "scale", Vector2.ONE, seconds * 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)


func first_move_button() -> Button:
	if not _moves.get_parent().visible or _shown_move_ids.is_empty():
		return null
	for id: StringName in _shown_move_ids:
		if move_buttons.has(id) and move_buttons[id].button_pressed:
			return move_buttons[id]
	# The first of the row the player may press now, else the row's first.
	var order: Array[StringName] = move_order()
	for id: StringName in order:
		if not move_buttons[id].disabled:
			return move_buttons[id]
	return move_buttons.get(order[0]) if not order.is_empty() else null


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


## 战斗决策层 1B / 战斗拍数 B: the move buttons (the name over the tag and the price, written
## against the target's next move; the chosen one pressed; all greyed while the round plays
## or the clock rolls on 自动; a locked or unaffordable one dimmed with why), the stances
## (in place of 加力 when offered) and the 自动 switch.
func _present_moves(projection: BattlePresentationProjection) -> void:
	var ids: Array[StringName] = []
	for move: CombatActionDefinition in projection.moves:
		ids.append(move.action_id)
	var offered: bool = projection.turns_offered and not ids.is_empty()
	_moves.get_parent().visible = offered and not is_asking()
	if ids != _shown_move_ids or projection.move_groups != _shown_groups:
		_shown_move_ids = ids
		_shown_groups = projection.move_groups.duplicate()
		move_buttons.clear()
		_move_titles.clear()
		_move_subs.clear()
		_move_ridges.clear()
		_move_group_words.clear()
		for child: Node in _moves.get_children():
			_moves.remove_child(child)
			child.queue_free()
		var last_group: String = ""
		var spare: int = 0
		var colors: Dictionary[String, Color] = {}
		for move: CombatActionDefinition in _grouped(projection.moves, projection.move_groups):
			if not move.group.is_empty() and not colors.has(move.group):
				colors[move.group] = GROUP_COLORS.get(move.group, SPARE_GROUP_COLORS[spare % SPARE_GROUP_COLORS.size()])
				if not GROUP_COLORS.has(move.group):
					spare += 1
			var first_of_group: bool = move.group != last_group
			if first_of_group and _moves.get_child_count() > 0:
				var gap := Control.new()
				gap.name = "Gap%d" % _moves.get_child_count()
				gap.custom_minimum_size.x = GROUP_GAP - 8
				gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_moves.add_child(gap)
			_moves.add_child(_move_button(move, colors.get(move.group, Color.TRANSPARENT), first_of_group))
			last_group = move.group
	for id: StringName in move_buttons:
		var button: Button = move_buttons[id]
		var chosen: bool = id == projection.chosen_action_id
		button.set_pressed_no_signal(chosen)
		# 战斗拍数 A / B: a move the player's school locks now (够不着) or the beats cannot pay
		# (拍不够) is dimmed with why; the buttons never reorder.
		var reason: String = projection.locked_moves.get(id, "")
		if reason.is_empty():
			reason = projection.unaffordable_moves.get(id, "")
		button.disabled = not (projection.waiting and projection.manual) or not reason.is_empty()
		var move: CombatActionDefinition = _move_of(projection, id)
		button.tooltip_text = reason if not reason.is_empty() else (move_tooltip(move) if move != null else "")
		_show_lines(id, move, projection, reason)
		_show_chosen(button, chosen)
	# The rows dim while the round plays and light when the fight waits for the player
	# (a show, not a lock: the buttons' own disabled state is the rule's).
	var dim: bool = projection.turns_offered and projection.manual and not projection.waiting
	decision_area.modulate = Color(PLAYING_DIM, PLAYING_DIM, PLAYING_DIM) if dim else Color.WHITE
	var stances_shown: bool = projection.stances_offered and not is_asking()
	stance_column.visible = stances_shown and not _compact
	for value: int in stance_buttons:
		stance_buttons[value].visible = stances_shown
		stance_buttons[value].set_pressed_no_signal(value == projection.stance)
	if projection.stances_offered:
		enforce_row.visible = false
	manual_button.visible = projection.turns_offered
	# TRANSLATORS: the battle panel's switch between the player's turns and ES2's auto-fight: the text names what pressing it does.
	manual_button.text = tr("改为自动") if projection.manual else tr("改为手动")
	manual_button.tooltip_text = tr("现在：每一拍等你出招；按下后战斗自己打，拍自动补满、演出加快。") if projection.manual else tr("现在：战斗自己打；按下后每一拍等你出招。")


## The moves in their groups' order (the school's `groups`, then as they appear), each
## group's moves in the set's own order; moves without a group last. The order is fixed for
## the fight: it never answers the fight's state.
static func _grouped(moves: Array[CombatActionDefinition], groups: Array[String]) -> Array[CombatActionDefinition]:
	var order: Array[String] = groups.duplicate()
	for move: CombatActionDefinition in moves:
		if not move.group.is_empty() and not order.has(move.group):
			order.append(move.group)
	var result: Array[CombatActionDefinition] = []
	for group: String in order:
		for move: CombatActionDefinition in moves:
			if move.group == group:
				result.append(move)
	for move: CombatActionDefinition in moves:
		if move.group.is_empty():
			result.append(move)
	return result


## One move button: the ridge in its group's colour, the group's word small on the group's
## first, the name over the sub line.
func _move_button(move: CombatActionDefinition, ridge_color: Color, first_of_group: bool) -> Button:
	var button := Button.new()
	button.name = "Move%d" % _moves.get_child_count()
	button.toggle_mode = true
	# 界面重做 4: the move chosen for the beat is lacquer.
	button.theme_type_variation = &"ToggleButton"
	button.custom_minimum_size = Vector2(MOVE_SIZE.x, COMPACT_MOVE_HEIGHT if _compact else MOVE_SIZE.y)
	button.pressed.connect(_move_pressed.bind(move.action_id))
	var lines := VBoxContainer.new()
	lines.name = "Lines"
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override("separation", 0)
	lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lines.offset_left = RIDGE_WIDTH + 6
	lines.offset_right = -6
	lines.offset_top = 3
	lines.offset_bottom = -5
	button.add_child(lines)
	var title := Label.new()
	title.name = "Title"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var shown_name: String = move.display_name if not move.display_name.is_empty() else String(move.action_id).get_slice("/", String(move.action_id).get_slice_count("/") - 1)
	title.text = tr(shown_name)
	title.add_theme_font_size_override("font_size", GameTheme.text_size(18))
	lines.add_child(title)
	var sub := Label.new()
	sub.name = "Sub"
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.clip_text = true
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.add_theme_font_size_override("font_size", GameTheme.text_size(18))
	sub.add_theme_color_override("font_color", SUB_COLOR)
	lines.add_child(sub)
	var ridge := ColorRect.new()
	ridge.name = "Ridge"
	ridge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ridge.color = ridge_color
	ridge.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	ridge.offset_left = 3
	ridge.offset_right = 3 + RIDGE_WIDTH
	ridge.offset_top = 4
	ridge.offset_bottom = -7
	ridge.visible = ridge_color.a > 0.0
	button.add_child(ridge)
	if first_of_group and not move.group.is_empty():
		var word := Label.new()
		word.name = "Group"
		word.mouse_filter = Control.MOUSE_FILTER_IGNORE
		word.text = tr(move.group)
		word.add_theme_font_size_override("font_size", SMALL_SIZE)
		word.add_theme_color_override("font_color", ridge_color.lightened(0.35))
		word.position = Vector2(RIDGE_WIDTH + 6, 1)
		button.add_child(word)
		_move_group_words[move.action_id] = word
	move_buttons[move.action_id] = button
	_move_titles[move.action_id] = title
	_move_subs[move.action_id] = sub
	_move_ridges[move.action_id] = ridge
	return button


## The sub line: why the move is dimmed, else its tag with its price or, against the
## target's next move, 克他这招 / 被他克 (the ring, DECISIONS「战斗决策」).
func _show_lines(id: StringName, move: CombatActionDefinition, projection: BattlePresentationProjection, reason: String) -> void:
	var sub: Label = _move_subs.get(id)
	if sub == null or move == null:
		return
	var ridge: ColorRect = _move_ridges.get(id)
	if ridge != null:
		ridge.modulate = Color(0.5, 0.5, 0.5) if not reason.is_empty() else Color.WHITE
	if not reason.is_empty():
		sub.text = reason
		sub.add_theme_color_override("font_color", UiPalette.DIM)
		return
	sub.add_theme_color_override("font_color", SUB_COLOR)
	sub.text = sub_line(move.tag, projection.move_costs.get(id, 1), projection.opponent_tag, projection.beats_shown())
	if not projection.opponent_tag.is_empty() and CombatMoveTags.beats(move.tag, projection.opponent_tag):
		sub.add_theme_color_override("font_color", COUNTER_COLOR)
	elif not projection.opponent_tag.is_empty() and CombatMoveTags.beats(projection.opponent_tag, move.tag):
		sub.add_theme_color_override("font_color", COUNTERED_COLOR)


## 「快 · 1拍」; against the target's next move 「快 · 克他这招」 / 「快 · 被他克」; without the
## beats (经典) the tag alone.
static func sub_line(tag: StringName, cost: int, opponent_tag: StringName, beats_shown: bool) -> String:
	var label: String = CombatMoveTags.label(tag)
	if not opponent_tag.is_empty() and CombatMoveTags.beats(tag, opponent_tag):
		# TRANSLATORS: a move button's sub line: {tag} the move's tag; it beats the target's next move on the ring.
		return TranslationServer.translate("{tag} · 克他这招").format({"tag": label})
	if not opponent_tag.is_empty() and CombatMoveTags.beats(opponent_tag, tag):
		# TRANSLATORS: a move button's sub line: {tag} the move's tag; the target's next move beats it on the ring.
		return TranslationServer.translate("{tag} · 被他克").format({"tag": label})
	if not beats_shown:
		return label
	# TRANSLATORS: a move button's sub line: {tag} the move's tag, {cost} its price in beats.
	return TranslationServer.translate("{tag} · {cost}拍").format({"tag": label, "cost": cost})


## The move's lines as shown (tests).
func move_title(id: StringName) -> String:
	var label: Label = _move_titles.get(id)
	return "" if label == null else label.text


func move_sub(id: StringName) -> String:
	var label: Label = _move_subs.get(id)
	return "" if label == null else label.text


func move_group_word(id: StringName) -> String:
	var label: Label = _move_group_words.get(id)
	return "" if label == null else label.text


## The move buttons in the row's order (tests: the order never changes).
func move_order() -> Array[StringName]:
	var order: Array[StringName] = []
	for child: Node in _moves.get_children():
		if child is Button:
			order.append(move_buttons.find_key(child))
	return order


## The move chosen for the beat stays lacquer while the round plays and the buttons are
## greyed (界面重做 4): the others grey, it does not.
static func _show_chosen(button: Button, chosen: bool) -> void:
	if chosen:
		button.add_theme_stylebox_override("disabled", GameTheme.shared().get_stylebox("pressed", &"ToggleButton"))
		button.add_theme_color_override("font_disabled_color", GameTheme.shared().get_color("font_pressed_color", &"ToggleButton"))
	else:
		button.remove_theme_stylebox_override("disabled")
		button.remove_theme_color_override("font_disabled_color")


func _move_pressed(action_id: StringName) -> void:
	move_requested.emit(action_id)


func _stance_pressed(value: int) -> void:
	stance_requested.emit(value)


func _manual_pressed() -> void:
	manual_toggled.emit(manual_button.text == tr("改为手动"))


func _queue_status(status: int) -> String:
	return tr("等你空下来") if status == CombatQueuedAction.Status.WAITING_FOR_BUSY else tr("就绪")


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
	yield_button.hide()
	_moves.get_parent().hide()
	prompt.show()
	prompt.ask(question[0], question[1], "取消", "", true)
	prompt.focus_default()


## Whether the panel asks about an action now.
func is_asking() -> bool:
	return not _asking_id.is_empty()


func _on_prompt_answered(yes: bool) -> void:
	var id: StringName = _asking_id
	_asking_id = &""
	prompt.hide()
	_actions.visible = not _shown_ids.is_empty()
	_moves.get_parent().visible = not _shown_move_ids.is_empty()
	if yes and not id.is_empty():
		action_requested.emit(id)


func _cancel_pressed() -> void:
	cancel_requested.emit(_displayed_request_id)


## Drops the planned action, when there is one (the battle's back key).
func cancel_planned() -> void:
	if _cancel.visible:
		_cancel_pressed()
