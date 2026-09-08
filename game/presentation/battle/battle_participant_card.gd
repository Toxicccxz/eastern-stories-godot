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
	target_button.tooltip_text = "Select target: " + value.display_name if value.targetable else "Not targetable"
	_title.text = value.display_name + (" · You" if value.participant_id == player_id else " · Current Target" if value.participant_id == current_id else " · Hostile" if value.hostile_to_player else " · Participant")
	_title.tooltip_text = "%s\n%s" % [_title.text, value.participant_id]
	var border: StyleBoxFlat = _current_border if value.participant_id == current_id else _ordinary_border
	if get_theme_stylebox("panel") != border:
		add_theme_stylebox_override("panel", border)
	_vitality.max_value = maxf(1, value.vitality.maximum) # Visual scale only; text retains exact values.
	_vitality.value = value.vitality.current
	_primary.text = "Vitality %s\nEssence %s · Spirit %s" % [_track(value.vitality), _track(value.essence), _track(value.spirit)]
	_primary.tooltip_text = "Current / effective / maximum (kee / gin / sen)"
	_secondary.text = "Force %d/%d · Mana %d/%d · Atman %d/%d" % [value.force.current, value.force.maximum, value.mana.current, value.mana.maximum, value.atman.current, value.atman.maximum]
	_secondary.tooltip_text = _secondary.text
	_status.text = "%s%s%s" % [
		"Available" if value.available else "Unavailable",
		" · Busy %d" % value.busy_value if value.busy_value != 0 else " · Not busy",
		" · %s" % String(CharacterState.LifeThreshold.keys()[value.threshold]).capitalize() if value.threshold != CharacterState.LifeThreshold.ACTIVE else "",
	]
	if value.life_status != CombatSliceLifeStatus.Value.ACTIVE:
		_status.text += " · %s" % String(CombatSliceLifeStatus.Value.keys()[value.life_status]).capitalize()
	_status.text = ("QUEUED TARGET · " if value.participant_id == queued_id else "Select target · " if value.targetable else "Not targetable · ") + _status.text
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
