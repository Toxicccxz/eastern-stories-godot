class_name BattleParticipantCard
extends PanelContainer

signal target_requested(participant_id: StringName)
## DECISIONS「了结 / 放过」: the player's choice for one who fell.
signal finish_requested(participant_id: StringName)
signal spare_requested(participant_id: StringName)

# TRANSLATORS: the battle card of one who fell while the player was killing them: the button that kills them with the next blow.
const FINISH_LABEL: String = "了结"
# TRANSLATORS: the battle card of one who fell: the button that lets them live (the player's side strikes them no more).
const SPARE_LABEL: String = "放过"

var target_button: Button
var _participant_id: StringName
var _ordinary_border: StyleBoxFlat
var _current_border: StyleBoxFlat

var _title: Label
var _vitality: ProgressBar
## Who the card showed and their 气 then: the bar moves and the card flashes from it
## (DECISIONS「手感」: bar_tween_ms, hit_flash_ms, the setting 受击闪红).
var _shown_id: StringName = &""
var _shown_vitality: int = -1
## 气, 精 and 神 as last shown (held while a blow's line waits to be told).
var _shown_resources: Array[BattleResourceProjection] = []
var _bar: Tween
var _flash: Tween
const HIT_COLOR: Color = Color(1.0, 0.45, 0.42)
var _primary: Label
var _secondary: Label
var _status: Label
## 战斗决策层 1B: the enemy's 起手 (the tag of its next move) and the special it announced.
var _intent: Label
## 了结 / 放过, shown while the one on the card waits on the player's choice.
var choice_row: HBoxContainer
var finish_button: Button
var spare_button: Button


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ordinary_border = StyleBoxFlat.new()
	_ordinary_border.bg_color = Color("182833")
	_ordinary_border.border_color = Color("405563")
	_ordinary_border.set_border_width_all(1)
	_ordinary_border.content_margin_left = 10
	_ordinary_border.content_margin_right = 10
	_current_border = _ordinary_border.duplicate() as StyleBoxFlat
	_current_border.border_color = Color("efc77b")
	_current_border.set_border_width_all(3)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 0)
	add_child(content)
	_title = _label(content)
	_title.add_theme_color_override("font_color", Color("efc77b"))
	_vitality = ProgressBar.new()
	_vitality.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitality.custom_minimum_size.y = 8
	_vitality.show_percentage = false
	content.add_child(_vitality)
	_primary = _label(content)
	_secondary = _label(content)
	_status = _label(content)
	_intent = _label(content)
	_intent.add_theme_color_override("font_color", Color("f2d27a"))
	_intent.visible = false
	choice_row = HBoxContainer.new()
	choice_row.name = "KnockoutChoice"
	choice_row.add_theme_constant_override("separation", 8)
	choice_row.visible = false
	content.add_child(choice_row)
	finish_button = _choice_button("FinishButton")
	finish_button.pressed.connect(func() -> void: finish_requested.emit(_participant_id))
	spare_button = _choice_button("SpareButton")
	spare_button.pressed.connect(func() -> void: spare_requested.emit(_participant_id))
	target_button = Button.new()
	target_button.name = "SelectTarget"
	target_button.custom_minimum_size = Vector2(64, 64)
	for style: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		target_button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("75d9ee") # Cyan input focus != gold authoritative target.
	focus.set_border_width_all(2)
	target_button.add_theme_stylebox_override("focus", focus)
	target_button.pressed.connect(_request_target)
	add_child(target_button) # Native focus/touch overlay; no extra narrow-screen row.


## `hold_resources`: 气, 精 and 神 stay as shown (the blow's line is not told yet).
func present(value: BattleParticipantProjection, player_id: StringName, current_id: StringName, queued_id: StringName = &"", hold_resources: bool = false) -> void:
	_participant_id = value.participant_id
	target_button.disabled = not value.targetable
	target_button.tooltip_text = tr("选为目标：%s") % tr(value.display_name) if value.targetable else tr("不能选为目标")
	var role: String = tr("你") if value.participant_id == player_id else tr("当前目标") if value.participant_id == current_id else tr("对手") if value.hostile_to_player else tr("参战")
	_title.text = "%s · %s" % [tr(value.display_name), role]
	_title.tooltip_text = _title.text
	var border: StyleBoxFlat = _current_border if value.participant_id == current_id else _ordinary_border
	if get_theme_stylebox("panel") != border:
		add_theme_stylebox_override("panel", border)
	if not hold_resources or value.participant_id != _shown_id or _shown_resources.is_empty():
		_show_resources(value.participant_id, [value.vitality, value.essence, value.spirit])
	_primary.tooltip_text = "当前／有效／上限"
	var powers: Dictionary = {
		"force": value.force.current, "max_force": value.force.maximum, "factor": value.force_factor,
		"mana": value.mana.current, "max_mana": value.mana.maximum,
		"atman": value.atman.current, "max_atman": value.atman.maximum,
	}
	if value.participant_id == player_id:
		# TRANSLATORS: the player's card; (+{factor}) is enforce.c's force_factor, as hp.c shows it.
		_secondary.text = tr("内力 {force}/{max_force} (+{factor}) · 法力 {mana}/{max_mana} · 灵力 {atman}/{max_atman}").format(powers)
	else:
		_secondary.text = tr("内力 {force}/{max_force} · 法力 {mana}/{max_mana} · 灵力 {atman}/{max_atman}").format(powers)
	_secondary.tooltip_text = _secondary.text
	var states := PackedStringArray([
		tr("已排定目标") if value.participant_id == queued_id else tr("点选为目标") if value.targetable else tr("不能选为目标"),
		tr("可以行动") if value.available else tr("无法行动"),
	])
	if value.busy_value != 0:
		states.append(tr("忙碌 %d") % value.busy_value)
	if value.life_status == CombatSliceLifeStatus.Value.DEAD or value.threshold == CharacterState.LifeThreshold.DEAD:
		states.append(tr("死亡"))
	elif value.life_status == CombatSliceLifeStatus.Value.UNCONSCIOUS or value.threshold == CharacterState.LifeThreshold.UNCONSCIOUS:
		states.append(tr("昏迷"))
	var knockout: BattleKnockoutProjection = value.knockout
	if knockout != null:
		states.append(tr("约 {n} 秒后醒来").format({"n": knockout.revive_seconds}))
	_status.text = " · ".join(states)
	_status.tooltip_text = _status.text
	var intents := PackedStringArray()
	if not value.next_move_tag.is_empty():
		# TRANSLATORS: an enemy's card: the tag of the move it will use next (起手式): 快 / 重 / 虚 / 守.
		intents.append(tr("起手：%s") % CombatMoveTags.label(value.next_move_tag))
	if not value.telegraph.is_empty():
		# TRANSLATORS: an enemy's card: the special it announced for its next move.
		intents.append(tr("要出「%s」") % value.telegraph)
	_intent.text = " · ".join(intents)
	_intent.tooltip_text = CombatMoveTags.description(value.next_move_tag) if not value.next_move_tag.is_empty() else _intent.text
	_intent.visible = not intents.is_empty()
	_present_choice(value, knockout)


