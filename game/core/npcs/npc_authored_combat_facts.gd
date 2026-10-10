class_name NpcAuthoredCombatFacts
extends RefCounted

## Immutable definition projection, not mutable skills/equipment or an action VM.
## A beast's limbs and verbs, and the set_temp("apply/...") values an NPC sets on
## itself in create() (serpent.c, the bandit chiefs). A skill's own key (shadow.c's
## apply/blade) adds to that skill as char.c query_skill() does.
const APPLY_KEYS: Array[StringName] = [&"attack", &"damage", &"armor", &"dodge", &"defense", &"parry", &"armor_vs_force", &"blade"]

var _limbs: Array[String] = []
var _verbs: Array[StringName] = []
var _apply: Dictionary[StringName, int] = {}

var intrinsic_attack: int:
	get:
		return apply_value(&"attack")
var intrinsic_damage: int:
	get:
		return apply_value(&"damage")
var intrinsic_armor: int:
	get:
		return apply_value(&"armor")
var intrinsic_dodge: int:
	get:
		return apply_value(&"dodge")


func _init(
	p_limbs: Array[String] = [],
	p_verbs: Array[StringName] = [],
	p_apply: Dictionary[StringName, int] = {},
) -> void:
	_limbs = p_limbs.duplicate()
	_verbs = p_verbs.duplicate()
	_apply = p_apply.duplicate()


## query_temp("apply/<key>") as the NPC set it; 0 when it set none.
func apply_value(key: StringName) -> int:
	return _apply.get(key, 0)


func limbs() -> Array[String]:
	return _limbs.duplicate()


func verbs() -> Array[StringName]:
	return _verbs.duplicate()


func duplicate_snapshot() -> NpcAuthoredCombatFacts:
	return NpcAuthoredCombatFacts.new(_limbs, _verbs, _apply)
