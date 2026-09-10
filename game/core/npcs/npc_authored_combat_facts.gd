class_name NpcAuthoredCombatFacts
extends RefCounted

## Immutable definition projection, not mutable skills/equipment or an action VM.
## Legacy limbs, verbs and the four intrinsic apply values used by serpent.c.
## Actions and Combat projection consumers are intentionally outside BF1.
var _limbs: Array[String] = []
var _verbs: Array[StringName] = []
var _attack: int
var _damage: int
var _armor: int
var _dodge: int

var intrinsic_attack: int:
	get:
		return _attack
var intrinsic_damage: int:
	get:
		return _damage
var intrinsic_armor: int:
	get:
		return _armor
var intrinsic_dodge: int:
	get:
		return _dodge


func _init(
	p_limbs: Array[String] = [],
	p_verbs: Array[StringName] = [],
	p_intrinsic_attack: int = 0,
	p_intrinsic_damage: int = 0,
	p_intrinsic_armor: int = 0,
	p_intrinsic_dodge: int = 0,
) -> void:
	_limbs = p_limbs.duplicate()
	_verbs = p_verbs.duplicate()
	_attack = p_intrinsic_attack
	_damage = p_intrinsic_damage
	_armor = p_intrinsic_armor
	_dodge = p_intrinsic_dodge


func limbs() -> Array[String]:
	return _limbs.duplicate()


func verbs() -> Array[StringName]:
	return _verbs.duplicate()


func duplicate_snapshot() -> NpcAuthoredCombatFacts:
	return NpcAuthoredCombatFacts.new(_limbs, _verbs, _attack, _damage, _armor, _dodge)