## The card of one held for the player's choice: 了结 (marked when it does 朱鸿雪's task or
## kills the player's master) and 放过 in place of picking the card as a target.
func _present_choice(value: BattleParticipantProjection, knockout: BattleKnockoutProjection) -> void:
	choice_row.visible = knockout != null
	# The card's own button covers it: away while the choice shows (one held is no target).
	target_button.visible = knockout == null
	if knockout == null:
		return
	var name: String = tr(value.display_name)
	var marks := PackedStringArray()
	if knockout.quest_target:
		# TRANSLATORS: on the 了结 button: killing them does the task 朱鸿雪 gave.
		marks.append(tr("任务目标"))
	if knockout.own_master:
		# TRANSLATORS: on the 了结 button: they are the player's own master (killing them leaves the family).
		marks.append(tr("弑师"))
	# TRANSLATORS: the 了结 button with what killing them means: {marks} is 任务目标 and/or 弑师.
	finish_button.text = tr(FINISH_LABEL) if marks.is_empty() else tr("了结（{marks}）").format({"marks": tr("、").join(marks)})
	# TRANSLATORS: hover on 了结: {name} lies unconscious; the next blow of the player's side (theirs or what they called) kills them.
	finish_button.tooltip_text = tr("了结{name}：下一招就会要了{name}的命。").format({"name": name})
	spare_button.text = tr(SPARE_LABEL)
	# TRANSLATORS: hover on 放过: nobody on the player's side strikes {name} again; they lie there and come to on their own.
	spare_button.tooltip_text = tr("放{name}一条生路：你这一方不再出手，{name}昏在原地，到时自己醒来。").format({"name": name})


func _show_vitality(id: StringName, current: int) -> void:
	var same: bool = id == _shown_id
	var lost: bool = same and current < _shown_vitality
	var moved: bool = not same or current != _shown_vitality
	_shown_id = id
	_shown_vitality = current
	if not moved:
		return
	var feel: FeelDefinition = GameContent.catalog().pacing().feel
	if _bar != null and _bar.is_valid():
		_bar.kill()
	if same and feel.bar_tween_seconds > 0.0:
		_bar = create_tween()
		_bar.tween_property(_vitality, "value", float(current), feel.bar_tween_seconds)
	else:
		_vitality.value = current
	if lost and BattlePace.hit_flash and feel.hit_flash_seconds > 0.0:
		if _flash != null and _flash.is_valid():
			_flash.kill()
		self_modulate = HIT_COLOR
		_flash = create_tween()
		_flash.tween_property(self, "self_modulate", Color.WHITE, feel.hit_flash_seconds)


## A finished fight's last blow on the card.
func show_final_vitality(vitality: CharacterResourceState) -> void:
	if _shown_resources.size() == 3:
		_show_resources(_shown_id, [BattleResourceProjection.new(vitality.current, vitality.effective, vitality.maximum), _shown_resources[1], _shown_resources[2]])


func _show_resources(id: StringName, resources: Array[BattleResourceProjection]) -> void:
	_vitality.max_value = maxf(1, resources[0].maximum) # Visual scale only; text retains exact values.
	_show_vitality(id, resources[0].current)
	_shown_resources = resources
	_primary.text = tr("气 %s\n精 %s · 神 %s") % [_track(resources[0]), _track(resources[1]), _track(resources[2])]


## The 气 bar's value now (the tween's, while it moves).
func vitality_shown() -> float:
	return _vitality.value


func _request_target() -> void:
	target_requested.emit(_participant_id)


static func _track(value: BattleResourceProjection) -> String:
	return "%d/%d/%d" % [value.current, value.effective, value.maximum]


func _choice_button(node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = Vector2(96, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_row.add_child(button)
	return button


static func _label(parent: Node) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 16)
	parent.add_child(label)
	return label
