class_name OldPineOutdoorHud
extends CanvasLayer

const MAX_LOG_LINES: int = 6
const WorldPlayerRuntimeType := preload(
	"res://runtime/characters/world_player_runtime_state.gd"
)

@onready var player_vitality: ProgressBar = %PlayerVitality
@onready var player_vitality_text: Label = %PlayerVitalityText
@onready var selected_target_label: Label = %SelectedTargetLabel
@onready var target_vitality: ProgressBar = %TargetVitality
@onready var target_vitality_text: Label = %TargetVitalityText
@onready var inspect_button: Button = %InspectButton
@onready var attack_button: Button = %AttackButton
@onready var portal_button: Button = %PortalButton
@onready var inspection_text: RichTextLabel = %InspectionText
@onready var combat_log: RichTextLabel = %CombatLog

var _player: WorldPlayerRuntimeType
var _selected_target: NpcRuntimeState
var _selected_landmark: WorldLandmarkDefinition
var _selected_landmark_source_available: bool = false
var _log_lines: Array[String] = []


func configure(player: WorldPlayerRuntimeType) -> bool:
	if player == null or not player.is_valid():
		return false
	_player = player
	set_selected_target(null)
	refresh_live_state()
	return true


func set_selected_target(target: NpcRuntimeState) -> void:
	_selected_target = target
	_selected_landmark = null
	_selected_landmark_source_available = false
	inspection_text.text = ""
	if target == null:
		selected_target_label.text = "Selected: none"
	else:
		selected_target_label.text = "Selected: %s" % target.definition().display_name
	refresh_live_state()


func set_selected_landmark(
	landmark: WorldLandmarkDefinition,
	source_available: bool,
) -> void:
	_selected_target = null
	_selected_landmark = landmark
	_selected_landmark_source_available = source_available
	inspection_text.text = ""
	selected_target_label.text = (
		"Selected: none"
		if landmark == null
		else "Selected landmark: %s" % landmark.display_name
	)
	refresh_live_state()


func set_selected_landmark_source_available(value: bool) -> void:
	_selected_landmark_source_available = value
	refresh_live_state()


func show_inspection(definition: NpcDefinition) -> void:
	if definition == null:
		inspection_text.text = ""
		return
	inspection_text.text = "%s\n%s" % [
		definition.display_name,
		definition.description.strip_edges(),
	]


func show_landmark_inspection(definition: WorldLandmarkDefinition) -> void:
	if definition == null:
		inspection_text.text = ""
		return
	inspection_text.text = "%s\n%s" % [
		definition.display_name,
		definition.description.strip_edges(),
	]


func refresh_live_state() -> void:
	if _player != null:
		_update_vitality(
			_player.state.vitality,
			player_vitality,
			player_vitality_text,
		)
	if _selected_target == null:
		target_vitality.value = 0.0
		target_vitality_text.text = "-"
	else:
		_update_vitality(
			_selected_target.character_state.vitality,
			target_vitality,
			target_vitality_text,
		)
	var target_available: bool = (
		_selected_target != null
		and _selected_target.exists_in_map
		and _selected_target.life_status != CharacterRuntimeLifeStatus.Value.DEAD
	)
	var landmark_available: bool = (
		_selected_landmark != null and _selected_landmark.is_valid()
	)
	var player_available: bool = (
		_player != null
		and _player.exists_in_world
		and _player.life_status == CharacterRuntimeLifeStatus.Value.ACTIVE
	)
	inspect_button.disabled = not target_available and not landmark_available
	attack_button.disabled = not target_available or not player_available
	portal_button.disabled = (
		not landmark_available
		or not _selected_landmark_source_available
		or not player_available
	)
	portal_button.text = (
		"Traverse"
		if _selected_landmark == null
		else _selected_landmark.action_label
	)


func append_log_lines(lines: Array[String]) -> void:
	for line: String in lines:
		if not line.is_empty():
			_log_lines.append(line)
	while _log_lines.size() > MAX_LOG_LINES:
		_log_lines.pop_front()
	combat_log.text = "\n".join(_log_lines)


func log_lines() -> Array[String]:
	return _log_lines.duplicate()


func selected_target_text() -> String:
	return selected_target_label.text


func inspection_display() -> String:
	return inspection_text.text


func attack_is_enabled() -> bool:
	return not attack_button.disabled


func portal_action_is_enabled() -> bool:
	return not portal_button.disabled


func portal_action_text() -> String:
	return portal_button.text


func _update_vitality(
	resource: CharacterResourceState,
	bar: ProgressBar,
	text_label: Label,
) -> void:
	bar.min_value = 0.0
	bar.max_value = float(maxi(resource.maximum, 1))
	bar.value = float(clampi(resource.current, 0, maxi(resource.maximum, 1)))
	text_label.text = "%d / %d / %d" % [
		resource.current,
		resource.effective,
		resource.maximum,
	]
