class_name BattleActionPanel
extends PanelContainer

## 战斗界面第二轮 (DECISIONS「战斗界面 · 节拍条」; 战斗拍数 B before it): the fight's panel.
## - The stances in a column on the left (changed seldom).
## - On top, the strip: 「还剩 N 手」, the beats as slots in one groove (BattleBeatChips) and
##   one sentence — what the target's next move is (他起手：守), what the last beat came to
##   (你出虚，他起手守 · 克), or, pointing at a move, what it would take (占 2 手，出完还剩 0 手;
##   red when the beats cannot pay). While the school can still win a beat a dashed slot says
##   how. The beats read 手 to the player; 拍 stays the rule's word.
## - The moves in columns by their tag (快 / 重 / 虚 / 守, then 平), each column under its tag's
##   word and colour; each button the move's name over 「标签 · N 手」, never a verdict on the
##   target's move (the ring is a map, not advice); a move the school locks or the beats
##   cannot pay is dimmed with why (够不着, 手不够). The buttons never reorder.
## - The orders: the performs and the other actions as buttons with their price small in the
##   corner, every 运功 in one menu, 逃跑 and 投降 small at the end, then 收势.
## - What waits and the planned order, 取消, 加力 and 改为自动 at the orders' end.
## - On the right the counter ring (BattleCounterRing): the target's next move ringed, the
##   tag pointed at lit with what it beats and what beats it.
## ES2's one-beat round shows no strip, no costs and no 收势. The panel never locks
## input to a show: the buttons answer whenever the rule says the player may act.

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
## The order buttons (by action ID) in the row's order, the 运功 menu among them; the suites
## walk `_actions`. An exert has no button of its own: it is an item of `exert_menu`.
var _actions: HBoxContainer
var action_buttons: Dictionary[StringName, Button] = {}
var exert_menu: MenuButton
var _exert_ids: Array[StringName] = []
var _shown_ids: Array[StringName] = []
## The actions that cannot run now (CombatTacticalActionInfo.unavailable_reason).
var _unavailable: Dictionary[StringName, String] = {}
var _displayed_request_id: StringName = &""
var _empty: Label
## What waits: 等你出招, 排定 (at the orders' end).
var _queue: Label
var _cancel: Button
var enforce_row: HBoxContainer
var enforce_text: Label
var enforce_amount: SpinBox
var enforce_button: Button
var _shown_factor: int = -1
var _shown_encounter: StringName = &""
## The move buttons (by action ID) with their lines, the columns, the stance column, the
## switches.
var _moves: HBoxContainer
var _shown_move_ids: Array[StringName] = []
var move_buttons: Dictionary[StringName, Button] = {}
var _move_titles: Dictionary[StringName, Label] = {}
var _move_subs: Dictionary[StringName, Label] = {}
var _move_ridges: Dictionary[StringName, ColorRect] = {}
var _move_tags: Dictionary[StringName, StringName] = {}
var _column_tags: Array[StringName] = []
var stance_column: VBoxContainer
var stance_buttons: Dictionary[int, Button] = {}
var manual_button: Button
var yield_button: Button
## The strip: the words before the slots, the slots, the sentence after them.
var strip_row: HBoxContainer
var _left_word: Label
var chips: BattleBeatChips
var strip_text: Label
var ring: BattleCounterRing
## 节拍填格 (DECISIONS「节拍填格」): the pressed move's beat flying up and filling its slot, drawn
## over the whole panel; whether it is still filling (the count waits for it).
var beat_fill: BattleBeatFill
var _filling: bool = false
## The count before the press, shown while its fill plays; the font size the count was fitted at.
var _left_before: int = 0
var _left_px: int = -1
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
## On a short screen (ApplicationShellLayout.SHORT_HEIGHT) the panel closes up: lower,
## narrower buttons.
var _compact: bool = false
## The strip's sentence: the projection last shown, the move or action pointed at, what the
## last beat came to, and what the panel last saw of the round (to tell a new beat).
var _projection: BattlePresentationProjection
var _pointed: StringName = &""
var _result: String = ""
var _seen_spent: int = 0
var _seen_earned: int = 0
var _seen_base: int = -1
var _seen_encounter: StringName = &""
## 战斗拍数 E: the record of the round last looked at (a round run whole between looks is new).
var _seen_round: CombatRoundBeats = null
## A focus the battle set itself (the first move when it waits) points at nothing: only the
## player's own walking or hovering does.
var _quiet_focus: bool = false
## 「放过」 on the right panel while it asks 了结 / 放过: the moves' up (wire_above()).
var _above_rows: Button = null
## Whether the strip shows now (the switches stand at its end when closed up).
var _strip_shown: bool = false

