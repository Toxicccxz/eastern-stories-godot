class_name CombatRiposteRequest
extends RefCounted

## Terminal continuation from combatd.c::do_attack(). The future consumer must
## project live reverse state and call the direct attack-execution path; this
## request deliberately contains no CombatAttackInput or authority reference.
var _has_request: bool
var _attacker_id: StringName
var _victim_id: StringName
var _attack_type: int
var _triggering_forward_action_id: StringName
var _triggering_legacy_damage: int
var _random_bound: int
var _random_draw: int

var has_request: bool:
	get:
		return _has_request
var attacker_id: StringName:
	get:
		return _attacker_id
var victim_id: StringName:
	get:
		return _victim_id
var attack_type: int:
	get:
		return _attack_type
var triggering_forward_action_id: StringName:
	get:
		return _triggering_forward_action_id
var triggering_legacy_damage: int:
	get:
		return _triggering_legacy_damage
var random_bound: int:
	get:
		return _random_bound
var random_draw: int:
	get:
		return _random_draw


func _init(
	p_has_request: bool = false,
	p_attacker_id: StringName = &"",
	p_victim_id: StringName = &"",
	p_attack_type: int = -1,
	p_triggering_forward_action_id: StringName = &"",
	p_triggering_legacy_damage: int = 0,
	p_random_bound: int = 0,
	p_random_draw: int = 0,
) -> void:
	_has_request = p_has_request
	_attacker_id = p_attacker_id
	_victim_id = p_victim_id
	_attack_type = p_attack_type
	_triggering_forward_action_id = p_triggering_forward_action_id
	_triggering_legacy_damage = p_triggering_legacy_damage
	_random_bound = p_random_bound
	_random_draw = p_random_draw


func is_valid() -> bool:
	return (
		_has_request
		and not _attacker_id.is_empty()
		and not _victim_id.is_empty()
		and _attacker_id != _victim_id
		and (
			_attack_type == CombatAttackType.Value.QUICK
			or _attack_type == CombatAttackType.Value.RIPOSTE
		)
		and not _triggering_forward_action_id.is_empty()
		and _random_bound > 0
		and _random_draw >= 0
		and _random_draw < _random_bound
	)


func duplicate_snapshot() -> CombatRiposteRequest:
	return CombatRiposteRequest.new(
		_has_request,
		_attacker_id,
		_victim_id,
		_attack_type,
		_triggering_forward_action_id,
		_triggering_legacy_damage,
		_random_bound,
		_random_draw,
	)
