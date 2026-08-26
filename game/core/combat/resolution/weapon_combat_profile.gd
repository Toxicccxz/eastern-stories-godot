class_name WeaponCombatProfile
extends RefCounted

## Immutable projection of the primary weapon facts read by do_attack().
## This type does not own an Item/Equipment authority. Final apply/damage is a
## character aggregate and therefore belongs to CombatAttackerSnapshot.
var _weapon_id: StringName
var _skill_type: StringName
var _hit_policy_status: int

var weapon_id: StringName:
	get:
		return _weapon_id
var skill_type: StringName:
	get:
		return _skill_type
var hit_policy_status: int:
	get:
		return _hit_policy_status


func _init(
	p_weapon_id: StringName = &"",
	p_skill_type: StringName = &"",
	p_hit_policy_status: int = CombatHitPolicyStatus.Value.NOT_APPLICABLE,
) -> void:
	_weapon_id = p_weapon_id
	_skill_type = p_skill_type
	_hit_policy_status = p_hit_policy_status


func is_valid() -> bool:
	return (
		not _weapon_id.is_empty()
		and not _skill_type.is_empty()
		and CombatHitPolicyStatus.is_valid(_hit_policy_status)
		and _hit_policy_status != CombatHitPolicyStatus.Value.NOT_APPLICABLE
	)


func duplicate_snapshot() -> WeaponCombatProfile:
	return WeaponCombatProfile.new(
		_weapon_id,
		_skill_type,
		_hit_policy_status,
	)