## 像素界面: the move button (two lines of the pixel face), an order's (48 high); on a short
## screen lower and narrower.
const MOVE_SIZE := Vector2(117, 56)
const COMPACT_MOVE_SIZE := Vector2(84, 42)
const ACTION_SIZE := Vector2(64, 48)
const COMPACT_ACTION_HEIGHT: float = 36.0
const COMPACT_STANCE_HEIGHT: float = 28.0
const COMPACT_STANCE_WIDTH: float = 44.0
const STANCE_SIZE := Vector2(64, 40)
const COLUMN_GAP: int = 14
const COMPACT_COLUMN_GAP: int = 8
const RIDGE_WIDTH: float = 4.0
const SMALL_SIZE: int = 12
const SUB_COLOR := Color("b8a689")
const SHORT_COLOR := Color("ff9f86")
## The columns' order: the ring's four, then 平.
const COLUMNS: Array[StringName] = [CombatMoveTags.QUICK, CombatMoveTags.HEAVY, CombatMoveTags.FEINT, CombatMoveTags.GUARD, CombatMoveTags.NONE]


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
	stance_column.alignment = BoxContainer.ALIGNMENT_END
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
	strip_row = HBoxContainer.new()
	strip_row.name = "StripRow"
	strip_row.add_theme_constant_override("separation", 10)
	strip_row.visible = false
	decision_area.add_child(strip_row)
	_left_word = Label.new()
	_left_word.name = "Left"
	_left_word.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_left_word.custom_minimum_size.y = BattleBeatChips.CHIP.y + BattleBeatChips.PAD.y * 2
	_left_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_left_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_left_word.add_theme_font_size_override("font_size", GameTheme.text_size(18))
	_left_word.add_theme_color_override("font_color", UiPalette.LANTERN)
	strip_row.add_child(_left_word)
	chips = BattleBeatChips.new()
	chips.name = "BeatChips"
	chips.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	strip_row.add_child(chips)
	strip_text = Label.new()
	strip_text.name = "StripText"
	strip_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip_text.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	strip_text.custom_minimum_size.y = _left_word.custom_minimum_size.y
	strip_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	strip_text.clip_text = true
	strip_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	strip_text.add_theme_font_size_override("font_size", GameTheme.text_size(18))
	strip_row.add_child(strip_text)
	var moves_scroll := ScrollContainer.new()
	moves_scroll.name = "MoveRow"
	moves_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	moves_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	moves_scroll.custom_minimum_size.y = MOVE_SIZE.y + SMALL_SIZE + 6
	moves_scroll.follow_focus = true
	moves_scroll.visible = false
	decision_area.add_child(moves_scroll)
	_moves = HBoxContainer.new()
	_moves.name = "Moves"
	_moves.add_theme_constant_override("separation", COLUMN_GAP)
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
	_actions = HBoxContainer.new()
	_actions.name = "Actions"
	_actions.add_theme_constant_override("separation", 8)
	orders.add_child(_actions)
	exert_menu = MenuButton.new()
	exert_menu.name = "Exerts"
	# TRANSLATORS: the battle panel's one button for every 运功 (exert) the player can do; it opens a list.
	exert_menu.text = tr("运功")
	exert_menu.custom_minimum_size = ACTION_SIZE
	exert_menu.flat = false
	exert_menu.switch_on_hover = false
	exert_menu.get_popup().id_pressed.connect(_exert_chosen)
	_add_cost_label(exert_menu)
	yield_button = Button.new()
	yield_button.name = "YieldRound"
	# TRANSLATORS: the battle panel's button that gives up the moves left this round (the enemies act, the next round waits for you).
	yield_button.text = tr("收势")
	# TRANSLATORS: hover of 收势.
	yield_button.tooltip_text = tr("放弃这一回合剩下的手，让对手出招；赢来的手照样归你。")
	yield_button.theme_type_variation = &"ChipButton"
	yield_button.custom_minimum_size = ACTION_SIZE
	yield_button.visible = false
	yield_button.pressed.connect(func() -> void: yield_requested.emit())
	orders.add_child(yield_button)
	# What waits and the switches stand at the orders' end (the row has room for them).
	var status_row: HBoxContainer = orders
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
	ring = BattleCounterRing.new()
	ring.name = "CounterRing"
	ring.size_flags_vertical = Control.SIZE_SHRINK_END
	ring.visible = false
	_rows.add_child(ring)
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
	# 节拍填格: over the whole panel, after everything else (the rows dim while the round plays).
	beat_fill = BattleBeatFill.new()
	beat_fill.name = "BeatFill"
	beat_fill.finished.connect(_fill_finished)
	add_child(beat_fill)


func _notification(what: int) -> void:
	# The 运功 menu is out of the tree while no exert is offered: it goes with the panel.
	if what == NOTIFICATION_PREDELETE and is_instance_valid(exert_menu) and exert_menu.get_parent() == null:
		exert_menu.free()


## A short screen: the panel closes up — the rows lower, the moves narrower with a smaller
## sub line, the ring smaller, the stances at the head of the orders' row (a 16:9 desktop at
## 150% is 853 wide), and 取消 / 加力 / 改为自动 moved up to the strip's end (what waits is the
## strip's cursor then); back to the full layout with false.
func set_compact(on: bool) -> void:
	if on == _compact:
		return
	_compact = on
	var move_size: Vector2 = COMPACT_MOVE_SIZE if on else MOVE_SIZE
	var action_height: float = COMPACT_ACTION_HEIGHT if on else ACTION_SIZE.y
	(_moves.get_parent() as Control).custom_minimum_size.y = move_size.y + SMALL_SIZE + (2 if on else 6)
	(_orders.get_parent() as Control).custom_minimum_size.y = action_height
	# The rows' scrollbars take 8 units each: closed up they scroll without one (the wheel,
	# the focus).
	for scroll: ScrollContainer in [_moves.get_parent() as ScrollContainer, _orders.get_parent() as ScrollContainer]:
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if on else ScrollContainer.SCROLL_MODE_AUTO
	chips.set_compact(on)
	ring.set_compact(on)
	var strip_height: float = (BattleBeatChips.COMPACT_CHIP.y if on else BattleBeatChips.CHIP.y) + BattleBeatChips.PAD.y * 2
	_left_word.custom_minimum_size.y = strip_height
	strip_text.custom_minimum_size.y = strip_height
	for label: Label in [_left_word, strip_text]:
		label.add_theme_font_size_override("font_size", SMALL_SIZE if on else GameTheme.text_size(18))
	decision_area.add_theme_constant_override("separation", 2 if on else 4)
	var stance_from: Node = stance_column if on else _orders
	var stance_to: Node = _orders if on else stance_column
	var at: int = 0
	for value: int in [CombatStance.Value.ATTACK, CombatStance.Value.GUARD, CombatStance.Value.EVADE]:
		var button: Button = stance_buttons[value]
		button.custom_minimum_size = Vector2(COMPACT_STANCE_WIDTH, COMPACT_STANCE_HEIGHT) if on else STANCE_SIZE
		_fit_order_button(button)
		if button.get_parent() == stance_from:
			stance_from.remove_child(button)
			stance_to.add_child(button)
			stance_to.move_child(button, at)
		at += 1
	for id: StringName in move_buttons:
		_fit_move_button(move_buttons[id])
	_moves.add_theme_constant_override("separation", COMPACT_COLUMN_GAP if on else COLUMN_GAP)
	for column: Node in _moves.get_children():
		(column.get_node("Buttons") as BoxContainer).add_theme_constant_override("separation", 6 if on else 8)
	for child: Node in _actions.get_children():
		if child is Button:
			(child as Button).custom_minimum_size.y = action_height
			_fit_order_button(child as Button)
	yield_button.custom_minimum_size.y = action_height
	for button: Button in [yield_button, exert_menu, _cancel, manual_button, enforce_button]:
		_fit_order_button(button)
	_place_status()
	for button: Button in [_cancel, manual_button, enforce_button]:
		button.custom_minimum_size.y = 28.0 if on else 36.0


