class_name CombatSliceHud
extends CanvasLayer

const MAX_LOG_LINES: int = 4

@onready var player_vitality: ProgressBar = %PlayerVitality
@onready var player_vitality_text: Label = %PlayerVitalityText
@onready var target_name: Label = %TargetName
@onready var enemy_vitality: ProgressBar = %EnemyVitality
@onready var enemy_vitality_text: Label = %EnemyVitalityText
@onready var selected_target_label: Label = %SelectedTargetLabel
@onready var attack_button: Button = %AttackButton
@onready var combat_log: RichTextLabel = %CombatLog

var _player: CombatSliceCharacterBinding
var _enemy: CombatSliceCharacterBinding
var _target_selected: bool = false
var _combat_started: bool = false
var _log_lines: Array[String] = []


func configure(
	player: CombatSliceCharacterBinding,
	enemy: CombatSliceCharacterBinding,
) -> bool:
	if player == null or enemy == null or not player.is_valid() or not enemy.is_valid():
		return false
	_player = player
	_enemy = enemy
	target_name.text = "Human Swordfighter"
	set_target_selected(false)
	refresh_live_state()
	return true


func set_target_selected(value: bool) -> void:
	_target_selected = value
	selected_target_label.text = (
		"Selected: Human Swordfighter" if value else "Selected: none"
	)
	_update_attack_button()


func set_combat_started(value: bool) -> void:
	_combat_started = value
	_update_attack_button()


func set_target_terminal_status(status: int) -> void:
	if status == CombatSliceLifeStatus.Value.DEAD:
		selected_target_label.text = "Selected: Human Swordfighter (dead)"
	elif status == CombatSliceLifeStatus.Value.UNCONSCIOUS:
		selected_target_label.text = "Selected: Human Swordfighter (unconscious)"
	_update_attack_button()


func refresh_live_state() -> void:
	if _player != null:
		_update_vitality(
			_player.state.vitality,
			player_vitality,
			player_vitality_text,
		)
	if _enemy != null:
		_update_vitality(
			_enemy.state.vitality,
			enemy_vitality,
			enemy_vitality_text,
		)


func append_log_lines(lines: Array[String]) -> void:
	for line: String in lines:
		if line.is_empty():
			continue
		_log_lines.append(line)
	while _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	combat_log.text = "\n".join(_log_lines)


func log_lines() -> Array[String]:
	return _log_lines.duplicate()


func attack_is_enabled() -> bool:
	return not attack_button.disabled


func player_vitality_display() -> String:
	return player_vitality_text.text


func enemy_vitality_display() -> String:
	return enemy_vitality_text.text


func _update_vitality(
	resource: CharacterResourceState,
	bar: ProgressBar,
	text_label: Label,
) -> void:
	bar.min_value = 0.0
	bar.max_value = float(resource.maximum)
	bar.value = float(clampi(resource.current, 0, resource.maximum))
	text_label.text = "%d / %d / %d" % [
		resource.current,
		resource.effective,
		resource.maximum,
	]


func _update_attack_button() -> void:
	var player_active: bool = (
		_player != null
		and _player.exists_in_encounter
		and _player.life_status == CombatSliceLifeStatus.Value.ACTIVE
	)
	var enemy_active: bool = (
		_enemy != null
		and _enemy.exists_in_encounter
		and _enemy.life_status == CombatSliceLifeStatus.Value.ACTIVE
	)
	attack_button.disabled = (
		not _target_selected or _combat_started or not player_active or not enemy_active
	)
