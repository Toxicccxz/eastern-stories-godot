class_name CombatProgressionFacts
extends RefCounted

var _character_id: StringName
var _is_user: bool
var _base_intelligence: int
var _base_spirituality: int
var _attack_skill_definition_id: StringName
var _attack_skill_definition_available: bool
var _experience_gain: int
var _gain_percent: int = 0
var _potential_cap: int = ProgressionRules.ES2_POTENTIAL_CAP

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
## What this side gets where combatd.c gives 1 combat_exp and 1 potential: 1 (ES2),
## or the player's pacing.json player_exp_gain.
var experience_gain: int:
	get:
		return _experience_gain
## Native (A2 落后补偿): percent more on top of experience_gain (ProgressionGain.scaled()).
## 0: ES2.
var gain_percent: int:
	get:
		return _gain_percent
## The most potential that stays unspent: combatd.c's 100, or the player's stage cap (A2).
var potential_cap: int:
	get:
		return _potential_cap


func _init(
	p_character_id: StringName = &"",
	p_is_user: bool = false,
	p_base_intelligence: int = 0,
	p_base_spirituality: int = 0,
	p_attack_skill_definition_id: StringName = &"unarmed",
	p_attack_skill_definition_available: bool = true,
	p_experience_gain: int = 1,
) -> void:
	_character_id = p_character_id
	_is_user = p_is_user
	_base_intelligence = p_base_intelligence
	_base_spirituality = p_base_spirituality
	_attack_skill_definition_id = p_attack_skill_definition_id
	_attack_skill_definition_available = p_attack_skill_definition_available
	_experience_gain = p_experience_gain


## These facts with the A2 knobs set (the player's; NPCs keep ES2's).
func with_progression(gain_percent: int, potential_cap: int) -> CombatProgressionFacts:
	_gain_percent = gain_percent
	_potential_cap = potential_cap
	return self


func is_valid() -> bool:
	return (
		not _character_id.is_empty()
		and not _attack_skill_definition_id.is_empty()
		and _experience_gain >= 1
		and _gain_percent >= 0
		and _potential_cap >= ProgressionRules.ES2_POTENTIAL_CAP
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
		_experience_gain,
	).with_progression(_gain_percent, _potential_cap)