## What waits, 取消, 加力 and 改为自动: at the orders' end; closed up at the strip's end while
## it shows (the orders' row is full then), else still at the orders' end (the one-beat round, a question).
func _place_status() -> void:
	var to: Node = strip_row if _compact and _strip_shown else _orders
	for node: Node in [_queue, _cancel, enforce_row, manual_button]:
		if node.get_parent() != to:
			node.get_parent().remove_child(node)
			to.add_child(node)
	_queue.visible = to == _orders


## An order button's face: closed up the small pixel size, so the row fits 960 units.
func _fit_order_button(button: Button) -> void:
	if _compact:
		button.add_theme_font_size_override("font_size", SMALL_SIZE)
	else:
		button.remove_theme_font_size_override("font_size")


## A move button's size and lines for the layout now: closed up narrower, the sub line small.
func _fit_move_button(button: Button) -> void:
	button.custom_minimum_size = COMPACT_MOVE_SIZE if _compact else MOVE_SIZE
	var lines: Control = button.get_node("Lines") as Control
	lines.offset_left = RIDGE_WIDTH + (3 if _compact else 6)
	lines.offset_right = -2 if _compact else -6
	var sub: Label = lines.get_node("Sub") as Label
	sub.add_theme_font_size_override("font_size", SMALL_SIZE if _compact else GameTheme.text_size(18))


func present(projection: BattlePresentationProjection) -> void:
	_projection = projection
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
		_build_actions(ids)
	# Every refresh (an action can become unavailable without the list changing): an
	# action that cannot run now is greyed with why; the others say what they do and cost.
	_unavailable.clear()
	var popup: PopupMenu = exert_menu.get_popup()
	var exert_costs: Array[int] = []
	for info: CombatTacticalActionInfo in infos:
		var reason: String = info.unavailable_reason
		if not reason.is_empty():
			_unavailable[info.action_id] = reason
		var cost: int = projection.action_costs.get(info.action_id, 0)
		var exert_at: int = _exert_ids.find(info.action_id)
		if exert_at >= 0:
			popup.set_item_text(exert_at, _exert_item_text(info.action_id, cost if shown else 0))
			popup.set_item_disabled(exert_at, not reason.is_empty())
			popup.set_item_tooltip(exert_at, reason if not reason.is_empty() else catalog.tooltip_for(info.action_id))
			exert_costs.append(cost)
			continue
		var button: Button = action_buttons.get(info.action_id)
		if button == null:
			continue
		button.disabled = not reason.is_empty()
		button.tooltip_text = reason if not reason.is_empty() else catalog.tooltip_for(info.action_id)
		var busy: int = own_busy_of(info.action_id)
		if shown and reason.is_empty() and busy > cost:
			# TRANSLATORS: hover of a perform that leaves the player busy longer than it costs ({busy} moves, 手; 玄羽乱舞's 3).
			var after: String = tr("出手后自己要忙 {busy} 手。").format({"busy": busy})
			button.tooltip_text = after if button.tooltip_text.is_empty() else button.tooltip_text + "\n" + after
		_set_cost(button, cost if shown else 0)
	if not _exert_ids.is_empty():
		var all_out: bool = _exert_ids.all(func(id: StringName) -> bool: return _unavailable.has(id))
		exert_menu.disabled = all_out
		# The menu's corner: the exerts' one price when they share it.
		var one_price: int = exert_costs[0] if not exert_costs.is_empty() and exert_costs.all(func(c: int) -> bool: return c == exert_costs[0]) else 0
		_set_cost(exert_menu, one_price if shown else 0)
		# TRANSLATORS: hover of the battle panel's 运功 button.
		exert_menu.tooltip_text = tr("运功：选一项内功的用法。")
	var queued: CombatQueuedAction = projection.queued_action()
	_displayed_request_id = &"" if queued == null else queued.request.request_id
	_present_strip(projection, shown)
	yield_button.visible = shown and projection.turns_offered and not is_asking()
	yield_button.disabled = not (projection.waiting and projection.manual)
	_queue.text = _status_text(projection)
	if queued != null:
		_queue.text += "\n" + tr("{action} · 目标：{target}").format({"action": catalog.label_for(queued.request.action_id), "target": tr(projection.display_name(queued.resolved_target_id))})
	_cancel.visible = queued != null
	_wire_focus()


## The order row's buttons: the performs and the other actions in the projection's order,
## then one 运功 menu for every exert, then 逃跑 and 投降 small at the end.
func _build_actions(ids: Array[StringName]) -> void:
	_shown_ids = ids
	_pointed = &""
	chips.clear_preview()
	ring.light(&"")
	action_buttons.clear()
	_exert_ids.clear()
	exert_menu.get_popup().clear()
	if exert_menu.get_parent() != null:
		exert_menu.get_parent().remove_child(exert_menu)
	for child: Node in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	var tail: Array[StringName] = []
	for id: StringName in ids:
		if not CombatExertTacticalPolicy.function_for(id).is_empty():
			_exert_ids.append(id)
			exert_menu.get_popup().add_item(catalog.label_for(id), _exert_ids.size() - 1)
			continue
		if id == CombatFleeTacticalPolicy.ACTION_ID or id == CombatSurrenderTacticalPolicy.ACTION_ID:
			tail.append(id)
			continue
		_actions.add_child(_action_button(id))
	if not _exert_ids.is_empty():
		exert_menu.custom_minimum_size.y = COMPACT_ACTION_HEIGHT if _compact else ACTION_SIZE.y
		_actions.add_child(exert_menu)
	for id: StringName in tail:
		_actions.add_child(_action_button(id))


