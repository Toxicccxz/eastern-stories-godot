class_name CombatAttackerSnapshot
extends RefCounted

var _character_id: StringName
var _living: bool
var _combat_experience: int
var _current_spirit: int
var _maximum_spirit: int
var _projected_attack_skill_type: StringName
var _effective_attack_skill_level: int
var _attack_usage_bonus: int
var _projected_apply_damage: int
var _strength_projection: CombatStrengthProjection
var _lethal_intent: bool
var _mapped_force_skill_id: StringName
var _force_hit_policy_status: int
var _mapped_attack_skill_id: StringName
var _martial_hit_policy_status: int
var _attacker_hit_policy_status: int
var _weapon_profile: WeaponCombatProfile
var _projected_force_skill_type: StringName
var _effective_force_skill_level: int

var character_id: StringName:
	get:
		return _character_id
var living: bool:
	get:
		return _living
var combat_experience: int:
	get:
		return _combat_experience
var current_spirit: int:
	get:
		return _current_spirit
var maximum_spirit: int:
	get:
		return _maximum_spirit
var projected_attack_skill_type: StringName:
	get:
		return _projected_attack_skill_type
var effective_attack_skill_level: int:
	get:
		return _effective_attack_skill_level
var attack_usage_bonus: int:
	get:
		return _attack_usage_bonus
var projected_apply_damage: int:
	get:
		return _projected_apply_damage
var strength_projection: CombatStrengthProjection:
	get:
		return _strength_projection.duplicate_snapshot()
var lethal_intent: bool:
	get:
		return _lethal_intent
var mapped_force_skill_id: StringName:
	get:
		return _mapped_force_skill_id
var force_hit_policy_status: int:
	get:
		return _force_hit_policy_status
var mapped_attack_skill_id: StringName:
	get:
		return _mapped_attack_skill_id
var martial_hit_policy_status: int:
	get:
		return _martial_hit_policy_status
var attacker_hit_policy_status: int:
	get:
		return _attacker_hit_policy_status
var weapon_profile: WeaponCombatProfile:
	get:
		return _weapon_profile.duplicate_snapshot() if _weapon_profile != null else null
var has_weapon: bool:
	get:
		return _weapon_profile != null
var projected_force_skill_type: StringName:
	get:
		return _projected_force_skill_type
var effective_force_skill_level: int:
	get:
		return _effective_force_skill_level


func _init(
	p_character_id: StringName = &"",
	p_living: bool = true,
	p_combat_experience: int = 0,
	p_current_spirit: int = 0,
	p_maximum_spirit: int = 0,
	p_projected_attack_skill_type: StringName = &"unarmed",
	p_effective_attack_skill_level: int = 0,
	p_attack_usage_bonus: int = 0,
	p_projected_apply_damage: int = 0,
	p_strength_projection: CombatStrengthProjection = null,
	p_lethal_intent: bool = false,
	p_mapped_force_skill_id: StringName = &"",
	p_force_hit_policy_status: int = CombatHitPolicyStatus.Value.NOT_APPLICABLE,
	p_mapped_attack_skill_id: StringName = &"",
	p_martial_hit_policy_status: int = CombatHitPolicyStatus.Value.NOT_APPLICABLE,
	p_attacker_hit_policy_status: int = CombatHitPolicyStatus.Value.NOT_APPLICABLE,
	p_weapon_profile: WeaponCombatProfile = null,
	p_projected_force_skill_type: StringName = &"force",
	p_effective_force_skill_level: int = 0,
) -> void:
	_character_id = p_character_id
	_living = p_living
	_combat_experience = p_combat_experience
	_current_spirit = p_current_spirit
	_maximum_spirit = p_maximum_spirit
	_projected_attack_skill_type = p_projected_attack_skill_type
	_effective_attack_skill_level = p_effective_attack_skill_level
	_attack_usage_bonus = p_attack_usage_bonus
	_projected_apply_damage = p_projected_apply_damage
	_strength_projection = (
		p_strength_projection.duplicate_snapshot()
		if p_strength_projection != null
		else CombatStrengthProjection.new()
	)
	_lethal_intent = p_lethal_intent
	_mapped_force_skill_id = p_mapped_force_skill_id
	_force_hit_policy_status = p_force_hit_policy_status
	_mapped_attack_skill_id = p_mapped_attack_skill_id
	_martial_hit_policy_status = p_martial_hit_policy_status
	_attacker_hit_policy_status = p_attacker_hit_policy_status
	_weapon_profile = (
		p_weapon_profile.duplicate_snapshot() if p_weapon_profile != null else null
	)
	_projected_force_skill_type = p_projected_force_skill_type
	_effective_force_skill_level = p_effective_force_skill_level


func is_valid() -> bool:
	return (
		not _character_id.is_empty()
		and not _projected_attack_skill_type.is_empty()
		and not _projected_force_skill_type.is_empty()
		and CombatHitPolicyStatus.is_valid(_force_hit_policy_status)
		and CombatHitPolicyStatus.is_non_force_valid(_martial_hit_policy_status)
		and CombatHitPolicyStatus.is_non_force_valid(_attacker_hit_policy_status)
		and (_mapped_force_skill_id.is_empty())
		== (_force_hit_policy_status == CombatHitPolicyStatus.Value.NOT_APPLICABLE)
		and (_mapped_attack_skill_id.is_empty())
		== (_martial_hit_policy_status == CombatHitPolicyStatus.Value.NOT_APPLICABLE)
		and (
			_weapon_profile != null
			or _attacker_hit_policy_status != CombatHitPolicyStatus.Value.NOT_APPLICABLE
		)
		and (_weapon_profile == null or _weapon_profile.is_valid())
	)


func duplicate_snapshot() -> CombatAttackerSnapshot:
	return CombatAttackerSnapshot.new(
		_character_id,
		_living,
		_combat_experience,
		_current_spirit,
		_maximum_spirit,
		_projected_attack_skill_type,
		_effective_attack_skill_level,
		_attack_usage_bonus,
		_projected_apply_damage,
		_strength_projection,
		_lethal_intent,
		_mapped_force_skill_id,
		_force_hit_policy_status,
		_mapped_attack_skill_id,
		_martial_hit_policy_status,
		_attacker_hit_policy_status,
		_weapon_profile,
		_projected_force_skill_type,
		_effective_force_skill_level,
	)
