class_name CombatFightDecisionFacts
extends RefCounted

var _attacker_id: StringName
var _attacker_living: bool
var _target_visible: bool
var _perception: CombatPerceptionSkillProjection
var _attacker_raw_courage: int
var _attacker_raw_bellicosity: int
var _victim_id: StringName
var _victim_living: bool
var _victim_busy: bool
var _victim_raw_composure: int

var attacker_id: StringName:
	get:
		return _attacker_id
var attacker_living: bool:
	get:
		return _attacker_living
var target_visible: bool:
	get:
		return _target_visible
var perception: CombatPerceptionSkillProjection:
	get:
		return _perception.duplicate_snapshot() if _perception != null else null
var attacker_raw_courage: int:
	get:
		return _attacker_raw_courage
var attacker_raw_bellicosity: int:
	get:
		return _attacker_raw_bellicosity
var victim_id: StringName:
	get:
		return _victim_id
var victim_living: bool:
	get:
		return _victim_living
var victim_busy: bool:
	get:
		return _victim_busy
var victim_raw_composure: int:
	get:
		return _victim_raw_composure


func _init(
	p_attacker_id: StringName = &"",
	p_attacker_living: bool = false,
	p_target_visible: bool = true,
	p_perception: CombatPerceptionSkillProjection = null,
	p_attacker_raw_courage: int = 0,
	p_attacker_raw_bellicosity: int = 0,
	p_victim_id: StringName = &"",
	p_victim_living: bool = false,
	p_victim_busy: bool = false,
	p_victim_raw_composure: int = 0,
) -> void:
	_attacker_id = p_attacker_id
	_attacker_living = p_attacker_living
	_target_visible = p_target_visible
	_perception = (
		p_perception.duplicate_snapshot()
		if p_perception != null
		else null
	)
	_attacker_raw_courage = p_attacker_raw_courage
	_attacker_raw_bellicosity = p_attacker_raw_bellicosity
	_victim_id = p_victim_id
	_victim_living = p_victim_living
	_victim_busy = p_victim_busy
	_victim_raw_composure = p_victim_raw_composure


func has_valid_identity() -> bool:
	return (
		not _attacker_id.is_empty()
		and not _victim_id.is_empty()
		and _attacker_id != _victim_id
	)


func duplicate_snapshot() -> CombatFightDecisionFacts:
	return CombatFightDecisionFacts.new(
		_attacker_id,
		_attacker_living,
		_target_visible,
		_perception,
		_attacker_raw_courage,
		_attacker_raw_bellicosity,
		_victim_id,
		_victim_living,
		_victim_busy,
		_victim_raw_composure,
	)

