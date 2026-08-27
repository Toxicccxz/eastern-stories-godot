class_name CombatProgressionFacts
extends RefCounted

var _character_id: StringName
var _is_user: bool
var _base_intelligence: int
var _base_spirituality: int
var _attack_skill_definition_id: StringName
var _attack_skill_definition_available: bool

var character_id: StringName:
	get:
		return _character_id
var is_user: bool:
	get:
		return _is_user
var base_intelligence: int:
	get:
		return _base_intelligence
var base_spirituality: int:
	get:
		return _base_spirituality
var attack_skill_definition_id: StringName:
	get:
		return _attack_skill_definition_id
var attack_skill_definition_available: bool:
	get:
		return _attack_skill_definition_available


func _init(
	p_character_id: StringName = &"",
	p_is_user: bool = false,
	p_base_intelligence: int = 0,
	p_base_spirituality: int = 0,
	p_attack_skill_definition_id: StringName = &"unarmed",
	p_attack_skill_definition_available: bool = true,
) -> void:
	_character_id = p_character_id
	_is_user = p_is_user
	_base_intelligence = p_base_intelligence
	_base_spirituality = p_base_spirituality
	_attack_skill_definition_id = p_attack_skill_definition_id
	_attack_skill_definition_available = p_attack_skill_definition_available


func is_valid() -> bool:
	return (
		not _character_id.is_empty()
		and not _attack_skill_definition_id.is_empty()
	)


func has_attack_skill_definition(skill_id: StringName) -> bool:
	return (
		_attack_skill_definition_available
		and _attack_skill_definition_id == skill_id
	)


func duplicate_snapshot() -> CombatProgressionFacts:
	return CombatProgressionFacts.new(
		_character_id,
		_is_user,
		_base_intelligence,
		_base_spirituality,
		_attack_skill_definition_id,
		_attack_skill_definition_available,
	)
