class_name BattleParticipantCard
extends PanelContainer

var _title: Label
var _vitality: ProgressBar
var _primary: Label
var _secondary: Label
var _status: Label


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 0)
	add_child(content)
	_title = _label(content)
	_title.add_theme_color_override("font_color", Color("efc77b"))
	_vitality = ProgressBar.new()
	_vitality.custom_minimum_size.y = 8
	_vitality.show_percentage = false
	content.add_child(_vitality)
	_primary = _label(content)
	_secondary = _label(content)
	_status = _label(content)


func present(value: BattleParticipantProjection, player_id: StringName, current_id: StringName) -> void:
	_title.text = value.display_name + (" · You" if value.participant_id == player_id else " · Current Target" if value.participant_id == current_id else " · Hostile" if value.hostile_to_player else " · Participant")
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


static func _track(value: BattleResourceProjection) -> String:
	return "%d/%d/%d" % [value.current, value.effective, value.maximum]


static func _label(parent: Node) -> Label:
	var label := Label.new()
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 16)
	parent.add_child(label)
	return label
