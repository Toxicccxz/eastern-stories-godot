class_name CombatReverseModifierProjection
extends RefCounted

## Typed post-forward projection of the legacy apply/* scalars consumed by the
## reverse ordinary body. Stable IDs bind the separately projected scalars to
## the same reverse characters without introducing a generic modifier map.
var _attacker_character_id: StringName
var _defender_character_id: StringName
var _attacker_attack_skill_modifier: int
var _attacker_force_skill_modifier: int
var _defender_dodge_skill_modifier: int
var _defender_parry_skill_modifier: int
var _defender_unarmed_skill_modifier: int
var _defender_force_skill_modifier: int
var _attacker_attack_usage_bonus: int
var _defender_defense_usage_bonus: int
var _attacker_apply_damage: int
var _defender_armor: int
var _defender_armor_vs_force: int

var attacker_character_id: StringName:
	get:
		return _attacker_character_id
var defender_character_id: StringName:
	get:
		return _defender_character_id
var attacker_attack_skill_modifier: int:
	get:
		return _attacker_attack_skill_modifier
var attacker_force_skill_modifier: int:
	get:
		return _attacker_force_skill_modifier
var defender_dodge_skill_modifier: int:
	get:
		return _defender_dodge_skill_modifier
var defender_parry_skill_modifier: int:
	get:
		return _defender_parry_skill_modifier
var defender_unarmed_skill_modifier: int:
	get:
		return _defender_unarmed_skill_modifier
var defender_force_skill_modifier: int:
	get:
		return _defender_force_skill_modifier
var attacker_attack_usage_bonus: int:
	get:
		return _attacker_attack_usage_bonus
var defender_defense_usage_bonus: int:
	get:
		return _defender_defense_usage_bonus
var attacker_apply_damage: int:
	get:
		return _attacker_apply_damage
var defender_armor: int:
	get:
		return _defender_armor
var defender_armor_vs_force: int:
	get:
		return _defender_armor_vs_force


func _init(
	p_attacker_character_id: StringName = &"",
	p_defender_character_id: StringName = &"",
	p_attacker_attack_skill_modifier: int = 0,
	p_attacker_force_skill_modifier: int = 0,
	p_defender_dodge_skill_modifier: int = 0,
	p_defender_parry_skill_modifier: int = 0,
	p_defender_unarmed_skill_modifier: int = 0,
	p_defender_force_skill_modifier: int = 0,
	p_attacker_attack_usage_bonus: int = 0,
	p_defender_defense_usage_bonus: int = 0,
	p_attacker_apply_damage: int = 0,
	p_defender_armor: int = 0,
	p_defender_armor_vs_force: int = 0,
) -> void:
	_attacker_character_id = p_attacker_character_id
	_defender_character_id = p_defender_character_id
	_attacker_attack_skill_modifier = p_attacker_attack_skill_modifier
	_attacker_force_skill_modifier = p_attacker_force_skill_modifier
	_defender_dodge_skill_modifier = p_defender_dodge_skill_modifier
	_defender_parry_skill_modifier = p_defender_parry_skill_modifier
	_defender_unarmed_skill_modifier = p_defender_unarmed_skill_modifier
	_defender_force_skill_modifier = p_defender_force_skill_modifier
	_attacker_attack_usage_bonus = p_attacker_attack_usage_bonus
	_defender_defense_usage_bonus = p_defender_defense_usage_bonus
	_attacker_apply_damage = p_attacker_apply_damage
	_defender_armor = p_defender_armor
	_defender_armor_vs_force = p_defender_armor_vs_force


func is_valid() -> bool:
	return (
		not _attacker_character_id.is_empty()
		and not _defender_character_id.is_empty()
		and _attacker_character_id != _defender_character_id
	)


func duplicate_snapshot() -> CombatReverseModifierProjection:
	return CombatReverseModifierProjection.new(
		_attacker_character_id,
		_defender_character_id,
		_attacker_attack_skill_modifier,
		_attacker_force_skill_modifier,
		_defender_dodge_skill_modifier,
		_defender_parry_skill_modifier,
		_defender_unarmed_skill_modifier,
		_defender_force_skill_modifier,
		_attacker_attack_usage_bonus,
		_defender_defense_usage_bonus,
		_attacker_apply_damage,
		_defender_armor,
		_defender_armor_vs_force,
	)
