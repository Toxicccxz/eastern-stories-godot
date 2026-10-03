class_name BattleParticipantCard
extends PanelContainer

signal target_requested(participant_id: StringName)

var target_button: Button
var _participant_id: StringName
var _ordinary_border: StyleBoxFlat
var _current_border: StyleBoxFlat

var _title: Label
var _vitality: ProgressBar
var _primary: Label
var _secondary: Label
var _status: Label


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


func present(value: BattleParticipantProjection, player_id: StringName, current_id: StringName, queued_id: StringName = &"") -> void:
	_participant_id = value.participant_id
	target_button.disabled = not value.targetable
	target_button.tooltip_text = tr("选为目标：%s") % tr(value.display_name) if value.targetable else tr("不能选为目标")
	var role: String = tr("你") if value.participant_id == player_id else tr("当前目标") if value.participant_id == current_id else tr("对手") if value.hostile_to_player else tr("参战")
	_title.text = "%s · %s" % [tr(value.display_name), role]
	_title.tooltip_text = _title.text
	var border: StyleBoxFlat = _current_border if value.participant_id == current_id else _ordinary_border
	if get_theme_stylebox("panel") != border:
		add_theme_stylebox_override("panel", border)
	_vitality.max_value = maxf(1, value.vitality.maximum) # Visual scale only; text retains exact values.
	_vitality.value = value.vitality.current
	_primary.text = tr("气 %s\n精 %s · 神 %s") % [_track(value.vitality), _track(value.essence), _track(value.spirit)]
	_primary.tooltip_text = "当前／有效／上限"
	_secondary.text = tr("内力 %d/%d · 法力 %d/%d · 灵力 %d/%d") % [value.force.current, value.force.maximum, value.mana.current, value.mana.maximum, value.atman.current, value.atman.maximum]
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
	_status.text = " · ".join(states)
	_status.tooltip_text = _status.text


func _request_target() -> void:
	target_requested.emit(_participant_id)


static func _track(value: BattleResourceProjection) -> String:
	return "%d/%d/%d" % [value.current, value.effective, value.maximum]


static func _label(parent: Node) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 16)
	parent.add_child(label)
	return label
