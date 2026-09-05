class_name BattleParticipantProjection
extends RefCounted

## Read-only value snapshot; retains no mutable gameplay authority.
var _participant_id: StringName
var participant_id: StringName:
	get: return _participant_id
var _display_name: String
var display_name: String:
	get: return _display_name
var _side_id: StringName
var side_id: StringName:
	get: return _side_id
var _hostile_to_player: bool
var hostile_to_player: bool:
	get: return _hostile_to_player
var _current_target_id: StringName
var current_target_id: StringName:
	get: return _current_target_id
var _vitality: BattleResourceProjection
var vitality: BattleResourceProjection:
	get: return _vitality
var _essence: BattleResourceProjection
var essence: BattleResourceProjection:
	get: return _essence
var _spirit: BattleResourceProjection
var spirit: BattleResourceProjection:
	get: return _spirit
var _force: BattleResourceProjection
var force: BattleResourceProjection:
	get: return _force
var _mana: BattleResourceProjection
var mana: BattleResourceProjection:
	get: return _mana
var _atman: BattleResourceProjection
var atman: BattleResourceProjection:
	get: return _atman
var _busy_value: int
var busy_value: int:
	get: return _busy_value
var _life_status: int
var life_status: int:
	get: return _life_status
var _threshold: int
var threshold: int:
	get: return _threshold
var _available: bool
var available: bool:
	get: return _available


func _init(
	p_participant_id: StringName = &"",
	p_display_name: String = "",
	p_side_id: StringName = &"",
	p_hostile_to_player: bool = false,
	p_current_target_id: StringName = &"",
	p_vitality: BattleResourceProjection = null,
	p_essence: BattleResourceProjection = null,
	p_spirit: BattleResourceProjection = null,
	p_force: BattleResourceProjection = null,
	p_mana: BattleResourceProjection = null,
	p_atman: BattleResourceProjection = null,
	p_busy_value: int = 0,
	p_life_status: int = 0,
	p_threshold: int = 0,
	p_available: bool = false,
) -> void:
	_participant_id = p_participant_id
	_display_name = p_display_name
	_side_id = p_side_id
	_hostile_to_player = p_hostile_to_player
	_current_target_id = p_current_target_id
	_vitality = p_vitality
	_essence = p_essence
	_spirit = p_spirit
	_force = p_force
	_mana = p_mana
	_atman = p_atman
	_busy_value = p_busy_value
	_life_status = p_life_status
	_threshold = p_threshold
	_available = p_available
