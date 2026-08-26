class_name StandardForceReflectionMutationResult
extends RefCounted

var _damage_transition_completed: bool
var _wound_transition_completed: bool
var _requested_damage: int
var _requested_wound: int
var _vitality_current_before: int
var _vitality_effective_before: int
var _vitality_current_after_damage: int
var _vitality_effective_after_damage: int
var _vitality_current_after_wound: int
var _vitality_effective_after_wound: int

var damage_transition_completed: bool:
	get:
		return _damage_transition_completed
var wound_transition_completed: bool:
	get:
		return _wound_transition_completed
var requested_damage: int:
	get:
		return _requested_damage
var requested_wound: int:
	get:
		return _requested_wound
var vitality_current_before: int:
	get:
		return _vitality_current_before
var vitality_effective_before: int:
	get:
		return _vitality_effective_before
var vitality_current_after_damage: int:
	get:
		return _vitality_current_after_damage
var vitality_effective_after_damage: int:
	get:
		return _vitality_effective_after_damage
var vitality_current_after_wound: int:
	get:
		return _vitality_current_after_wound
var vitality_effective_after_wound: int:
	get:
		return _vitality_effective_after_wound


func _init(
	p_damage_transition_completed: bool = false,
	p_wound_transition_completed: bool = false,
	p_requested_damage: int = 0,
	p_requested_wound: int = 0,
	p_vitality_current_before: int = 0,
	p_vitality_effective_before: int = 0,
	p_vitality_current_after_damage: int = 0,
	p_vitality_effective_after_damage: int = 0,
	p_vitality_current_after_wound: int = 0,
	p_vitality_effective_after_wound: int = 0,
) -> void:
	_damage_transition_completed = p_damage_transition_completed
	_wound_transition_completed = p_wound_transition_completed
	_requested_damage = p_requested_damage
	_requested_wound = p_requested_wound
	_vitality_current_before = p_vitality_current_before
	_vitality_effective_before = p_vitality_effective_before
	_vitality_current_after_damage = p_vitality_current_after_damage
	_vitality_effective_after_damage = p_vitality_effective_after_damage
	_vitality_current_after_wound = p_vitality_current_after_wound
	_vitality_effective_after_wound = p_vitality_effective_after_wound


func duplicate_snapshot() -> StandardForceReflectionMutationResult:
	return StandardForceReflectionMutationResult.new(
		_damage_transition_completed,
		_wound_transition_completed,
		_requested_damage,
		_requested_wound,
		_vitality_current_before,
		_vitality_effective_before,
		_vitality_current_after_damage,
		_vitality_effective_after_damage,
		_vitality_current_after_wound,
		_vitality_effective_after_wound,
	)