func _action_button(id: StringName) -> Button:
	var button := Button.new()
	button.name = "Action%d" % _actions.get_child_count()
	button.text = short_label(id)
	button.custom_minimum_size = Vector2(ACTION_SIZE.x, COMPACT_ACTION_HEIGHT if _compact else ACTION_SIZE.y)
	button.pressed.connect(_action_pressed.bind(id))
	# 逃跑 and 投降 read small (纪要 §九): chips at the row's end.
	if id == CombatSurrenderTacticalPolicy.ACTION_ID or id == CombatFleeTacticalPolicy.ACTION_ID:
		button.theme_type_variation = &"ChipButton"
	_add_cost_label(button)
	_fit_order_button(button)
	button.mouse_entered.connect(_point.bind(id))
	button.mouse_exited.connect(_unpoint.bind(id))
	button.focus_entered.connect(_point.bind(id))
	button.focus_exited.connect(_unpoint.bind(id))
	action_buttons[id] = button
	return button


func _add_cost_label(button: Button) -> void:
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


## An order button's corner: its price in 手 (0: none).
func _set_cost(button: Button, cost: int) -> void:
	var label: Label = button.get_node("Cost") as Label
	# TRANSLATORS: the small corner of an order button: its price in moves (手) this round.
	label.text = tr("%d手") % cost if cost > 0 else ""
	label.reset_size()
	label.position = Vector2(-label.size.x - 4, -label.size.y - 2)


## 运功恢复气 · 1 手 → the menu's item: the exert without 运功, with its price.
func _exert_item_text(id: StringName, cost: int) -> String:
	var label: String = catalog.label_for(id)
	if cost <= 0:
		return label
	# TRANSLATORS: an item of the battle panel's 运功 list: {action} the exert, {cost} its price in moves (手).
	return tr("{action} · {cost} 手").format({"action": label, "cost": cost})


## An order button's words: a perform's own name without its quotes (封字诀, 玄羽乱舞: the
## row says what it is), the catalog's for the rest.
func short_label(id: StringName) -> String:
	var perform: PerformFunction = SpecialFunctions.perform(CombatPerformTacticalPolicy.function_for(id))
	if perform == null or perform.label.is_empty():
		return catalog.label_for(id)
	return tr(perform.label).replace("「", "").replace("」", "")


## The exerts as the menu lists them (tests).
func exert_items() -> Array[StringName]:
	return _exert_ids.duplicate()


## The action whose button or 运功 item is labelled `label` (catalog.label_for): [id,
## greyed, hover], [] when there is none (tests).
func action_by_label(label: String) -> Array:
	for id: StringName in action_buttons:
		if catalog.label_for(id) == label or action_buttons[id].text == label:
			return [id, action_buttons[id].disabled, action_buttons[id].tooltip_text]
	var popup: PopupMenu = exert_menu.get_popup()
	for index: int in _exert_ids.size():
		if catalog.label_for(_exert_ids[index]) == label:
			return [_exert_ids[index], popup.is_item_disabled(index), popup.get_item_tooltip(index)]
	return []


func _exert_chosen(index: int) -> void:
	if index >= 0 and index < _exert_ids.size():
		_action_pressed(_exert_ids[index])


## What waits: 等你出招, the planned order.
func _status_text(projection: BattlePresentationProjection) -> String:
	# Nothing planned, nothing said (DECISIONS「数值用到才出现」: 「排定：无」 is gone).
	var parts := PackedStringArray()
	if projection.waiting:
		# TRANSLATORS: the battle panel's status while the fight's clock waits for the player's order.
		parts.append(tr("等你出招"))
	if projection.queue_status != CombatQueuedAction.Status.EMPTY:
		parts.append(tr("排定：%s") % _queue_status(projection.queue_status))
	return " · ".join(parts)


## The strip: how many 手 are left, the slots (with the dashed one and the cursor), the
## sentence; the ring beside it rings the target's next move.
func _present_strip(projection: BattlePresentationProjection, shown: bool) -> void:
	var offered: bool = shown and projection.turns_offered
	_strip_shown = offered and not is_asking()
	strip_row.visible = _strip_shown
	_place_status()
	ring.visible = projection.turns_offered and not projection.moves.is_empty() and not is_asking()
	ring.mark(projection.opponent_tag)
	_note_result(projection)
	if not offered:
		return
	var beats: CombatRoundBeats = projection.player_beats
	if not beat_fill.playing():
		# A fill stopped short (the fight is over): the strip is let go.
		chips.release()
		_filling = false
	chips.present(beats, projection.beat_rules, GameContent.catalog().pacing().feel.beat_chip_seconds, projection.last_round_beats)
	var can_earn: bool = beats != null and not projection.player_earn.is_empty() and projection.beat_rules != null and beats.earned.size() < projection.beat_rules.earned_beat_cap
	chips.set_earnable(can_earn, TranslationServer.translate(CombatSchoolSkeleton.EARN_HINTS.get(projection.player_earn, "")) if can_earn else "")
	chips.set_cursor(projection.waiting and projection.manual)
	_show_left()
	_show_sentence()


## The strip's first words: how many 手 are left — less a press the record does not show yet,
## once its fill has filled.
func _show_left() -> void:
	_fit_left_word()
	var beats: CombatRoundBeats = null if _projection == null else _projection.player_beats
	var left: int = _left_before if _filling else (0 if beats == null else maxi(0, beats.remaining - chips.pending_count()))
	# TRANSLATORS: the battle strip's first words: how many moves (手) the player has left this round; 没手了 none.
	_left_word.text = tr("还剩 %d 手") % left if left > 0 else tr("没手了")


## The count keeps one width (its longest words): the slots never shift as it changes.
func _fit_left_word() -> void:
	var font: Font = _left_word.get_theme_font(&"font")
	if font == null:
		return
	var px: int = _left_word.get_theme_font_size(&"font_size")
	if px == _left_px:
		return
	_left_px = px
	var width: float = 0.0
	for words: String in [tr("还剩 %d 手") % 9, tr("没手了")]:
		width = maxf(width, font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
	_left_word.custom_minimum_size.x = ceilf(width)


## 节拍填格: the move pressed (and taken by the fight) sends its beat from its button into the
## strip, filling its slot (a 重's two); the slot stays filled until the round's record has it.
## False with the feel off (the slot fills when the record shows it, as before) or no free slot.
func fill_beat(action_id: StringName) -> bool:
	var seconds: float = GameContent.catalog().pacing().feel.beat_fill_seconds
	var button: Button = move_buttons.get(action_id)
	if seconds <= 0.0 or _projection == null or not _strip_shown or button == null or not chips.is_visible_in_tree():
		return false
	var key: StringName = _move_tags.get(action_id, CombatMoveTags.NONE)
	if key == CombatMoveTags.NONE:
		key = CombatBeatRules.COST_PLAIN
	var before: int = 0 if _projection.player_beats == null else maxi(0, _projection.player_beats.remaining - chips.pending_count())
	var run: Array[int] = chips.hold(key, _projection.move_costs.get(action_id, 1))
	if run.is_empty():
		return false
	_left_before = before
	var to_local: Transform2D = beat_fill.get_global_transform().affine_inverse()
	var from: Rect2 = to_local * button.get_global_rect()
	var to: Rect2 = to_local * (chips.get_global_transform() * chips.slot_rect(run[0], run[1]))
	_filling = beat_fill.play(from, to, BattleBeatChips.color_of(key), BattleBeatChips.glyph_of(key), seconds)
	if not _filling:
		chips.release()
	_show_left()
	return _filling


## The fill is full: the strip and the count take the record's last look.
func _fill_finished() -> void:
	if beat_fill.playing():
		return
	_filling = false
	chips.release()
	_show_left()
	_show_sentence()


## What the last beat came to, noticed when the player's spent beats grow within a round:
## the move against what it met on the ring, as the round's record holds it (beat_line()), and
## a beat won.
func _note_result(projection: BattlePresentationProjection) -> void:
	var beats: CombatRoundBeats = projection.player_beats
	if beats == null or not projection.beats_shown():
		_result = ""
		_seen_spent = 0
		_seen_earned = 0
		_seen_base = -1
		return
	if projection.encounter_id != _seen_encounter:
		_seen_encounter = projection.encounter_id
		_result = ""
		_seen_spent = 0
		_seen_earned = 0
		_seen_base = beats.base
		_seen_round = projection.last_round_beats
	# 战斗拍数 E: a round that ran whole between two looks (a 重 against one who lost its beat)
	# is a round of its own too: its beats are another record.
	var whole: bool = projection.last_round_beats != null and projection.last_round_beats != _seen_round and projection.last_round_beats != beats
	var fresh: bool = whole or beats.base != _seen_base or beats.spent.size() < _seen_spent or (beats.spent.is_empty() and _seen_spent > 0)
	if fresh:
		# The round ended since the last look: its last beat is the round that last ran's.
		var last: CombatRoundBeats = projection.last_round_beats
		if last != null and last.spent.size() > _seen_spent:
			_result = beat_line(last, last.spent.size() - 1)
			if last.earned.size() > _seen_earned:
				_result += " · " + _won_line(last.earned[last.earned.size() - 1])
		_seen_spent = 0
		_seen_earned = 0
	if beats.spent.size() > _seen_spent:
		_result = beat_line(beats, beats.spent.size() - 1)
	if beats.earned.size() > _seen_earned:
		var won: String = _won_line(beats.earned[beats.earned.size() - 1])
		_result = won if _result.is_empty() else _result + " · " + won
	_seen_spent = beats.spent.size()
	_seen_earned = beats.earned.size()
	_seen_base = beats.base
	_seen_round = projection.last_round_beats


## 「多一手（隙）」: a beat the player's school won (`source`: CombatSchoolSkeleton EARN_*).
static func _won_line(source: StringName) -> String:
	var word: String = TranslationServer.translate(CombatSchoolSkeleton.EARN_LABELS.get(source, ""))
	# TRANSLATORS: the battle strip: the player's school won one more move this round ({word}: 隙 / 压 / 连).
	return TranslationServer.translate("多一手（{word}）").format({"word": word}) if not word.is_empty() else TranslationServer.translate("多一手")


## The line for the beat `index` of `beats`: what it went on, and what its blow met on the ring
## and the verdict as the resolver recorded them when it was struck (CombatRoundBeats.against /
## rings) — the strip never works the ring out itself (自动 runs a round between two looks).
static func beat_line(beats: CombatRoundBeats, index: int) -> String:
	var against: StringName = beats.against[index] if index < beats.against.size() else &""
	var ring: int = beats.rings[index] if index < beats.rings.size() else 0
	return result_line(beats.spent[index], against, ring)


## 「你出虚，他起手守 · 克」: a beat the player spent on `key` against the target's move
## `before` (&"" unknown: no verdict), `ring` the resolver's verdict (1 克, -1 被克, 0 平); a
## perform or an order by its name alone.
static func result_line(key: StringName, before: StringName, ring: int = 0) -> String:
	if key == CombatEncounterScheduler.SPENT_BUSY:
		# TRANSLATORS: the battle strip after a beat the player lost to being busy.
		return TranslationServer.translate("这一手你在忙")
	if key == CombatEncounterScheduler.SPENT_WAIT:
		# TRANSLATORS: the battle strip after a beat the player let pass.
		return TranslationServer.translate("这一手你停了")
	if not CombatMoveTags.ALL.has(key):
		var word: String = spent_word(key)
		# TRANSLATORS: the battle strip after a beat that was no move ({action}: a perform's name, 功, 势).
		return TranslationServer.translate("你出了{action}").format({"action": word})
	var mine: String = CombatMoveTags.label(key)
	if before.is_empty():
		# TRANSLATORS: the battle strip after a beat: the player's move's tag, the target's unknown.
		return TranslationServer.translate("你出{mine}").format({"mine": mine})
	var verdict: String = TranslationServer.translate("平")
	if ring > 0:
		# TRANSLATORS: the battle strip's verdict after a beat: the player's move beat the target's on the ring.
		verdict = TranslationServer.translate("克！")
	elif ring < 0:
		# TRANSLATORS: the battle strip's verdict after a beat: the target's move beat the player's on the ring.
		verdict = TranslationServer.translate("被克")
	# TRANSLATORS: the battle strip after a beat: {mine} the player's tag, {theirs} the target's, {verdict} 克！/ 被克 / 平.
	return TranslationServer.translate("你出{mine}，他起手{theirs} · {verdict}").format({"mine": mine, "theirs": CombatMoveTags.label(before), "verdict": verdict})


## The sentence: pointing at a move or an action, what it would take; else the last beat's
## result and the target's next move.
func _show_sentence() -> void:
	if _projection == null:
		return
	strip_text.remove_theme_color_override("font_color")
	var pointed: String = _pointed_line()
	if not pointed.is_empty():
		strip_text.text = pointed
		if _pointed_cost_now() > _projection.player_beats.remaining:
			strip_text.add_theme_color_override("font_color", SHORT_COLOR)
		return
	var parts := PackedStringArray()
	if not _result.is_empty():
		parts.append(_result)
	var target: BattleParticipantProjection = _projection.participant(_projection.current_target_id)
	if target != null and target.hostile_to_player:
		var tag: String = "？"
		if not _projection.opponent_tag.is_empty():
			tag = CombatMoveTags.label(_projection.opponent_tag)
		elif target.next_move_known and target.next_move_guard:
			# TRANSLATORS: the battle strip: the target holds 守势 (the guard stance) instead of a move, as its card's seal says.
			tag = tr("守势")
		# 战斗拍数 E: the target has spent its beats and the player still has some.
		var left: int = 0 if _projection.player_beats == null else _projection.player_beats.remaining
		if _projection.waiting and left > 0 and _target_beats_left() == 0:
			# TRANSLATORS: the battle strip: the target has no move (手) left this round while the player still has {left}.
			parts.append(TranslationServer.translate("他没手了，你还有 {left} 手").format({"left": left}))
		# TRANSLATORS: the battle strip: the target's next move's tag as the player reads it (？ not known).
		parts.append(tr("他起手：%s") % tag)
	strip_text.text = "　".join(parts)


## What the move or action pointed at would take: 「空山鸟语占 2 手，出完还剩 0 手」, or why
## the beats cannot pay (red); "" when nothing is pointed at.
func _pointed_line() -> String:
	if not _pointing():
		return ""
	var cost: int = _pointed_cost_now()
	if cost <= 0:
		return ""
	var name: String = move_title(_pointed) if move_buttons.has(_pointed) else catalog.label_for(_pointed)
	return pointed_line(name, cost, _projection.player_beats.remaining, _target_beats_left(), own_busy_of(_pointed))


## Whether a move or action is pointed at and the fight waits for the player (while the
## round plays the focus rests on the move just pressed: that is no question).
func _pointing() -> bool:
	return not _pointed.is_empty() and _projection != null and _projection.beats_shown() and _projection.player_beats != null and _projection.waiting and _projection.manual


## The price of what is pointed at (0: nothing, or an order that costs none).
func _pointed_cost_now() -> int:
	if move_buttons.has(_pointed):
		return _projection.move_costs.get(_pointed, 1)
	if action_buttons.has(_pointed):
		return _projection.action_costs.get(_pointed, 0)
	return 0


## The busy a perform always leaves its performer in (PerformFunction.own_busy), 0 for any
## other order.
static func own_busy_of(id: StringName) -> int:
	var perform: PerformFunction = SpecialFunctions.perform(CombatPerformTacticalPolicy.function_for(id))
	return 0 if perform == null else perform.own_busy


## The sentence for a move or action `name` costing `cost` with `left` 手 left, the target
## holding `theirs` this round (-1 unknown); a perform that leaves the performer `busy` longer
## than it costs says so after.
static func pointed_line(name: String, cost: int, left: int, theirs: int, busy: int = 0) -> String:
	var line: String = _pointed_cost(name, cost, left, theirs, busy)
	if busy > cost and cost <= left:
		# TRANSLATORS: the battle strip, after what a perform costs: it leaves the player busy for {busy} moves (手) in all.
		line += TranslationServer.translate("；出手后自己要忙 {busy} 手").format({"busy": busy})
	return line


## The busy a perform leaves counts its beats down first (DECISIONS「战斗拍数 C」): what is
## left after it is less by max(price, busy).
static func _pointed_cost(name: String, cost: int, left: int, theirs: int, busy: int) -> String:
	if cost > left:
		# TRANSLATORS: the battle strip, pointing at a move the moves left cannot pay: {name}, its price, what is left.
		return TranslationServer.translate("不够：{name}要 {cost} 手，你还剩 {left} 手").format({"name": name, "cost": cost, "left": left})
	var after: int = maxi(0, left - maxi(cost, busy))
	if after > 0:
		# TRANSLATORS: the battle strip, pointing at a move: {name} takes {cost} moves (手), {after} left after it.
		return TranslationServer.translate("{name}占 {cost} 手，出完还剩 {after} 手").format({"name": name, "cost": cost, "after": after})
	if theirs >= 2:
		# TRANSLATORS: the battle strip, pointing at a move that takes the player's last moves while the target still has {theirs} this round.
		return TranslationServer.translate("{name}占 {cost} 手，出完你这回合没手了，他连出 {theirs} 手").format({"name": name, "cost": cost, "theirs": theirs})
	# TRANSLATORS: the battle strip, pointing at a move that takes the player's last moves this round.
	return TranslationServer.translate("{name}占 {cost} 手，出完你这回合没手了").format({"name": name, "cost": cost})


## The beats the target still holds this round, -1 when more than one enemy stands (the
## sentence then names no one) or unknown.
func _target_beats_left() -> int:
	var hostile: int = 0
	for value: BattleParticipantProjection in _projection.participants():
		if value.hostile_to_player and value.available:
			hostile += 1
	var target: BattleParticipantProjection = _projection.participant(_projection.current_target_id)
	if hostile != 1 or target == null or target.beats == null:
		return -1
	return target.beats.remaining


func _point(id: StringName) -> void:
	if _quiet_focus:
		return
	_pointed = id
	chips.clear_preview()
	if _pointing():
		var cost: int = _pointed_cost_now()
		var key: StringName = BattleBeatChips.FREE
		if move_buttons.has(id):
			key = _move_tags.get(id, CombatMoveTags.NONE)
			if key == CombatMoveTags.NONE:
				key = CombatBeatRules.COST_PLAIN
		elif not CombatPerformTacticalPolicy.function_for(id).is_empty():
			key = CombatBeatRules.perform_key(CombatPerformTacticalPolicy.function_for(id))
		else:
			key = CombatBeatRules.COST_EXERT
		var left: int = _projection.player_beats.remaining
		var ok: bool = cost <= left
		# What it takes this round: its price, or the busy it leaves when longer (within what is left).
		chips.set_preview(mini(maxi(cost, own_busy_of(id)), left) if ok else cost, key, ok)
	ring.light(_move_tags.get(id, &""))
	_show_sentence()


func _unpoint(id: StringName) -> void:
	if _pointed != id:
		return
	_clear_point()


## Nothing pointed at: no ghost, no lit arrows, the sentence back.
func _clear_point() -> void:
	_pointed = &""
	chips.clear_preview()
	ring.light(&"")
	_show_sentence()


## The battle's own focus (the first move when the fight waits): no pointing.
func focus_quietly(control: Control) -> void:
	_quiet_focus = true
	control.grab_focus()
	_quiet_focus = false


## 快→虚→封's words: what a spent beat went on (busy and waits as 忙 / 停).
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


## The keys and the pad walk the rows (DECISIONS「战斗界面」): left and right along the moves
## (column after column), down to the orders (the first, else 收势) and on down to 改为自动,
## up again to the chosen move; the stances stand in a column on the left of the first move,
## up and down among themselves. Up from the moves (the orders without them) to 「放过」 while
## the right panel asks 了结 / 放过 (wire_above()).
func wire_above(button: Button) -> void:
	if button == _above_rows:
		return
	_above_rows = button
	_wire_focus()


func _wire_focus() -> void:
	var row: Array[Button] = []
	if _moves.get_parent().visible:
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
	var choice: Button = _above_rows if is_instance_valid(_above_rows) and _above_rows.is_visible_in_tree() else null
	var above: Button = first_move_button()
	if above == null and not row.is_empty():
		above = row[0]
	for index: int in row.size():
		var button: Button = row[index]
		button.focus_neighbor_left = button.get_path_to(row[index - 1]) if index > 0 else (button.get_path_to(stances[0]) if not stances.is_empty() else NodePath())
		button.focus_neighbor_right = button.get_path_to(row[index + 1]) if index + 1 < row.size() else NodePath()
		button.focus_neighbor_bottom = button.get_path_to(below) if below != null else NodePath()
		button.focus_neighbor_top = button.get_path_to(choice) if choice != null else NodePath()
	for index: int in orders.size():
		var button: Button = orders[index]
		button.focus_neighbor_left = button.get_path_to(orders[index - 1]) if index > 0 else (button.get_path_to(stances[0]) if not stances.is_empty() else NodePath())
		button.focus_neighbor_right = button.get_path_to(orders[index + 1]) if index + 1 < orders.size() else NodePath()
		button.focus_neighbor_top = button.get_path_to(above) if above != null else (button.get_path_to(choice) if choice != null else NodePath())
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


## 战斗决策层 1B / 战斗界面第二轮: the move buttons in their tag's column (the name over the
## tag and the price; the chosen one pressed; all greyed while the round plays or the clock
## rolls on 自动; a locked or unaffordable one dimmed with why), the stances (in place of
## 加力 when offered) and the 自动 switch.
func _present_moves(projection: BattlePresentationProjection) -> void:
	var ids: Array[StringName] = []
	for move: CombatActionDefinition in projection.moves:
		ids.append(move.action_id)
	var offered: bool = projection.turns_offered and not ids.is_empty()
	_moves.get_parent().visible = offered and not is_asking()
	if ids != _shown_move_ids:
		_shown_move_ids = ids
		_pointed = &""
		chips.clear_preview()
		ring.light(&"")
		move_buttons.clear()
		_move_titles.clear()
		_move_subs.clear()
		_move_ridges.clear()
		_move_tags.clear()
		_column_tags.clear()
		for child: Node in _moves.get_children():
			_moves.remove_child(child)
			child.queue_free()
		for tag: StringName in COLUMNS:
			var in_column: Array[CombatActionDefinition] = []
			for move: CombatActionDefinition in projection.moves:
				if (move.tag if CombatMoveTags.ALL.has(move.tag) else CombatMoveTags.NONE) == tag:
					in_column.append(move)
			if in_column.is_empty():
				continue
			_moves.add_child(_column(tag, in_column))
			_column_tags.append(tag)
	for id: StringName in move_buttons:
		var button: Button = move_buttons[id]
		var chosen: bool = id == projection.chosen_action_id
		button.set_pressed_no_signal(chosen)
		# 战斗拍数 A / B: a move the player's school locks now (够不着) or the beats cannot pay
		# (手不够) is dimmed with why; the buttons never reorder.
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
	manual_button.tooltip_text = tr("现在：每一手等你出招；按下后战斗自己打，手自动补满、演出加快。") if projection.manual else tr("现在：战斗自己打；按下后每一手等你出招。")


## One column: the tag's colour and word over its moves in the set's own order.
func _column(tag: StringName, moves: Array[CombatActionDefinition]) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = "Column%s" % (String(tag).capitalize() if not tag.is_empty() else "Plain")
	column.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override("separation", 4)
	column.add_child(head)
	var color: Color = BattleBeatChips.COLORS.get(tag if not tag.is_empty() else CombatBeatRules.COST_PLAIN)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(8, 8)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.color = color
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(swatch)
	var word := Label.new()
	word.name = "Word"
	word.text = CombatMoveTags.label(tag)
	word.tooltip_text = CombatMoveTags.description(tag)
	word.mouse_filter = Control.MOUSE_FILTER_PASS
	word.add_theme_font_size_override("font_size", SMALL_SIZE)
	word.add_theme_color_override("font_color", color.lightened(0.35))
	head.add_child(word)
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override("separation", 6 if _compact else 8)
	column.add_child(buttons)
	for move: CombatActionDefinition in moves:
		buttons.add_child(_move_button(move, color))
	return column


## One move button: the ridge in its tag's colour, the name over the sub line.
func _move_button(move: CombatActionDefinition, ridge_color: Color) -> Button:
	var button := Button.new()
	button.name = "Move%d" % move_buttons.size()
	button.toggle_mode = true
	# 界面重做 4: the move chosen for the beat is lacquer.
	button.theme_type_variation = &"ToggleButton"
	button.custom_minimum_size = COMPACT_MOVE_SIZE if _compact else MOVE_SIZE
	button.pressed.connect(_move_pressed.bind(move.action_id))
	button.mouse_entered.connect(_point.bind(move.action_id))
	button.mouse_exited.connect(_unpoint.bind(move.action_id))
	button.focus_entered.connect(_point.bind(move.action_id))
	button.focus_exited.connect(_unpoint.bind(move.action_id))
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
	button.add_child(ridge)
	_fit_move_button(button)
	move_buttons[move.action_id] = button
	_move_titles[move.action_id] = title
	_move_subs[move.action_id] = sub
	_move_ridges[move.action_id] = ridge
	_move_tags[move.action_id] = move.tag if CombatMoveTags.ALL.has(move.tag) else CombatMoveTags.NONE
	return button


## The sub line: why the move is dimmed, else its tag with its price (never a verdict on the
## target's move: DECISIONS「战斗界面 · 节拍条」).
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
	sub.text = sub_line(move.tag, projection.move_costs.get(id, 1), projection.beats_shown())


## 「快 · 1 手」; without the beats the tag alone.
static func sub_line(tag: StringName, cost: int, beats_shown: bool) -> String:
	var label: String = CombatMoveTags.label(tag)
	if not beats_shown:
		return label
	# TRANSLATORS: a move button's sub line: {tag} the move's tag, {cost} its price in moves (手) this round.
	return TranslationServer.translate("{tag} · {cost} 手").format({"tag": label, "cost": cost})


## The move's lines as shown (tests).
func move_title(id: StringName) -> String:
	var label: Label = _move_titles.get(id)
	return "" if label == null else label.text


func move_sub(id: StringName) -> String:
	var label: Label = _move_subs.get(id)
	return "" if label == null else label.text


## The columns' tags left to right (tests).
func column_tags() -> Array[StringName]:
	return _column_tags.duplicate()


## The move buttons in the row's order, column after column (tests: the order never changes).
func move_order() -> Array[StringName]:
	var order: Array[StringName] = []
	for column: Node in _moves.get_children():
		var buttons: Node = column.get_node_or_null("Buttons")
		if buttons == null:
			continue
		for child: Node in buttons.get_children():
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
	_clear_point()
	move_requested.emit(action_id)


func _stance_pressed(value: int) -> void:
	stance_requested.emit(value)


func _manual_pressed() -> void:
	# The switch turns the way the fight stands now (not by its words, which a language changes).
	manual_toggled.emit(_projection == null or not _projection.manual)


func _queue_status(status: int) -> String:
	return tr("等你空下来") if status == CombatQueuedAction.Status.WAITING_FOR_BUSY else tr("就绪")


## The first action button as the row reads (a perform before 运功, 逃跑 and 投降 last; the
## 运功 menu is no action of its own), null without one: one press there never flees unless
## fleeing is all there is.
func first_action_button() -> Button:
	for child: Node in _actions.get_children():
		if child is Button and child != exert_menu:
			return child as Button
	return null


func _action_pressed(id: StringName) -> void:
	if _unavailable.has(id):
		return # Greyed: it cannot run now (its hover says why).
	_clear_point()
	var question: PackedStringArray = confirm_text.call(id) if confirm_text.is_valid() else PackedStringArray()
	if question.size() < 2:
		action_requested.emit(id)
		return
	_asking_id = id
	_actions.hide()
	yield_button.hide()
	_moves.get_parent().hide()
	_strip_shown = false
	strip_row.hide()
	_place_status()
	prompt.show()
	prompt.ask(question[0], question[1], "取消", "", true)
	prompt.focus_default()


## Chooses an action as its button or menu item would (tests, the pad's menu).
func choose_action(id: StringName) -> void:
	_action_pressed(id)


## Whether the panel asks about an action now.
func is_asking() -> bool:
	return not _asking_id.is_empty()


func _on_prompt_answered(yes: bool) -> void:
	var id: StringName = _asking_id
	_asking_id = &""
	prompt.hide()
	_actions.visible = not _shown_ids.is_empty()
	_moves.get_parent().visible = not _shown_move_ids.is_empty()
	_strip_shown = _projection != null and _projection.beats_shown() and _projection.turns_offered
	strip_row.visible = _strip_shown
	_place_status()
	if yes and not id.is_empty():
		action_requested.emit(id)


func _cancel_pressed() -> void:
	cancel_requested.emit(_displayed_request_id)


## Drops the planned action, when there is one (the battle's back key).
func cancel_planned() -> void:
	if _cancel.visible:
		_cancel_pressed()
